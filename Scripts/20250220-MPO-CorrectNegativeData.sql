/*<info serverAlias="DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: Max
	Task : Max Payout - correct data
	DB: DBSITEC2 - bodb02

	Revisions:
		- 20250120@Max: Create script [Redmine: #215858]

	Note: Run on DBSITEC2 ONLY
*/

--run on SiteDB2
USE bodb02
GO

BEGIN
	UPDATE l SET l.AccumTurnover = l.AccumTurnover + 50
				, l.AccumPayout = l.AccumPayout + 13637.07
	FROM dbo.CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)
	WHERE l.Matchid = 29
		AND l.CustID = 155424995
		AND l.EventTypeID = 4
END
GO

