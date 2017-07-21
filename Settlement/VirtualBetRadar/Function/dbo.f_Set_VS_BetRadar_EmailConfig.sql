/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" selecters="vnteam" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_VS_BetRadar_EmailConfig] ()
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
			, CAST('bobby.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Recipients --general
			, CAST('bobby.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Credit_Recipients --credit model
			, CAST('bobby.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Deposit_Recipients --depsit model
			, 'DB230' 	AS ServerName
			, 'DEV' 	AS Environment
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'bobby.nguyen@starixsoft.com'
			, 'dora.le@starixsoft.com'
			, 'justin.doan@starixsoft.com;dora.le@starixsoft.com'
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'bobby.nguyen@starixsoft.com'
			, 'dora.le@starixsoft.com'
			, 'justin.doan@starixsoft.com;dora.le@starixsoft.com'
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'bobby.nguyen@starixsoft.com'
			, 'dora.le@starixsoft.com'
			, 'justin.doan@starixsoft.com;dora.le@starixsoft.com'
			, 'DBTRANS'
			, 'PROD'
		
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'bobby.nguyen@starixsoft.com', '', ''
			, 'DB230'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'bobby.nguyen@starixsoft.com;dora.le@starixsoft.com;justin.doan@starixsoft.com', '', ''
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'dora.le@starixsoft.com;justin.doan@starixsoft.com', '', ''
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'dora.le@starixsoft.com;justin.doan@starixsoft.com', '', ''
			, 'DBTRANS'
			, 'PROD'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)
GO