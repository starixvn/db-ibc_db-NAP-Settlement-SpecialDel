/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_GetEarlyBettypes] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20170612@Kathy
    Task: Early settlement bettypes [Redmine:#77835]
    DB: DBTXN/bodb02
    Revisions:
		- 20170613@Kathy: Early Settlement [Redmine:#77835] 
	
    Parameters Explanation:    
   
*/

RETURN (
   SELECT CAST(604 AS SMALLINT) AS bettype
   UNION ALL
   SELECT 606
   UNION ALL 
   SELECT 607 
   UNION ALL
   SELECT 613	
)
GO
