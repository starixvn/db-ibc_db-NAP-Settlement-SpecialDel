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

	-- 11076 rows
	--select count(1) from #tmp_Member

	--3714 rows
	-- select count(1) from #tmp_Member m
    -- inner join bettrans b with(nolock) on m.custid = b.custid	
END


--UPDATE Bettrans ( bettrans use RepUpdateTime for Inhouse Replication)
BEGIN		
	UPDATE b
	SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
		,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
		,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
		,b.RepUpdateTime = SYSDATETIME()
	FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tmp_Member t ON b.custid = t.custid
END

----UPDATE translog ( translog use tstamp for Inhouse Replication)
BEGIN		
	UPDATE b
	SET b.recommend		= CASE WHEN t.recommend_NEW IS NULL THEN b.recommend ELSE t.recommend_NEW END
		,b.mrecommend	= CASE WHEN t.mrecommend_New IS NULL THEN b.mrecommend ELSE t.mrecommend_New END
		,b.srecommend	= CASE WHEN t.srecommend_New IS NULL THEN b.srecommend ELSE t.srecommend_New END
	FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tmp_Member t ON b.custid = t.custid
END
