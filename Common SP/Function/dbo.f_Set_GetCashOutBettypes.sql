/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_GetCashOutBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created by: Kent
	Date: 20170323
	Original: 
	Task: Get all bettypes offered for cash-out
	DB: DBTXN/BODB02

	Revisions:		
		- 20211130@Kathy: New cashout model [Redmine:#164838]


*/

RETURN (    
	SELECT	CONVERT(SMALLINT, 1) AS BetType, CAST(0 AS BIT) AS IsDecimalOnly, CAST('FT' AS VARCHAR(20)) AS GroupName			
	UNION ALL SELECT CONVERT(SMALLINT, 3), CAST(0 AS BIT), CAST('FT' AS VARCHAR(20)) AS GroupName	
	UNION ALL SELECT CONVERT(SMALLINT, 5), CAST(1 AS BIT), CAST('FT' AS VARCHAR(20)) AS GroupName	
	UNION ALL SELECT CONVERT(SMALLINT, 7), CAST(0 AS BIT), CAST('HT' AS VARCHAR(20)) AS GroupName	
	UNION ALL SELECT CONVERT(SMALLINT, 8), CAST(0 AS BIT), CAST('HT' AS VARCHAR(20)) AS GroupName	
	UNION ALL SELECT CONVERT(SMALLINT, 15), CAST(1 AS BIT), CAST('HT' AS VARCHAR(20)) AS GroupName	
)
GO


