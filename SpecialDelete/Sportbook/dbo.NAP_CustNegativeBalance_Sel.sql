/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CustNegativeBalance_Sel] 	
	@CustIds			  VARCHAR(MAX)	= '',
    @NegativeBalanceUsers VARCHAR(MAX) OUTPUT
AS
/*
	Created: 20161111@Kent
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions: 		
		- 20161026@Kent: Check negative balance after recovering voided Parlay tickets [Redmine:#65531]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20190321@Alan: Do not check negative balance for CN88 [109858]
		- 20210517@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20211229@Max: [TVS] Changes of TVS related to split Transfer out of bettrans [Redmine: #165093]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20230331@July: TVS changes for new process of BU [Redmine: #184000]
		- 20240111@July: [TVS] Negative Balance - Don't Send Notification to Single Wallet Licensee [Redmine: #199097]
		- 20240527@July: [TVS] Scaleout DBCUST [Redmine: #205629]

*/
BEGIN
	SET NOCOUNT ON		
	
	DECLARE @SiteDBGroupID	SMALLINT = 0
		  , @movebetdate	SMALLDATETIME
		  , @balanceupdate	SMALLDATETIME

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @CustList TABLE (custid INT)
	
	DECLARE @balanceCust TABLE (
		custid		INT
		,username	NVARCHAR(50)
		,balance	MONEY
	)	
	CREATE TABLE #CustomerList (
		 custid			INT
		,Username		NVARCHAR(50)
		,winlost		MONEY
		,actual_stake	MONEY
		,playercomm		MONEY
		,srecommend		INT
	)
	DECLARE @BalNetPositionTmp TABLE(CustId INT, Balance MONEY)	
	
	INSERT INTO @CustList(custid)
	SELECT value FROM STRING_SPLIT(@CustIds, ',') WHERE value <> ''
	
	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
	--Get BalanceUpDate
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @balanceupdate OUTPUT

	BEGIN
		INSERT INTO #CustomerList (custid, Username, winlost, actual_stake, playercomm, srecommend)
		SELECT	b.custid, b.Username, b.winlost, b.actual_stake, b.playercomm, b.srecommend
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID AND tl.SiteDBGroupID = b.SiteDBGroupID
		WHERE	b.custid IN (SELECT custid FROM @CustList)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))
				AND b.bettype < 19999
				AND b.winlostdate > @movebetdate 
				AND b.SiteDBGroupID = @SiteDBGroupID

		--Get sum ticket from new table Transfer
		UNION ALL
		SELECT	tl.custid, tl.Username, tl.Winlost, tl.Actual_Stake, tl.PlayerComm, tl.srecommend
		FROM	dbo.Transfer tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @CustList)
				AND tl.Bettype >= 19999
				AND 1 = CASE WHEN tl.bettype = 19999 AND tl.winlostdate > @movebetdate THEN 0 --> new sum 
							 WHEN tl.bettype = 20000 AND tl.winlostdate > @balanceupdate then 0 --> new bal
                             WHEN tl.winlostdate < @balanceupdate then 0 --> old data
						ELSE 1 END

		UNION ALL 
		SELECT	tl.custid, tl.Username, 0, tl.actual_stake, 0, tl.srecommend
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @CustList)
				AND tl.statusID IN (0, 1)	
				AND tl.SiteDBGroupID = @SiteDBGroupID
				
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm, srecommend
		FROM	dbo.bettransRnG WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM @CustList)
				AND IsSum = 0
				AND SiteDBGroupID = @SiteDBGroupID
				
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm, srecommend
		FROM	dbo.bettransLC WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM @CustList) 
				AND IsSum = 0	
				AND SiteDBGroupID = @SiteDBGroupID
	END			
	
	-- delete custid belonging to Single wallet Licensee
	DELETE t
	FROM #CustomerList t
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

	INSERT INTO @balanceCust (custid, username, balance)
	SELECT custid, username, SUM(winlost - actual_stake + playercomm)
	FROM #CustomerList
	GROUP BY custid, username	
	
	--netposition bal
	INSERT INTO @BalNetPositionTmp(CustId, Balance)
	SELECT bal.CustId, SUM(Credit - Debit) AS Balance
	FROM dbo.BalNetPosition bal WITH(NOLOCK)
		INNER JOIN @CustList d ON bal.CustId = d.CustId
	GROUP BY bal.CustId
	
	SET @NegativeBalanceUsers = ''
	SELECT @NegativeBalanceUsers = @NegativeBalanceUsers + 
								   CASE WHEN @NegativeBalanceUsers <> '' THEN ',' ELSE '' END + 
								   bal.username			
	FROM @balanceCust bal
		INNER JOIN CustDB.dbo.custInfo c WITH(NOLOCK ) 
			ON	bal.custid = c.custid
		INNER JOIN custDB.dbo.Customer ag WITH(NOLOCK) 
			ON	ag.custid = c.recommend AND ag.site <> 'CN88'
		LEFT JOIN @BalNetPositionTmp tt ON bal.CustId = tt.CustId
	WHERE (c.credit + bal.balance + ISNULL(tt.Balance, 0)) < 0	
	
	DROP TABLE #CustomerList
END
GO


