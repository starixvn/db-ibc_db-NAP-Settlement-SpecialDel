/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Settle_GetTradingBettype] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 
    Task: 
    DB: DBTXN/bodb02; DBPRO/bodb02
    Revisions:
		- 20160825@Bobby: #62921 - Allow FGLG (14,127) bet types to settle determindable
	
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
