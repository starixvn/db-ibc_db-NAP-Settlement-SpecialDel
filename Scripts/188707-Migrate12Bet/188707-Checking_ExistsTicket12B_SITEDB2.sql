/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 [Redmineid:#188707] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230602@Louisa: Checking if sitedb2 exists ticket 12B before migrate [Redmineid:#188707]

*/


--RUN ON SITEDB02

USE bodb02
GO

-----======= Range Active ===========
	
	---bettrans
	SELECT TOP(3) b.transid, b.custid 
	FROM bettrans b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransm
	SELECT TOP(3) b.transid, b.refno, b.custid 
	FROM bettransm b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransRnG
	SELECT TOP(3) b.transid, b.custid 
	FROM bettransRnG b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransG
	SELECT TOP(3) b.transid, b.custid 
	FROM bettransG b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransLC
	SELECT TOP(3) b.transid, b.custid 
	FROM bettransLC b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'


	----translog
	SELECT TOP(3) b.translogid, b.custid 
	FROM translog b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----Transfer
	SELECT TOP(3) b.transid, b.custid 
	FROM Transfer b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

-----======= Range 14 ===========
	
	---bettrans14
	SELECT TOP(3) b.transid, b.custid 
	FROM bettrans14 b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransm14
	SELECT TOP(3) b.transid, b.refno, b.custid 
	FROM bettransm14 b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransRnG14
	SELECT TOP(3) b.transid, b.custid 
	FROM bettransRnG14 b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransG14
	SELECT TOP(3) b.transid, b.custid 
	FROM bettransG14 b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'

	----bettransLC14
	SELECT TOP(3) b.transid, b.custid 
	FROM bettransLC14 b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'


	----translog14
	SELECT TOP(3) b.translogid, b.custid 
	FROM translog14 b WITH(NOLOCK)
		INNER JOIN custdb.dbo.vw_customer tmp WITH (NOLOCK) ON tmp.custid = b.custid ---cust 12B
		INNER JOIN custdb.dbo.site s WITH (NOLOCK) ON s.site = tmp.site
	WHERE s.site = '12Bet'
