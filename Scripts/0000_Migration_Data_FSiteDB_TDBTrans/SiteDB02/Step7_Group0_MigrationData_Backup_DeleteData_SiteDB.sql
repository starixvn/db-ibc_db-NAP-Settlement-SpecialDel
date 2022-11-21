/*<info serverAlias="DBSIG-SiteDB02tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB02tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for [Redmineid:#180033] 
								1. CustDB.dbo.Customer
								2. Refno of bodb02.dbo.bettrans and bodb02.dbo.bettrans14
*/

USE SiteDB02tmp
GO

CREATE TABLE refno_delete
(
	refno BIGINT PRIMARY KEY
)

------------------------------------------------

INSERT INTO refno_delete (refno)
SELECT DISTINCT b.refno
FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.bettype = 29 AND b.matchid = 29

INSERT INTO refno_delete (refno)
SELECT DISTINCT b.refno
FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.bettype = 29 AND b.matchid = 29