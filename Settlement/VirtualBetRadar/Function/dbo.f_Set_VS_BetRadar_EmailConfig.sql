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
		- 20181017@Helen: Remove email address from Betradar VS Settlement service - [Redmine:103352]
		- 20181115@Victor: add RD Email eric.fu@onelab.tw
		- 20181115@Helen: Add one email address into Settlement email notification - [Redmine:104840]
		
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
			, CAST('kathy.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Recipients --general
			, CAST('kathy.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Credit_Recipients --credit model
			, CAST('kathy.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Deposit_Recipients --depsit model
			, 'DB230' 	AS ServerName
			, 'DEV' 	AS Environment
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;jason.ni@onelab.tw;eric.fu@onelab.tw;angela.chan@onelab.tw;ariel.lin@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;celine.saw99@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;jason.ni@onelab.tw;eric.fu@onelab.tw;angela.chan@onelab.tw;ariel.lin@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;celine.saw99@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;jason.ni@onelab.tw;eric.fu@onelab.tw;angela.chan@onelab.tw;ariel.lin@onelab.tw' --deposit
			, 'DBTRANS'
			, 'PROD'
		
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixsoft.com;csoneonone@enpine.com', '', ''
			, 'DB230'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;kathy.nguyen@starixsoft.com', '', ''
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;kathy.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;jason.ni@onelab.tw;eric.fu@onelab.tw;angela.chan@onelab.tw;ariel.lin@onelab.tw', '', ''
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixsoft.com;amy.vu@starixsoft.com;lena.huynh@starixsoft.com;jason.ni@onelab.tw;eric.fu@onelab.tw;angela.chan@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw', '', ''
			, 'DBTRANS'
			, 'PROD'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)
GO
