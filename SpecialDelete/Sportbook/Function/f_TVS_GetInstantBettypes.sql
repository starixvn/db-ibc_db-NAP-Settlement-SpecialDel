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

    Parameters Explanation:    
*/

RETURN (
	
	WITH cte 
	AS (
		SELECT s.BetType
		FROM dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)		
		WHERE s.SportType = 1 and s.DeterminedType = 2  -- cal ht
	)
	SELECT COALESCE(s.BetType, f.bettype) bettype, COALESCE(f.InstantType,2) AS InstantType
	FROM cte s
		FULL JOIN f_Set_Instant_GetBettypes () f
			ON s.BetType = f.bettype
)

GO

