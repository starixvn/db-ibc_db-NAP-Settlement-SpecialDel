/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" selecters="" isFunction="1" isNested="1"></info>*/
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
		- 20201012@Louisa: Update new email domain starixvn.com [Redmine:#143284]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
		- 20221017@Kathy: Remove email yikhun.chiu@onelab.tw, add carrie.chen@onelabe.tw [Redmine:#179106]
		- 20221104@Louisa: Update email address from carrie.chen@onelabe.tw to carrie.chen@onelab.tw [Redmine:#179106]
		- 20230704@Louisa:  Update ServerName for local environment + Update domain starixsoft [Redmine:#189854]
		- 20230907@Louisa: Add email eason.chou@onelab.tw and remove aaron.wang@onelab.tw [Redmine:#193816]
		- 20231002@Louisa: Add email csd.one1@enpine.com for Deposite, Remove: csoneonone@enpine.com [Redmine: #194949]
		- 20231016@Aries: SIT env: remove mail  [Redmine:#195333]
		- 20240710@Kathy: Change instance name [Redmine:#207768]

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
			, CAST('qa@starixsoft.com' 	AS VARCHAR(500)) AS Recipients --general
			, CAST('qa@starixsoft.com' 	AS VARCHAR(500)) AS Credit_Recipients --credit model
			, CAST('qa@starixsoft.com' 	AS VARCHAR(500)) AS Deposit_Recipients --depsit model
			, 'DB-60\DevDBTrans' 	AS ServerName
			, 'DEV' 	AS Environment
		
		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'DB62\DEVSITEDB'
			, 'DEV'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'DEVDB061\DEVSITEDB2'
			, 'DEV'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'TESTDBTRANS'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'DB66'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'DB67'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'TESTSITEDB2'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBTRANS'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBGRP01N1'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBGRP01N2'
			, 'SIT'
		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBSITEC1'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBSITEC2\INST2'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBSITEC3\INST3'
			, 'SIT'
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBGRP02N1'
			, 'SIT'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBGRP02N2'
			, 'SIT'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBTRANS'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBGRP01N1'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBGRP01N2'
			, 'PROD'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBGRP02N1'
			, 'PROD'
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBGRP02N2'
			, 'PROD'
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBSITEC1'
			, 'PROD'
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBSITEC2\INST2'
			, 'PROD'
		UNION ALL 
		SELECT 'NOTIFY'
			, 'lena.huynh@starixsoft.com;it@starixsoft.com;dbaadmin@starixsoft.com'
			, 'martin.jr@oneworks.com;csd.one1@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --credit
			, 'martin.jr@oneworks.com;csoneonone@enpine.com;elwin.tsw@enpine.com;IT@cardiff-service.com;rdadmin@onelab.tw;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw' --deposit
			, 'DBSITEC3\INST3'
			, 'PROD'
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', '', ''
			, 'DB-60\DevDBTrans'
			, 'DEV'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', '', ''
			, 'DB62\DEVSITEDB'
			, 'DEV'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', '', ''
			, 'DEVDB061\DEVSITEDB2'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', '', ''
			, 'TESTDBTRANS'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', '', ''
			, 'DB66'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', '', ''
			, 'DB67'
			, 'LOCAL'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBTRANS'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBGRP01N1'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBGRP01N2'
			, 'SIT'
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBSITEC1'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBSITEC2\INST2'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBSITEC3\INST3'
			, 'SIT'	
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBGRP02N1'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com;lena.huynh@starixsoft.com;eric.fu@onelab.tw;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'SITDBGRP02N2'
			, 'SIT'
		
			
		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBTRANS'
			, 'PROD'

		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBGRP01N1'
			, 'PROD'

		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBGRP01N2'
			, 'PROD'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBGRP02N1'
			, 'PROD'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBGRP02N2'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBSITEC1'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBSITEC2\INST2'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			, 'lena.huynh@starixsoft.com;eric.fu@onelab.tw;IT@cardiff-service.com;rdadmin@onelab.tw;IT@starixsoft.com;dbaadmin@starixsoft.com;ariel.lin@onelab.tw;eason.chou@onelab.tw;carrie.chen@onelab.tw;sobi.chen@onelab.tw', '', ''
			, 'DBSITEC3\INST3'
			, 'PROD'
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)

GO
