/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[f_Set_Instant_GetBettypes] ()
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
	SELECT ib.bettype
		, ib.InstantType
		--, bt.typenamee
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
		UNION ALL SELECT 402 , 3
		UNION ALL SELECT 403 , 1
		UNION ALL SELECT 404 , 1
		UNION ALL SELECT 434 , 2
		UNION ALL SELECT 435 , 3
	) AS ib
	--INNER JOIN dbo.bettype bt WITH(NOLOCK) ON ib.bettype = bt.typeid
	--WHERE EXISTS (
	--	SELECT 1
	--	FROM [dbo].[f_Set_GetGroupBettypes] () sb 
	--	WHERE sb.bettype = ib.bettype AND sb.IsDetermined = 1
)
GO
SELECT *
FROM [dbo].[f_Set_Instant_GetBettypes] ()
--WHERE InstantType & 2 = 2
ORDER BY InstantType