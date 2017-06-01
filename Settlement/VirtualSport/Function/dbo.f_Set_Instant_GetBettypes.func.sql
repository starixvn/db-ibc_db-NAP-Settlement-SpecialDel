/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" selecters="vnteam" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Set_BetRadarVS_GetBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20161129@Bobby
    Task: 
    DB: DBTXN/bodb02
    Revisions:
	
     Columns Explanation:    
		- InstantType: bits[0|1:1H,0|2:2H]
    
*/

RETURN (
	SELECT vs.bettype
		, vs.SportType
		, vs.SettleType
	FROM (
		SELECT CAST(3 AS SMALLINT) AS bettype
			, CAST(190 AS TINYINT) AS SportType
			, CAST(1 AS TINYINT) AS SettleType -- HT-FT
		UNION ALL SELECT 8 , 1
		UNION ALL SELECT 14 , 3
		UNION ALL SELECT 18 , 2
		UNION ALL SELECT 127 , 1
		UNION ALL SELECT 178 , 2
		UNION ALL SELECT 189 , 2
		UNION ALL SELECT 190 , 3
		UNION ALL SELECT 401 , 3
		UNION ALL SELECT 402 , 3
		UNION ALL SELECT 403 , 1
		UNION ALL SELECT 404 , 1
		UNION ALL SELECT 434 , 2
		UNION ALL SELECT 435 , 3
	) AS vs
)
GO
