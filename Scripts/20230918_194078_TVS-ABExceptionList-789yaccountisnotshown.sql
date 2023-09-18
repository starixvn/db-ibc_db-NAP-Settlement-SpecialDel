/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230918@July
	Task:[TVS] 789y account is not shown in AB Exception List [Redmine: #194078]
	DB: DBCTG-bodb02

*/

USE bodb02
GO
--Update sitedb 789y(old) => sitedb current (22 ROWS)
UPDATE a WITH (ROWLOCK, UPDLOCK)
SET a.SiteId = s.SiteId
FROM dbo.TicketVoiding_ABWhiteList a 
	INNER JOIN Custdb.dbo.vw_Customer c WITH (NOLOCK) ON a.custid = c.custid
	INNER JOIN Custdb.dbo.site s WITH (NOLOCK) ON c.Site = s.Site
WHERE a.SiteId = 3


--Delete custid not exists (2 ROWS)
DELETE a
FROM dbo.TicketVoiding_ABWhiteList a 
   LEFT JOIN Custdb.dbo.Custinfo c WITH (NOLOCK) ON a.custid = c.custid
WHERE c.custid IS NULL
