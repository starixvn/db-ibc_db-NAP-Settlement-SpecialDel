/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="1"></info>*/

/*
	Created: 20240114@Louisa
	Task: Migrate Data for table transfer [Redmine: #201044]
	DB: DBSIC/bodb02 

*/

USE bodb02
GO


---- init data
BEGIN
	DROP TABLE IF EXISTS #tmp_Cust;
	CREATE TABLE #tmp_Cust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT, IsFinished BIT DEFAULT(0))
	
	DROP TABLE IF EXISTS #tmp_transfer;
	CREATE TABLE #tmp_transfer ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

	INSERT INTO #tmp_Cust(CustID, Username, site, roleid)
	SELECT custid,username,'Hedging',roleid
	FROM custdb.dbo.custinfo WITH (NOLOCK)
	WHERE username IN ('999MYR','USTM','MOLLYBET','AH501','MollyBF','XYZHK','billma','FRARM','M008iRM','M9999RM','mbrm','2022WC-RM','CASHTEST','CMD','FRA','IT-test1','MMRODDS','XYZPTRM','XYZRM','ISN','STELIM')
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


DECLARE @MoveBetsDay	 SMALLDATETIME
EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @MoveBetsDay OUTPUT
SELECT  @MoveBetsDay AS MoveBetsDay

----UPDATE Transfer, roleid = 1
BEGIN
	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, recommend_NEW, mrecommend_New, srecommend_New )
	SELECT f.transid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM dbo.Transfer f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.custid
	WHERE c.roleid = 1
		AND f.WinlostDate > XXX  ------@MoveBetsDay
		AND f.Bettype > 20000
	
	DECLARE @Threshold1 INT  = 1000
		,@StartRow1 INT = 1, @StopRow1 INT = 0, @MaxRow1  INT = 0

	SELECT @MaxRow1	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold1 >= @MaxRow1
	SET @Threshold1 = @MaxRow1

	SELECT @StopRow1 = @Threshold1
	
	WHILE (@MaxRow1 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) f
		SET f.recommend = t.recommend_NEW
			,f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = SYSDATETIME()
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow1 AND @StopRow1

		IF @StopRow1 = @MaxRow1 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow1 = @StopRow1 + 1
		SET @StopRow1 = @StopRow1 + @Threshold1
		IF @StopRow1 >= @MaxRow1
			SET @StopRow1 = @MaxRow1
	END
END

----UPDATE Transfer, roleid = 2
BEGIN
	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, mrecommend_New, srecommend_New )
	SELECT f.transid, c.mrecommend_New, c.srecommend_New
	FROM dbo.Transfer f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.Recommend
	WHERE c.roleid = 2
		AND f.WinlostDate > XXXXX ---@MoveBetsDay
		AND f.Bettype > 20000
	
	DECLARE @Threshold2 INT  = 1000
		,@StartRow2 INT = 1, @StopRow2 INT = 0, @MaxRow2  INT = 0

	SELECT @MaxRow2	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold2 >= @MaxRow2
	SET @Threshold2 = @MaxRow2

	SELECT @StopRow2 = @Threshold2
	
	WHILE (@MaxRow2 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) f
		SET f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = SYSDATETIME()
		FROM dbo.Transfer f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow2 AND @StopRow2

		IF @StopRow2 = @MaxRow2 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow2 = @StopRow2 + 1
		SET @StopRow2 = @StopRow2 + @Threshold2
		IF @StopRow2 >= @MaxRow2
			SET @StopRow2 = @MaxRow2
	END
END

