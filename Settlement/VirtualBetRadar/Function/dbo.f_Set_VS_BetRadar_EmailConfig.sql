/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" selecters="" isFunction="1" isNested="1"></info>*/
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
		- 20200108@Max: Refund/resettle Betradar VS: Remove email address - [Redmine: #126807]
		- 20200513@EricFu: remove jason.ni@onelab.tw,angela.chan@onelab.tw, add aaron.wang@onelab.tw,yikhun.chiu@onelab.tw,sobi.chen@onelab.tw
		 20201012@Louisa: Update new email domain starixvn.com [Redmine:#143284]
		
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
			, 'kathy.nguyen@starixvn.com'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixvn.com;amy.vu@starixvn.com;lena.huynh@starixvn.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;aaron.wang@onelab.tw;yikhun.chiu@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixvn.com;amy.vu@starixvn.com;lena.huynh@starixvn.com;it@starixvn.com;dbaadmin@starixvn.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;aaron.wang@onelab.tw;yikhun.chiu@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;aaron.wang@onelab.tw;yikhun.chiu@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBTRANS'
			, 'PROD'
		
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixvn.com;csoneonone@enpine.com', '', ''
			, 'DB230'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixvn.com;kathy.nguyen@starixvn.com', '', ''
			, 'DB206'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixvn.com;kathy.nguyen@starixvn.com;amy.vu@starixvn.com;lena.huynh@starixvn.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;aaron.wang@onelab.tw;yikhun.chiu@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBTRANS'
			, 'SIT'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixvn.com;amy.vu@starixvn.com;lena.huynh@starixvn.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixvn.com;dbaadmin@starixvn.com;ariel.lin@onelab.tw;aaron.wang@onelab.tw;yikhun.chiu@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBTRANS'
			, 'PROD'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)

GO
