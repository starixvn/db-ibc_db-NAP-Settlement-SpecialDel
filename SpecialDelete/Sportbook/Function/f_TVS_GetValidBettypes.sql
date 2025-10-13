/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TVS_GetValidBettypes]()
RETURNS TABLE
AS
/*
	Created by: 20251011@Lani
	Task: [TVS] Danger Accepted/Wrong Score - Display the excluding ticket based on the business rules - CICD rule [Redmine: #236067]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions: 
		- 20251011@Lani: Create new function - Refactor code following CI/CD rules [Redmine: #236067]
*/
RETURN
(
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
)
GO