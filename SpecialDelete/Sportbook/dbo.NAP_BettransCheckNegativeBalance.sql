/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransCheckNegativeBalance]
	@TransIds		VARCHAR(MAX) = '',
	@Type			BIT,
	@ExcludeRunning BIT = 0
AS
	/*
	Created by: 20131119@Kathy
	Task : Check if a bet credit of customer is negative
	DB: DBTXN.bodb02

	Revisions:   
		- 20140515@Kathy: Calculate balance from translog (for running tickets) and bettrans
		- 20140919@Kathy: Correct balance formula of translog 
		- 20150606@Kathy: Migrate custDB to new server DBCust(Get credit from DBCust.CustDB) [Redmine:#36216] 
		- 20150612@Dominic: Exclude BetTrade members
		- 20150630@Dominic: Remove duplicated running Metric Gaming tickets [Redmine:#38200]
		- 20160118@Kathy: get balance from bettransRNG & bettransLC [Redmine:#50674]
		- 20160112@Patrick: Support Cricket [Redmine: #50688] & [Redmine: #52109]
		- 20170112@Kent: Tune performance to calculate for 3K ticket [Redmine: #67987]
		- 20170321@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20190321@Alan: Do not check negative balance for CN88 [109858]
		- 20210326@Kathy: Tuning SP for EC [Redmine:#151103]
		- 20210517@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20211229@Max: [TVS] Changes of TVS related to split Transfer out of bettrans [Redmine: #165093]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220818@July: Change of Void By Bet ID regarding to Scale out DBTrans [Redmine: #176811]
		- 20230331@July: TVS changes for new process of BU [Redmine: #184000]
		- 20240111@July: [TVS] Negative Balance - Don't Send Notification to Single Wallet Licensee [Redmine: #199097]

	Param's Explanation: Special bet delete option
		@transids: All ticket of customers who need to be check negative bet credit
				   For bonus	: cash or bonus tickets that are enabled and checked
		@Type: 
			- 0: Check negative bet credit for special delete funcion
			- 1: Check negative bet credit for recover funcion
		@ExcludeRunning: Indicate status of tickets for special delete fuction
			- 0: Check negative bet credit of running tickets and settled tickets
			- 1: Check negative bet credit of settled tickets

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @SiteDBGroupID	SMALLINT = 0
		  , @movebetdate	SMALLDATETIME
		  , @balanceupdate	SMALLDATETIME

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpTransId TABLE (transid BIGINT PRIMARY KEY)
	
	DECLARE @tmpCurrentBalance TABLE (
		custid		INT
		,username	NVARCHAR(50)
		,balance	MONEY
	)
	
	DECLARE @tmpChangedBalance TABLE (
		custid		INT
		,balance	MONEY
	)	
	
	CREATE TABLE #BetDelete (
		transid			BIGINT PRIMARY KEY
		,custid			INT
		,winlost		MONEY
		,actual_stake	MONEY
		,playercomm		MONEY
		,bettype		SMALLINT
		,matchid		INT
		,refno			BIGINT	
		,WalletType		TINYINT
		,BonusID		INT
		,srecommend		INT
	)
	
	DECLARE @tmpAffectedCustId TABLE (CustId INT)

	INSERT INTO @tmpTransId(transid)
	SELECT value FROM STRING_SPLIT(@TransIds, ',') WHERE value <> ''

	INSERT INTO #BetDelete(
			transid
			,custid
			,winlost
			,actual_stake
			,playercomm
			,bettype
			,matchid
			,refno
			,WalletType
			,BonusID
			,srecommend
	)
	SELECT	b.transid -- normal ticket 
			,b.custid
			,b.winlost
			,b.actual_stake
			,b.playercomm
			,b.bettype
			,b.matchid
			,b.refno
			,b.WalletType
			,b.BonusID
			,b.srecommend
	FROM	@tmpTransId t
		INNER JOIN bettrans b WITH(NOLOCK)
			ON	b.transid = t.transid AND b.SiteDBGroupID = @SiteDBGroupID
	WHERE	1 = CASE 
					WHEN @Type = 0 AND @ExcludeRunning = 0 AND b.statusID IN (0, 1,111,112,113) THEN 1 
					WHEN @Type = 0 AND @ExcludeRunning = 1 AND b.statusID IN (111, 112, 113) THEN 1
					WHEN @Type = 1 AND b.statusID = 102 THEN 1
					ELSE 0 
					END 
	
	-- delete bonus tickets belonging to canceled/expired campaign
	DELETE t
	FROM #BetDelete t
		 LEFT JOIN dbo.BonusWalletCredit AS bwc WITH(NOLOCK)
			ON	t.BonusID = bwc.BonusID
				AND t.custid = bwc.CustID
		 LEFT JOIN dbo.f_Set_BonusWallet_StatusSel() st
			ON	bwc.StatusID = st.StatusId
	WHERE t.BonusID > 0 
	  AND t.WalletType = 1 
	  AND st.BonusFlag = 2				    				    		  		  			 				    		  

	-- delete tickets belonging to Single wallet Licensee
	DELETE t
	FROM #BetDelete t
		 INNER JOIN CustDB.dbo.Dep_CustSuper cs WITH(NOLOCK)
			ON t.srecommend = cs.custid
		 OUTER APPLY (
						SELECT TOP(1) vp.SiteID
						FROM DBCUST.SiteConfig.dbo.LicVendorProfile vp WITH(NOLOCK)
							INNER JOIN DBCUST.SiteConfig.dbo.ConfigMaster cm WITH(NOLOCK)
								ON vp.SiteID = cm.SiteID
							INNER JOIN DBCUST.SiteConfig.dbo.ConfigDetail cd WITH(NOLOCK)
								ON cm.ConfigID = cd.ConfigID
						WHERE cd.KeyName = 'EnableSingleWallet'
							AND cd.KeyValue = 'true'
							AND vp.SiteName = cs.site
					) vp 
	WHERE vp.SiteID IS NOT NULL

	INSERT INTO @tmpAffectedCustId(CustId)
	SELECT	DISTINCT custid
	FROM	#BetDelete

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
	--Get BalanceUpDate
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceupdate OUTPUT

	-- calculate sum of members' balance on bettrans tables
	INSERT INTO @tmpCurrentBalance(custid, username, balance)
	SELECT b.custid, b.Username, SUM(b.balance)
	FROM 
	(
		SELECT	b.custid, b.Username, (b.winlost - b.actual_stake + b.playercomm ) AS balance
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID AND tl.SiteDBGroupID = b.SiteDBGroupID				
		WHERE	b.custid IN (SELECT custid FROM #BetDelete)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))	
				AND b.bettype < 19999
				AND b.winlostdate > @movebetdate 
				AND b.SiteDBGroupID = @SiteDBGroupID

		--Get sum ticket from new table Transfer
		UNION ALL
		SELECT	tl.custid, tl.Username, (tl.Winlost - tl.actual_stake + tl.PlayerComm) AS balance
		FROM	dbo.Transfer tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @tmpAffectedCustId)
				AND tl.Bettype >= 19999
				AND 1 = CASE WHEN tl.bettype = 19999 AND tl.winlostdate > @movebetdate THEN 0 --> new sum
							 WHEN tl.bettype = 20000 AND tl.winlostdate > @balanceupdate then 0 --> new bal
                             WHEN tl.winlostdate < @balanceupdate then 0 --> old data
						ELSE 1 END
				
		UNION ALL 
		SELECT	tl.custid, tl.Username, (0 - tl.actual_stake + 0 ) AS balance
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @tmpAffectedCustId)
				AND tl.statusID IN (0, 1)	
				AND tl.SiteDBGroupID = @SiteDBGroupID
		UNION ALL
		SELECT	b.custid, b.Username, (b.winlost - b.actual_stake + b.playercomm ) AS balance
		FROM	dbo.bettransRnG b WITH(NOLOCK)
		WHERE	b.custid IN (SELECT custid FROM @tmpAffectedCustId)
				AND b.IsSum=0				
				AND b.SiteDBGroupID = @SiteDBGroupID
		UNION ALL
		SELECT	b.custid, b.Username, (b.winlost - b.actual_stake + b.playercomm ) AS balance
		FROM	dbo.bettransLC b WITH(NOLOCK)
		WHERE	b.custid IN (SELECT custid FROM @tmpAffectedCustId) 
				AND b.IsSum=0	
				AND b.SiteDBGroupID = @SiteDBGroupID
	) b
	GROUP BY b.custid, b.Username

	--calc chargecomm
	DECLARE @ChargeComm TABLE (custid INT, matchid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY)
	
	INSERT INTO @ChargeComm (custid, matchid, winlost, actual_stake, playercomm)
	SELECT t.custid, t.matchid, t.NetWin AS winlost, t.NetWin AS actual_stake, (t.NetWin * b.playerdiscount) AS playercomm
	FROM (
		SELECT MIN(transid) AS FirstTransId, SUM(winlost - actual_stake) AS NetWin, custid, matchid
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE EXISTS (SELECT TOP 1 1 FROM #BetDelete bb WHERE b.custid = bb.custid)  
			AND NOT EXISTS (SELECT TOP 1 1 FROM @tmpTransId bb WHERE b.transid = bb.transid)
			AND bettype = 501
			AND playerdiscount < 0
			AND b.SiteDBGroupID = @SiteDBGroupID
		GROUP BY custid, matchid
	)t
	INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.FirstTransId = b.transid AND b.SiteDBGroupID = @SitedbgroupId
	WHERE t.NetWin > 0

	UNION ALL
	SELECT DISTINCT b.custid, b.matchid, b.winlost, b.actual_stake, -b.playercomm
	From dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #BetDelete bd on bd.matchid = b.matchid AND bd.custid = b.custid
	WHERE b.bettype = 500 AND b.SiteDBGroupID = @SiteDBGroupID

	IF(@Type = 0)
	BEGIN
		INSERT INTO @tmpChangedBalance (custid, balance)
		SELECT t.custid, SUM(t.winlost - t.actual_stake + t.playercomm) AS balance
		FROM (
			SELECT b.custid, b.winlost, b.actual_stake, b.playercomm
			FROM #BetDelete b
			UNION ALL
			SELECT b.custid, b.winlost, b.actual_stake, -b.playercomm
			FROM @ChargeComm b
		)t
		GROUP BY t.custid
	END
	ELSE -- recover
	BEGIN
		INSERT INTO @tmpChangedBalance(custid, balance)
		SELECT tmp.custid, SUM(tmp.balance)
		FROM (
			SELECT	b.custid, b.actual_stake AS balance
			FROM	#BetDelete b
		) tmp
		GROUP BY tmp.custid
	END		

	--netposition bal
	DECLARE @BalNetPositionTmp TABLE(CustId INT, Balance MONEY)

	INSERT INTO @BalNetPositionTmp(CustId, Balance)
	SELECT bal.CustId, SUM(Credit - Debit) AS Balance
	FROM dbo.BalNetPosition bal WITH(NOLOCK)
		INNER JOIN #BetDelete d ON bal.CustId = d.CustId AND bal.MatchId = d.MatchId AND bal.Bettype = d.bettype
	GROUP BY bal.CustId
	
	SELECT	bal.custid
			,bal.username
			,c.site
	FROM	@tmpChangedBalance t
		INNER JOIN @tmpCurrentBalance bal 
			on	t.custid = bal.custid
		INNER JOIN DBCUST.custDB.dbo.custInfo ci WITH(NOLOCK ) 
			ON	bal.custid = ci.custid
		INNER JOIN custDB.dbo.Customer c WITH(NOLOCK) 
			ON	c.custid = ci.custid AND c.site <> 'CN88'
		LEFT JOIN @BalNetPositionTmp tt ON t.CustId = tt.CustId
	WHERE	t.balance > 0 
			AND (ci.credit + bal.balance - t.balance + ISNULL(tt.Balance, 0)) < 0	
			
	DROP TABLE #BetDelete
END
GO
