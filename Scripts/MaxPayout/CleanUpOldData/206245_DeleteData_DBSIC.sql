/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created: 20240918@Max
    Task: Delete old data - [Redmine: #206245]
    DB: DBSIC-bodb02
    Revisions:
		- 20240918@Max: Delete old data - [Redmine: #206245]

	Param's explanation:		
		
*/
USE bodb02
GO

--truncate data LIC on credit server
TRUNCATE TABLE dbo.CustLimitBet_LIC

--delete old data for MBC & 789y
DELETE m
FROM dbo.CustLimitBet_MBC m
WHERE m.Matchid = 58261718 AND m.CustID = 60081994 AND m.EventTypeID = 1

DELETE m
FROM dbo.CustLimitBet_MBC m
WHERE m.Matchid = 58284962 AND m.CustID = 48119980 AND m.EventTypeID = 1

DELETE m
FROM dbo.CustLimitBet_789 m
WHERE m.Matchid = 54339151 AND m.CustID = 64650212 AND m.EventTypeID = 1


