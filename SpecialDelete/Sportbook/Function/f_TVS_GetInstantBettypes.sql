/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_GetInstantBettypes] ()
RETURNS TABLE
AS
/*
    Created: 20220615@July
    Task: Get Bettype Instant Settlement
	 DB: DBTXN/bodb02
    Revisions:
		- 20220615@July: [TVS] Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20230821@July: [TVS] Instant Settlement of Basketball [Redmine: #185492]

    Parameters Explanation:    
*/

RETURN (
	
	WITH cte 
	AS (
		SELECT s.BetType
		FROM dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)		
		WHERE s.SportType = 1 and s.DeterminedType = 2  -- cal ht
	)
	SELECT ISNULL(s.BetType, f.bettype) AS bettype, ISNULL(f.InstantType,2) AS InstantType, NULL AS BetID, NULL AS ResourceId, 1 AS SportType
	FROM cte s
		FULL JOIN f_Set_Instant_GetBettypes () f
			ON s.BetType = f.bettype

	UNION ALL

	SELECT  s.BetType, NULL AS InstantType, s.BetID, ISNULL(S.RefResourceId,s.SDTResourceId) AS ResourceId, 2 AS SportType
	FROM	dbo.SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
	WHERE	s.SportType = 2
		AND (  ISNULL(s.DeterminedType,0) > 0 
			OR ISNULL(s.SDTInstant,0) > 0 
			)
)

GO

