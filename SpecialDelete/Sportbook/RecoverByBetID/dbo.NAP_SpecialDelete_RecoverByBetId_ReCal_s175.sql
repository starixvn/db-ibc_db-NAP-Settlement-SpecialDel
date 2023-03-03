/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,dot_intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SpecialDelete_RecoverByBetId_ReCal_s175
	@MatchId		INT
	,@TransIds		VARCHAR(MAX)
	,@Action		VARCHAR(20)		= 'CAL'
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20210908@July
	Task: Recover by BetID - Bitcoin
	DB: DBTXN/bodb02
	
	Revisions:
		- 20210908@July: Integrate Bitcoin Re-cal match - [Redmine:#159714]
		- 20210930@July: Change the source balance (balancetype = 4) of Bitcoin product [Redmine: #162474]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220825@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]

	Param's Explanation:
		@TransIds: Maxbet 1000 tickets
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @strTransIds			VARCHAR(MAX)
			,@Bettype				SMALLINT = 7901
			,@GameResult			VARCHAR(50)	= ''
			,@SiteDBGroupID			SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpTransIDResettle TABLE (TransId BIGINT)	

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY)
	CREATE TABLE #BalanceBefore (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)
	CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)	
	CREATE TABLE #Balance (custid INT, balance MONEY, Increased BIT)
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	DECLARE @tblDebitOthersPending TVP_BalanceList
	DECLARE @tblCreditOthersPending TVP_BalanceList
	
	-------------------------BEGIN TRY------------------------------------------------------------------------
	BEGIN TRY

		SELECT	@GameResult = GameResult
		FROM	DBPRO.bodb02.dbo.ResultDetail3rd WITH(NOLOCK)
		WHERE	MatchID = @MatchId

		INSERT INTO @tmpTransIDResettle (TransId)
		SELECT value
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

		INSERT INTO #tmpTransID (TransID, modds)
		SELECT	b.transid, m.modds
		FROM	dbo.bettrans b WITH (NOLOCK)
			CROSS APPLY dbo.f_Set_Calculate_modds(b.bettype, b.betteam, b.hdp1, NULL, @GameResult,NULL, NULL, NULL, NULL, NULL) m
			INNER JOIN @tmpTransIDResettle r ON b.transid = r.TransId
		WHERE	b.matchid = @MatchId
				AND b.bettype = @bettype
				AND b.statusID NOT IN (101,102)
				AND b.SiteDBGroupID = @SiteDBGroupID
			 
		INSERT INTO #BalanceBefore(custid, balance, winlost, winlostdate, gametypeid)
		SELECT	custid
				,SUM(winlost - actual_stake + playercomm)
				,SUM(CASE
						WHEN ruben = 1 THEN winlost - actual_stake 
						ELSE 0 
					END) AS winlost
				,winlostdate
				,bettype
		FROM	dbo.bettrans bt WITH (ROWLOCK)
			INNER JOIN #tmpTransId t
				ON bt.transid = t.transid
		WHERE	bt.matchid = @matchid
				AND bt.bettype = @bettype
				AND bt.SiteDBGroupID = @SiteDBGroupID
		GROUP BY custid, winlostdate, bettype		

		--filter selectedRID by current Profile and BetType
		SET @strTransIds = (SELECT transid		AS '@t'
									,modds		AS '@m'
									,1			AS '@ot'
							FROM #tmpTransId
							FOR XML PATH('r'), ROOT( 'root' ))

		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
				,@action			 = @Action
				,@strTransIds		 = @strTransIds
				,@Is3rd				 = 1
				,@EventTable		 = 3

		INSERT INTO #BalanceAfter(custid, balance, winlost, winlostdate, gametypeid)
		SELECT	custid
				,SUM(winlost - actual_stake + playercomm)
				,SUM(CASE 
						WHEN ruben = 1 THEN winlost - actual_stake 
						ELSE 0
					END) AS winlost
				,winlostdate
				,bettype
		FROM	dbo.bettrans bt WITH (ROWLOCK)
			INNER JOIN #tmpTransId t
				ON bt.transid = t.transid
		WHERE matchid = @matchid 
				AND bt.bettype = @bettype
				AND bt.SiteDBGroupID = @SiteDBGroupID
		GROUP BY custid, winlostdate, bettype
		
		INSERT INTO #Balance
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM	#BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	b.custid = a.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE	b.balance <> a.balance
	
		INSERT INTO @tblDebitOthersPending (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance
		WHERE	Increased = 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitOthersPending
				,@Type			= 4 
		
		INSERT INTO @tblCreditOthersPending (custID, balance)
		SELECT	custid, balance
		FROM	#Balance
		WHERE	Increased = 1
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditOthersPending
				,@Type			= 4
	
		---insert data into pending balance game table 
		INSERT INTO BalancePendingCreditGame (
			custid
			,winlostdate
			,balance
			,bettype
			,GameTypeID
			)
		SELECT a.custid
			,a.winlostdate
			,(a.winlost - b.winlost) AS Balance
			,@bettype
			,a.gametypeid
		FROM #BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE (a.winlost - b.winlost) > 0
	
		INSERT INTO BalancePendingDebitGame (
			custid
			,winlostdate
			,balance
			,bettype
			,GameTypeID
			)
		SELECT a.custid
			,a.winlostdate
			,ABS(a.winlost - b.winlost) AS Balance
			,@bettype
			,a.gametypeid
		FROM #BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE (a.winlost - b.winlost) < 0
		
		DROP TABLE #Balance
		DROP TABLE #BalanceBefore
		DROP TABLE #BalanceAfter
		DROP TABLE #tmpTransID
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()
				
	END CATCH
	
END
GO
