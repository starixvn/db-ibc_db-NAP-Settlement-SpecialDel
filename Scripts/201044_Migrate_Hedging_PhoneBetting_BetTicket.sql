/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="1"></info>*/

/*
	Created: 20240114@Louisa
	Task: Migrate Data for bettrans, translog[Redmine: #201044]
	DB: DBSIC/bodb02 

*/

USE bodb02
GO


---- init data
BEGIN
	DROP TABLE IF EXISTS #tmp_Cust;
	CREATE TABLE #tmp_Cust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT, IsFinished BIT DEFAULT(0))
	
	DROP TABLE IF EXISTS #tmp_bettrans;
	CREATE TABLE #tmp_bettrans ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

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
	
		UNION SELECT 'wsrmb'	, 'MV-RMB'	, 'SV-RMB'
		UNION SELECT '8RM'		, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8801'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8802'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8803'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8804'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8805'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8806'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8807'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8808'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8809'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RM8810'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT '8RMTest01', 'MV-RM'	, 'SV-RM'
		UNION SELECT 'BARM'		, 'MV-RM'	, 'SV-RM'
		UNION SELECT 'BARM002'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT 'MMRWC22'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT 'PHIRM'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT 'WCBill'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT 'WINRM'	, 'MV-RM'	, 'SV-RM'
		UNION SELECT 'wsrm'		, 'MV-RM'	, 'SV-RM'
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

	/* check data
		SELECT count(1)
		from bettrans b with (nolock)
			inner join #tmp_Cust c ON c.CustID = b.custid
		WHERE c.roleid = 1 and b.SiteDBGroupID = 3

		SELECT count(1)
		from bettrans b with (nolock)
			inner join #tmp_Cust c ON c.CustID = b.recommend
		WHERE c.roleid = 2 and b.SiteDBGroupID = 3

		SELECT count(1)
		from bettrans b with (nolock)
			inner join #tmp_Cust_RecommendList_roleid_3 c ON c.recommend = b.recommend
		where  b.SiteDBGroupID = 3

	*/
END


