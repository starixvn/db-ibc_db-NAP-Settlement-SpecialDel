/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TVS_GetInstantSettlementBettypes]
(
	@MatchIds VARCHAR(MAX)
)
RETURNS @tmpInstantSettlementBettypes TABLE
(
	matchid INT,
	bettype SMALLINT,
	betid BIGINT
)
AS
/*
	Created by: 20251011@Lani
	Task: [TVS] Danger Accepted/Wrong Score - Display the excluding ticket based on the business rules - CICD rule [Redmine: #236067]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions: 
		- 20251011@Lani: Create new function get instant settlement bettypes - Refactor code following CI/CD rules [Redmine: #236067]
*/
BEGIN
	DECLARE @CTE_match AS TABLE (MatchId INT, SportType SMALLINT)
	DECLARE @CTE_isCal AS TABLE (MatchId INT, IsHTCal BIT, ResourceId VARCHAR(20))
	DECLARE @EvenStatusCompleted NVARCHAR(50) = 'completed'

	INSERT INTO @CTE_match (MatchId, SportType)
	SELECT t.value AS MatchId, m.sporttype
	FROM STRING_SPLIT(@MatchIds,',') AS t
	INNER JOIN dbo.match AS m WITH (NOLOCK) 
		ON CAST(t.value AS INT) = m.matchid AND m.eventstatus <> @EvenStatusCompleted
	WHERE t.value <> ''

	IF EXISTS (SELECT TOP 1 1 FROM @CTE_match WHERE sporttype = 1) --Soccer	 
	BEGIN 
		INSERT INTO @CTE_isCal (matchid, IsHTCal)
		SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
		FROM @CTE_match AS m
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON mr.matchid = m.matchid
		WHERE m.sporttype = 1

		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO @tmpInstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM @CTE_isCal AS c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
									WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
								ELSE 0 END
			) AS f
	END

	IF EXISTS (SELECT TOP 1 1 FROM @CTE_match WHERE sporttype = 2) --Basketball
	BEGIN
		INSERT INTO @CTE_isCal (matchid, ResourceId)
		SELECT m.matchid, rd.ResourceId
		FROM @CTE_match AS m
			LEFT JOIN DBPRO.bodb02.dbo.ResultDetail AS rd WITH (NOLOCK) 
				ON rd.matchid = m.matchid
				AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 
		WHERE m.sporttype = 2

		INSERT INTO @tmpInstantSettlementBettypes (matchid, bettype, betid)
		SELECT DISTINCT c.matchid, f.bettype, f.betid
		FROM @CTE_isCal AS c
			CROSS APPLY (
					SELECT bettype, betid
					FROM dbo.f_TVS_GetInstantBettypes()
					WHERE InstantType IS NULL
					AND 1 = CASE WHEN c.ResourceId IS NULL THEN 1 --NOT executed on this match.
									WHEN c.ResourceId IS NOT NULL AND ResourceId NOT IN (SELECT ResourceId FROM @CTE_isCal) THEN 1
									ELSE 0 END
			) AS f	
	END
	
	RETURN
END
GO