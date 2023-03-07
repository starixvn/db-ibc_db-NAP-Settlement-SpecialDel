/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20230307@Louisa
	Task: Resettle Bettrans14  [Redmine:184747]
	DB: DBTXN/bodb02

*/
USE bodb02
GO

BEGIN

	DECLARE @TransIdsInput VARCHAR(MAX) --- list transID has issues
			,@TransIds VARCHAR(MAX) = '' ---filter list transid again: if Sitedb -> get ticket sitedb, if central -> get all ticket
			,@AffectedList		VARCHAR(MAX)
			,@IsCentral			BIT = 0
			,@ErrCode			INT				= 0		
			,@ErrMsg			VARCHAR(1000)	= ''

	SET @TransIdsInput = '90266683419131922,90266700599001089,90266640469459003,90266717778870285,90259858720292921,90264166572490797,90259837245456438,90265253199216715,90251346095112211'

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	CREATE TABLE #tmpInputTransId (TransId BIGINT)

	INSERT INTO #tmpInputTransId (TransId)
	SELECT CAST([value] AS BIGINT) FROM STRING_SPLIT(@TransIdsInput, ',')

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

	CREATE TABLE #tmpTransInfo (
		TransId			BIGINT
		,MatchId		INT
		,CustId			INT
		,Bettype		SMALLINT
		,SiteDBGroupID		SMALLINT
	)

	INSERT INTO #tmpTransInfo (TransId, MatchId, CustId, Bettype, SiteDBGroupID )
	SELECT	b14.transid
			,b14.matchid
			,b14.custid
			,b14.bettype
			,b14.SiteDBGroupID
	FROM	#tmpInputTransId t
		INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK)
			ON	t.TransId = b14.transid
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'

		RETURN
	END	

	SELECT @TransIds = ( SELECT STRING_AGG (CONVERT(VARCHAR(30),TransId),',') AS str
						  FROM	#tmpTransInfo m
						)

	----Update statuswinlost = 2 for bettrans14 first
	UPDATE b14
		SET statuswinlost = 2
	FROM dbo.bettrans14 b14 WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tmpTransInfo t
			ON t.TransId = b14.transid

	IF @IsCentral = 1
	BEGIN
		WAITFOR DELAY '00:00:30'  ----delay 30s befor run SP execrep NAP_Admin_Calculate_Bet14
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
		INNER JOIN #tmpTransInfo t
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
		INNER JOIN #tmpTransInfo t
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
	IF @IsCentral = 0 ---skip DBTRans due to not exists ticket of DBTRans
	BEGIN
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @BeforeUpd
			, @BalanceWalletAfter	= @AfterUpd
			, @ActionId				= 0
	END

	SET @AffectedList = CAST((
		SELECT	bla.CustId AS '@c'
				,bla.WinlostDate AS '@w'
				,SUM(bla.stake) AS '@st'
				,SUM(bla.actual_stake) AS '@ast'
				,SUM(bla.Winlost - blb.Winlost) AS '@w_dif'
				,SUM(bla.aWinlost - blb.aWinlost) AS '@aw_dif'
				,SUM(bla.mWinlost - blb.mWinlost) AS '@mw_dif'
				,SUM(bla.sWinlost - blb.sWinlost) AS '@sw_dif'
				,SUM(bla.playerComm - blb.playerComm) AS '@pc_dif'
				,SUM(bla.Comm - blb.Comm) AS '@c_dif'
				,SUM(bla.aComm - blb.aComm) AS '@ac_dif'
				,SUM(bla.sComm - blb.sComm) AS '@sc_dif'
		FROM	@BalanceInfoAfterUpd bla
			INNER JOIN @BalanceInfoBeforeUpd blb
				ON bla.CustId = blb.CustId AND bla.MatchId = blb.MatchId
		GROUP BY bla.CustId
				,bla.WinlostDate
		FOR XML PATH('r'), ROOT('root'), TYPE
	) AS VARCHAR(MAX))
	

	BEGIN TRY
		-- update summary ticket
		EXEC dbo.TicketVoiding_Admin_Bet14_19999 
			@AffectedList = @AffectedList
			,@IsSiteDB	  = 0 ---run dependent on each server, so need by pass this param

		-- insert routine task
		EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
			@AffectedList = @AffectedList
			,@IsSiteDB	  = 0 ---run dependent on each server, so need by pass this param
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_PROCEDURE () + ERROR_MESSAGE()
	END CATCH

END
GO
