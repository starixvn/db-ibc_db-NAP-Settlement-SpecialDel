/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction=""></info>*/

/*
	Created: 20240416@Louisa
	Task: Migrate Data for bettrans14, translog14 [Redmine: #201044]
	DB: DBCTG/bodb02 

*/

USE bodb02
GO

---- init data
BEGIN

	DROP TABLE IF EXISTS #tmp_Cust;
	CREATE TABLE #tmp_Cust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT)

	DROP TABLE IF EXISTS #tmp_Member;
	CREATE TABLE #tmp_Member (CustID INT PRIMARY KEY,recommend_NEW INT, mrecommend_New INT, srecommend_New INT)

	DROP TABLE IF EXISTS #tmp_trans14;
	CREATE TABLE #tmp_trans14 ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

	DROP TABLE IF EXISTS #tmp_batch;
	CREATE TABLE #tmp_batch ( transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

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

	--select count(1) from #tmp_Member select count(1) from #tmp_Member
END

--UPDATE bettrans14
BEGIN
	TRUNCATE TABLE #tmp_trans14
	TRUNCATE TABLE #tmp_batch
	
	INSERT INTO #tmp_trans14 (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.transid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM bettrans14 b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID
		
	DECLARE @Batch_Trans14 INT  = 2000
			,@StartTrans14 INT = 1, @StopTrans14 INT = 0, @MaxTrans14  INT = 0
			,@debug_Trans14 VARCHAR(500)
			,@transIds14 VARCHAR (MAX) = ''
			,@tablename1 VARCHAR (200) = 'bettrans14'

	SELECT @MaxTrans14	= ISNULL(MAX(ID),0) FROM #tmp_trans14

	SELECT @StopTrans14 = @Batch_Trans14
	
	WHILE (1=1)
	BEGIN		
		TRUNCATE TABLE #tmp_batch

		DELETE b
		OUTPUT DELETED.transid, DELETED.recommend_NEW, DELETED.mrecommend_New, DELETED.srecommend_New
		INTO #tmp_batch (transid, recommend_NEW, mrecommend_New, srecommend_New)
		FROM #tmp_trans14 b
		WHERE b.ID BETWEEN @StartTrans14 AND @StopTrans14

		IF @@ROWCOUNT = 0 
		BREAK

		SET @debug_Trans14 = @tablename1 + ' StartRow: ' + CAST(@StartTrans14 AS VARCHAR)  + ' StopRow: ' + CAST(@StopTrans14 AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_Trans14, 0, 1) WITH NOWAIT

		SET @transIds14 = (SELECT transid AS t
								 ,recommend_NEW AS r
								 ,mrecommend_New AS mr
								 ,srecommend_New AS sr
							FROM #tmp_batch
							FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds14, @SiteDBGroupID = 3, @tablename = @tablename1, @mode = 1

		WAITFOR DELAY '00:00:00.010'

		SET @StartTrans14 = @StopTrans14 + 1
		SET @StopTrans14 = @StopTrans14 + @Batch_Trans14

		IF @StartTrans14 > @MaxTrans14
		BREAK

	END
END
GO

--UPDATE translog14
BEGIN
	TRUNCATE TABLE #tmp_trans14
	TRUNCATE TABLE #tmp_batch

	INSERT INTO #tmp_trans14 (transid, recommend_NEW, mrecommend_New, srecommend_New)	
	SELECT b.translogid, m.recommend_NEW, m.mrecommend_New, m.srecommend_New
	FROM translog14 b WITH(NOLOCK)
		INNER JOIN #tmp_Member m
			ON b.custid = m.CustID
		
	DECLARE @Batch_TransLog14 INT  = 2000
			,@StartLog14 INT = 1, @StopLog14 INT = 0, @MaxLog14  INT = 0
			,@debug_Log14 VARCHAR(500)
			,@transLogIds14 VARCHAR (MAX) = ''
			,@tablename2 VARCHAR (200) = 'translog14'

	SELECT @MaxLog14 = ISNULL(MAX(ID),0) FROM #tmp_trans14

	SELECT @StopLog14 = @Batch_TransLog14
	
	WHILE (1=1)
	BEGIN		
		TRUNCATE TABLE #tmp_batch

		DELETE b
		OUTPUT DELETED.transid, DELETED.recommend_NEW, DELETED.mrecommend_New, DELETED.srecommend_New
		INTO #tmp_batch (transid, recommend_NEW, mrecommend_New, srecommend_New)
		FROM #tmp_trans14 b
		WHERE b.ID BETWEEN @StartLog14 AND @StopLog14

		IF @@ROWCOUNT = 0 
		BREAK

		SET @debug_Log14 = @tablename2 + ' StartRow: ' + CAST(@StartLog14 AS VARCHAR)  + ' StopRow: ' + CAST(@StopLog14 AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_Log14, 0, 1) WITH NOWAIT

		SET @translogIds14 = (SELECT transid AS t
								 ,recommend_NEW AS r
								 ,mrecommend_New AS mr
								 ,srecommend_New AS sr
							FROM #tmp_batch
							FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @translogIds14, @SiteDBGroupID = 3, @tablename = @tablename2 , @mode = 1

		WAITFOR DELAY '00:00:00.010'

		SET @StartLog14 = @StopLog14 + 1
		SET @StopLog14 = @StopLog14 + @Batch_TransLog14

		IF @StartLog14 > @MaxLog14
		BREAK

	END
END
