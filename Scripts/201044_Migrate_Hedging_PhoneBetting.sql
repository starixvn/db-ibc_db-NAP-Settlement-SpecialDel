/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="1"></info>*/

/*
	Created: 20240114@Louisa
	Task: Migrate Data [Redmine: #201044]
	DB: DBSIC/bodb02 

*/

USE bodb02
GO

CREATE TABLE #tblCust (CustID INT PRIMARY KEY, Username VARCHAR(10), site VARCHAR(30), roleid TINYINT, mrecommend_New INT, srecommend_New INT,recommend_NEW INT, IsFinished BIT DEFAULT(0))
DECLARE @custid INT, @Username VARCHAR(30), @site VARCHAR(10), @roleid TINYINT, @mrecommend_New INT, @srecommend_New INT, @recommend_New INT

INSERT INTO #tblCust(CustID,Username,site,roleid)
SELECT custid,username,'Hedging',roleid
FROM custdb.dbo.custinfo (NOLOCK)
WHERE username IN ('999MYR','USTM','MOLLYBET','AH501','MollyBF','XYZHK','billma','FRARM','M008iRM','M9999RM','mbrm','2022WC-RM','CASHTEST','CMD','FRA','IT-test1','MMRODDS','XYZPTRM','XYZRM','ISN','STELIM')
UNION 
SELECT custid,username,'Special',roleid
FROM custdb.dbo.custinfo (NOLOCK)
WHERE username IN ('wsrmb','8RM','8RM8801','8RM8802','8RM8803','8RM8804','8RM8805','8RM8806','8RM8807','8RM8808','8RM8809','8RM8810','8RMTest01','BARM','BARM002','MMRWC22','PHIRM','WCBill','WINRM','wsrm')

;WITH T AS (
	SELECT 'MOLLYBET' username, 'MH-EURO' Master, 'SH-EURO' Super
	UNION SELECT 'AH501', NULL, 'SH-HK$'
	UNION SELECT 'MollyBF', 'MH-HK$', 'SH-HK$'
	UNION SELECT 'XYZHK', 'MH-HK$', 'SH-HK$'
	UNION SELECT 'billma', NULL, 'SH-RM'
	UNION SELECT 'FRARM', NULL, 'SH-RM'
	UNION SELECT 'M008iRM', NULL, 'SH-RM'
	UNION SELECT 'M9999RM', NULL, 'SH-RM'
	UNION SELECT 'mbrm', NULL, 'SH-RM'
	UNION SELECT '2022WC-RM', 'MH-RM', 'SH-RM'
	UNION SELECT 'CASHTEST', 'MH-RM', 'SH-RM'
	UNION SELECT 'CMD', 'MH-RM', 'SH-RM'
	UNION SELECT 'FRA', 'MH-RM', 'SH-RM'
	UNION SELECT 'IT-test1', 'MH-RM', 'SH-RM'
	UNION SELECT 'MMRODDS', 'MH-RM', 'SH-RM'
	UNION SELECT 'XYZPTRM', 'MH-RM', 'SH-RM'
	UNION SELECT 'XYZRM', 'MH-RM', 'SH-RM'
	UNION SELECT 'ISN', NULL, 'SH-RMB'
	UNION SELECT 'STELIM', NULL, 'SH-RMB'
	
	UNION SELECT 'wsrmb', 'MV-RMB', 'SV-RMB'
	UNION SELECT '8RM', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8801', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8802', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8803', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8804', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8805', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8806', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8807', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8808', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8809', 'MV-RM', 'SV-RM'
	UNION SELECT '8RM8810', 'MV-RM', 'SV-RM'
	UNION SELECT '8RMTest01', 'MV-RM', 'SV-RM'
	UNION SELECT 'BARM', 'MV-RM', 'SV-RM'
	UNION SELECT 'BARM002', 'MV-RM', 'SV-RM'
	UNION SELECT 'MMRWC22', 'MV-RM', 'SV-RM'
	UNION SELECT 'PHIRM', 'MV-RM', 'SV-RM'
	UNION SELECT 'WCBill', 'MV-RM', 'SV-RM'
	UNION SELECT 'WINRM', 'MV-RM', 'SV-RM'
	UNION SELECT 'wsrm', 'MV-RM', 'SV-RM'
)
UPDATE c
SET c.srecommend_New = s.custid,
	c.mrecommend_New = m.custid
FROM #tblCust c
	INNER JOIN T ON c.username = t.username
	INNER JOIN custdb.dbo.customer s WITH(NOLOCK) ON t.super = s.username
	LEFT JOIN custdb.dbo.customer m WITH(NOLOCK) ON t.master = m.username