--UPDATE Bettrans, roleid = 1
BEGIN
	TRUNCATE TABLE #tmp_bettrans;
	INSERT INTO #tmp_bettrans ( transid, recommend_NEW, mrecommend_New, srecommend_New )
	SELECT b.transid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = b.custid
	WHERE c.roleid = 1

	DECLARE @Threshold1 INT  = 1000
			,@StartRow1 INT = 1, @StopRow1 INT = 0, @MaxRow1  INT = 0

	SELECT @MaxRow1	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold1 >= @MaxRow1
	SET @Threshold1 = @MaxRow1

	SELECT @StopRow1 = @Threshold1
	
	WHILE (@MaxRow1 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend = t.recommend_NEW
			,b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow1 AND @StopRow1

		IF @StopRow1 = @MaxRow1 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow1 = @StopRow1 + 1
		SET @StopRow1 = @StopRow1 + @Threshold1
		IF @StopRow1 >= @MaxRow1
			SET @StopRow1 = @MaxRow1
	END
END

--UPDATE Bettrans, roleid = 2
BEGIN
	TRUNCATE TABLE #tmp_bettrans
	INSERT INTO #tmp_bettrans ( transid, mrecommend_New, srecommend_New )
	SELECT b.transid, c.mrecommend_New, c.srecommend_New
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = b.recommend
	WHERE c.roleid = 2

	DECLARE @Threshold2 INT  = 1000
			,@StartRow2 INT = 1, @StopRow2 INT = 0, @MaxRow2  INT = 0

	SELECT @MaxRow2	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold2 >= @MaxRow2
	SET @Threshold2 = @MaxRow2

	SELECT @StopRow2 = @Threshold2
	
	WHILE (@MaxRow2 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow2 AND @StopRow2

		IF @StopRow2 = @MaxRow2 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow2 = @StopRow2 + 1
		SET @StopRow2 = @StopRow2 + @Threshold2
		IF @StopRow2 >= @MaxRow2
			SET @StopRow2 = @MaxRow2
	END
END

--UPDATE Bettrans, roleid = 3
BEGIN
	TRUNCATE TABLE #tmp_bettrans
	INSERT INTO #tmp_bettrans ( transid, srecommend_New )
	SELECT b.transid, c.srecommend_New
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tmp_Cust_RecommendList_roleid_3 c ON c.recommend = b.recommend

	DECLARE @Threshold3 INT  = 1000
			,@StartRow3 INT = 1, @StopRow3 INT = 0, @MaxRow3  INT = 0

	SELECT @MaxRow3	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold3 >= @MaxRow3
	SET @Threshold3 = @MaxRow3

	SELECT @StopRow3 = @Threshold3
	
	WHILE (@MaxRow3 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.TransId = t.TransId
		WHERE t.ID BETWEEN @StartRow3 AND @StopRow3

		IF @StopRow3 = @MaxRow3 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow3 = @StopRow3 + 1
		SET @StopRow3 = @StopRow3 + @Threshold3
		IF @StopRow3 >= @MaxRow3
			SET @StopRow3 = @MaxRow3
	END
END
---/end bettrans


----------------TRANSLOG-----------------------------------

---Note : inhouse replication rep data translog by tstamp

----UPDATE translog, roleid = 1
BEGIN
	TRUNCATE TABLE #tmp_bettrans
	INSERT INTO #tmp_bettrans ( transid, recommend_NEW, mrecommend_New, srecommend_New )
	SELECT b.translogid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	FROM dbo.translog b WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = b.custid
	WHERE c.roleid = 1

	DECLARE @Threshold11 INT  = 1000
			,@StartRow11 INT = 1, @StopRow11 INT = 0, @MaxRow11  INT = 0

	SELECT @MaxRow11 = MAX(ID)	FROM #tmp_bettrans
	
	IF @Threshold11 >= @MaxRow11
	SET @Threshold11 = @MaxRow11

	SELECT @StopRow11 = @Threshold11
	
	WHILE (@MaxRow11 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend = t.recommend_NEW
			,b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.translogid = t.TransId
		WHERE t.ID BETWEEN @StartRow11 AND @StopRow11

		IF @StopRow11 = @MaxRow11 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow11 = @StopRow11 + 1
		SET @StopRow11 = @StopRow11 + @Threshold11
		IF @StopRow11 >= @MaxRow11
			SET @StopRow11 = @MaxRow11
	END
END

----UPDATE translog, roleid = 2
BEGIN
	TRUNCATE TABLE #tmp_bettrans
	INSERT INTO #tmp_bettrans ( transid, mrecommend_New, srecommend_New )
	SELECT b.translogid, c.mrecommend_New, c.srecommend_New
	FROM dbo.translog b WITH(NOLOCK)
		INNER JOIN #tmp_Cust c ON c.CustID = b.recommend
	WHERE c.roleid = 2

	DECLARE @Threshold12 INT  = 1000
			,@StartRow12 INT = 1, @StopRow12 INT = 0, @MaxRow12  INT = 0

	SELECT @MaxRow12	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold12 >= @MaxRow12
	SET @Threshold12 = @MaxRow12

	SELECT @StopRow12 = @Threshold12
	
	WHILE (@MaxRow12 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.translogid = t.TransId
		WHERE t.ID BETWEEN @StartRow12 AND @StopRow12

		IF @StopRow12 = @MaxRow12 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow12 = @StopRow12 + 1
		SET @StopRow12 = @StopRow12 + @Threshold12
		IF @StopRow12 >= @MaxRow12
			SET @StopRow12 = @MaxRow12
	END
END

----UPDATE translog, roleid = 3
BEGIN
	TRUNCATE TABLE #tmp_bettrans
	INSERT INTO #tmp_bettrans ( transid, srecommend_New )
	SELECT b.translogid, c.srecommend_New
	FROM dbo.translog b WITH(NOLOCK)
		INNER JOIN #tmp_Cust_RecommendList_roleid_3 c ON c.recommend = b.recommend

DECLARE @Threshold13 INT  = 1000
			,@StartRow13 INT = 1, @StopRow13 INT = 0, @MaxRow13  INT = 0

	SELECT @MaxRow13	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold13 >= @MaxRow13
	SET @Threshold13 = @MaxRow13

	SELECT @StopRow13 = @Threshold13
	
	WHILE (@MaxRow13 IS NOT NULL)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.srecommend = t.srecommend_New
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.translogid = t.TransId
		WHERE t.ID BETWEEN @StartRow13 AND @StopRow13

		IF @StopRow13 = @MaxRow13 BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow13 = @StopRow13 + 1
		SET @StopRow13 = @StopRow13 + @Threshold13
		IF @StopRow13 >= @MaxRow13
			SET @StopRow13 = @MaxRow13
	END
END