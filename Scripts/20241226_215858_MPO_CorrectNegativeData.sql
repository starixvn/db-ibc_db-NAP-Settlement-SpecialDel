/*<info serverAlias="DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: Max
	Task : Max Payout - Update script to correct data to avoid duplication
	DB: DBSITEC2 - bodb02

	Revisions:
		- 20241226@Max: Create script [Redmine: #215858]

	Note: Run on DBSITEC2 ONLY
*/

--run on SiteDB2
USE bodb02
GO

BEGIN
	UPDATE l SET l.AccumTurnover = 0
	FROM dbo.CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)
	WHERE l.Matchid = 98192914
		AND l.CustID = 174943686
		AND l.EventTypeID = 1
END
GO

