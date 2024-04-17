/*<info serverAlias="DBSIC-bodb02,DBCTG-bodb02" executers="" viewers="" isFunction="1"></info>*/

/*
	Created: 20240416@Louisa
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
	WHERE username IN ('6666AHK')

	;WITH T AS (
		SELECT '6666AHK' username, 'MH-HK$' Master, 'SH-HK$' Super		
	)
	UPDATE c
	SET c.srecommend_New = s.custid,
		c.mrecommend_New = m.custid
	FROM #tmp_Cust c
		INNER JOIN T ON c.username = t.username
		INNER JOIN custdb.dbo.customer s WITH(NOLOCK) ON t.super = s.username
		LEFT JOIN custdb.dbo.customer m WITH(NOLOCK) ON t.master = m.username

	-- member 230RMB, 231RMB (move member)
	INSERT INTO #tmp_Cust (CustID, Username, roleid, site, recommend_NEW, mrecommend_New,srecommend_New)
	SELECT ci.custid, ci.username,ci.roleid, 'Hedging',temp.recommend_New, temp.mrecommend_New, temp.srecommend_New
	FROM custdb.dbo.custinfo ci WITH(NOLOCK)
		CROSS APPLY (SELECT custid AS recommend_New,
						 mrecommend AS mrecommend_New,
						 srecommend AS srecommend_New		
					FROM custdb.dbo.custinfo WITH(NOLOCK)
					WHERE username = 'AH-RMB'
	) AS temp
	WHERE username IN('230RMB','231RMB')

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
		SET f.recommend = ISNULL(t.recommend_NEW, f.recommend)
			,f.mrecommend = ISNULL(t.mrecommend_New, f.mrecommend)
			,f.srecommend = ISNULL(t.srecommend_New, f.srecommend)
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		UPDATE TOP(@Threshold) f
		SET f.Recommend		= ISNULL(t.recommend_NEW, f.Recommend)
			,f.mrecommend	= ISNULL(t.mrecommend_New, f.mrecommend)
			,f.srecommend	= ISNULL(t.srecommend_New, f.srecommend)
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
		SET f.mrecommend	= ISNULL(t.mrecommend_New, f.mrecommend)
			,f.srecommend	= ISNULL(t.srecommend_New, f.srecommend)
			,f.RepUpdateTime = CASE WHEN IsInHouse = 1 THEN SYSDATETIME() ELSE f.RepUpdateTime END
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		UPDATE TOP(@Threshold) f
		SET f.mrecommend =	ISNULL(t.mrecommend_New, f.mrecommend)
			,f.srecommend = ISNULL(t.srecommend_New, f.srecommend)
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
		SET f.recommend		= ISNULL(t.recommend_NEW, f.recommend)
			,f.mrecommend	= ISNULL(t.mrecommend_New, f.mrecommend)
			,f.srecommend	= ISNULL(t.srecommend_New, f.srecommend)
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
		SET f.mrecommend	= ISNULL(t.mrecommend_New, f.mrecommend)
			,f.srecommend	= ISNULL(t.srecommend_New, f.srecommend)
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
