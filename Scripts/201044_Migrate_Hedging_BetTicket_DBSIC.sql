/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction=""></info>*/

/*
	Created: 20240114@Louisa
	Task: Migrate Data for bettrans,bettrans14,translog,translog14 [Redmine: #201044]
	DB: DBSIC/bodb02 

*/

USE bodb02
GO

---- init data
BEGIN
	DROP TABLE IF EXISTS #tmp_Cust;
	CREATE TABLE #tmp_Cust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT)

	DROP TABLE IF EXISTS #tmp_Member;
	CREATE TABLE #tmp_Member (CustID INT PRIMARY KEY,recommend_NEW INT, mrecommend_New INT, srecommend_New INT)

	--39 rows
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

	-- member fmrup (move member)
	INSERT INTO  #tmp_Member (CustID,recommend_NEW, mrecommend_New, srecommend_New)
	SELECT ci.custid, temp.recommend_New, temp.mrecommend_New, temp.srecommend_New
	FROM custdb.dbo.custinfo ci WITH(NOLOCK)
		CROSS APPLY (SELECT custid AS recommend_New,
						 mrecommend AS mrecommend_New,
						 srecommend AS srecommend_New		
					FROM custdb.dbo.custinfo WITH(NOLOCK)
					WHERE username = 'AH-RUP'
	) AS temp
	WHERE username = 'fmrup'

	--- move agent to another master
	INSERT INTO #tmp_Member (CustID,mrecommend_New, srecommend_New)
	SELECT s.CustID, c.mrecommend_New, c.srecommend_New
	FROM #tmp_Cust c
		INNER JOIN custdb.dbo.vw_customer s WITH(NOLOCK) 
			ON c.CustID = s.recommend
	WHERE c.roleid = 2

	--move master to another super
	INSERT INTO #tmp_Member (CustID,recommend_NEW, mrecommend_New, srecommend_New)
	SELECT s.CustID, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM #tmp_Cust c
		INNER JOIN custdb.dbo.vw_customer s WITH(NOLOCK) 
			ON c.CustID = s.mrecommend
	WHERE c.roleid = 3

	-- 11076 cust
	--select count(1) from #tmp_Member

END


--UPDATE Bettrans --> in-house rep to dbtrans --> replication to Replicated ( bettrans use RepUpdateTime for Inhouse Replication)
BEGIN
	DROP TABLE IF EXISTS #tmp_bettrans;
	CREATE TABLE #tmp_bettrans ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	
	
	INSERT INTO #tmp_bettrans (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.transid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM bettrans b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID
		
	DECLARE @Threshold1 INT  = 1000
			,@StartBettrans14 INT = 1, @StopBettrans14 INT = 0, @MaxBettrans14  INT = 0

	SELECT @MaxBettrans14	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold1 >= @MaxBettrans14
	SET @Threshold1 = @MaxBettrans14

	SELECT @StopBettrans14 = @Threshold1
	
	WHILE (@MaxBettrans14 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartBettrans14 AND @StopBettrans14

		IF @StopBettrans14 = @MaxBettrans14 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartBettrans14 = @StopBettrans14 + 1
		SET @StopBettrans14 = @StopBettrans14 + @Threshold1
		IF @StopBettrans14 >= @MaxBettrans14
			SET @StopBettrans14 = @MaxBettrans14
	END
END

----UPDATE translog--> in-house rep to dbtrans --> replication to Replicated ( translog use tstamp for Inhouse Replication)
BEGIN
	DROP TABLE IF EXISTS #tmp_translog;
	CREATE TABLE #tmp_translog ( ID INT IDENTITY(1,1) PRIMARY KEY, translogid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	
	
	INSERT INTO #tmp_translog (translogid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.translogid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM translog b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID

	DECLARE @Threshold2 INT  = 1000
			,@StartRow2 INT = 1, @StopRow2 INT = 0, @MaxRow2  INT = 0

	SELECT @MaxRow2 = MAX(ID)	FROM #tmp_translog
	
	IF @Threshold2 >= @MaxRow2
	SET @Threshold2 = @MaxRow2

	SELECT @StopRow2 = @Threshold2
	
	WHILE (@MaxRow2 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_translog t ON b.translogid = t.translogid
		WHERE t.ID BETWEEN @StartRow2 AND @StopRow2

		IF @StopRow2 = @MaxRow2 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow2 = @StopRow2 + 1
		SET @StopRow2 = @StopRow2 + @Threshold2
		IF @StopRow2 >= @MaxRow2
			SET @StopRow2 = @MaxRow2
	END
END

--UPDATE Bettrans14
BEGIN
	DROP TABLE IF EXISTS #tmp_bettrans14;
	CREATE TABLE #tmp_bettrans14 ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	
	
	INSERT INTO #tmp_bettrans14 (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.transid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM bettrans14 b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID
		
	DECLARE @Threshold3 INT  = 1000
			,@StartRow3 INT = 1, @StopRow3 INT = 0, @MaxRow3  INT = 0

	SELECT @MaxRow3	= MAX(ID) FROM #tmp_bettrans14
	
	IF @Threshold3 >= @MaxRow3
	SET @Threshold3 = @MaxRow3

	SELECT @StopRow3 = @Threshold3
	
	WHILE (@MaxRow3 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		FROM dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans14 t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow3 AND @StopRow3

		IF @StopRow3 = @MaxRow3 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow3 = @StopRow3 + 3
		SET @StopRow3 = @StopRow3 + @Threshold3
		IF @StopRow3 >= @MaxRow3
			SET @StopRow3 = @MaxRow3
	END
END

----UPDATE translog14
BEGIN
	DROP TABLE IF EXISTS #tmp_translog14;
	CREATE TABLE #tmp_translog14 ( ID INT IDENTITY(1,1) PRIMARY KEY, translogid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	
	
	INSERT INTO #tmp_translog14 (translogid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.translogid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM translog14 b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID

	DECLARE @Threshold4 INT  = 1000
			,@StartRow4 INT = 1, @StopRow4 INT = 0, @MaxRow4  INT = 0

	SELECT @MaxRow4 = MAX(ID)	FROM #tmp_translog14
	
	IF @Threshold4 >= @MaxRow4
	SET @Threshold4 = @MaxRow4

	SELECT @StopRow4 = @Threshold4
	
	WHILE (@MaxRow4 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		FROM dbo.translog14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_translog14 t ON b.translogid = t.translogid
		WHERE t.ID BETWEEN @StartRow4 AND @StopRow4

		IF @StopRow4 = @MaxRow4 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow4 = @StopRow4 + 1
		SET @StopRow4 = @StopRow4 + @Threshold4
		IF @StopRow4 >= @MaxRow4
			SET @StopRow4 = @MaxRow4
	END
END
