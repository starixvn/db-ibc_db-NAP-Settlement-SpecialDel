/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction=""></info>*/

/*
	Created: 20240114@Louisa
	Task: Migrate Data for new site Hedging and PhoneBetting [Redmine: #201044]
	DB: DBSIC/bodb02 

	bettrans,translog		: Update sma and RepUpdateTime to Inhouse rep to DBTrans
	bettrans14,translog14	: Update sma
*/

USE bodb02
GO

---- init data
BEGIN

	DROP TABLE IF EXISTS #tmp_Cust;
	CREATE TABLE #tmp_Cust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT)

	DROP TABLE IF EXISTS #tmp_Member;
	CREATE TABLE #tmp_Member (CustID INT PRIMARY KEY,recommend_NEW INT, mrecommend_New INT, srecommend_New INT)

	DROP TABLE IF EXISTS #tmp_bettrans;
	CREATE TABLE #tmp_bettrans ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT)	

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
	INSERT INTO  #tmp_Member (CustID,recommend_NEW, mrecommend_New, srecommend_New)
	SELECT ci.custid, temp.recommend_New, temp.mrecommend_New, temp.srecommend_New
	FROM custdb.dbo.custinfo ci WITH(NOLOCK)
		CROSS APPLY (SELECT custid AS recommend_New,
						 mrecommend AS mrecommend_New,
						 srecommend AS srecommend_New		
					FROM custdb.dbo.custinfo WITH(NOLOCK)
					WHERE username = 'AH-RMB'
	) AS temp
	WHERE username IN('230RMB','231RMB')

	--- move agent to another master
	INSERT INTO #tmp_Member (CustID,mrecommend_New, srecommend_New)
	SELECT s.CustID, c.mrecommend_New, c.srecommend_New
	FROM #tmp_Cust c
		INNER JOIN custdb.dbo.vw_customer s WITH(NOLOCK) 
			ON c.CustID = s.recommend
	WHERE c.roleid = 2

END


--UPDATE Bettrans --> in-house rep to dbtrans --> replication to Replicated
BEGIN
	TRUNCATE TABLE #tmp_bettrans;
	
	INSERT INTO #tmp_bettrans (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.transid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM bettrans b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID
		
	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.TransId = t.TransId
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

----UPDATE translog--> in-house rep to dbtrans --> replication to Replicated ( translog use tstamp for Inhouse Replication)
BEGIN
	TRUNCATE TABLE #tmp_bettrans;
	
	INSERT INTO #tmp_bettrans (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.translogid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM translog b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID

	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow = MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.translogid = t.transid
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

--UPDATE Bettrans14
BEGIN
	TRUNCATE TABLE #tmp_bettrans;	
	
	INSERT INTO #tmp_bettrans (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.transid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM bettrans14 b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID
		
	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow	= MAX(ID) FROM #tmp_bettrans
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		FROM dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.TransId = t.TransId
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

----UPDATE translog14
BEGIN
	TRUNCATE TABLE #tmp_bettrans	
	
	INSERT INTO #tmp_bettrans (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.translogid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM translog14 b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID

	DECLARE @Threshold INT  = 1000
			,@StartRow INT = 1, @StopRow INT = 0, @MaxRow  INT = 0

	SELECT @MaxRow = MAX(ID)	FROM #tmp_bettrans
	
	IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

	SELECT @StopRow = @Threshold
	
	WHILE (@MaxRow IS NOT NULL)
	BEGIN		
		UPDATE TOP(@Threshold) b
		SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
			,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
			,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		FROM dbo.translog14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans t ON b.translogid = t.transid
		WHERE t.ID BETWEEN @StartRow AND @StopRow

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.010'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow
	END
END
