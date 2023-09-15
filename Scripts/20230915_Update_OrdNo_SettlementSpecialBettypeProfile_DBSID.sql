/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230915@Louisa
	Task: Correct column OrdNo for Volleyball [Redmine: #194049]
	DB: DBSID-bodb02
*/
 

USE bodb02
GO

IF OBJECT_ID('tempdb..#Checking') IS NOT NULL
DROP TABLE #Checking

IF OBJECT_ID('tempdb..#DataDBTRANS') IS NOT NULL
DROP TABLE #DataDBTRANS

CREATE TABLE #DataDBTRANS (BetType SMALLINT ,BetID	BIGINT ,ResourceID VARCHAR(20) ,OrdNo SMALLINT)

---Checking: 303 rows different - column OrdNo
SELECT BetType ,BetID ,ResourceID ,OrdNo
INTO #Checking
FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
WHERE sp.Sporttype = 6
EXCEPT
SELECT BetType ,BetID ,ResourceID ,OrdNo
FROM DBCTG.bodb02.dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
WHERE sp.Sporttype = 6

--correct column OrdNo
INSERT INTO #DataDBTRANS ( BetType ,BetID ,ResourceID ,OrdNo )
SELECT dbtrans.BetType ,dbtrans.BetID ,dbtrans.ResourceID ,dbtrans.OrdNo
FROM DBCTG.bodb02.dbo.SettlementSpecialBettypeProfile dbtrans WITH(NOLOCK)
INNER JOIN #Checking chk
	ON dbtrans.BetType = chk.BetType 
	 AND dbtrans.BetID = chk.BetID
	 AND dbtrans.ResourceID = chk.ResourceID
WHERE dbtrans.Sporttype = 6

UPDATE sitedb
SET sitedb.OrdNo = dbtrans.OrdNo
FROM SettlementSpecialBettypeProfile sitedb WITH(ROWLOCK,UPDLOCK)
INNER JOIN #DataDBTRANS dbtrans
	ON dbtrans.BetType = sitedb.BetType 
	 AND dbtrans.BetID = sitedb.BetID
	 AND dbtrans.ResourceID = sitedb.ResourceID
WHERE sitedb.Sporttype = 6
