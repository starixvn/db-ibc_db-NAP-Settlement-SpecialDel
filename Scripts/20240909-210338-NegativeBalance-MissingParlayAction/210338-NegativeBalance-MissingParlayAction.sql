/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240909@Aries.Nguyen
	Task: The lack of some ActionIDs when inserting Negative Balance of Parlay Settlement [Redmine: #210338]
*/
USE bodb02
GO

DECLARE @LogID TABLE(LogID BIGINT)

INSERT INTO @LogID(LogID)
SELECT LogID
FROM BalanceNegativeHistory WITH(NOLOCK)
WHERE StatusID = 0 AND actionid  IN ( 81030,81029,81028)  AND LogDate < '2024-09-07'

UPDATE h
SET StatusID = 1
FROM BalanceNegativeHistory AS  h
WHERE h.LogID IN (SELECT l.LogID FROM @LogID AS l);