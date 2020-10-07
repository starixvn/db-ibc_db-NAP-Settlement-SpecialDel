/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_CheckingProcessGroupBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20201007@Max
    Task: Get group bettypes for checking process
    DB: DBTXN/bodb02; DBPRO/bodb02
    Revisions:
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]

    Parameters Explanation: 
		GroupId:
			+ 1: Fast Market
    
*/

RETURN (
	-- Fast Market
	SELECT	CONVERT(SMALLINT, 221) AS BetType
			,CONVERT(INT, 1) AS GroupId
	
	UNION ALL SELECT 222,1
	UNION ALL SELECT 223,1
	UNION ALL SELECT 224,1
	UNION ALL SELECT 225,1
	UNION ALL SELECT 226,1
	UNION ALL SELECT 227,1
	UNION ALL SELECT 228,1
	
)
GO
