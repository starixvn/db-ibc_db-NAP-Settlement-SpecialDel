/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TVS_GetInstantSettlementBettypes]
(
	@MatchIds VARCHAR(MAX)
)
RETURNS TABLE
AS
/*
	Created by: 20251011@Lani
	Task: [TVS] Danger Accepted/Wrong Score - Display the excluding ticket based on the business rules - CICD rule [Redmine: #236067]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions: 
		- 20251011@Lani: Create new function get instant settlement bettypes - Refactor code following CI/CD rules [Redmine: #236067]
*/
RETURN
(
	WITH CTE_Match AS (
		SELECT DISTINCT m.matchid, m.sporttype
		FROM dbo.match AS m WITH (NOLOCK)
		CROSS APPLY STRING_SPLIT(@MatchIds, ',') AS t
		WHERE m.matchid = CAST(t.value AS INT) 
			AND m.eventstatus <> 'completed'
	),
	CTE_isCal AS (
		SELECT m.matchid, 
			   CASE WHEN m.sporttype = 1 THEN ISNULL(mr.IsHTCal, 0) ELSE NULL END AS IsHTCal,
			   CASE WHEN m.sporttype = 2 THEN rd.ResourceId ELSE NULL END AS ResourceId,
			   m.sporttype
		FROM CTE_Match AS m
		LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) 
				ON mr.matchid = m.matchid AND m.sporttype = 1
		LEFT JOIN DBPRO.bodb02.dbo.ResultDetail AS rd WITH (NOLOCK) 
				ON rd.matchid = m.matchid 
				AND m.sporttype = 2 
				AND rd.ResultStatusID IN (2,5) 
				AND (rd.ResourceId LIKE 'Q[1-4]' OR rd.ResourceId IN ('01','OT'))
	),
	CTE_ResourceIds AS (
		SELECT DISTINCT c.ResourceId 
		FROM CTE_isCal AS c
		WHERE c.sporttype = 2 AND c.ResourceId IS NOT NULL
	)
	-- Soccer
	SELECT c.matchid, f.bettype, NULL AS betid
	FROM CTE_isCal AS c
	CROSS APPLY dbo.f_TVS_GetInstantBettypes() AS f
	WHERE c.sporttype = 1
		AND (
			(c.IsHTCal = 0 AND f.InstantType IN (1, 3))
			OR (c.IsHTCal > 0 AND f.InstantType IN (2, 3))
		)
	
	UNION ALL
	
	-- Basketball 
	SELECT DISTINCT c.matchid, f.bettype, f.betid
	FROM CTE_isCal AS c
	CROSS APPLY dbo.f_TVS_GetInstantBettypes() AS f
	WHERE c.sporttype = 2
		AND f.InstantType IS NULL
		AND (
			c.ResourceId IS NULL
			OR (c.ResourceId IS NOT NULL AND c.ResourceId NOT IN (SELECT ResourceId FROM CTE_ResourceIds))
		)
)
GO