-- member fmrup
INSERT INTO #tblCust (CustID, Username, roleid, site, recommend_NEW, mrecommend_New,srecommend_New)
SELECT ci.custid, ci.username,ci.roleid, 'Hedging',temp.recommend_New, temp.mrecommend_New, temp.srecommend_New
FROM custdb.dbo.custinfo ci WITH(NOLOCK)
	CROSS APPLY (SELECT custid AS recommend_New,
					 mrecommend AS mrecommend_New,
					 srecommend AS srecommend_New		
				FROM custdb.dbo.custinfo WITH(NOLOCK)
				WHERE username = 'AH-RUP'
) AS temp
WHERE username = 'fmrup'

 
CREATE TABLE #tblCust_RecommendList_roleid_3 (recommend INT PRIMARY KEY, mrecommend INT, srecommend_New INT)

INSERT INTO #tblCust_RecommendList_roleid_3 (recommend, mrecommend,srecommend_New)
SELECT cc.recommend, c.CustID,c.srecommend_New
FROM #tblCust c
	INNER JOIN CUSTDB.dbo.vw_Customer cc WITH (NOLOCK) 
		ON c.CustID = cc.mrecommend 
			AND cc.roleid = 2
WHERE c.roleid = 3

/* check data
	SELECT count(1)
	from bettrans b with (nolock)
		inner join #tblCust c ON c.CustID = b.custid
	WHERE c.roleid = 1 and b.SiteDBGroupID = 3

	SELECT count(1)
	from bettrans b with (nolock)
		inner join #tblCust c ON c.CustID = b.recommend
	WHERE c.roleid = 2 and b.SiteDBGroupID = 3

	SELECT count(1)
	from bettrans b with (nolock)
		inner join #tblCust_RecommendList_roleid_3 c ON c.recommend = b.recommend
	where  b.SiteDBGroupID = 3

*/
	
--Bettrans, roleid = 1
BEGIN
	SELECT b.transid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	INTO  #tmp_bettrans_role_1
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblCust c ON c.CustID = b.custid
	WHERE c.roleid = 1

	WHILE (1=1)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend = t.recommend_NEW
			,b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans_role_1 t ON b.TransId = t.TransId
				AND b.recommend <> t.recommend_NEW

		IF @@ROWCOUNT = 0
		BREAK;
	END
END

--Bettrans, roleid = 2
BEGIN
	SELECT b.transid, c.mrecommend_New, c.srecommend_New
	INTO  #tmp_bettrans_role_2
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblCust c ON c.CustID = b.recommend
	WHERE c.roleid = 2

	WHILE (1=1)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans_role_2 t ON b.TransId = t.TransId
				AND b.mrecommend <> t.mrecommend_New

		IF @@ROWCOUNT = 0
		BREAK;
	END
END

--Bettrans, roleid = 3
BEGIN
	SELECT b.transid, c.srecommend_New
	INTO  #tmp_bettrans_role_3
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblCust_RecommendList_roleid_3 c ON c.recommend = b.recommend

	WHILE (1=1)
	BEGIN		
		UPDATE TOP(1000) b
		SET  b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_bettrans_role_3 t ON b.TransId = t.TransId
				AND b.srecommend <> t.srecommend_New

		IF @@ROWCOUNT = 0
		BREAK;
	END	
END 
---/end bettrans


----translog, roleid = 1
BEGIN	
	SELECT b.translogid, c.recommend_NEW, c.mrecommend_New, c.srecommend_New
	INTO  #tmp_translog_role_1
	FROM dbo.translog b WITH(NOLOCK)
		INNER JOIN #tblCust c ON c.CustID = b.custid
	WHERE c.roleid = 1

	WHILE (1=1)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.recommend = t.recommend_NEW
			,b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_translog_role_1 t ON b.translogid = t.translogid
				AND b.recommend <> t.recommend_NEW

		IF @@ROWCOUNT = 0
		BREAK;
	END
END

----translog, roleid = 2
BEGIN
	SELECT b.translogid, c.mrecommend_New, c.srecommend_New
	INTO  #tmp_translog_role_2
	FROM dbo.translog b WITH(NOLOCK)
		INNER JOIN #tblCust c ON c.CustID = b.recommend
	WHERE c.roleid = 2

	WHILE (1=1)
	BEGIN		
		UPDATE TOP(1000) b
		SET b.mrecommend = t.mrecommend_New
			,b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_translog_role_2 t ON b.translogid = t.translogid
				AND b.mrecommend <> t.mrecommend_New

		IF @@ROWCOUNT = 0
		BREAK;
	END
END

----translog, roleid = 3
BEGIN
	SELECT b.translogid, c.srecommend_New
	INTO  #tmp_translog_role_3
	FROM dbo.translog b WITH(NOLOCK)
		INNER JOIN #tblCust_RecommendList_roleid_3 c ON c.recommend = b.recommend

	WHILE (1=1)
	BEGIN
		UPDATE TOP(1000) b
		SET  b.srecommend = t.srecommend_New
			,b.RepUpdateTime = SYSDATETIME()
		FROM dbo.translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tmp_translog_role_3 t ON b.translogid = t.translogid
				AND b.srecommend <> t.srecommend_New

		IF @@ROWCOUNT = 0
		BREAK;
	END	
END