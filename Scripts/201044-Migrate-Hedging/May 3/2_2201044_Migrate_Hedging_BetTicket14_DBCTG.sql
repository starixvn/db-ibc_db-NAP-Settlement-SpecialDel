/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction=""></info>*/

/*
	Created: 20240429@Louisa
	Task: Migrate Data for bettrans14 [Redmine: #201044]
	DB: DBCTG/bodb02 

*/

USE bodb02
GO

---- init data
BEGIN

	DROP TABLE IF EXISTS #tmp_Member;
	CREATE TABLE #tmp_Member (CustID INT PRIMARY KEY,recommend_NEW INT, mrecommend_New INT, srecommend_New INT)

	DROP TABLE IF EXISTS #tmp_trans14;
	CREATE TABLE #tmp_trans14 ( ID INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

	DROP TABLE IF EXISTS #tmp_batch;
	CREATE TABLE #tmp_batch ( transid BIGINT, recommend_NEW INT, mrecommend_New INT, srecommend_New INT )	

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

--translog14: no ticket to update
--select count(1) from translog14 with(nolock) where custid = 120216224