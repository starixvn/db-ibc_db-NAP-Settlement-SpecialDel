/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap,dot_intg" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SpecialDelete_RecoverByBetId_ReCal_s175
	@MatchId		INT
	,@TransIds		VARCHAR(MAX)
	,@Action		VARCHAR(20)		= 'CAL'
	,@UserId		INT = 0
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
		- 20230921@Max: [TVS] Recover Virtual Sports Bet and Recover By Bet ID - Update more info when calling SP from Settlement site [Redmine: #194269]
		- 20250402@Mike: [TVS] Upgrade ExchangeID data type [Redmine:#222191]
		- 20250612@July: Fix replication issue caused by NULL values in the action call/refund input ticket [Redmine:#229870]
		
	Param's Explanation:
		@TransIds: Maxbet 1000 tickets
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @strTransIds			VARCHAR(MAX) =''
			,@Bettype				SMALLINT = 7901
			,@GameResult			VARCHAR(50)	= ''
			,@SiteDBGroupID			SMALLINT = 0
			,@TransInfoMaxPO		VARCHAR(MAX)
			,@TotalTransMaxPO		INT = 0
			,@batchPO				SMALLINT = 500

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpTransIDResettle TABLE (TransId BIGINT)	

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, custid INT, currency SMALLINT, actualPO MONEY, winlost MONEY,IsApplyMaxPO BIT
		,transdate DATETIME, bettype SMALLINT)

	CREATE TABLE #BalanceBefore (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)
	CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)	
	CREATE TABLE #Balance (custid INT, balance MONEY, Increased BIT)
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)
	DECLARE @tmpTransIDMaxPO TABLE (TransID BIGINT
		,custid INT, actualPO MONEY, winlost MONEY
		,transdate DATETIME, bettype SMALLINT
	)


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

		INSERT INTO #tmpTransID (TransID, modds, custid, currency, actualPO, transdate, bettype)
		SELECT	b.transid, m.modds
			,b.custid					
			,b.currency
			,CASE
				WHEN m.modds >  0.25 THEN b.actual_stake + b.stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds - 1 END)
				WHEN m.modds =  0.25 THEN b.actual_stake + b.stake * (CASE WHEN b.odds < 0 THEN 1 ELSE b.odds - 1 END) * 0.5
				ELSE NULL
			END actualPO
			,b.transdate
			,b.bettype
		FROM	dbo.bettrans b WITH (NOLOCK)
			CROSS APPLY dbo.f_Set_Calculate_modds(b.bettype, b.betteam, b.hdp1, NULL, @GameResult,NULL, NULL, NULL, NULL, NULL) m
			INNER JOIN @tmpTransIDResettle r ON b.transid = r.TransId
		WHERE	b.matchid = @MatchId
				AND b.bettype = @bettype
				AND b.statusID NOT IN (101,102)
				AND b.SiteDBGroupID = @SiteDBGroupID

		-- check if winlost reaches the maxpayout
		IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
		BEGIN
			;WITH cteCustIds
			AS(
				SELECT DISTINCT custid, currency
				FROM	#tmpTransID t
				WHERE	modds >= 0.25
			)
			INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
			SELECT	t.custid, fc.MaxWinLimit
			FROM	CustDB.dbo.Customer c WITH(NOLOCK)
				INNER JOIN cteCustIds t
					ON t.custid = c.custid
				INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
					ON s.site = c.site
				INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
					ON s.siteid = fs.siteid
				INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
					ON	t.currency = fc.ExchangeId
						AND fc.SiteDBGroupId = @SiteDBGroupId

			IF @@ROWCOUNT > 0
			BEGIN
				UPDATE t 
					SET IsApplyMaxPO = 1
						,winlost = m.MaxWinLimit
				FROM	#tmpTransID t
					INNER JOIN	@tmpMaxWinLimit m
						ON t.CustId = m.CustId
				WHERE	t.actualPO > m.MaxWinLimit

				SET @TotalTransMaxPO = @@ROWCOUNT
			END
					
		END
			 
		INSERT INTO #BalanceBefore(custid, balance, winlost, winlostdate, gametypeid)
		SELECT	bt.custid
				,SUM(bt.winlost - actual_stake + playercomm)
				,SUM(CASE
						WHEN ruben = 1 THEN bt.winlost - actual_stake 
						ELSE 0 
					END) AS winlost
				,winlostdate
				,bt.bettype
		FROM	dbo.bettrans bt WITH (ROWLOCK)
			INNER JOIN #tmpTransId t
				ON bt.transid = t.transid
		WHERE	bt.matchid = @matchid
				AND bt.bettype = @bettype
				AND bt.SiteDBGroupID = @SiteDBGroupID
		GROUP BY bt.custid, winlostdate, bt.bettype		

		--filter selectedRID by current Profile and BetType
		SET @strTransIds = (SELECT transid		AS '@t'
									,modds		AS '@m'
									,1			AS '@ot'
									,CASE WHEN IsApplyMaxPO = 1 THEN winlost ELSE NULL END AS '@wl'
									,CASE WHEN IsApplyMaxPO = 1 THEN actualPO ELSE NULL END AS '@apo'
									,IsApplyMaxPO AS '@iMPO'
							FROM #tmpTransId
							FOR XML PATH('r'), ROOT( 'root' ))
		
		IF ISNULL (@strTransIds, '') <> ''
		BEGIN 
			EXEC dbo.NAP_Admin_Calculate_OtherSports
					@matchid			 = @matchid
					,@action			 = @Action
					,@strTransIds		 = @strTransIds
					,@Is3rd				 = 1
					,@EventTable		 = 3
		END

		INSERT INTO #BalanceAfter(custid, balance, winlost, winlostdate, gametypeid)
		SELECT	bt.custid
				,SUM(bt.winlost - actual_stake + playercomm)
				,SUM(CASE 
						WHEN ruben = 1 THEN bt.winlost - actual_stake 
						ELSE 0
					END) AS winlost
				,winlostdate
				,bt.bettype
		FROM	dbo.bettrans bt WITH (ROWLOCK)
			INNER JOIN #tmpTransId t
				ON bt.transid = t.transid
		WHERE matchid = @matchid 
				AND bt.bettype = @bettype
				AND bt.SiteDBGroupID = @SiteDBGroupID
		GROUP BY bt.custid, winlostdate, bt.bettype
		
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

		-- notify
		WHILE (@TotalTransMaxPO > 0)
		BEGIN
			IF @TotalTransMaxPO > @batchPO
			BEGIN
				DELETE @tmpTransIDMaxPO

				DELETE TOP (@batchPO) t
					OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
					INTO @tmpTransIDMaxPO(custid, winlost, actualPO, transdate, bettype, transid)
				FROM	#tmpTransID t
				WHERE	IsApplyMaxPO = 1

				SET @TransInfoMaxPO = CAST((
										SELECT	TOP (@batchPO) CustId AS a1
												,175 AS a2 -- productid
												,0 AS a3 -- groupid
												,winlost AS a4 -- maxwinlimit
												,actualPO AS a6 -- winamt
												,255 AS a7 -- levelid
												,255 AS a8 -- actionid
												,@UserId AS a12 -- createdby
												,transdate AS a13 -- winlostdate
												,bettype AS a16
												,transid AS a17
										FROM	@tmpTransIDMaxPO
										FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
			END
			ELSE
			BEGIN
				SET @TransInfoMaxPO = CAST((
										SELECT	CustId AS a1
												,175 AS a2 -- productid
												,0 AS a3 -- groupid
												,winlost AS a4 -- maxwinlimit
												,actualPO AS a6 -- winamt
												,255 AS a7 -- levelid
												,255 AS a8 -- actionid
												,@UserId AS a12 -- createdby
												,transdate AS a13 -- winlostdate
												,bettype AS a16
												,transid AS a17
										FROM	#tmpTransID
										WHERE	IsApplyMaxPO = 1
										FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
			END

			SET @TotalTransMaxPO = @TotalTransMaxPO - @batchPO

			BEGIN TRY
				EXEC DBCUST.CustDB.dbo.Task_Winlimit_InsertHistoryData
					@XmlData = @TransInfoMaxPO
			END TRY
			BEGIN CATCH
				SELECT	 @ErrCode = ERROR_NUMBER()
						,@ErrMsg = ERROR_MESSAGE()				
			END CATCH
		END
		
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
