/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="" viewers="" isFunction="1"></info>*/

/*
	Created: 20240114@Louisa
	Task: Migrate Data for new site Hedging and PhoneBetting [Redmine: #201044]
	DB: DBSIC/bodb02, DBCTG-bodb02

	--Transfer/Transfer_Coll (bettype 19999,20000), BalanceTable_tmp_cal: run on SiteDB3 and DBTrans
	--Transfer, Transfer_Coll (bettype not in 19999,20000)				: run SiteDB3 only, then Inhouse rep to DBtrans
	--Script will check @@server Name to run
*/

USE bodb02
GO


---- init data
BEGIN
	DROP TABLE IF EXISTS #tmp_Cust;
	CREATE TABLE #tmp_Cust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT )
	
	DROP TABLE IF EXISTS #tmp_transfer;
	CREATE TABLE #tmp_transfer ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT, IsInHouse BIT )	

	DROP TABLE IF EXISTS #tmp_Balance;
	CREATE TABLE #tmp_Balance ( ID INT IDENTITY(1,1) PRIMARY KEY, dow TINYINT, custid INT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

	INSERT INTO #tmp_Cust(CustID, Username, site, roleid)
	SELECT custid,username,'Hedging',roleid
	FROM custdb.dbo.custinfo WITH (NOLOCK)
	WHERE username IN ('MOLLYBET','AH501','MollyBF','XYZHK','billma','FRARM','M008iRM','M9999RM','mbrm','2022WC-RM','CASHTEST','CMD','FRA','IT-test1','MMRODDS','XYZPTRM','XYZRM','ISN','STELIM')
	UNION 
	SELECT custid,username,'Special',roleid
	FROM custdb.dbo.custinfo WITH (NOLOCK)
	WHERE username IN ('wsrmb','8RM','8RM8801','8RM8802','8RM8803','8RM8804','8RM8805','8RM8806','8RM8807','8RM8808','8RM8809','8RM8810','8RMTest01','BARM','BARM002','MMRWC22','PHIRM','WCBill','WINRM','wsrm')

	;WITH T AS (
		SELECT 'MOLLYBET' username, 'MH-EURO' Master, 'SH-EURO' Super
		UNION SELECT 'AH501'	, NULL		, 'SH-HK$'
		UNION SELECT 'MollyBF'	, 'MH-HK$'	, 'SH-HK$'
		UNION SELECT 'XYZHK'	, 'MH-HK$'	, 'SH-HK$'
		UNION SELECT 'billma'	, NULL		, 'SH-RM'
		UNION SELECT 'FRARM'	, NULL		, 'SH-RM'
		UNION SELECT 'M008iRM'	, NULL		, 'SH-RM'
		UNION SELECT 'M9999RM'	, NULL		, 'SH-RM'
		UNION SELECT 'mbrm'		, NULL		, 'SH-RM'
		UNION SELECT '2022WC-RM', 'MH-RM'	, 'SH-RM'
		UNION SELECT 'CASHTEST'	, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'CMD'		, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'FRA'		, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'IT-test1'	, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'MMRODDS'	, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'XYZPTRM'	, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'XYZRM'	, 'MH-RM'	, 'SH-RM'
		UNION SELECT 'ISN'		, NULL		, 'SH-RMB'
		UNION SELECT 'STELIM'	, NULL		, 'SH-RMB'
	
		UNION SELECT 'wsrmb'		, 'MS-RMB' 	, 'SS-RMB'
		UNION SELECT '8RM'			, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8801'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8802'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8803'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8804'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8805'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8806'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8807'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8808'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8809'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RM8810'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT '8RMTest01'	, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'BARM'			, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'BARM002'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'MMRWC22'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'PHIRM'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'WCBill'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'WINRM'		, 'MS-RM'	, 'SS-RM'
		UNION SELECT 'wsrm'			, 'MS-RM'	, 'SS-RM'
	)
	UPDATE c
	SET c.srecommend_New = s.custid,
		c.mrecommend_New = m.custid
	FROM #tmp_Cust c
		INNER JOIN T ON c.username = t.username
		INNER JOIN custdb.dbo.customer s WITH(NOLOCK) ON t.super = s.username
		LEFT JOIN custdb.dbo.customer m WITH(NOLOCK) ON t.master = m.username

	-- member fmrup
	INSERT INTO #tmp_Cust (CustID, Username, roleid, site, recommend_NEW, mrecommend_New,srecommend_New)
	SELECT ci.custid, ci.username,ci.roleid, 'Hedging',temp.recommend_New, temp.mrecommend_New, temp.srecommend_New
	FROM custdb.dbo.custinfo ci WITH(NOLOCK)
		CROSS APPLY (SELECT custid AS recommend_New,
						 mrecommend AS mrecommend_New,
						 srecommend AS srecommend_New		
					FROM custdb.dbo.custinfo WITH(NOLOCK)
					WHERE username = 'AH-RUP'
	) AS temp
	WHERE username = 'fmrup'
	
	DROP TABLE IF EXISTS #tmp_Cust_RecommendList_roleid_3
	CREATE TABLE #tmp_Cust_RecommendList_roleid_3 (recommend INT PRIMARY KEY, mrecommend INT, srecommend_New INT)

	INSERT INTO #tmp_Cust_RecommendList_roleid_3 (recommend, mrecommend,srecommend_New)
	SELECT cc.recommend, c.CustID,c.srecommend_New
	FROM #tmp_Cust c
		INNER JOIN CUSTDB.dbo.vw_Customer cc WITH (NOLOCK) 
			ON c.CustID = cc.mrecommend 
				AND cc.roleid = 2
	WHERE c.roleid = 3

