/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_RecoverHistorical_MainParlay_Update
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
	Task: recover main parlay ticket [Redmine:#115376]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20190823@Kathy: recover main parlay ticket [Redmine:#115376]
		- 20210514@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240416@Max: [TVS] Recover Ticket - Recover full range of archived tickets [Redmine: #203754]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
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
			,@SiteDBGroupID		SMALLINT = 0
			,@CustIds			VARCHAR(MAX)
			,@IsSiteDB			BIT 
			,@tmp_MatchId		INT
			,@RowNumber			INT	= 1
			,@MatchDate			DATETIME
			,@tmp_TransIds		VARBINARY(MAX) = NULL
			,@refnos_29			VARCHAR(MAX)
			,@strSetting		VARCHAR(MAX)
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@ActionID			INT = 200 --Void/Recover
			,@session			NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	SET @ResettledTransIds = @TransIds

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1
	
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	DECLARE @tblMatchIds TABLE ( 
		RowNumber		INT 	IDENTITY (1,1)									
		,matchid		INT
		,eventdate		DATETIME
		,transid		BIGINT
		,refno			BIGINT
		,BetSiteID		INT
	)			

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
		TransId		BIGINT
		,invalid	TINYINT DEFAULT(0)
	)

	CREATE TABLE #tmpTransId (
		TransId		BIGINT
		,refno		BIGINT
		,custid		INT
		,invalid	TINYINT DEFAULT(0)
		,WinlostDate	DATETIME
		,BetSiteID INT
		,betteam		NVARCHAR(20)
		,oddsspread		MONEY
		,srecommend		INT
	)

	DECLARE @tmpBoostSite TABLE(SiteId INT, srecommend INT, IsDeposit BIT DEFAULT(0))
	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90201
	SET @SB_Error = 0

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')

	INSERT INTO #tmpTransId (TransId,custid, refno, invalid, WinlostDate, betteam, oddsspread, srecommend, BetSiteID)
	SELECT	b14.transid,b14.custid
			,b14.refno
			,0 AS invalid
			,b14.winlostdate
			,b14.betteam
			,b14.oddsspread
			,b14.srecommend
			,si.siteid
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON t.TransId = b14.transid
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b14.custid
		INNER JOIN CustDB.dbo.Site si WITH (NOLOCK) ON c.site = si.site
	WHERE	b14.statusID = 102
			AND b14.betfrom <> 'p'
			AND b14.matchid = 29
			AND b14.bettype = 29
			AND b14.SiteDBGroupID = @SiteDBGroupID

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'

		RETURN
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
						WHEN EXISTS (
								SELECT TOP 1 1
								FROM	dbo.bettransm bm WITH(NOLOCK)
								WHERE	bm.refno = r.refno
										AND (bm.statuswinlost IS NULL OR bm.statuswinlost NOT BETWEEN 0 AND 6)
										AND bm.statusID <> 0
								UNION ALL
								SELECT TOP 1 1
								FROM	dbo.bettransm14 bm14 WITH(NOLOCK)
								WHERE	bm14.refno = r.refno
										AND (bm14.statuswinlost IS NULL OR bm14.statuswinlost NOT BETWEEN 0 AND 6)
							) THEN 2 -- not have 'statuswinlost' value
						WHEN r.invalid > 0 THEN r.invalid
					END AS invalid
		) AS i
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpInputTransId WHERE invalid > 0)
	BEGIN
		DECLARE @Msg VARCHAR(MAX) = ''

		SET @ErrCode = 100
		SET @ErrMsg = ''

		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 1

		IF @@rowcount > 0
			SET @ErrMsg = 'Invalid transid: ' + STUFF(@Msg, 1, 1, '') + '. '

		SET @Msg = ''		
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 2

		IF @@rowcount > 0
			SET @ErrMsg = @ErrMsg + 'Existing data but do not have statuswinlost value: ' + STUFF(@Msg, 1, 1, '') + '. '

		SET @Msg = ''
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 3

		IF @@rowcount > 0
			SET @ErrMsg = @ErrMsg + 'Existing but data has not been moved yet: ' + STUFF(@Msg, 1, 1, '') + '. '
		
		RETURN
				
	END

	/*Modify the way to get move bet date*/
	DECLARE @BeingMovebetDate SMALLDATETIME 
		   ,@currentdate SMALLDATETIME = GETDATE()

	DECLARE @tblTransId_MoveBet TABLE (MatchId INT, TransId BIGINT)
	
	-- get current beingmovebetdate if movebet in-progress, paste @currentdate to get @BeingMovebetDate only
	EXEC [dbo].[NAP_Admin_VerifySettleDate] @Winlostdate = @currentdate, @BeingMovebetDate = @BeingMovebetDate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE WinlostDate <= @BeingMovebetDate)
	BEGIN	
		DELETE 
		FROM #tmpTransId
			OUTPUT	@MatchId, DELETED.TransId
			INTO  @tblTransId_MoveBet (Matchid, TransId)
		WHERE WinlostDate <= @BeingMovebetDate

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
		EXEC dbo.NAP_Admin_Calculate_MainParlay14
			@TransIds = @TransIds
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
				,@ErrMsg = ERROR_PROCEDURE () + ERROR_MESSAGE()
	END CATCH

	INSERT INTO @tblMatchIds (matchid, eventdate, transid, refno, BetSiteID)
	SELECT t.matchid, t.eventdate, t.transid, t.refno, t.BetSiteID
	FROM(
		SELECT	ROW_NUMBER() OVER (PARTITION BY b14.transid ORDER BY m14.eventdate DESC) AS RowNumber
				,bm14.matchid, m14.eventdate,  b14.transid, b14.refno, b14.BetSiteID
		FROM	dbo.bettransm14 bm14 WITH(NOLOCK) 
			INNER JOIN #tmpTransId b14 ON b14.refno = bm14.refno	
			INNER JOIN dbo.match14 m14 WITH (NOLOCK) ON bm14.matchid = m14.matchid		
	) t
	WHERE	t.RowNumber = 1

	
	WHILE (1 = 1)
	BEGIN
		SELECT	TOP 1 @tmp_MatchId = matchid
		FROM	@tblMatchIds
		WHERE	RowNumber = @RowNumber
	
		IF @@rowcount = 0
			BREAK		
	
		SET @RowNumber = @RowNumber + 1
	
		SELECT  @MatchDate = eventdate
		FROM	dbo.match14 WITH(NOLOCK)
		WHERE	matchid = @tmp_MatchId

		SET @tmp_TransIds = COMPRESS((SELECT t.transid AS 't'
			,t.BetSiteID  AS 'bet_sid'
		FROM @tblMatchIds t
		WHERE matchid = @tmp_MatchId
		FOR JSON PATH))

		SELECT @refnos_29 = ''
		SELECT 	@refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
		FROM	@tblMatchIds
		WHERE	matchid = @tmp_MatchId

		SET @refnos_29 = STUFF(@refnos_29,1,1,'')

		DELETE @tmpBoostSite
		INSERT INTO @tmpBoostSite(SiteId, srecommend )
		SELECT DISTINCT r.BetSiteID, r.srecommend
		FROM	@tblMatchIds t
			INNER JOIN #tmpTransId r ON r.transid = t.transid
		WHERE	t.matchid = @tmp_MatchId
			AND r.betteam = '1' -- mix parlay
			AND r.oddsspread = 2 -- offer parlay bonus
			AND NOT EXISTS (SELECT 	TOP 1 1 
								FROM 	dbo.bettransm bm WITH(NOLOCK) 
								WHERE 	t.refno = bm.refno 
										AND ((ISNULL(bm.statuswinlost,0) = 4 AND bm.statusID = 113)
											OR bm.statusId = 0
										)
						) -- lose/running

		UPDATE si 
		SET IsDeposit = 1
		FROM	@tmpBoostSite si
			INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK)
				ON si.srecommend = d.custid
			
		SET @sqlOpenqueryCommand = ''
		SET @sqlOpenqueryCommand = 'SELECT SiteId, OverOdds, Boost FROM OPENQUERY(DBPRO,''SELECT SiteId, OverOdds, Boost FROM bodb02.dbo.ParlayOddsBoostSetting p WITH(NOLOCK) WHERE p.SiteId IN ('
								+ (SELECT  STRING_AGG(CAST(s.SiteID AS VARCHAR(MAX)),',') 
									FROM (
										SELECT SiteId
										FROM (
											SELECT SiteId
											FROM @tmpBoostSite t
											UNION
											SELECT -1
											UNION 
											SELECT -2
										) t
										GROUP BY t.SiteID
									) s 
								)
						+ ')'')'

		DELETE @tmpBoostSetting
		INSERT INTO @tmpBoostSetting(SiteId, OverOdds, Boost)							
		EXEC (@sqlOpenqueryCommand)

		SET @strSetting = ''
		SELECT @strSetting = CAST((
			SELECT	si.SiteId AS 's'
					,(SELECT t.OverOdds AS 'o', t.Boost AS 'b' -- get its own settings
						FROM (SELECT se.SiteId, se.OverOdds, se.Boost
							FROM	@tmpBoostSetting se
							WHERE	EXISTS (SELECT TOP 1 1 FROM	@tmpBoostSite si WHERE se.SiteId = si.SiteId)
							UNION
							SELECT	si.SiteId, se.OverOdds, se.Boost -- If the site ID does not have its own settings, the default value will be taken on default SiteId (-1 if it's credit, -2 if it's licensee)
							FROM	@tmpBoostSite si
								CROSS APPLY (
									SELECT	se.OverOdds, se.Boost
									FROM	@tmpBoostSetting se
									WHERE	se.SiteId = CASE WHEN si.IsDeposit = 1 THEN -2 ELSE -1 END
								) se
							WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpBoostSetting se WHERE si.SiteId = se.SiteId)
						) t
					WHERE si.SiteId = t.SiteId
					FOR JSON AUTO
					) AS v
			FROM	@tmpBoostSite si
			FOR JSON AUTO
		) AS VARCHAR(MAX))
	
		EXEC dbo.NAP_Admin_Calculate_MP_Bet14_PreCal_29 
			 @matchdate = @matchdate
			,@TransInfoJson = @tmp_TransIds
			,@strSetting = @strSetting
			,@MatchId = @tmp_MatchId

		EXEC dbo.NAP_Admin_Calculate_MP_Bet14_29
				@strXML	= @refnos_29
				
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

	INSERT INTO #Balance (custid, balance, Increased)
	SELECT b.custid, SUM(a.balance - b.balance) AS balance, CASE WHEN SUM(a.balance) > SUM(b.balance) THEN 1 ELSE 0 END
	FROM @BeforeUpd b
		INNER JOIN @AfterUpd a ON b.custid = a.custid
								AND b.matchid = a.matchid
								AND b.balanceType = a.balanceType
								AND b.bonusId = a.bonusId
								AND b.walletType = a.walletType	
	WHERE b.balance <> a.balance
	GROUP BY b.custid

	--> Build list of customer name with negative balance
	SET @CustIds = ''
	SELECT @CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), custid)
	FROM #Balance
	WHERE Increased = 0	
		
	EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
		@CustIds = @CustIds,
		@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT	
	
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
					,[SessionId]
					,[Remark])
		SELECT	 GETDATE()
				,@MatchId
				,@ActionID
				,0		-- For Void/Recover
				,CustID
				,Balance
				,0
				,@session
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
					,SUM(aWinlost ) AS '@aw_dif'
					,SUM(mWinlost ) AS '@mw_dif'
					,SUM(sWinlost ) AS '@sw_dif'
					,SUM(playerComm ) AS '@pc_dif'
					,SUM(Comm ) AS '@c_dif'
					,SUM(aComm ) AS '@ac_dif'
					,SUM(sComm ) AS '@sc_dif'
			FROM	@BalanceInfoAfterUpd a
					
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
		SELECT 	@ErrCode = 100
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

	DROP TABLE #tmpTransId
END
GO