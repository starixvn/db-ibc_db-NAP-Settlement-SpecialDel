/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_RecoverHistorical_Single_Update
(
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX) 
	,@UserId			INT = 0 
	,@IP				VARCHAR(15) =''
	,@IssueTypeId		TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(1000)	= ''	OUTPUT
	,@FailedTransIds    VARCHAR(MAX) = '' OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT
	,@ResettledTransIds   VARCHAR(MAX)	= NULL	OUTPUT
)
AS
/*	
	Created by: 20190823@Kathy
	Task: recover single ticket [Redmine:#115376]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20190823@Kathy: recover single ticket [Redmine:#115376]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20210514@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20250516@July: Recover 14 - Insert changed data into BalanceTrigger table [Redmine: #227625]
		- 20250617@July: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@AffectedList		VARCHAR(MAX)
			,@SiteDBGroupID     SMALLINT = 0
			,@CustIds			VARCHAR(MAX)
			,@IsSiteDB			BIT
			,@TransidList		VARCHAR(MAX) = ''
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@ActionID			INT = 90999 --TVS - Agency Cash Service
			,@session			NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	CREATE TABLE #tblTransInfo (
		 transid		BIGINT PRIMARY KEY
		,stake			MONEY
		,matchid		INT
		,creator		INT
		,status			VARCHAR(20)
		,SportType		TINYINT
		,zzzwinlost		MONEY
		,modds			SMALLMONEY
	)
	
	/*Modify the way to get move bet date*/
	DECLARE @BeingMovebetDate SMALLDATETIME 
		   ,@currentdate SMALLDATETIME = GETDATE()

	DECLARE @tblTransId_MoveBet TABLE (MatchId INT, TransId BIGINT)
		
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	DECLARE @BalanceInfoBeforeUpd TABLE (
		CustId			INT
		,MatchId		INT
		,WinlostDate	DATETIME
		,Winlost		MONEY
		,aWinlost		MONEY
		,mWinlost		MONEY
		,sWinlost		MONEY
		,playerComm		MONEY
		,Comm			MONEY
		,aComm			MONEY
		,sComm			MONEY
		,stake			MONEY
		,actual_stake	MONEY
		,balance		MONEY
	)
	DECLARE @BalanceInfoAfterUpd TABLE (
		CustId			INT
		,MatchId		INT
		,WinlostDate	DATETIME
		,Winlost		MONEY
		,aWinlost		MONEY
		,mWinlost		MONEY
		,sWinlost		MONEY
		,playerComm		MONEY
		,Comm			MONEY
		,aComm			MONEY
		,sComm			MONEY
		,stake			MONEY
		,actual_stake	MONEY
		,balance		MONEY
	)

	DECLARE @tmpInputTransId TABLE(
		TransId BIGINT
		,invalid TINYINT DEFAULT(0)
	)

	CREATE TABLE #tmpTransId (
		TransId			BIGINT
		,MatchId		INT
		,CustId			INT
		,Bettype		SMALLINT
		,ExtraInfo		XML
		,IsAbnormalBet	BIT DEFAULT(0)
		,KeyId			TINYINT DEFAULT(1)
		,Invalid		TINYINT DEFAULT(0)
		,sporttype		SMALLINT
		,eventdate		DATETIME
		,oddsid			INT
		,winlostdate	SMALLDATETIME
		,IsCashOut      BIT DEFAULT(0)
	)

	CREATE TABLE #tblMatch (matchid INT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90200
	SET @SB_Error = 0

	SET @ErrCode = 0
	SET @ErrMsg = ''

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')

	INSERT INTO #tmpTransId (TransId, MatchId, CustId, Bettype, KeyId, invalid, oddsid, winlostdate, IsCashOut)
	SELECT	b14.transid
			,b14.matchid
			,b14.custid
			,b14.bettype
			,CASE 
				WHEN f.GroupId = 1 THEN 6
				WHEN f.GroupID = 2 THEN 7
				ELSE 1
			END AS KeyId
			,CASE 
				WHEN b14.statuswinlost IS NULL OR b14.statuswinlost NOT BETWEEN 0 AND 6 THEN 2 -- not have 'statuswinlost' value
				ELSE 0
			END AS invalid
			,b14.oddsid
			,b14.winlostdate
			,CASE WHEN b14.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK)
			ON	t.TransId = b14.transid
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b14.Bettype
			)f
	WHERE	b14.statusID = 102
			AND b14.betfrom <> 'p'
			AND b14.bettype NOT IN (10, 29)
			AND b14.bettype NOT BETWEEN 801 AND 806
			AND b14.bettype NOT BETWEEN 8101 AND 8120
			AND b14.bettype NOT BETWEEN 81 AND 120
			AND b14.bettype NOT BETWEEN 1201 AND 1299
			AND b14.bettype NOT BETWEEN 2700 AND 2899
			AND b14.SiteDBGroupID = @SiteDBGroupID
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'

		RETURN
	END	

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE	b
		SET eventdate 	= m.eventdate
			,sporttype 	= m.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.match14 m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))		
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET eventdate 	= o.eventdate
			,sporttype	= l.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid			
		WHERE bettype IN (10)
	END
		
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET eventdate	= o.eventdate
			,sporttype 	= r.sporttype	
		FROM	#tmpTransId b
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
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

	IF EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)))
	BEGIN
		UPDATE #tmpTransId
		SET eventdate = winlostdate
		WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))	
	END

	UPDATE t 
		SET invalid = i.invalid
	FROM	@tmpInputTransId t
		LEFT JOIN #tmpTransId r
			ON t.TransId = r.TransId
		OUTER APPLY (
			SELECT CASE 
						WHEN EXISTS (SELECT TOP 1 1 FROM dbo.bettrans b WITH(NOLOCK) WHERE b.transid = t.TransId AND b.statusID = 102) THEN 3  -- data has not been moved yet
						WHEN r.transId IS NULL THEN 1 -- not pass validation rule
						WHEN r.invalid > 0 THEN r.invalid
					END AS invalid
		) AS i
			
	-- get current beingmovebetdate if movebet in-progress, paste @currentdate to get @BeingMovebetDate only
	EXEC [dbo].[NAP_Admin_VerifySettleDate] @Winlostdate = @currentdate, @BeingMovebetDate = @BeingMovebetDate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE Eventdate <= @BeingMovebetDate)
	BEGIN	
		DELETE 
		FROM #tmpTransId
			OUTPUT	DELETED.matchid, DELETED.TransId
			INTO  @tblTransId_MoveBet (Matchid, TransId)
		WHERE eventdate <= @BeingMovebetDate

		SET @ErrCode = 99 
		SET @MoveBetMatchIds = CAST((SELECT DISTINCT t.MatchId "@MatchId"
									  , CASE WHEN t.MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN  STUFF(ts.TransIds,1,1,'') ELSE NULL END "@TransIds"
								FROM @tblTransId_MoveBet t
									OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
													FROM @tblTransId_MoveBet s
													WHERE s.MatchId = t.MatchId AND t.MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
													FOR XML PATH('')
												)ts	 (TransIds)
								FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
	END
	
	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#tmpTransId
	GROUP BY matchid
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpInputTransId WHERE invalid > 0)
	BEGIN
		DECLARE @Msg VARCHAR(MAX) = ''

		SET @ErrCode = 100
		SET @ErrMsg = ''

		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 1

		IF @@rowcount > 0
			SELECT	@ErrCode = 100
			SET @ErrMsg = 'Invalid transid: ' + STUFF(@Msg, 1, 1, '') + '. '

		SET @Msg = ''		
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 2

		IF @@rowcount > 0
			SELECT	@ErrCode = 101
			SET @ErrMsg = @ErrMsg + 'Existing data but do not have statuswinlost value: ' + STUFF(@Msg, 1, 1, '') + '. '

		SET @Msg = ''
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 3

		IF @@rowcount > 0
			SELECT	@ErrCode = 102
			SET @ErrMsg = @ErrMsg + 'Existing but data has not been moved yet: ' + STUFF(@Msg, 1, 1, '') + '. '
		
		SET @Msg = ''
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 4
			
		RETURN
				
	END
	
	IF @IP IS NULL OR @UserId IS NULL
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = @ErrMsg + 'IP and UserID must be inputted.'
		
		RETURN
	END

	INSERT INTO @BalanceInfoBeforeUpd (CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.awinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)
			,SUM(b14.winlost - b14.actual_stake + b14.playercomm) 
	FROM	dbo.bettrans14 b14 WITH(NOLOCK)
		INNER JOIN #tmpTransId t
			ON t.TransId = b14.transid
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate

	INSERT INTO @BeforeUpd (matchid, custid, balanceType, bonusId, walletType, balance)
	SELECT	b14.matchid
			,b14.custid
			,1 AS BalanceType
			,0 AS BonusID
			,2 AS WalletType -- normal tickets are treated as cash tickets
			,SUM(b14.balance) AS balance
	FROM	@BalanceInfoBeforeUpd b14
	GROUP BY b14.custid
			,b14.matchid

	BEGIN TRY
		SELECT @TransidList = (SELECT DISTINCT TransId AS '@transid'
										      ,sporttype  AS '@sporttype'
											  ,IsCashOut  AS '@IsCashOut'
								FROM #tmpTransId
								WHERE IsCashOut = 0
								FOR XML PATH('r'), ROOT('root')
							)

		IF @TransidList <> ''
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Bet14 
				@TransIds = @TransidList
				,@MatchId = @MatchId
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	--Update CashOutSelling for new CO Model
	IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransId WHERE IsCashOut = 1 )
	BEGIN
		BEGIN TRY
			INSERT INTO #tblTransInfo (transid, modds, stake, zzzwinlost, status, creator, matchid)
			SELECT t.TransId, b.modds, b.stake, z.winlost, z.status, z.creator, b.matchid
			FROM @tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	b.transid = z.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid
						AND z.bettype = b.bettype
						AND z.SiteDBGroupID = b.SiteDBGroupID
			WHERE b.betdaqid = -2
				AND ISNULL(z.comstatus,'') <> 'CO'

			UPDATE t SET t.SportType = m.sporttype
			FROM #tblTransInfo t
				CROSS APPLY (
					SELECT Sporttype
					FROM dbo.match14 WITH (NOLOCK)
					WHERE matchid = t.matchid
					UNION
					SELECT Sporttype
					FROM dbo.match WITH (NOLOCK)
					WHERE matchid = t.matchid
				)m

			SELECT @TransidList = (SELECT DISTINCT TransId AS '@transid'
										          ,sporttype  AS '@sporttype'
											      ,1  AS '@IsCashOut'
												  ,zzzwinlost AS '@zzzwinlost'
												  --,modds AS '@modds'
												 -- ,Stake AS '@Stake'
												  ,status AS '@status'
												  ,creator AS '@creator'
								FROM	#tblTransInfo
								FOR XML PATH('r'), ROOT('root')
							)

			IF @TransidList <> ''
			BEGIN
				EXEC dbo.NAP_Admin_Calculate_Bet14 
					@TransIds = @TransidList
					,@MatchId = @MatchId
			END

			--Update CO Selling
			UPDATE co
			SET co.CashOutStatus = 4
			   ,ChangeDate = GETDATE()
			FROM dbo.CashOutSelling co WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #tblTransInfo t ON co.transid = t.transid
			WHERE co.CashOutStatus = 6
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 100
					,@ErrMsg = ERROR_MESSAGE()
		END CATCH
	END

	INSERT INTO @BalanceInfoAfterUpd (CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.awinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)
			,SUM(b14.winlost - b14.actual_stake + b14.playercomm)
	FROM	dbo.bettrans14 b14 WITH(NOLOCK)
		INNER JOIN #tmpTransId t
			ON t.TransId = b14.transid
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate

	INSERT INTO @AfterUpd (matchid, custid, balanceType, bonusId, walletType, balance)
	SELECT	b14.matchid
			,b14.custid
			,1 AS BalanceType
			,0 BonusID
			,2 AS WalletType -- normal tickets are treated as cash tickets
			,SUM(b14.balance) AS balance
	FROM	@BalanceInfoAfterUpd b14
	GROUP BY b14.custid
			,b14.matchid

	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0

	--Return ResettledTransIds
	SET @ResettledTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( t.TransId AS VARCHAR(20))
								FROM @tmpInputTransId t
									INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
								WHERE 1 = CASE WHEN ISNULL(b.betdaqid, 0) <> -2 AND b.statusID NOT IN (0,1,102) THEN 1
											WHEN b.betdaqid = -2 AND b.statusID = 103 THEN 1
											ELSE 0 END												
								FOR XML PATH ('')
							),1,1,''))
	
	INSERT INTO #Balance (custid, balance, Increased)
	SELECT b.custid, SUM(a.balance - b.balance) AS balance, CASE WHEN SUM(a.balance) > SUM(b.balance) THEN 1 ELSE 0 END
	FROM @BeforeUpd b
		INNER JOIN @AfterUpd a ON b.custid = a.custid AND b.matchid = a.matchid
								AND b.balanceType = a.balanceType
								AND b.bonusId = a.bonusId
								AND b.walletType = a.walletType
	WHERE b.balance <> a.balance
	GROUP BY b.custid

	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(custid AS VARCHAR(20)) + ','
	FROM #Balance 
	WHERE Increased = 0

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	--> Add Agency Cash Service - Negative Balance into BalanceNegative table  [#225390]
	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL AND @SiteDBGroupID = 3 --Credit
	BEGIN
		INSERT INTO [dbo].[BalanceNegative]
					([ExecDate]
					,[MatchID]
					,[ActionID]
					,[GroupID]
					,[CustID]
					,[Balance]
					,[StatusID]
					,[Remark])
		SELECT	 GETDATE()
				,@MatchId
				,@ActionID
				,0		-- For Void/Recover
				,CustID
				,Balance
				,0
				,@spName + ' - RequestId: ' + CAST(@RequestId AS VARCHAR)
		FROM	#Balance
		WHERE	Increased = 0
	END		        
	DROP TABLE #Balance

	SET @AffectedList = CAST((
		SELECT	CustId AS '@c'
				,WinlostDate AS '@w'
				,SUM(stake) AS '@st'
				,SUM(actual_stake) AS '@ast'
				,SUM(Winlost) AS '@w_dif'
				,SUM(aWinlost) AS '@aw_dif'
				,SUM(mWinlost) AS '@mw_dif'
				,SUM(sWinlost) AS '@sw_dif'
				,SUM(playerComm) AS '@pc_dif'
				,SUM(Comm) AS '@c_dif'
				,SUM(aComm) AS '@ac_dif'
				,SUM(sComm) AS '@sc_dif'
		FROM	@BalanceInfoAfterUpd 
		GROUP BY CustId
				,WinlostDate
		FOR XML PATH('r'), ROOT('root'), TYPE
	) AS VARCHAR(MAX))

	-- update summary ticket
	BEGIN TRY
		EXEC dbo.TicketVoiding_Admin_Bet14_19999 
			@AffectedList = @AffectedList
			,@IsSiteDB = @IsSiteDB
			,@Action = 'Recover_14'
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_PROCEDURE () + ERROR_MESSAGE()
	END CATCH

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	0 AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'TransId: ' + @TransIds 
								+ ' AffectedList: ' + ISNULL(@AffectedList,'')
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblMatch
	DROP TABLE #tmpTransId
	DROP TABLE #tblTransInfo
END
GO