END

----UPDATE Transfer, Transfer_coll, roleid = 1
BEGIN
	DECLARE @IsSiteDB3 BIT	,@IsDBTrans BIT

	SELECT @IsSiteDB3 = CASE WHEN @@SERVERNAME IN( 'DEVDB061\DEVSITEDB2','TESTSITEDB2', 'SITDBGRP03N1','SITDBGRP03N2','DBGRP03N1', 'DBGRP03N2') 
							THEN 1 ELSE 0
							END
	SELECT @IsDBTrans = CASE WHEN @@SERVERNAME IN('DB-60\DevDBTrans','TESTDBTRANS','SITDBTRANS','DBTRANS')
							THEN 1 ELSE 0
							END

	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, recommend_NEW, mrecommend_New, srecommend_New, IsInHouse)
	SELECT f.transid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
			, CASE WHEN @IsSiteDB3 = 1 AND f.Bettype NOT IN(19999,20000) THEN 1 ELSE 0 
					END AS IsInHouse
	FROM dbo.Transfer f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.custid
	WHERE c.roleid = 1
		AND ( 
				@IsSiteDB3 = 1	OR ( @IsDBTrans = 1 AND f.Bettype IN (19999, 20000) )
			)
	
	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) f
		SET f.recommend = t.recommend_NEW
			,f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		UPDATE TOP(@Threshold) f
		SET f.Recommend	= t.recommend_NEW
			,f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.transfer_coll f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END
GO

----UPDATE Transfer, Transfer_coll, roleid = 2
BEGIN
	DECLARE @IsSiteDB3 BIT	,@IsDBTrans BIT

	SELECT @IsSiteDB3 = CASE WHEN @@SERVERNAME IN( 'DEVDB061\DEVSITEDB2','TESTSITEDB2', 'SITDBGRP03N1','SITDBGRP03N2','DBGRP03N1', 'DBGRP03N2') 
							THEN 1 ELSE 0
							END
	SELECT @IsDBTrans = CASE WHEN @@SERVERNAME IN('DB-60\DevDBTrans','TESTDBTRANS','SITDBTRANS','DBTRANS')
							THEN 1 ELSE 0
							END

	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, mrecommend_New, srecommend_New, IsInHouse)
	SELECT f.transid, c.mrecommend_New, c.srecommend_New
			, CASE WHEN @IsSiteDB3 = 1 AND f.Bettype NOT IN(19999,20000) THEN 1 ELSE 0 
					END AS IsInHouse
	FROM dbo.Transfer f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.Recommend
	WHERE c.roleid = 2
		AND ( 
				@IsSiteDB3 = 1	OR ( @IsDBTrans = 1 AND f.Bettype IN (19999, 20000) )
			)
	
	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) f
		SET f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		UPDATE TOP(@Threshold) f
		SET f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.transfer_coll f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow
		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END
GO

