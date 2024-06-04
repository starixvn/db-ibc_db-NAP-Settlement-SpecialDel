/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240604@Max
	Task: Resert 0 if not exists in bettrans CustLitmitBet_LIC - EventTypeID = 3 [Redmine:#206061]
	DB:  DBSID.bodb02
*/
USE bodb02
GO
 
UPDATE t
SET AccumPayout = 0
	, AccumTurnover = 0
FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
	OUTER APPLY ( SELECT TOP 1 1 AS IsExists FROM bettrans b WITH (NOLOCK) WHERE b.custid = t.CustID AND b.matchid = 29 AND b.oddsid = 1) AS t1
WHERE  t.matchid = 29
	AND t.EventTypeID = 3
	AND t.AccumTurnover <> 0
	AND t1.IsExists IS NULL

