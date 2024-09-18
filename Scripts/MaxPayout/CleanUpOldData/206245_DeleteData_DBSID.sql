/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created: 20240918@Max
    Task: Delete old data - [Redmine: #206245]
    DB: DBGRP02L-bodb02
    Revisions:
		- 20240918@Max: Delete old data - [Redmine: #206245]

	Param's explanation:		
		
*/
USE bodb02
GO

--delete old data for LIC
DELETE m
FROM dbo.CustLimitBet_LIC m
WHERE m.Matchid = 58227075 AND m.CustID = 65461409 AND m.EventTypeID = 1



