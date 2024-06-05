/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240605@Max
	Task: Update value missing for CustLimitBet_LIC - SITE01 [Redmine:#206061]
	DB:  DBGRP01L.bodb02
*/
USE bodb02
GO

UPDATE t
SET t.AccumPayout = t.AccumPayout + 1840.25
	, t.AccumTurnover = t.AccumTurnover + 100.00
FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
WHERE t.matchid = 29
	AND t.EventTypeID = 3
	AND t.CustID = 97179305