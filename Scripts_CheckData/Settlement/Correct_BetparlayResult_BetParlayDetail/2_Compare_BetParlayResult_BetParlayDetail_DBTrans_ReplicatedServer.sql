/*<info serverAlias="DB05x-bodb02,DB06x-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	-- Check differrent data BetParlayDetail/dbo.BetParlayResult DBTRANS and Replicated Server
*/


--Run on Replicated Server
USE bodb02
GO

BEGIN
	--Input MatchID OR List Refno 
	DECLARE @MatchID INT
			,@Refno_List VARCHAR(MAX) = '300003522866,300003522869,300003522870'
	
	IF ( ISNULL(@MatchID,0) = 0 AND ISNULL(@Refno_List,'') = '' )
	 OR ( ISNULL(@MatchID,0) <> 0 AND ISNULL(@Refno_List,'') <> '' )
	BEGIN
		SELECT 'Input @MatchID OR @Refno_List'
		RETURN
	END
	
	--------------------------------------------------------------
	DROP TABLE IF EXISTS #tmpRefno_List
	DROP TABLE IF EXISTS #tmp_DBTrans_BetParlayX
	DROP TABLE IF EXISTS #tmp_Replicated_BetParlayX

	CREATE TABLE #tmpRefno_List (RefNo BIGINT)
	CREATE TABLE #tmp_DBTrans_BetParlayX (refno BIGINT ,TotalCheckSumAgg BIGINT, TableName VARCHAR(100) )
	CREATE TABLE #tmp_Replicated_BetParlayX (refno BIGINT ,TotalCheckSumAgg BIGINT, TableName VARCHAR(100))
	
	IF ISNULL(@MatchID,0) > 0
	BEGIN
		INSERT INTO #tmpRefno_List (RefNo)
		SELECT DISTINCT bm.refno
		FROM dbo.bettransm bm WITH(NOLOCK)
		WHERE bm.matchid = @MatchID
			AND bm.statusID <> 101
	END
	INSERT INTO #tmpRefno_List (RefNo)
	SELECT DISTINCT f.[value] 
	FROM STRING_SPLIT(@Refno_List, ',') f
		INNER JOIN dbo.bettransm bm WITH(NOLOCK)
			ON f.value = bm.refno
	WHERE bm.statusID <> 101

	
	--Check sum to compare data:
	
	/* 
		Style 1: run script directly on DBtrans and Replicated Server, then paste data into Excel to compare column TotalCheckSumAgg
				
		--Can modify script to GROUP BY statusid or bettype or refno
		INSERT INTO #tmp_Replicated_BetParlayX (refno, TotalCheckSumAgg, TableName)
		SELECT	b.refno -- b.statusid
			,CHECKSUM_AGG(CHECKSUM(b.RefNo,b.Serial,b.transid,b.statuswinlost,b.statusid,b.matchid,b.winlostdate)) AS TotalCheckSumAgg
			,'BetParlayDetail' AS TableName
		FROM bodb02.dbo.BetParlayDetail b WITH (NOLOCK)
			INNER JOIN #tmpRefno_List tmp ON tmp.refno = b.refno
		GROUP BY b.refno -- b.statusid

		--Can modify script to GROUP BY statusid or refno
		INSERT INTO #tmp_Replicated_BetParlayX (refno,TotalCheckSumAgg, TableName)
		SELECT	b.refno -- ,b.statusid
				,CHECKSUM_AGG(CHECKSUM(	b.RefNo,b.Serial,b.transid,b.ExtraValue,b.winlostdate,b.Odds
										,b.winlost,b.awinlost,b.mwinlost,b.swinlost,b.playercomm,b.comm,b.acomm,b.scomm)) AS TotalCheckSumAgg
				,'BetParlayResult' AS TableName
		FROM dbo.BetParlayResult b WITH (NOLOCK)
			INNER JOIN #tmpRefno_List tmp ON tmp.refno = b.refno
		GROUP BY b.refno -- ,b.statusid
	*/

	/* Stype 2: Run script only at Replicated: get data at Replicated, use linked server get data from DBTRANS then insert into Table and compare */
	
	--DBCTG.bodb02.dbo.BetParlayDetail
	--Can modify script to GROUP BY statusid or bettype or refno
	INSERT INTO #tmp_DBTrans_BetParlayX (refno, TotalCheckSumAgg, TableName)
	SELECT	b.refno -- ,b.statusid
			,CHECKSUM_AGG(CHECKSUM(b.RefNo,b.Serial,b.transid,b.statuswinlost,b.statusid,b.matchid,b.winlostdate)) AS TotalCheckSumAgg
			,'BetParlayDetail' AS TableName
	FROM DBCTG.bodb02.dbo.BetParlayDetail b WITH (NOLOCK)
		INNER JOIN #tmpRefno_List tmp ON tmp.refno = b.refno
	GROUP BY b.refno -- ,b.statusid

	--Replicated dbo.BetParlayDetail
	--Can modify script to GROUP BY statusid or bettype or refno
	INSERT INTO #tmp_Replicated_BetParlayX (refno, TotalCheckSumAgg, TableName)
	SELECT	b.refno -- ,b.statusid
			,CHECKSUM_AGG(CHECKSUM(b.RefNo,b.Serial,b.transid,b.statuswinlost,b.statusid,b.matchid,b.winlostdate)) AS TotalCheckSumAgg
			,'BetParlayDetail' AS TableName
	FROM bodb02.dbo.BetParlayDetail b WITH (NOLOCK)
		INNER JOIN #tmpRefno_List tmp ON tmp.refno = b.refno
	GROUP BY b.refno

	--DBCTG.bodb02.dbo.BetParlayResult
	--Can modify script to GROUP BY statusid or refno
	INSERT INTO #tmp_DBTrans_BetParlayX (refno,TotalCheckSumAgg, TableName)
	SELECT	b.refno -- ,b.statusid
			,CHECKSUM_AGG(CHECKSUM(	b.RefNo,b.Serial,b.transid,b.ExtraValue,b.winlostdate,b.Odds
									,b.winlost,b.awinlost,b.mwinlost,b.swinlost,b.playercomm,b.comm,b.acomm,b.scomm)) AS TotalCheckSumAgg
			,'BetParlayResult' AS TableName
	FROM DBCTG.bodb02.dbo.BetParlayResult b WITH (NOLOCK)
		INNER JOIN #tmpRefno_List tmp ON tmp.refno = b.refno
	GROUP BY b.refno-- ,b.statusid

	--Replicated dbo.BetParlayResult
	--Can modify script to GROUP BY statusid or refno
	INSERT INTO #tmp_Replicated_BetParlayX (refno,TotalCheckSumAgg, TableName)
	SELECT	b.refno -- ,b.statusid
			,CHECKSUM_AGG(CHECKSUM(	b.RefNo,b.Serial,b.transid,b.ExtraValue,b.winlostdate,b.Odds
									,b.winlost,b.awinlost,b.mwinlost,b.swinlost,b.playercomm,b.comm,b.acomm,b.scomm)) AS TotalCheckSumAgg
			,'BetParlayResult' AS TableName
	FROM dbo.BetParlayResult b WITH (NOLOCK)
		INNER JOIN #tmpRefno_List tmp ON tmp.refno = b.refno
	GROUP BY b.refno -- ,b.statusid

	--compare data
	SELECT tmp1.TableName, tmp1.RefNo, tmp1.TotalCheckSumAgg AS SumDBTrans, tmp2.TotalCheckSumAgg AS SumReplicated
	FROM #tmp_DBTrans_BetParlayX tmp1 
		LEFT JOIN #tmp_Replicated_BetParlayX tmp2 
			ON tmp2.refno = tmp1.refno
				AND tmp1.TableName = tmp2.TableName
	WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
		AND tmp1.TableName = 'BetParlayDetail'
	UNION ALL
	SELECT  tmp1.TableName, tmp1.RefNo, tmp1.TotalCheckSumAgg AS SumDBTrans, tmp2.TotalCheckSumAgg AS SumReplicated
	FROM #tmp_DBTrans_BetParlayX tmp1 
		LEFT JOIN #tmp_Replicated_BetParlayX tmp2 
			ON tmp2.refno = tmp1.refno
				AND tmp1.TableName = tmp2.TableName
	WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
		AND tmp1.TableName = 'BetParlayResult'

END


--select matchid, * from bettransm with(Nolock) where refno in ( 300003522866,300003522869,300003522870)