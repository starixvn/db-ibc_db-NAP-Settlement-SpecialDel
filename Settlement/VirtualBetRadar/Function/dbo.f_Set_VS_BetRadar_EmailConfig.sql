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
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'bobby.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;johnson.nguyen@starixsoft.com;jason.ni@onelab.tw;angela.chan@onelab.tw;jefferson.liu@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'bobby.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;celine.saw99@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;jason.ni@onelab.tw;angela.chan@onelab.tw;jefferson.liu@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;celine.saw99@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;jason.ni@onelab.tw;angela.chan@onelab.tw;jefferson.liu@onelab.tw' --deposit
			, 'DBTRANS'
			, 'PROD'
		
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'bobby.nguyen@starixsoft.com;csoneonone@enpine.com', '', ''
			, 'DB230'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;bobby.nguyen@starixsoft.com', '', ''
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;bobby.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;johnson.nguyen@starixsoft.com;jason.ni@onelab.tw;angela.chan@onelab.tw;jefferson.liu@onelab.tw', '', ''
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'bobby.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;jason.ni@onelab.tw;angela.chan@onelab.tw;jefferson.liu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com', '', ''
			, 'DBTRANS'
			, 'PROD'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)
GO