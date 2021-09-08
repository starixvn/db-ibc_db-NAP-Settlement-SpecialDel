/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,dot_intg" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_SpecialDelete_RecoverByBetId_ReCal_s175
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
		
	Param's Explanation:
		@TransIds: Maxbet 1000 tickets
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @strTransIds			VARCHAR(MAX)
			,@Bettype				SMALLINT = 7901
			,@GameResult			VARCHAR(50)	= ''

	DECLARE @tmpTransIDResettle TABLE (TransId BIGINT)	

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY)
	CREATE TABLE #BalanceBefore (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)
	CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)	
	CREATE TABLE #Balance (custid INT, balance MONEY, Increased BIT)
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	-------------------------BEGIN TRY------------------------------------------------------------------------
	BEGIN TRY

		SELECT	@GameResult = GameResult
		FROM	DBPRO.bodb02.dbo.ResultDetail3rd WITH(NOLOCK)
		WHERE	MatchID = @MatchId

		INSERT INTO @tmpTransIDResettle (TransId)
		SELECT val
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)

		INSERT INTO #tmpTransID (TransID, modds)
		SELECT	b.transid, m.modds
		FROM	dbo.bettrans b WITH (NOLOCK)
			CROSS APPLY dbo.f_Set_Calculate_modds(b.bettype, b.betteam, b.hdp1, NULL, @GameResult,NULL, NULL, NULL, NULL, NULL) m
			INNER JOIN @tmpTransIDResettle r ON b.transid = r.TransId
		WHERE	b.matchid = @MatchId
				AND b.bettype = @bettype
				AND b.statusID NOT IN (101,102)
			 
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
		GROUP BY custid, winlostdate, bettype
		
		INSERT INTO #Balance
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM	#BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	b.custid = a.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
		WHERE	b.balance <> a.balance
	
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance
		WHERE	Increased = 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 
		
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT	custid, balance
		FROM	#Balance
		WHERE	Increased = 1
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 1 
	
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
