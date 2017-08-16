/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" selecters="vnteam" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION [dbo].[f_Set_VS_BetRadar_GetBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20161129@Bobby
    Task: 
    DB: DBTXN/bodb02
    Revisions:
		- 20160606@Bobby: Initialize
    
	Columns Explanation:    
		- @CalMode: TINYINT [1:HT,2:FT]
    
*/

RETURN (
	SELECT vs.bettype
		, vs.SportType
		, vs.CalMode
	FROM (
		--single bettype VS League
		SELECT CAST(2701 AS SMALLINT) AS bettype
			, CAST(190 AS SMALLINT) AS SportType
			, CAST(2 AS TINYINT) AS CalMode -- HT-FT
		UNION ALL SELECT 2702, 190, 1
		UNION ALL SELECT 2703, 190, 2
		UNION ALL SELECT 2704, 190, 1
		UNION ALL SELECT 2705, 190, 2
		UNION ALL SELECT 2706, 190, 1
		UNION ALL SELECT 2707, 190, 2
		
		--single bettype VS Nation
		UNION ALL SELECT 2701, 191, 2
		UNION ALL SELECT 2702, 191, 1
		UNION ALL SELECT 2703, 191, 2
		UNION ALL SELECT 2704, 191, 1
		UNION ALL SELECT 2705, 191, 2
		UNION ALL SELECT 2706, 191, 1
		UNION ALL SELECT 2707, 191, 2
		
		--mix-parlay
		UNION ALL SELECT 2799, 190, 1
		
	) AS vs
)
GO
