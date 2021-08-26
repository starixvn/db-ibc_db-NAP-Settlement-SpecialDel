/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" selecters="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Bitcoin_EmailConfig] ()
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20210810@Kathy
    Task: 
    DB: DBTXN/bodb02
    Revisions:
		- 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
		
	Columns Explanation:    
    
    Notes: TW Team can change function and not notify VNTeam, please ALWAYS check Code Pro before modify function
*/

RETURN (
	SELECT vs.GroupName
		, vs.Recipients
		, vs.Credit_Recipients
		, vs.Deposit_Recipients
		, @@ServerName AS EnvName
	FROM (
		/*----------------------
		NOTIFY Recipients
		-----------------------*/
		SELECT 
			CAST('NOTIFY' AS VARCHAR(10)) AS GroupName
			, CAST('kathy.nguyen@starixvn.com' 	AS VARCHAR(500)) AS Recipients --general
			, CAST('kathy.nguyen@starixvn.com' 	AS VARCHAR(500)) AS Credit_Recipients --credit model
			, CAST('kathy.nguyen@starixvn.com' 	AS VARCHAR(500)) AS Deposit_Recipients --depsit model
			, 'DB230' 	AS ServerName
			, 'DEV' 	AS Environment
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'DB206'
			, 'LOCAL'
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixvn.com;', '', ''
			, 'DB230'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com', 'qa@starixvn.com', 'qa@starixvn.com'
			, 'DB206'
			, 'LOCAL'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)

GO
