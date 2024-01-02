/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_BalanceNegative]
AS
/*
	Created by: Viet
	Date: 2014-01-06
	Task: Add Customers together with their Negative Balance 
	DB: DBTXN/BODB02
	ORIGINAL SP: Task_BalanceNegativeHistoryIns_Cust, Task_BalanceNegativeDel_CustCredit
	
	Revision: 		
		- 20150316@Elodie: Support Negative Balance function for more licensee ('12Bet', 'asiabet88', 'mansion88', 'Mayfair') [Red:#30840]
		- 20150624@Elodie: Add Bodog Licensee (Licenseeid = 14)
		- 20150917@Elodie: Support Negative Balance function for all licensee [Red:#43705]
		- 20151126@Elodie: Remove BetTrade accounts in Negative Balance process [Red:#36480]
		- 20170604@Bobby: Remove dummy accounts from table CustDB-TradeCust [Red:#36480]
		- 20180326@Kathy: Enhancememnt for WC [Redmine:#89132]
		- 20180927@Sophia: Migrate bodb_Licensee from DB052 to DBCUST [redmine: #99855]
		- 20210702@Max: Expand Transfer Time Frame - Change The Rule Checking Move Bet Flag [Redmine: #154572]
		- 20211229@Max: Split Transfer - Adjust Negative Balance Service & Adjustment Transfer of Bonus [Redmine: #165098]
		- 20230201@July: TVS changes for new process of BU [Redmine: #184000]
		- 20231229@Louisa: Exclude Single Wallet Licensee [Redmine: #199060]
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @BatchCount INT
		, @movebetdate SMALLDATETIME
		, @balanceupdate SMALLDATETIME

	DECLARE @tmpMatch TABLE (MatchId INT PRIMARY KEY, MinExecId BIGINT, MaxExecId BIGINT)
	DECLARE @tmpAffectedCustId	TABLE (CustId INT, Recommend INT)
	DECLARE @tmpCustIdSendMail	TABLE (CustId INT, Site VARCHAR(50))
	
	CREATE TABLE #tmpMemberBalance (CustId INT, Balance MONEY, Site VARCHAR(50))
	CREATE TABLE #tmpMemberBalanceNegative (custid INT PRIMARY KEY, balance MONEY, Site VARCHAR(50))	
	CREATE TABLE #tmpAllCustomer (CustId INT PRIMARY KEY)

	SET @BatchCount = 2000

	INSERT INTO @tmpMatch (MatchId, MinExecId, MaxExecId)
	SELECT	MatchID, MIN(ExecId), MAX(ExecID)
	FROM	dbo.BalanceNegative bn WITH(NOLOCK)
	WHERE	bn.StatusID = 0
	GROUP BY MatchID

	IF @@ROWCOUNT = 0
		RETURN

	INSERT INTO @tmpCustIdSendMail(CustId, Site)
	SELECT	c.custid, c.site
	FROM	@tmpMatch m
		INNER JOIN dbo.BalanceNegative bn WITH(NOLOCK)
			ON m.MatchId = bn.MatchID
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON c.custid = bn.CustID
		INNER JOIN CustDB.dbo.Dep_CustSuper cs WITH(NOLOCK)
			ON c.recommend = cs.custid
		OUTER APPLY (
							SELECT TOP(1) vp.SiteID
							FROM DBCUST.SiteConfig.dbo.LicVendorProfile vp WITH(NOLOCK)
								INNER JOIN DBCUST.SiteConfig.dbo.configMaster cm WITH(NOLOCK)
									ON vp.SiteId = cm.SiteId
								INNER JOIN DBCUST.SiteConfig.dbo.configdetail cd WITH(NOLOCK)
									ON cm.ConfigId = cd.ConfigID
							WHERE cd.KeyName = 'EnableSingleWallet'
								AND cd.KeyValue = 'true'
								AND vp.SiteName = cs.site
						) vp 
	WHERE	bn.ExecID BETWEEN m.MinExecId AND m.MaxExecId
			AND bn.StatusID = 0
			AND c.roleid = 1
			AND vp.SiteID IS NULL
	GROUP by c.custid, c.site

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
		
	--Get BalanceUpDate
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceupdate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM @tmpCustIdSendMail)
	BEGIN

		-- turn to use bettrans in realtime
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS Balance, c.Site
		FROM	@tmpCustIdSendMail c
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON b.custid = c.CustId	AND b.bettype < 19999
		WHERE	1 = CASE 
						WHEN b.bettype BETWEEN 801 AND 806 AND b.statusID = 0 THEN 0
						WHEN b.bettype < 19999 AND b.winlostdate <= @movebetdate THEN 0 -- old bet
						ELSE 1
					END
		GROUP BY b.CustId, c.Site

		--Get sum ticket from new table Transfer
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS Balance, c.Site
		FROM	@tmpCustIdSendMail c
			INNER JOIN dbo.Transfer b WITH(NOLOCK)
				ON b.custid = c.CustId	AND b.bettype >= 19999
		WHERE 1 = CASE WHEN b.bettype = 19999 AND b.winlostdate > @movebetdate THEN 0 --> new sum
					   WHEN b.bettype = 20000 AND b.winlostdate > @balanceupdate then 0 --> new bal
                       WHEN b.winlostdate < @balanceupdate then 0 --> old data
					ELSE 1 END
		GROUP BY b.CustId, c.Site
		
		-- translog
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT tl.custid, SUM(0 - tl.actual_stake) AS Balance, c.Site
		FROM	@tmpCustIdSendMail c
			INNER JOIN dbo.translog tl WITH(NOLOCK)
				ON tl.custid = c.CustId
		WHERE	tl.statusID BETWEEN 0 AND 1
		GROUP BY tl.custid, c.Site

		-- bettransRnG
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT	br.custid, SUM(br.winlost - br.actual_stake + br.playercomm) AS Balance, c.Site
		FROM	@tmpCustIdSendMail c
			INNER JOIN dbo.bettransRnG br WITH(NOLOCK)
				ON	br.custid = c.CustId
		WHERE	br.IsSum = 0
		GROUP BY br.custid, c.Site

		-- bettransLC
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT	lc.custid, SUM(lc.winlost - lc.actual_stake + lc.playercomm) AS Balance, c.Site
		FROM	@tmpCustIdSendMail c
			INNER JOIN dbo.bettransLC lc WITH(NOLOCK)
				ON	lc.custid = c.CustId
		WHERE	lc.IsSum = 0
		GROUP BY lc.custid, c.Site

		-- BonusAdjustmentTransfer
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT	aj.CustID, SUM(Amount) AS Balance, c.Site
		FROM	dbo.BonusAdjustmentTransfer aj WITH(NOLOCK)
			INNER JOIN @tmpCustIdSendMail c 
				ON aj.CustID = c.CustId
		WHERE	aj.isTransferred = 0
		GROUP BY aj.CustID, c.Site
		
		-- BalNetPosition
		INSERT INTO #tmpMemberBalance (CustId, Balance, Site)
		SELECT	bn.CustID, SUM(bn.Credit - bn.Debit) AS Balance, c.Site
		FROM	dbo.BalNetPosition bn WITH(NOLOCK)
			INNER JOIN @tmpCustIdSendMail c
				ON bn.CustID = c.CustId
		GROUP BY	bn.CustID, c.Site
		
		INSERT INTO #tmpMemberBalanceNegative (CustID, Balance, Site)
		SELECT	c.custid, SUM(c.balance), c.Site
		FROM	#tmpMemberBalance c
		GROUP BY c.custid, c.Site
		HAVING SUM(c.Balance) < 0 -- negative balance

		-- Others dummy
		DELETE	t
		FROM	#tmpMemberBalanceNegative t
		WHERE	EXISTS (SELECT TOP 1 1 FROM DBCUST.CustDB.dbo.TradeCust tc WITH(NOLOCK) WHERE tc.CustId = t.CustId)

		IF EXISTS (SELECT TOP 1 1 FROM #tmpMemberBalanceNegative) 
		BEGIN
			INSERT INTO dbo.BalanceNegativeHistory(
				LogDate
				, ExecDate
				, MatchID
				, ActionID
				, GroupID
				, CustID
				, Balance
				, TotalBalance
				, StatusID
				, Site
				, Remark
			)
			
			SELECT	GETDATE()
					, bn.ExecDate
					, bn.MatchID
					, bn.ActionID
					, bn.GroupID
					, bn.CustID
					, bn.Balance
					, t.balance AS TotalBalance
					, 0
					, t.site
					, bn.Remark 
			FROM	dbo.BalanceNegative bn WITH (NOLOCK) 
					INNER JOIN @tmpMatch m	
						ON bn.MatchID = m.MatchId
					INNER JOIN #tmpMemberBalanceNegative t WITH (NOLOCK)
						ON t.custID = bn.CustID 
			WHERE	bn.ExecID BETWEEN m.MinExecId AND m.MaxExecId
					AND bn.StatusID = 0
		END
	END

	-- Remove Credit Customer & SWL out BalanceNegative
	INSERT INTO #tmpAllCustomer (CustId)
	SELECT	DISTINCT CustID
	FROM	dbo.BalanceNegative bn WITH (NOLOCK)
		INNER JOIN @tmpMatch m	
			ON bn.MatchID = m.MatchId
	WHERE	bn.ExecID BETWEEN m.MinExecId AND m.MaxExecId
			AND bn.StatusID = 0
	
	-- delete deposit member
	DELETE t
	FROM	#tmpAllCustomer t
	WHERE	EXISTS (SELECT TOP 1 1 FROM @tmpCustIdSendMail c WHERE t.CustId = c.CustId)
	
	WHILE( 1 = 1)
	BEGIN
		-- delete credit member
		DELETE	TOP (@BatchCount) bn
		FROM	dbo.BalanceNegative bn --WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tmpMatch m
				ON bn.MatchID = m.MatchId
		WHERE	bn.ExecID BETWEEN m.MinExecId AND m.MaxExecId
				AND bn.StatusID = 0
				AND	EXISTS (SELECT TOP 1 1 FROM #tmpAllCustomer t WHERE t.CustID = bn.CustID)

		IF @@ROWCOUNT < @BatchCount
			BREAK
	END

	-- update statusid 
	WHILE (1 = 1)
	BEGIN
		UPDATE	TOP (@BatchCount) bn --WITH(UPDLOCK,ROWLOCK)
			SET StatusID = 1
		FROM	dbo.BalanceNegative bn 
			INNER JOIN @tmpMatch m 
				ON m.MatchId = bn.MatchID
		WHERE	bn.ExecID BETWEEN m.MinExecId AND m.MaxExecId
				AND StatusID = 0 

		IF @@ROWCOUNT < @BatchCount
			BREAK
	END
	
	DROP TABLE #tmpMemberBalance
	DROP TABLE #tmpMemberBalanceNegative
	DROP TABLE #tmpAllCustomer
END
GO

