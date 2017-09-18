/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Instant_GetBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20161129@Bobby
    Task: 
    DB: DBTXN/bodb02
    Revisions:
		- 20170919@Kathy: Offer new 4 bettypes (461, 462, 463, 464) [Redmine:#83261]
	
     Columns Explanation:    
		- InstantType: bits[0|1:1H,0|2:2H]
    
*/

RETURN (
	SELECT ib.bettype
		, ib.InstantType
	FROM (
		SELECT CAST(3 AS SMALLINT) AS bettype
			, CAST(3 AS TINYINT) AS InstantType
		UNION ALL SELECT 8 , 1
		UNION ALL SELECT 14 , 3
		UNION ALL SELECT 18 , 2
		UNION ALL SELECT 127 , 1
		UNION ALL SELECT 178 , 2
		UNION ALL SELECT 189 , 2
		UNION ALL SELECT 190 , 3
		UNION ALL SELECT 401 , 3
		UNION ALL SELECT 461 , 3
		UNION ALL SELECT 402 , 3
		UNION ALL SELECT 462 , 3
		UNION ALL SELECT 403 , 1
		UNION ALL SELECT 463 , 1
		UNION ALL SELECT 404 , 1
		UNION ALL SELECT 464 , 1
		UNION ALL SELECT 434 , 2
		UNION ALL SELECT 435 , 3
	) AS ib
)
GO