--UPDATE transfer, roleid = 3
BEGIN
	TRUNCATE TABLE #tmp_transfer
	INSERT INTO #tmp_transfer ( transid, srecommend_New )
	SELECT f.transid, c.srecommend_New
	FROM dbo.Transfer f WITH(NOLOCK)
		INNER JOIN #tmp_Cust_RecommendList_roleid_3 c ON c.recommend = f.recommend
	WHERE f.WinlostDate > XXXX ---@MoveBetsDay
		AND f.Bettype > 20000

	DECLARE @Threshold3 INT  = 1000
			,@StartRow3 INT = 1, @StopRow3 INT = 0, @MaxRow3  INT = 0

	SELECT @MaxRow3	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold3 >= @MaxRow3
	SET @Threshold3 = @MaxRow3

	SELECT @StopRow3 = @Threshold3
	
	WHILE (@MaxRow3 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.Transfer b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow3 AND @StopRow3

		IF @StopRow3 = @MaxRow3 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow3 = @StopRow3 + 1
		SET @StopRow3 = @StopRow3 + @Threshold3
		IF @StopRow3 >= @MaxRow3
			SET @StopRow3 = @MaxRow3
	END
END
---/end transfer


----transfer_coll---------------------------

--UPDATE transfer_coll, roleid = 1
BEGIN
	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, recommend_NEW, mrecommend_New, srecommend_New )
	SELECT f.transid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM dbo.transfer_coll f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.custid
	WHERE c.roleid = 1
		AND f.WinlostDate > XXX ----@MoveBetsDay
		AND f.Bettype > 20000
	
	DECLARE @Threshold11 INT  = 1000
		,@StartRow11 INT = 1, @StopRow11 INT = 0, @MaxRow11  INT = 0

	SELECT @MaxRow11	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold11 >= @MaxRow11
	SET @Threshold11 = @MaxRow11

	SELECT @StopRow11 = @Threshold11
	
	WHILE (@MaxRow11 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) f
		SET f.recommend = t.recommend_NEW
			,f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = SYSDATETIME()
		FROM dbo.transfer_coll f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow11 AND @StopRow11

		IF @StopRow11 = @MaxRow11 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow11 = @StopRow11 + 1
		SET @StopRow11 = @StopRow11 + @Threshold11
		IF @StopRow11 >= @MaxRow11
			SET @StopRow11 = @MaxRow11
	END
END

----UPDATE transfer_coll, roleid = 2
BEGIN
	TRUNCATE TABLE #tmp_transfer;
	INSERT INTO #tmp_transfer ( transid, mrecommend_New, srecommend_New )
	SELECT f.transid, c.mrecommend_New, c.srecommend_New
	FROM dbo.transfer_coll f WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = f.Recommend
	WHERE c.roleid = 2
		AND f.WinlostDate > XXX ----@MoveBetsDay
		AND f.Bettype > 20000
	
	DECLARE @Threshold22 INT  = 1000
		,@StartRow22 INT = 1, @StopRow22 INT = 0, @MaxRow22  INT = 0

	SELECT @MaxRow22	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold22 >= @MaxRow22
	SET @Threshold22 = @MaxRow22

	SELECT @StopRow22 = @Threshold22
	
	WHILE (@MaxRow22 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) f
		SET f.mrecommend = t.mrecommend_New
			,f.srecommend = t.srecommend_New
			,f.RepUpdateTime = SYSDATETIME()
		FROM dbo.transfer_coll f WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON f.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow22 AND @StopRow22

		IF @StopRow22 = @MaxRow22 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow22 = @StopRow22 + 1
		SET @StopRow22 = @StopRow22 + @Threshold22
		IF @StopRow22 >= @MaxRow22
			SET @StopRow22 = @MaxRow22
	END
END

--UPDATE transfer, roleid = 3
BEGIN
	TRUNCATE TABLE #tmp_transfer
	INSERT INTO #tmp_transfer ( transid, srecommend_New )
	SELECT f.transid, c.srecommend_New
	FROM dbo.transfer_coll f WITH(NOLOCK)
		INNER JOIN #tmp_Cust_RecommendList_roleid_3 c ON c.recommend = f.recommend
	WHERE f.WinlostDate > XXX---@MoveBetsDay
		AND f.Bettype > 20000

	DECLARE @Threshold33 INT  = 1000
			,@StartRow33 INT = 1, @StopRow33 INT = 0, @MaxRow33  INT = 0

	SELECT @MaxRow33	= MAX(ID) FROM #tmp_transfer
	
	IF @Threshold33 >= @MaxRow33
	SET @Threshold33 = @MaxRow33

	SELECT @StopRow33 = @Threshold33
	
	WHILE (@MaxRow33 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.transfer_coll b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_transfer t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow33 AND @StopRow33

		IF @StopRow33 = @MaxRow33 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow33 = @StopRow33 + 1
		SET @StopRow33 = @StopRow33 + @Threshold33
		IF @StopRow33 >= @MaxRow33
			SET @StopRow33 = @MaxRow33
	END
END