--UPDATE transfer, roleid = 3
BEGIN
	DECLARE @IsSiteDB3 BIT	,@IsDBTrans BIT

	SELECT @IsSiteDB3 = CASE WHEN @@SERVERNAME IN( 'DEVDB061\DEVSITEDB2','TESTSITEDB2', 'SITDBGRP03N1','SITDBGRP03N2','DBGRP03N1', 'DBGRP03N2') 
							THEN 1 ELSE 0
							END
	SELECT @IsDBTrans = CASE WHEN @@SERVERNAME IN('DB-60\DevDBTrans','TESTDBTRANS','SITDBTRANS','DBTRANS')
							THEN 1 ELSE 0
							END

	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, srecommend_New, IsInHouse)
	SELECT f.transid, c.srecommend_New
			, CASE WHEN @IsSiteDB3 = 1 AND f.Bettype NOT IN(19999,20000) THEN 1 ELSE 0 
					END AS IsInHouse
	FROM dbo.Transfer f WITH(NOLOCK)
		INNER JOIN #tmp_Cust_RecommendList_roleid_3 c ON c.recommend = f.recommend
	WHERE @IsSiteDB3 = 1 OR ( @IsDBTrans = 1 AND f.Bettype IN (19999, 20000) )

	INSERT INTO #tmp_transfer ( transid, srecommend_New, IsInHouse)
	SELECT f.transid,   cc.srecommend_New  
			, CASE WHEN @IsSiteDB3 = 1 AND f.Bettype NOT IN(19999,20000) THEN 1 ELSE 0 
					END AS IsInHouse
	FROM dbo.Transfer f WITH(NOLOCK)	
		INNER JOIN CUSTDB.dbo.vw_Customer c1 WITH (NOLOCK) ON   f.CustId = c1.CustID AND c1.roleid = 3
		CROSS APPLY (SELECT	c.srecommend_New, cc.mrecommend 
						FROM #tmp_Cust c
							INNER JOIN CUSTDB.dbo.vw_Customer cc WITH (NOLOCK) 
								ON c.CustID = cc.mrecommend AND cc.roleid = 2
						WHERE c.roleid = 3	AND f.custid = cc.mrecommend 
					) cc
	WHERE (@IsSiteDB3 = 1 OR ( @IsDBTrans = 1 AND f.Bettype IN (19999, 20000) ))

	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) f
		SET f.srecommend = t.srecommend_New
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		UPDATE TOP(@Threshold) f
		SET f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.transfer_coll f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END
GO
---/end transfer, transfer_coll


----BalanceTable_tmp_cal
----UPDATE BalanceTable_tmp_cal, roleid = 1
BEGIN
	TRUNCATE TABLE #tmp_Balance;
	INSERT INTO #tmp_Balance ( dow, custid, recommend_NEW, mrecommend_New, srecommend_New )
	SELECT f.dow, f.custid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM dbo.BalanceTable_tmp_cal f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.custid
	WHERE c.roleid = 1
	
	DECLARE @Threshold INT  = 1000
		,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_Balance
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) f
		SET f.recommend = t.recommend_NEW
			,f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
		FROM dbo.BalanceTable_tmp_cal f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_Balance t ON f.dow = t.dow AND f.custid = t.custid
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END
GO

----UPDATE BalanceTable_tmp_cal, roleid = 2
BEGIN
	TRUNCATE TABLE #tmp_Balance;
	INSERT INTO #tmp_Balance ( dow, custid, recommend_NEW, mrecommend_New, srecommend_New )
	SELECT f.dow, f.custid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM dbo.BalanceTable_tmp_cal f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.Recommend
	WHERE c.roleid = 2
	
	DECLARE @Threshold INT  = 1000
		,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_Balance
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) f
		SET f.recommend = t.recommend_NEW
			,f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
		FROM dbo.BalanceTable_tmp_cal f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_Balance t ON f.dow = t.dow AND f.custid = t.custid
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END
GO

--UPDATE BalanceTable_tmp_cal, roleid = 3
BEGIN
	TRUNCATE TABLE #tmp_Balance;
	INSERT INTO #tmp_Balance ( dow, custid, srecommend_New )
	SELECT f.dow, f.custid, c.srecommend_New
	FROM dbo.BalanceTable_tmp_cal f WITH(NOLOCK)
		INNER JOIN #tmp_Cust_RecommendList_roleid_3 c ON c.mrecommend = f.mrecommend

	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_Balance
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) b
		SET b.srecommend = t.srecommend_New
		FROM dbo.BalanceTable_tmp_cal b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_Balance t ON b.dow = t.dow AND b.custid = t.custid
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END