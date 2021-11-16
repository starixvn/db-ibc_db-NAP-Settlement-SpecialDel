/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SingleType_Update]
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)		= ''
	,@BypassCheckingProcess TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
	,@QueueIds			VARCHAR(MAX)	= NULL	OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT

AS
/*	Created by: Kathy
	Date 20181212
	Task: void single ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190419@Kathy: Change KeyId = 6 for FastMarket and send notification in case of void all marked ticket [Redmine:#108826]
		- 20190605@Kathy: Add keyId = 5 for BetBuilder [Redmine:#106898]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200210@Helen: Hotfix - cashout - not insert 914 [Redmine:#128190]
		- 20200303@Charles: Copy 'epositiontaking' value from translog into bettrans [128921]
		- 20200609@Charles: Remove notify when void tickets [131865]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210206@Max: TVS - Lock TempVariableNumber and can't void cash out ticket [Redmine: #150176]
		- 20210207@Helen: Increase Retry for void process [Redmine: #150178]
		- 20210208@Max: [TVS] Enhance performance of void abnormal account [Redmine: #150204]
		- 20210225@July: HotFix - Update balance CO wrong wallet [Redmine: #150621]
		- 20210401@Kathy:  Enhance Auto Void Retry process [Redmine:#152581]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210601@July: TVS - Abnormal Account - Update Min/MaxWinlostdate into dbo.TicketVoiding_VoidingHistory [Redmine:#152175]
		- 20210622@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210722@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20211115@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
		- 20211122@Max: Hot fix - TVS insert CustLimitBetQueue when void CO ticket [Redmine: #164966]


	Param's explanation:	
		Note: Retry lock single: 5s*16 = 90s(1p30s), Retry lock parlay: 20s*16 = 320s(5p)
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@Movebetdate		DATETIME
			,@MatchDate			DATETIME
			,@ThreadHold		INT = 0-- over threadhold, the parlay process will be locked in systemsetting 
			,@totalMainParlay	INT = 0

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL

	DECLARE @avaiableProcess BIT
			,@isExistMG BIT
			,@isExistFM BIT
			,@isExistFM2	BIT
			,@IsExistBB	BIT
			,@isExistMatch BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@CustBalance XML
			,@IssueTypeId	TINYINT
			,@CustIdsCashOut VARCHAR(MAX)
			,@winlostdate				DATETIME
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistBT					BIT = 0
			,@isExistCashOut			BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@Remark					VARCHAR (500) = ''
			,@isExistLucky3				BIT = 0
			,@Lucky3TransIDs			VARCHAR(MAX)
			,@Lucky3Matches				VARCHAR(MAX) = ''
			,@MatchId_Retry				INT = 0
			,@avaiableProcessRefNo		BIT
			,@ErrCodeRefNo				BIT = 0
			,@ErrMsgRefNo				VARCHAR(300) = '' 

	DECLARE @Retry INT, @Success BIT, @RetryCnt INT
	SET @RetryCnt = 0

			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)
	DECLARE @tmpBalanceMember TABLE (CustId INT, Balance MONEY)		
	DECLARE @tmpCustCashOut TABLE (CustId INT, matchid INT)
	DECLARE @tblTransId_MoveBet TABLE (MatchId INT, TransId BIGINT)
						
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchProcess_Retry (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatch_TransIds (matchid INT, transids NVARCHAR(MAX), isFinish BIT)
	CREATE TABLE #tblMatch (matchid INT, isFinish BIT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #tblMatchParlayProcess_Retry (matchid INT, RefNo BIGINT)

	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		SMALLDATETIME
		,eventdate			DATETIME
		,isFinish			BIT
		,srecommend			INT
		,ruben				TINYINT
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
		 ,matchid	INT
	)

	CREATE TABLE #Lucky3Matches
	(
		MatchID				INT PRIMARY KEY,
		Has1stPrize			BIT,
		NumberOf1stPrize	INT DEFAULT(0),
		NumberOf2ndPrize	INT DEFAULT(0),
		NumberOf3rdPrize	INT DEFAULT(0)
	)

	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)

	DECLARE @tmpTransIdBatch TABLE (
		TransId				BIGINT
		,betid				BIGINT
		,Refno				BIGINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
	)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0

	SET @session = CAST(NEWID() AS NVARCHAR(50))
	
	SET @IssueTypeId = (SELECT IssueTypeId FROM dbo.TicketVoiding_Request WITH (NOLOCK) WHERE RequestId = @RequestId)

	IF @IssueTypeId <> 13 AND @TransIds <> ''
	BEGIN
		SET @FailedTransIds = @TransIds

		INSERT INTO @tmpInputTransId (TransId)
		SELECT	val AS TransId
		FROM	dbo.f_SplitString(@TransIds, ',')
		OPTION (maxrecursion 0)

		SELECT 	@MatchDate = eventdate
		FROM dbo.match WITH(NOLOCK)
		WHERE matchid = @MatchId
	END
	ELSE --13
	BEGIN
		SET @FailedTransIds = NULL

		INSERT INTO #tblMatch_TransIds (matchid, transids)
		SELECT	q.MatchId, q.TransIds
		FROM dbo. TicketVoiding_Queue q WITH (NOLOCK)	
		WHERE q.RequestId = @RequestId
			AND q.StatusId IN (0,1)
			AND q.VoidingHistoryId = @VoidingHistoryId 

		INSERT INTO @tmpInputTransId (TransId)
		SELECT	f.TransId AS TransId
		FROM #tblMatch_TransIds q WITH (NOLOCK)	
			CROSS APPLY (
					SELECT	val AS TransId
					FROM	dbo.f_SplitString(q.TransIds, ',')
				)f
		OPTION (maxrecursion 0)
	END

	SELECT @QueueIds = STUFF((SELECT ',' + CAST(QueueId AS VARCHAR(50)) 
							FROM dbo. TicketVoiding_Queue q WITH (NOLOCK)	
							WHERE q.RequestId = @RequestId
								AND q.StatusId IN (0,1)
								AND q.VoidingHistoryId = @VoidingHistoryId
						FOR XML PATH('')),1,1,'')

	INSERT INTO #tmpTransId(custid, bettype, KeyId, Refno, actual_stake, TicketType, matchid, winlostdate, srecommend)
	SELECT	tl.custid, tl.gameID, 3, tl.translogid, tl.actual_stake, 5 -- Metric gaming
		, tl.eventID
		, tl.winlostdate
		, tl.srecommend
	FROM	@tmpInputTransId t
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON t.TransId = tl.translogid
	WHERE	tl.statusID <> 102			
	
	IF @@ROWCOUNT <> 0
		SET @isExistMG = 1
		
	INSERT INTO #tmpTransId(TransId, custid, bettype, KeyId, TicketType, betdaqid, extrainfo, refcode, betid, matchid, oddsid, winlostdate, Refno, srecommend, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN b.bettype = 38 THEN 5
				WHEN f.GroupId = 1 THEN 6 
				WHEN f.GroupId = 2 THEN 7
				ELSE 1 				
			END AS KeyId
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3			
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			,b.matchid, b.oddsid
			,b.winlostdate, b.refno
			,b.srecommend
			,b.ruben
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.bettype
			)f
	WHERE	b.statusID <> 102		

	--IF @@ROWCOUNT <> 0
	--	SET @isExistMatch = 1
		
	IF NOT EXISTS (SELECT * FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'				

		RETURN
	END

	IF @IssueTypeId = 13 --Abnormal Account
	BEGIN
		DECLARE @MinWinlostdate SMALLDATETIME, @MaxWinlostdate SMALLDATETIME

		SELECT @MinWinlostdate = MIN(winlostdate)
		      ,@MaxWinlostdate = MAX(winlostdate)
		FROM #tmpTransId 

		UPDATE dbo.TicketVoiding_VoidingHistory WITH(ROWLOCK, UPDLOCK)
		SET MinWinlostdate = @MinWinlostdate
		   ,MaxWinlostdate = @MaxWinlostdate
		WHERE RequestId = @RequestId 
			AND VoidingHistoryId = @VoidingHistoryId

	END

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE	b
		SET sporttype 	= m.sporttype
			,eventdate = m.eventdate
		FROM	#tmpTransId b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		
		WHERE bettype NOT IN (9, 29, 2799)
			
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET sporttype	= l.sporttype
			,eventdate = o.eventdate
		FROM	#tmpTransId b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
			
		WHERE bettype IN (10)
	END
	
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET sporttype 	= r.sporttype
			,eventdate = o.EventDate	
		FROM	#tmpTransId b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	IF EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (9,29,2799))
	BEGIN
		UPDATE #tmpTransId
		SET eventdate = winlostdate
		WHERE bettype IN (9,29,2799)	
	END

	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF @IssueTypeId IN (11,13) AND EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE Eventdate <= @Movebetdate)
	BEGIN	
		DELETE 
		FROM #tmpTransId
			OUTPUT	DELETED.matchid, DELETED.TransId
			INTO  @tblTransId_MoveBet (Matchid, TransId)
		WHERE eventdate <= @Movebetdate

		SET @MoveBetMatchIds = CAST((SELECT DISTINCT t.MatchId "@MatchId"
									  , CASE WHEN t.MatchId IN (9,29,2799) THEN  STUFF(ts.TransIds,1,1,'') ELSE NULL END "@TransIds"
								FROM @tblTransId_MoveBet t
									OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
													FROM @tblTransId_MoveBet s
													WHERE s.MatchId = t.MatchId AND t.MatchId IN (9,29,2799)
													FOR XML PATH('')
												)ts	 (TransIds)
								FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
	END

	IF (@IssueTypeId NOT IN (1,10,3) AND @MatchDate <= @Movebetdate)
		OR (@IssueTypeId IN (11,13) AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)) 
	BEGIN   
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Match is under Movebet process, could not void ticket.'
		RETURN
	END

	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#tmpTransId
	WHERE matchid NOT IN (9,29,2799)
	GROUP BY matchid
	UNION ALL
	SELECT	matchid
	FROM	#tmpTransId
	WHERE matchid IN (9,29,2799)
	GROUP BY matchid

	IF @BypassCheckingProcess = 0
	BEGIN
	
		WHILE (1=1)
		BEGIN
			SET @MatchId_Retry = 0
			DELETE #tblMatchProcess
			DELETE #tblMatchParlayProcess

			UPDATE TOP(1) m SET m.isFinish = 1, @MatchId_Retry = m.matchid
			FROM #tblMatch m
			WHERE m.isFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
					,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
					,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
					,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
					,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
					,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
					,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
					,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
					,@isExistBT 				= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
					,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
					,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
					,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
					,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
					,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
					,@isExistLucky3				= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
					,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
			FROM	#tmpTransId b
				OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = b.Bettype
					)f
			WHERE b.matchid = @MatchId_Retry

	
			INSERT INTO #tblMatchProcess(matchid, KeyID)
			SELECT DISTINCT matchid
				, CASE 
					WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
							AND Bettype NOT BETWEEN 801 AND 899
							AND f.GroupId IS NULL
							AND Bettype NOT IN (1231,1232,1233)
						THEN 1 --SB,NG,LC
					WHEN Bettype = 10 THEN 2	-- Outright
					WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
					WHEN f.GroupId = 1 THEN 6 -- FM
					WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
					WHEN Bettype = 38 THEN 5 -- Bet Builder
					WHEN f.GroupId = 2 THEN 7 -- FM 228
					ELSE 0
				END AS KeyID
			FROM #tmpTransId b
				OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = b.Bettype
					)f
			WHERE b.matchid = @MatchId_Retry

			SET @Retry = 0
			SET @Success = 0
			
			IF @MatchId_Retry IN (9,29) --NOT 2799: Virtual Sport
			BEGIN
				INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
				SELECT @MatchId_Retry, refno
				FROM #tmpTransId
				WHERE matchid = @MatchId_Retry

				SET @totalMainParlay = @@ROWCOUNT

				EXEC dbo.NAP_Set_GlobalSettingSel 
					 @LockName = 'ParlayRefno'
					,@ThreadHold = @ThreadHold OUTPUT

			END

			WHILE @Retry < 16 AND @Success = 0
			BEGIN
				SET @Success = 1
				SELECT @ErrCode = 0, @ErrMsg = ''
				-- Apply new way to lock parlay tickets - Sportsbook	
				IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
				BEGIN
					IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
						OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
					BEGIN
						-- checking single proccess
						EXEC dbo.NAP_Admin_CheckingProcess
							@isExistOutright 			= @isExistOutright
							, @isExistMG				= @isExistMG
							, @isExistFM				= @isExistFM
							, @isExistMatch				= @isExistMatch
							, @isExistNG				= @isExistNG
							, @isExistVS				= @isExistVS
							, @isExistBB				= @isExistBB
							, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
							, @isExistFM2				= @isExistFM2
							, @spName					= @spName
							, @avaiableProcess 			= @avaiableProcess OUTPUT
							, @ErrCode					= @ErrCode OUTPUT
							, @ErrMsg					= @ErrMsg OUTPUT
					END

					IF @totalMainParlay > 0
					BEGIN
						-- checking Refno parlay proccess
						EXEC dbo.NAP_Admin_CheckingProcess
							 @IsLockingByRefno	= 1
							,@spName			= @spName
							,@Session			= @Session
							,@avaiableProcess 	= @avaiableProcessRefNo OUTPUT
							,@ErrCode			= @ErrCodeRefNo OUTPUT
							,@ErrMsg			= @ErrMsgRefNo OUTPUT
					END
							
				END
				ELSE IF @totalMainParlay > @ThreadHold
				BEGIN
					-- checking SD proccess
					EXEC dbo.NAP_Admin_CheckingProcess
						@isExistParlay 				= @isExistParlay
						, @isExistOutright 			= @isExistOutright
						, @isExistMG				= @isExistMG
						, @isExistFM				= @isExistFM
						, @isExistMatch				= @isExistMatch
						, @isExistNG				= @isExistNG
						, @isExistVS				= @isExistVS
						, @isExistBB				= @isExistBB
						, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
						, @isExistFM2				= @isExistFM2
						, @spName					= @spName
						, @avaiableProcess 			= @avaiableProcess OUTPUT
						, @ErrCode					= @ErrCode OUTPUT
						, @ErrMsg					= @ErrMsg OUTPUT
				
				END

				IF(@ErrCode <> 0 OR @avaiableProcess = 0 --Single + SD
					OR @ErrCodeRefNo <> 0 OR @avaiableProcessRefNo = 0 --Refno 
					) 
				BEGIN
					SET @Retry = @Retry + 1
					SET @Success = 0

					--Waitfor Delay
					IF @isExistMatch = 1
					BEGIN
						WAITFOR DELAY '00:00:05'
					END
					ELSE IF (@isExistParlay = 1) OR (@ErrCodeRefNo <> 0 OR @avaiableProcessRefNo = 0)
					BEGIN
						WAITFOR DELAY '00:00:20'
						SELECT  @ErrCode = @ErrCodeRefNo, @ErrMsg = @ErrMsgRefNo --Output message
					END
				END
				ELSE 
				BEGIN
					INSERT INTO #tblMatchProcess_Retry(matchid, KeyID)
					SELECT matchid, KeyID
					FROM #tblMatchProcess

					IF @totalMainParlay > 0 AND @totalMainParlay <= @ThreadHold
					BEGIN
						INSERT INTO #tblMatchParlayProcess_Retry(matchid, RefNo)
						SELECT matchid, RefNo
						FROM #tblMatchParlayProcess
					END
				END
				
			END
	
			IF @Success = 0 
			BEGIN
			
				DELETE #tblMatchProcess
				DELETE #tblMatchParlayProcess

				INSERT INTO #tblMatchProcess(matchid, KeyID)
				SELECT matchid, KeyID
				FROM #tblMatchProcess_Retry

				IF @totalMainParlay > 0 AND @totalMainParlay <= @ThreadHold
				BEGIN
					INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
					SELECT matchid, RefNo
					FROM #tblMatchParlayProcess_Retry
				END

				SELECT @ErrCode = 101

				SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
						,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
						,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
						,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
						,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
						,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
						,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
						,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
						,@isExistBT 				= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
						,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
						,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
						,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
						,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
						,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
						,@isExistLucky3				= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
						,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
				FROM	#tmpTransId b
					INNER JOIN #tblMatchProcess_Retry m ON m.matchid = b.matchid
					OUTER APPLY (
								SELECT GroupId
								FROM dbo.f_TVS_CheckingProcessGroupBettypes()
								WHERE Bettype = b.Bettype
						)f

				-- Apply new way to lock parlay tickets
				IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
				BEGIN
					IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
						OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
					BEGIN
						EXEC dbo.NAP_Admin_CheckingProcess
							@isExistOutright 			= @isExistOutright
							, @isExistMG				= @isExistMG
							, @isExistFM				= @isExistFM
							, @isExistMatch				= @isExistMatch
							, @isExistNG				= @isExistNG
							, @isExistVS				= @isExistVS
							, @isExistBB				= @isExistBB
							, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
							, @isExistFM2				= @isExistFM2
							, @IsReleased				= 1	
					END
					
					IF @totalMainParlay > 0 
					BEGIN
						------ releasing Refno parlay proccess
						EXEC dbo.NAP_Admin_CheckingProcess
							@IsLockingByRefno = 1
						   ,@Session	= @Session
						   ,@IsReleased = 1							
					END				
				END
				ELSE IF @totalMainParlay > @ThreadHold
				BEGIN
					EXEC dbo.NAP_Admin_CheckingProcess
						@isExistParlay 				= @isExistParlay
						, @isExistOutright 			= @isExistOutright
						, @isExistMG				= @isExistMG
						, @isExistFM				= @isExistFM
						, @isExistMatch				= @isExistMatch
						, @isExistNG				= @isExistNG
						, @isExistVS				= @isExistVS
						, @isExistBB				= @isExistBB
						, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
						, @isExistFM2				= @isExistFM2
						, @IsReleased				= 1
				END

				RETURN;
			END

		END

		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT matchid, KeyID
		FROM #tblMatchProcess_Retry

		IF @totalMainParlay > 0 AND @totalMainParlay <= @ThreadHold
		BEGIN
			INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
			SELECT matchid, RefNo
			FROM #tblMatchParlayProcess_Retry
		END
	END
	ELSE
	BEGIN
		DECLARE @tmpRemainingBatchTransIds TABLE (TransIds VARCHAR(MAX))
		DECLARE @tmpRemainingTransId TABLE (TransId BIGINT)

		INSERT INTO @tmpRemainingBatchTransIds (TransIds)
		SELECT	q.TransIds
		FROM	dbo.TicketVoiding_Queue q WITH (NOLOCK)	
		WHERE	q.VoidingHistoryId = @VoidingHistoryId 
				AND q.voidingtypeId = 1 -- single
				AND StatusId = 0
				AND q.MatchId = @MatchId

		INSERT INTO @tmpRemainingTransId (TransId)
		SELECT	f.TransId AS TransId
		FROM	@tmpRemainingBatchTransIds t 
			CROSS APPLY (
					SELECT	val AS TransId
					FROM	dbo.f_SplitString(t.TransIds, ',')
				)f
		OPTION (maxrecursion 0)

		;WITH cteRemainingKeyIds
		AS (
			SELECT	@MatchId AS matchid
					,CASE 
						WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
						WHEN Bettype = 38 THEN 5 -- Bet Builder
						WHEN f.GroupId = 1 THEN 6 -- FM
						WHEN f.GroupId = 2 THEN 7 -- FM 228
						WHEN Bettype NOT IN (9, 10, 29, 2799) THEN 1 --SB,NG,LC
						ELSE 0
					END AS KeyID
			FROM	@tmpRemainingTransId t
				LEFT JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
				OUTER APPLY (
						SELECT	GroupId
						FROM	dbo.f_TVS_CheckingProcessGroupBettypes() f
						WHERE	f.Bettype = b.bettype
					)f
			GROUP BY CASE 
						WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
						WHEN Bettype = 38 THEN 5 -- Bet Builder
						WHEN f.GroupId = 1 THEN 6 -- FM
						WHEN f.GroupId = 2 THEN 7 -- FM 228
						WHEN Bettype NOT IN (9, 10, 29, 2799) THEN 1 --SB,NG,LC
						ELSE 0
					END
		)
		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT t.matchid, t.KeyID
		FROM (
			SELECT	DISTINCT matchid
					,CASE 
						WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
						WHEN Bettype = 38 THEN 5 -- Bet Builder
						WHEN f.GroupId = 1 THEN 6 -- FM
						WHEN f.GroupId = 2 THEN 7 -- FM 228
						WHEN Bettype NOT IN (9, 10, 29, 2799, 1231,1232,1233) THEN 1 --SB
						ELSE 0
					END AS KeyID
			FROM	#tmpTransId b
				OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = b.Bettype
					)f
		) t
			LEFT JOIN cteRemainingKeyIds r
				ON	t.matchid = r.matchid
					AND t.KeyID = r.KeyID
		WHERE r.matchid IS NULL		

		IF @MatchDate <= @Movebetdate
		BEGIN
			SELECT	@isExistMatch = CASE WHEN KeyID = 1 THEN 1 ELSE 0 END
					,@isExistMG = CASE WHEN KeyID = 3 THEN 1 ELSE 0 END
					,@isExistBB = CASE WHEN KeyID = 5 THEN 1 ELSE 0 END
					,@isExistFM = CASE WHEN KeyID = 6 THEN 1 ELSE 0 END
					,@isExistFM2 = CASE WHEN KeyID = 7 THEN 1 ELSE 0 END
			FROM	#tblMatchProcess

			EXEC dbo.NAP_Admin_CheckingProcess
					@isExistMG				= @isExistMG
				  , @isExistFM				= @isExistFM
				  , @isExistMatch			= @isExistMatch
				  , @isExistBB				= @isExistBB
				  , @isExistFM2				= @isExistFM2
				  , @IsReleased				= 1

			SELECT	@ErrCode = 99
					,@ErrMsg = 'Match is under Movebet process, could not void ticket.'
			
			RETURN
		END
	END

	SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistBT 				= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistLucky3				= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM	#tmpTransId b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid)
	SELECT	t.transid
	FROM	#tmpTransId t	
	WHERE	t.TicketType = 3

	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
		@Mode = 'Original'
		,@Action = 'Void'
		,@IsReleased = 0

	DELETE	t
	FROM	#tmpTransId t
		 INNER JOIN #tblCashOutProcess co
				 ON t.transid = co.transid					
					AND co.IsAvailable = 0

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId t)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'

		------ releasing SD process
		IF @BypassCheckingProcess = 0
		BEGIN
			-- Apply new way to lock parlay tickets
			IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
			BEGIN
				IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
						OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
				BEGIN
					EXEC dbo.NAP_Admin_CheckingProcess
						@isExistOutright 			= @isExistOutright
						, @isExistMG				= @isExistMG
						, @isExistFM				= @isExistFM
						, @isExistMatch				= @isExistMatch
						, @isExistNG				= @isExistNG
						, @isExistVS				= @isExistVS
						, @isExistBB				= @isExistBB
						, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
						, @isExistFM2				= @isExistFM2
						, @IsReleased				= 1
				END

				IF @totalMainParlay > 0 
				BEGIN
					EXEC dbo.NAP_Admin_CheckingProcess
						@IsLockingByRefno = 1
						,@Session	= @Session
						,@IsReleased = 1						
				END				
			END
			ELSE IF @totalMainParlay > @ThreadHold
			BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					, @isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @IsReleased				= 1
			END

		END
		ELSE --@BypassCheckingProcess = 1	
			EXEC dbo.NAP_Admin_CheckingProcess
				  @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistBB				= @isExistBB
				, @isExistFM2				= @isExistFM2
				, @IsReleased				= 1
		
			
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original' 
			  , @Action = 'Void'
			  , @IsReleased = 1				

		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO #tmpTransId (TransId, custid, Refno, bettype, TicketType, isSubTransaction, matchid, sporttype, srecommend)
		SELECT	sub.transid, sub.custid, sub.refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, main.matchid, main.sporttype, sub.srecommend
		FROM	#tmpTransId main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = main.matchid
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)

		-- cashout bet ticket, 912, 913
		INSERT INTO #tmpTransId(TransId,custid, Refno, bettype, TicketType, isSubTransaction, matchid, sporttype, srecommend)
		SELECT	sub.TransId,sub.custid, sub.Refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, sub.matchid, sub911.sporttype, sub.srecommend
		FROM	#tmpTransId sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = sub911.matchid
		WHERE	sub.statusID NOT IN (101, 102)
				AND sub911.bettype = 911

		INSERT INTO @tmpCustCashOut(CustId, matchid)
		SELECT DISTINCT	t.custid, t.matchid
		FROM	#tmpTransId t
		WHERE	t.TicketType = 3
				AND t.bettype = 912
		GROUP BY t.custid, t.matchid
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 5)
	BEGIN
		INSERT INTO [bodb02].[dbo].[bettrans]  (
				[custid]  
				,[transdate]  
				,[oddsid]  
				,[hdp1]  
				,[hdp2]  
				,[odds]  
				,[stake]  
				,[status]  
				,[winlost]  
				,[awinlost]  
				,[mwinlost]  
				,[playercomm]  
				,[comm]  
				,[acomm]  
				,[apositiontaking]  
				,[mpositiontaking]  
				,[tpositiontaking]  
				,[playerdiscount]  
				,[discount]  
				,[adiscount]  
				,[livehomescore]  
				,[liveawayscore]  
				,[liveindicator]  
				,[betteam]  
				,[creator]  
				,[refno]  
				,[comstatus]  
				,[winlostdate]  
				,[betfrom]  
				,[betcheck]  
				,[checktime]  
				,[oddsspread]  
				,[actualrate]  
				,[matchid]  
				,[recommend]  
				,[mrecommend]  
				,[ruben]  
				,[betid]  
				,[statuswinlost]  
				,[modds]  
				,[bettype]  
				,[betdaqid]  
				,[actual_stake]  
				,[currency]  
				,[ip]  
				,[transdesc]  
				,[sdiscount]  
				,[scomm]  
				,[spositiontaking]  
				,[swinlost]  
				,[srecommend]  
				,[Username]  
				,[CurrencyName]  
				,[virtualrate]  
				,[oddstype]  
				,[statusID]  
				,[currency2]  
				,[balance]  
				,[SecAcceptFlag]  
				,[transid2]  
				,[RecommDate]
				,[epositiontaking]
		)  
		SELECT	tl.[custid]  
				,tl.[transdate]  
				,0 [oddsid]  
				,0 [hdp1]  
				,0 [hdp2]  
				,tl.[odds]  
				,tl.[stake]  
				,tl.[status]  
				,0 [winlost]  
				,0 [awinlost]  
				,0 [mwinlost]  
				,0 [playercomm]  
				,0 [comm]  
				,0 [acomm]  
				,tl.[apositiontaking]  
				,tl.[mpositiontaking]  
				,tl.[tpositiontaking]  
				,tl.[playerdiscount]  
				,tl.[discount]  
				,tl.[adiscount]  
				,0 [livehomescore]  
				,0 [liveawayscore]  
				,tl.[liveindicator]  
				,SUBSTRING(tl.[transdesc],11,CHARINDEX(';BettypeTime',tl.[transdesc],0) - 11) [betteam]  
				,tl.[creator]  
				,tl.translogid [refno]  
				,tl.custom2 [comstatus]  
				,tl.[winlostdate]  
				,tl.[betfrom]  
				,tl.transdate [betcheck]  
				,NULL [checktime]  
				,0 [oddsspread]  
				,tl.[actualrate]  
				,tl.EventID  
				,tl.[recommend]  
				,tl.[mrecommend]  
				--,1 [ruben]  
				,0 [ruben] --#94603
				,CASE WHEN ISNULL(tl.custom3,'') = '' THEN NULL ELSE CAST(tl.custom3 AS BIGINT) END [betid]  
				,NULL [statuswinlost]  
				,0 [modds]  
				,tl.GameID [bettype]  
				,NULL [betdaqid]  
				--,b.[actual_stake] --#94603 
				,0 [actual_stake]
				,tl.[currency]  
				,tl.[ip]  
				,tl.[transdesc]  
				,tl.[sdiscount]  
				,0 [scomm]  
				,tl.[spositiontaking]  
				,0 [swinlost]  
				,tl.[srecommend]  
				,tl.[Username]  
				,tl.[CurrencyName]  
				,tl.[virtualrate]  
				,tl.custom1 [oddstype]  
				,tl.[statusID]  
				,NULL [currency2]  
				,tl.[balance]  
				,0 [SecAcceptFlag]  
				,0 [transid2]  
				,NULL [RecommDate]
				,tl.[epositiontaking] 				
			FROM #tmpTransId t
				INNER JOIN dbo.translog tl WITH(NOLOCK)  
					ON tl.translogid = t.Refno
			WHERE NOT EXISTS (
					SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK) 
					WHERE b.custid = tl.custid 
						AND b.refno = tl.translogid 
						AND b.matchid = tl.eventID
				)

		UPDATE  t
			SET TransId = b.transid
				,betid = ISNULL(b.BetID, rs.ResultID)
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.Refno = b.refno
					AND b.matchid = t.matchid
					AND b.bettype = t.bettype
					AND b.custid = t.custid
			OUTER APPLY (
				SELECT	rs.ResultID
				FROM	DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)
				WHERE	(
							(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0)
							OR b.bettype = 806
						)
						AND rs.GameID = b.bettype	
						AND rs.VendorID = 5		
						AND rs.MatchID = b.matchid	
			) rs
		WHERE	t.TicketType = 5

	END

	-- Insert more bonus or cash ticket in case only one ticket appears in #tmpTransId	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid, matchid)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid, t.matchid
	FROM	#tmpTransId t
	WHERE	t.refcode IS NOT NULL
	GROUP BY t.refcode, t.custid, t.bettype, t.matchid

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId (TransId, custid, bettype, KeyId, TicketType, refcode, matchid)
		SELECT b.TransId, b.custid, b.bettype, 1, 1, b.refcode, b.matchid
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = r.matchid
					AND b.custid = r.custid
					AND b.bettype = r.bettype
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE b.transid = TransId)
	END

	SET @FailedTransIds = NULL

	;WITH cteResult 
	AS(
		SELECT	refno AS TransId
		FROM	#tmpTransId
		WHERE	TicketType = 5
		UNION ALL
		SELECT	TransId 
		FROM	#tmpTransId
		WHERE	TicketType <> 5
	)
	SELECT	@FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(it.TransId AS VARCHAR(30)), CAST(it.TransId AS VARCHAR(30)))
	FROM	@tmpInputTransId it
	WHERE	NOT EXISTS (SELECT * FROM cteResult c WHERE c.TransId = it.TransId)
			AND 1 = CASE WHEN @IssueTypeId <> 13 THEN 1 
						 WHEN @IssueTypeId = 13 AND NOT EXISTS (SELECT TOP 1 1 FROM @tblTransId_MoveBet m WHERE m.TransId = it.TransId) THEN 1
						 ELSE 0 END

	-- backup into zzzbettrans
	INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
			,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
			,betteam, creator, refno, winlostdate, betfrom
			,betcheck
			,comstatus
			,checktime, matchid, bettype  
			,VoidingHistoryId
		)  
	SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
		,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
		,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
		,CASE 
			WHEN t.TicketType = 3 THEN @session -- original ticket & cashout bet ticket
			ELSE b.betcheck END AS betcheck 
		,CASE WHEN t.TicketType = 3 AND t.isSubTransaction = 1 THEN 'CO' ELSE b.comstatus END
		,b.checktime, b.matchid, b.bettype  
		,@VoidingHistoryId
	FROM	#tmpTransId AS t WITH (NOLOCK)  
		INNER JOIN dbo.bettrans b WITH (NOLOCK)  
			ON b.transid = t.TransId

	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		INSERT INTO #balanceGameBefore(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END AS groupId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1201 AND 1299
			OR b.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END

	--capture balance before voiding
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	b.matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	t.matchid
				,b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost 
					- CASE 
						WHEN t.TicketType = 5 THEN t.actual_stake -- get actual_stake from translog
						ELSE b.actual_stake 
					END 
					+ b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
		UNION ALL
		SELECT	b914.matchid
				,b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = c.matchid
					AND b914.custid = c.CustId
					AND b914.bettype = 914
	)b
	GROUP BY b.matchid
			,b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIdBatch

		UPDATE TOP(2000) t
			SET t.isFinish = 1
		OUTPUT deleted.TransId
			,deleted.TicketType
			,deleted.Refno
			,deleted.betid
			,deleted.actual_stake
			,deleted.isSubTransaction
		INTO @tmpTransIdBatch(TransId, TicketType, Refno, betid, actual_stake, isSubTransaction)
		FROM #tmpTransId t
		WHERE t.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		SELECT @xmlTransId = (SELECT	t.TransId AS '@transid'
										,CASE WHEN t.TicketType = 5 THEN t.Refno ELSE NULL END AS '@translogid'
										,t.betid AS '@betid'
										,CASE WHEN t.TicketType = 5 THEN 1 ELSE NULL END AS '@isMG'
										,CASE WHEN t.TicketType = 5 THEN t.actual_stake ELSE NULL END AS '@actual_stake'
										,t.isSubTransaction AS '@IsCashOutMember'
								FROM	@tmpTransIdBatch t
								FOR XML PATH('r'), ROOT('root')
							)
	
						
		EXEC dbo.TicketVoiding_Admin_VoidingTransId 
			@TransIds = @xmlTransId
			,@UserId = @UserId
			,@IssueTypeId = @IssueTypeId

		SET @xmlTransId = ''

	END

	-- PRE CAL 914
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 3)
	BEGIN
		BEGIN TRY				
			DECLARE @TempDataBT1 TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
			INSERT INTO @TempDataBT1(MatchId, CustIds)
			SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
									FROM @tmpCustCashOut tt 
									where tt.MatchId = t.MatchId
									FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
			FROM @tmpCustCashOut t
			GROUP BY MatchId
				
			DECLARE @RowIdBT1 INT, @MatchIdTmpBT1 INT, @CustIdsBT1 VARCHAR(MAX)
			SELECT @RowIdBT1 = 1
			WHILE EXISTS (SELECT TOP 1 1 FROM @TempDataBT1 WHERE RowId = @RowIdBT1)
			BEGIN
				SELECT @MatchIdTmpBT1 = MatchId
					, @CustIdsBT1 = CustIds
				FROM @TempDataBT1 t 
				WHERE RowId = @RowIdBT1
					
				EXEC dbo.NAP_Admin_Calculate_914 
					@MatchId 	= @MatchIdTmpBT1
					, @Action 	= 'VOID'
					, @CustIds 	= @CustIdsBT1
						
				SET @RowIdBT1 = @RowIdBT1 + 1
			END				
		END TRY 
		BEGIN CATCH
			SELECT @ErrCode = 914
					, @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
		END CATCH
	END

	-- PRE CAL 501 Cricket - charge comm
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE bettype = 501)
	BEGIN
		DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))		
		BEGIN TRY
			INSERT INTO @TempData(MatchId, CustIds)
			SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
									FROM #tmpTransId tt where tt.MatchId = t.MatchId
									FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
			FROM #tmpTransId t
			WHERE Bettype = 501
			GROUP BY MatchId

			IF EXISTS (SELECT TOP 1 1 FROM @TempData)
			BEGIN
				DECLARE @RowId INT, @MatchIdTmp INT, @CustIdsCricket VARCHAR(MAX)
				SELECT @RowId = 1
				WHILE EXISTS (SELECT TOP 1 1 FROM @TempData WHERE RowId = @RowId)
				BEGIN
					SELECT @MatchIdTmp = MatchId
						, @CustIdsCricket = CustIds
					FROM @TempData t WHERE RowId = @RowId
					SET @RowId = @RowId + 1
					
					EXEC dbo.NAP_Admin_Calculate_500 @MatchId	= @MatchIdTmp
						, @Action = 'VOID'
						, @CustIds = @CustIdsCricket
				END
			END
		END TRY 
		BEGIN CATCH
			SELECT	@ErrCode = 500
				,@ErrMsg = 'Called NAP_Admin_Calculate_500 with error.'
		END CATCH
	END

	IF (@isExistLucky3 = 1)
	BEGIN
		SELECT @Lucky3TransIDs = STUFF(
										(
											SELECT ',' + CAST(transid AS VARCHAR(MAX))
											FROM #tmpTransId
											WHERE Bettype = 1600
											FOR XML PATH('')
										), 1, 1, '')
		
		INSERT INTO #Lucky3Matches(MatchID, Has1stPrize)
		SELECT	r.MatchId,
				MAX(CASE r.Prize WHEN 1 THEN 1 ELSE 0 END)
		FROM dbo.BetLucky3Result r WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #tmpTransId b WHERE b.transid = r.TransId AND b.Bettype = 1600)
			AND r.Bettype = 1601
		GROUP BY r.matchid
		
		--Delete data in betLucky3Result
		EXEC dbo.NAP_Admin_PreCalculate_s160 @MatchId = 0, @Mode = 'preCAL', @Action = 'VOID', @strVoidedTransId = @Lucky3TransIDs,
											@FirstBall = NULL, @SecondBall = NULL, @ThirdBall = NULL, @FirstPrizeMaxCount = NULL,
											@PrizeSettingId = NULL, @strCustSetting = NULL
		
		UPDATE l
		SET NumberOf1stPrize = d.NumberOf1stPrize,
			NumberOf2ndPrize = d.NumberOf2ndPrize,
			NumberOf3rdPrize = d.NumberOf3rdPrize
		FROM #Lucky3Matches l
			JOIN (
				SELECT  r.MatchId,
						SUM(CASE r.Prize WHEN 1 THEN Odds * Hits ELSE 0 END) AS NumberOf1stPrize,
						SUM(CASE r.Prize WHEN 2 THEN Odds * Hits ELSE 0 END) AS NumberOf2ndPrize,
						SUM(CASE r.Prize WHEN 3 THEN Odds * Hits ELSE 0 END) AS NumberOf3rdPrize
				FROM dbo.BetLucky3Result r WITH(NOLOCK)
				WHERE EXISTS (SELECT 1 FROM #Lucky3Matches l1 WHERE r.MatchId = l1.MatchID)
					AND r.Bettype = 1601
				GROUP BY r.MatchId
			) d ON l.MatchID = d.MatchId
		
		SELECT @Lucky3Matches = CAST((	SELECT	MatchID AS '@m',
												NumberOf1stPrize AS '@fn',
												NumberOf2ndPrize AS '@sn',
												NumberOf3rdPrize AS '@tn'
										FROM #Lucky3Matches
										FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX))
		
		--Update match prize count
		EXEC DBPRO.bodb02.dbo.NAP_Admin_Match_Update_s160 @Action = NULL, @IsAuto = 0, @strMatchInfo = @Lucky3Matches
		
	END
	
	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		INSERT INTO #balanceGameAfter(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR tmp.Bettype BETWEEN 1201 AND 1299
			OR tmp.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END

	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	b.matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	t.matchid
				,b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
		UNION ALL
		SELECT b914.matchid
				,b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = c.matchid
					AND b914.custid = c.CustId
					AND b914.bettype = 914
	)b
	GROUP BY b.matchid
			,b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--UPDATE balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd
			, @ActionId				= 0	

	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		
		CREATE TABLE #balanceGameChange (
			custid 			INT
			,winlostdate 	SMALLDATETIME
			,balance 		MONEY
			,bettype		SMALLINT
			,gametypeid		SMALLINT			
			,Increased 		BIT
		)

		INSERT INTO #balanceGameChange (custid, winlostdate, balance, bettype, gametypeid, Increased)
		SELECT	b.custid
				,b.winlostdate
				,a.winlost - b.winlost
				,a.groupid
				,a.gametypeid
				,CASE WHEN a.winlost > b.winlost THEN 1 ELSE 0 END
		FROM	#balanceGameBefore b
			INNER JOIN #balanceGameAfter a 
				ON	b.custid 		= a.custid
				AND b.winlostdate 	= a.winlostdate
				AND a.gametypeid = b.gametypeid
				AND a.groupid = b.groupid
		WHERE	b.winlost <> a.winlost
		
		INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,ABS(balance)
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 0

		INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,balance
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 1
		
		DROP TABLE #balanceGameChange
	END

	-- Update BetTradeSellingCancelled information
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	#tmpTransId t
	WHERE	t.bettype = 911
	GROUP BY t.custid

	EXEC dbo.TicketVoiding_BalanceMember_Select 
		@CustIds = @CustIds
		,@CustBalance = @CustBalance OUTPUT

	INSERT INTO @tmpBalanceMember (CustId, Balance)
	SELECT	T.C.value('./@c', 'int')
			,T.C.value('./@b', 'money')
	FROM	@CustBalance.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustBalance = NULL ))

	;WITH CTE_Source AS
		(
			SELECT	bts.TradeID AS TradeID
					,bts.TicketID AS [TicketID]					
					,'SB void ticket due to ' AS [Remark]
					,sub.awinlost AS [BTBuyBack]
					,0 AS [BTComission]
					,c.Balance AS [AfterBalance]
					,'SB' AS [Owner]
					,1 AS [Cancelled]
					,GETDATE() AS [ChangeDate]
					,GETDATE() AS [CreateDate]
			FROM	#tmpTransId sub						 											 
				 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
						 ON bts.TicketID = sub.refno -- bettrade + cash-out
							AND CASE																				 
									WHEN sub.bettype = 911 -- cash-out													 
											THEN CASE
													WHEN bts.SoldTicketID = sub.transid THEN 1
													ELSE 0
												 END																							
									ELSE 1
								END = 1	
				 INNER JOIN @tmpBalanceMember c
						 ON sub.custid = c.custid						 							
			WHERE sub.BetType = 911
		)
		MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
		USING (SELECT * FROM CTE_Source) AS [Source]
		ON [Target].TradeID = [Source].TradeID
		WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
									,[BTBuyBack] = [Source].[BTBuyBack]
									,[BTComission] = [Source].[BTComission]
									,[AfterBalance] = [Source].[AfterBalance]
									,[Owner] = [Source].[Owner]
									,[Cancelled] = [Source].[Cancelled]
									,[ChangeDate] = [Source].[ChangeDate]										
		WHEN NOT MATCHED THEN INSERT(TradeID
									,[TicketID]										
									,[Remark]
									,[BTBuyBack]
									,[BTComission]
									,[AfterBalance]
									,[Owner]
									,[Cancelled]
									,[ChangeDate]
									,[CreateDate])
							  VALUES([Source].TradeID
									,[Source].[TicketID]										
									,[Source].[Remark]
									,[Source].[BTBuyBack]
									,[Source].[BTComission]
									,[Source].[AfterBalance]
									,[Source].[Owner]
									,[Source].[Cancelled]
									,[Source].[ChangeDate]
									,[Source].[CreateDate]); 

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE TicketType = 5)
	BEGIN		
		INSERT INTO dbo.BettradeAPI (
					transid
					,matchid
					,[Session]
					,[action]
					,buybackNo
					,Payout
					,Remark
			)
		SELECT	b.TicketID
				,b.MatchID
				,@session
				,'VOID'
				,b.BuyBackNo
				,b.PayOut
				,'SB void ticket due to ' 
		FROM	#tmpTransId t
			INNER JOIN dbo.BetTradeSelling b WITH(NOLOCK)
				ON t.TransId = b.TicketID
		WHERE	t.TicketType = 5
			AND b.[Status] IN ('Accept', 'Confirm')
	END

	IF @BypassCheckingProcess = 0
	BEGIN
		IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
		BEGIN
			IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
				OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
			BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @IsReleased				= 1
			END

			IF @totalMainParlay	> 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1				
			END			
		END
		ELSE IF @totalMainParlay > @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay 				= @isExistParlay
				, @isExistOutright 			= @isExistOutright
				, @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @IsReleased				= 1
		END
	END
	ELSE --@BypassCheckingProcess = 1
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMG				= @isExistMG
			, @isExistFM				= @isExistFM
			, @isExistMatch				= @isExistMatch
			, @isExistBB				= @isExistBB
			, @isExistFM2				= @isExistFM2
			, @IsReleased				= 1
	END	
	
	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 1
		  
	----------------Insert Max Payout Queue----------------
	DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL
	DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, IsFinish BIT)

	IF @IssueTypeId = 13
	BEGIN
		INSERT INTO @Match_tmp (MatchId, sporttype)
		SELECT DISTINCT t.matchid, t.sporttype
		FROM #tmpTransId t

		WHILE (1=1)
		BEGIN
			SELECT @TransIds_MaxPO = '', @MatchId_MaxPO = NULL, @sporttype = NULL
		
			UPDATE TOP(1) mt SET mt.isFinish = 1, @MatchId_MaxPO = mt.matchid, @sporttype = mt.sporttype
			FROM @Match_tmp mt
			WHERE mt.isFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
						,CASE 
							WHEN dp.custid IS NOT NULL THEN 3 --deposit 
							WHEN c.site = '789y' THEN 2 --789y
							ELSE 1 END AS '@sitetype'
						,b.TransId AS '@transid'
						,b.bettype AS '@bettype'
					FROM #tmpTransId b
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
					WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype AND b.bettype NOT IN (9,29,2799)
					FOR XML PATH('r'), ROOT('root')
				)

			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
				@MatchId = @MatchId_MaxPO
				,@sporttype = @sporttype
				,@TransidList = @TransIds_MaxPO
		END
	END
	ELSE
	BEGIN
		SET @sporttype = (SELECT DISTINCT m.sporttype FROM #tmpTransId m WITH (NOLOCK) WHERE m.matchid = @MatchID)

		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
					,CASE 
						WHEN dp.custid IS NOT NULL THEN 3 --deposit 
						WHEN c.site = '789y' THEN 2 --789y
						ELSE 1 END AS '@sitetype'
					,b.TransId AS '@transid'
					,b.bettype AS '@bettype'
				FROM #tmpTransId b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.matchid = @MatchId AND b.sporttype = @sporttype AND b.bettype NOT IN (9,29,2799)
				FOR XML PATH('r'), ROOT('root')
			)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE bettype = 29)
	BEGIN
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #tmpTransId t
								GROUP BY custid, ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
	END
	-------------------------------------------------------
	
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	(
		SELECT DISTINCT b.custid
		FROM @BeforeUpd b
			INNER JOIN @AfterUpd a
				ON b.custid = a.custid
					AND b.matchid = a.matchid
					AND b.balanceType = a.balanceType
					AND b.bonusId = a.bonusId
					AND b.walletType = a.walletType
		WHERE	b.balance > a.balance
	)t

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	-- Write Log
	SET @EndTime = GETDATE()
	IF @IssueTypeId = 13
	BEGIN
		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) t
				SET t.isFinish = 1
					, @MatchId = t.matchid
					, @TransIds = t.transids
			FROM #tblMatch_TransIds t
			WHERE t.isFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
									,@LogActionId AS '@LogActionId'
									,@UserId AS '@UserId'
									,@IP AS '@IP'
									,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
										+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
										+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
										+ ' Single ticket with TransId: ' + @TransIds
										AS '@LogData'
							FOR XML PATH ('r'), ROOT ('root'), TYPE
			) AS VARCHAR(MAX))

			EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
		END
	END
	ELSE
	BEGIN
		SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
								,@LogActionId AS '@LogActionId'
								,@UserId AS '@UserId'
								,@IP AS '@IP'
								,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
									+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
									+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
									+ CASE WHEN @IssueTypeId = 11 AND @MatchId = 29 THEN  ' Main Parlay ticket with TransId: ' ELSE ' Single ticket with TransId: '  END + @TransIds
									AS '@LogData'
						FOR XML PATH ('r'), ROOT ('root'), TYPE
		) AS VARCHAR(MAX))

		EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	END
	
	DROP TABLE #tblCashOutProcess
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tmpTransId
	DROP TABLE #balanceGameAfter
	DROP TABLE #balanceGameBefore
	DROP TABLE #Lucky3Matches
	DROP TABLE #tblMatchProcess_Retry
	DROP TABLE #tblMatch
	DROP TABLE #tblMatch_TransIds
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblMatchParlayProcess_Retry
END

GO

