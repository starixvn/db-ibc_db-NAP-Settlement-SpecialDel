/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_Settle_GetTradingBettype] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20170801@Bobby.Nguyen
    Task: Implement new capture balance method [Redmine:#80774]
    DB: DBTXN/bodb02
    Revisions:
		  - 20170801@Bobby.Nguyen: Initialize
	
    Parameters Explanation:    
*/

RETURN (
   SELECT bettype
	FROM (
		VALUES 
		(901),(902),(903),(904) 	--Bettrade
		,(911),(912),(913),(914)	--CashOut
	) AS t (bettype)
)
GO
