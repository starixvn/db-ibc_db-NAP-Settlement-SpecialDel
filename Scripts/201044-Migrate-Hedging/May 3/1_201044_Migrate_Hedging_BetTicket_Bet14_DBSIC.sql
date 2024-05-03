/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction=""></info>*/

/*
	Created: 20240429@Louisa
	Task: Migrate Data for new site Hedging and PhoneBetting [Redmine: #201044]
	DB: DBSIC/bodb02 

	bettrans,translog		: Update sma and RepUpdateTime to Inhouse rep to DBTrans
	bettrans14				: Update sma
*/

USE bodb02
GO

---- init data
BEGIN

	DROP TABLE IF EXISTS #tmp_Member;
	CREATE TABLE #tmp_Member (CustID INT PRIMARY KEY,recommend_NEW INT, mrecommend_New INT, srecommend_New INT)

	DROP TABLE IF EXISTS #tmp_bettrans;
	CREATE TABLE #tmp_bettrans ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT)	

	-- member '231USDT' (move member)
	INSERT INTO  #tmp_Member (CustID,recommend_NEW, mrecommend_New, srecommend_New)
	SELECT ci.custid, temp.recommend_New, temp.mrecommend_New, temp.srecommend_New
	FROM custdb.dbo.custinfo ci WITH(NOLOCK)
		CROSS APPLY (SELECT custid AS recommend_New,
						 mrecommend AS mrecommend_New,
						 srecommend AS srecommend_New		
					FROM custdb.dbo.custinfo WITH(NOLOCK)
					WHERE username = '231'
	) AS temp
	WHERE username = '231USDT'

	--select * from #tmp_Member

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

----translog14: no ticket to update 
--- select count(1) from translog14 with(nolock) where custid = 120216224

