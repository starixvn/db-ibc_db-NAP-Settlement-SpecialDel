/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
)
AS
/*	
	Created by: Kathy
	Date 20190823
	Task: recover single ticket [Redmine:#115376]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20190823@Kathy: recover single ticket [Redmine:#115376]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20210514@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
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
			,@isExistFM			BIT
			,@isExistFM2		BIT = 0
			,@isExistMatch		BIT
			,@AffectedList		VARCHAR(MAX)
			
			,@moveBetDay		SMALLDATETIME
			,@FromDate			SMALLDATETIME    
			,@ToDate			SMALLDATETIME
	
	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @moveBetDay OUTPUT
	
	SELECT @FromDate	= CONVERT(VARCHAR(10), DATEADD(d, -6, GETDATE()), 102)
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
	)

	CREATE TABLE #tblMatchProcess (MatchId INT, KeyID TINYINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90200
	SET @SB_Error = 0

	SET @ErrCode = 0
	SET @ErrMsg = ''

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')

	INSERT INTO #tmpTransId (TransId, MatchId, CustId, Bettype, KeyId, invalid)
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
				WHEN cs.custid IS NOT NULL THEN 1 -- not pass validation rule
				WHEN b14.statuswinlost IS NULL OR b14.statuswinlost NOT BETWEEN 0 AND 6 THEN 2 -- not have 'statuswinlost' value
				WHEN b14.winlostdate < @FromDate OR b14.winlostdate > @ToDate THEN 4
				ELSE 0
			END AS invalid
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK)
			ON	t.TransId = b14.transid
		LEFT JOIN CustDB.dbo.Dep_CustSuper cs WITH(NOLOCK)
			ON	b14.srecommend = cs.custid
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b14.Bettype
			)f
	WHERE	b14.statusID = 102
			AND b14.betfrom <> 'p'
			AND b14.bettype NOT IN (10, 38, 29)
			AND b14.bettype NOT BETWEEN 801 AND 806
			AND b14.bettype NOT BETWEEN 8101 AND 8120
			AND b14.bettype NOT BETWEEN 81 AND 120
			AND b14.bettype NOT BETWEEN 1201 AND 1299
			AND b14.bettype NOT BETWEEN 2700 AND 2899
			
	
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
	
	IF @IP IS NULL OR @UserId IS NULL
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = @ErrMsg + 'IP and UserID must be inputted.'
		
		RETURN
	END
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	MatchId, KeyId
	FROM	#tmpTransId
	GROUP BY MatchId, KeyId
	
	SELECT	@isExistFM = CASE WHEN KeyID = 6 THEN 1 ELSE 0 END
			,@isExistMatch = CASE WHEN KeyID = 1 THEN 1 ELSE 0 END
			, @isExistFM2 = CASE WHEN KeyID = 7 THEN 1 ELSE 0 END
	FROM	#tblMatchProcess

	EXEC dbo.NAP_Admin_CheckingProcess
		 @isExistFM = @isExistFM
		, @isExistMatch	= @isExistMatch
		, @isExistFM2 = @isExistFM2
		, @avaiableProcess = @avaiableProcess OUTPUT
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
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
		EXEC dbo.NAP_Admin_Calculate_Bet14 
			@TransIds = @TransIds
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

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

	IF @ErrCode <> 0
	BEGIN
		------ release data of TempVariableNumBer table
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= @isExistMatch
			, @isExistFM 		= @isExistFM
			, @isExistFM2		= @isExistFM2
			, @IsReleased		= 1	
	END
	ELSE
	BEGIN
		DELETE	z
		FROM	dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmpTransId t
				ON z.transid = t.TransId
		WHERE	z.custid = t.CustId
				AND z.matchid = t.MatchId
				AND z.bettype = t.Bettype

		-- release data of TempVariableNumBer table
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= @isExistMatch
			, @isExistFM 		= @isExistFM
			, @isExistFM2		= @isExistFM2
			, @IsReleased		= 1	

		BEGIN TRY
			-- update summary ticket
			EXEC dbo.TicketVoiding_Admin_Bet14_19999 
				@AffectedList = @AffectedList
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 100
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
								+ ' AffectedList: ' + ISNULL(@AffectedList,'')
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO
