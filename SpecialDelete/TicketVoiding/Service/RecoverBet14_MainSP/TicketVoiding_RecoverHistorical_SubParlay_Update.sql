/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_RecoverHistorical_SubParlay_Update
	@MatchId			INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)  
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
AS
/*	Created by: Kathy
	Date 20190823
	Task: recover sub parlay ticket [Redmine:#115376]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20190823@Kathy: recover sub parlay ticket [Redmine:#115376]
		- 20210514@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

			,@avaiableProcess	BIT

			,@subTransIds		VARCHAR(MAX)
			,@AffectedList		VARCHAR(MAX)
	
			,@moveBetDay		SMALLDATETIME
			,@FromDate			DATETIME    
			,@ToDate			DATETIME   
			
	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @moveBetDay OUTPUT
	
	SELECT @FromDate	= DATEADD(d, -6, GETDATE())
		, @ToDate 		= @moveBetDay
		
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

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
		mainTransId BIGINT
		,subTransId	BIGINT
		,matchid	INT
		,custid		INT
		,bettype	SMALLINT
		,winlost	MONEY
		,invalid	TINYINT DEFAULT(0)
	)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90202
	SET @SB_Error = 0
	SET @subTransIds = ''

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')

	IF @@rowcount > 1000
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'List inputted transid over 1000 value'

		RETURN
	END
	
	IF NOT EXISTS (SELECT 1 FROM dbo.match14 WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'Invalid match'

		RETURN
	END

	INSERT INTO #tmpTransId (mainTransId, subTransId, matchid, custid, bettype,winlost, invalid)
	SELECT	b14.transid
			,bm14.transid
			,bm14.matchid
			,bm14.custid
			,bm14.bettype
			,b14.winlost
			,CASE
				WHEN cs.custid IS NOT NULL THEN 1 -- not pass validation rule
				WHEN bm14.statuswinlost IS NULL OR bm14.statuswinlost NOT BETWEEN 0 AND 6 THEN 2 -- not have 'statuswinlost' value
				WHEN bm14.winlostdate < @FromDate OR bm14.winlostdate > @ToDate THEN 4
				ELSE 0
			END
	FROM	@tmpInputTransId t
		CROSS APPLY 
			(SELECT TOP 1 b.transid, b.refno, b.srecommend, b.betfrom, b.winlost
			 FROM	dbo.bettrans b WITH(NOLOCK)
			 WHERE	b.transid = t.TransId
			 UNION ALL
			 SELECT TOP 1 b14.transid, b14.refno, b14.srecommend, b14.betfrom, b14.winlost
			 FROM	dbo.bettrans14 b14 WITH(NOLOCK)
			 WHERE	b14.transid = t.TransId
			)	b14			
		INNER JOIN dbo.bettransm14 bm14 WITH(NOLOCK)
			ON bm14.refno = b14.refno
		LEFT JOIN CustDB.dbo.Dep_CustSuper cs WITH(NOLOCK)
			ON	b14.srecommend = cs.custid
	WHERE	bm14.statusID = 102
			AND bm14.matchid = @MatchId
			AND b14.betfrom <> 'p'
			AND bm14.bettype NOT IN (10, 38)
			AND bm14.bettype NOT BETWEEN 801 AND 806
			AND bm14.bettype NOT BETWEEN 8101 AND 8120
			AND bm14.bettype NOT BETWEEN 81 AND 120
			AND bm14.bettype NOT BETWEEN 1201 AND 1299
			AND bm14.bettype NOT BETWEEN 2700 AND 2899

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found'

		RETURN
	END
	
	UPDATE t
		SET invalid = i.invalid
	FROM	@tmpInputTransId t
		LEFT JOIN #tmpTransId r
			ON t.TransId = r.mainTransId
		OUTER APPLY (
			SELECT CASE
						WHEN EXISTS (SELECT TOP 1 1 FROM dbo.bettransm bm WITH(NOLOCK) WHERE bm.transid = r.subTransId AND bm.statusID = 102) THEN 3 -- data has not been moved yet
						WHEN r.mainTransId IS NULL THEN 1 -- not pass validation rule
						WHEN r.invalid > 0 THEN r.invalid
						END AS invalid

		)AS i

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
		
		
		SET @Msg = ''
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 4

		IF @@rowcount > 0
			SET @ErrMsg = @ErrMsg + 'BetID are not within supported date range: ' + STUFF(@Msg, 1, 1, '') + '. '
			
		RETURN
				
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM SystemSettings WITH (NOLOCK) WHERE VName = 'IsMovingBet' AND VValue = 1)
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = @ErrMsg + 'This Movebet process is running, please wait until the on-going process is completed and try again.'
		
		RETURN
		
	END
	
	EXEC dbo.NAP_Admin_CheckingProcess
		@IsExistParlay = 1
		, @avaiableProcess = @avaiableProcess OUTPUT
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		RETURN
	END

	SELECT @subTransIds = @subTransIds + ',' + CONVERT(VARCHAR,subTransId)
	FROM	#tmpTransId

	SET @subTransIds = STUFF(@subTransIds, 1, 1, '')

	INSERT INTO @BalanceInfoBeforeUpd(CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.aWinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)

			,SUM(b14.winlost - b14.actual_stake + b14.playercomm) 
	FROM	#tmpTransId t
		CROSS APPLY (
			SELECT	b.custid, b.matchid, b.winlostdate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, b.stake, b.actual_stake
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.transid = t.mainTransId AND b.statusID NOT IN (101,102)
			UNION ALL
			SELECT	b14.custid, b14.matchid, b14.winlostdate, b14.winlost, b14.awinlost, b14.mwinlost, b14.swinlost, b14.playercomm, b14.comm, b14.acomm, b14.scomm, b14.stake, b14.actual_stake
			FROM	dbo.bettrans14 b14 WITH(NOLOCK)
			WHERE	b14.transid = t.mainTransId AND b14.statusID NOT IN (101,102)
		) b14
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate
	
	INSERT INTO @BeforeUpd (matchid, custid, balanceType, bonusId, walletType, balance)
	SELECT	 b14.matchid
			,b14.custid
			,1 AS BalanceType
			,0 AS BonusId
			,2 AS WalletType
			,SUM(b14.balance) AS balance
	FROM	@BalanceInfoBeforeUpd b14
	GROUP BY b14.custid
			,b14.matchid
			
	BEGIN TRY
		EXEC dbo.NAP_Admin_Calculate_SubParlay14 
			@TransIds = @subTransIds
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	INSERT INTO @BalanceInfoAfterUpd(CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.aWinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)

			,SUM(b14.winlost - b14.actual_stake + b14.playercomm) 
	FROM	#tmpTransId t
		CROSS APPLY (
			SELECT	b.custid, b.matchid, b.winlostdate, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, b.stake, b.actual_stake
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.transid = t.mainTransId AND b.statusID NOT IN (101,102)
			UNION ALL
			SELECT	b14.custid, b14.matchid, b14.winlostdate, b14.winlost, b14.awinlost, b14.mwinlost, b14.swinlost, b14.playercomm, b14.comm, b14.acomm, b14.scomm, b14.stake, b14.actual_stake
			FROM	dbo.bettrans14 b14 WITH(NOLOCK)
			WHERE	b14.transid = t.mainTransId AND b14.statusID NOT IN (101,102)
		) b14
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate

	INSERT INTO @AfterUpd (matchid, custid, balanceType, bonusId, walletType, balance)
	SELECT	 b14.matchid
			,b14.custid
			,1 AS BalanceType
			,0 AS BonusId
			,2 AS WalletType
			,SUM(b14.balance) AS balance
	FROM	@BalanceInfoAfterUpd b14
	GROUP BY b14.custid
			,b14.matchid

	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0
		
	-- Starting for summary tickets and routine tasks
	-- Just insert/update for summary ticket if main tickets move to Bet14
	
	SET @AffectedList = CAST((
			SELECT	a.CustId AS '@c'
					,a.WinlostDate AS '@w'
					,SUM(a.stake - b.stake) AS '@st'
					,SUM(a.actual_stake - b.actual_stake) AS '@ast'
					,SUM(a.Winlost - b.Winlost) AS '@w_dif'
					,SUM(a.aWinlost - b.aWinlost) AS '@aw_dif'
					,SUM(a.mWinlost - b.mWinlost) AS '@mw_dif'
					,SUM(a.sWinlost - b.sWinlost) AS '@sw_dif'
					,SUM(a.playerComm - b.playerComm) AS '@pc_dif'
					,SUM(a.Comm - b.Comm) AS '@c_dif'
					,SUM(a.aComm - b.aComm) AS '@ac_dif'
					,SUM(a.sComm - b.sComm) AS '@sc_dif'
			FROM	@BalanceInfoBeforeUpd b
				INNER JOIN @BalanceInfoAfterUpd a
					ON	a.custid = b.custid
						AND a.WinlostDate = b.WinlostDate AND a.Winlost <> b.Winlost
			WHERE EXISTS (SELECT TOP 1 1 FROM dbo.bettrans14 b14 WITH (NOLOCK) WHERE b14.custid = a.CustId AND a.WinlostDate = b14.winlostdate)
			
			GROUP BY a.CustId
					,a.WinlostDate
			FOR XML PATH('r'), ROOT('root'), TYPE
		) AS VARCHAR(MAX))
	
	IF @ErrCode <> 0
	BEGIN
		-- release data of TempVariableNumber table
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsExistParlay = 1
			,@IsReleased = 1	
	END
	ELSE
	BEGIN
		DELETE	zm
		FROM	dbo.zzzbettransm zm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmpTransId t
				ON zm.transid = t.subTransId

		DELETE	z
		FROM	dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmpTransId t
				ON z.transid = t.subTransId
		WHERE	z.custid = t.custid
				AND z.matchid = @MatchId
				AND z.bettype = t.bettype

		-- release data of TempVariableNumber table
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsExistParlay = 1
			,@IsReleased = 1

		BEGIN TRY
			-- update summary ticket
			EXEC dbo.TicketVoiding_Admin_Bet14_19999 
				@AffectedList = @AffectedList
			-- insert routine task
			EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
				@AffectedList = @AffectedList
		END TRY
		BEGIN CATCH
			SELECT 	@ErrCode = 100
					,@ErrMsg = ERROR_PROCEDURE () + ERROR_MESSAGE()
		END CATCH
	END
	
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	0 AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'TransId: ' + @TransIds 
								+ ' AffectedList: ' + ISNULL(@AffectedList,'N/A')
								AS '@LogData'
							,@MatchId AS '@MatchId'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO