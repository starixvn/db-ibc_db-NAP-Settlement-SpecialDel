/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" selecters="" isFunction="1" isNested="1"></info>*/
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
		- 20211005@Kathy: Change email on Prod [Redmine:#159714]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
		- 20230704@Louisa: Update email from csd.one1@enpine.com to csd.one1@enpine.com [Redmine:#189854]
		- 20231026@Louisa: Update email domain from starixvn to starixsoft [Redmine:#195197]
		- 20240710@Kathy: Change instance name [Redmine:#207768]
		- 20250508@Aries: Change instance name DBTRANS [Redmine:#226591]
		
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
			, CAST('kathy.nguyen@starixsoft.com' 	AS VARCHAR(500)) AS Deposit_Recipients --deposit model
			, 'DB230' 	AS ServerName
			, 'DEV' 	AS Environment
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'DB206'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'TESTDBTRANS'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com'
			, 'testdb053\TESTSITEDB'
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
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBGRP01N1'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
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
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBSITEC2\INST2'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'qa@starixsoft.com'
			, 'SITDBSITEC3\INST3'
			, 'SIT'
		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBTRANS'
			, 'PROD'
		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBTRANS\INST2'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBGRP01N1'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBGRP01N2'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBSITEC1'
			, 'PROD'
		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBSITEC2\INST2'
			, 'PROD'
		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			--,'qa@starixsoft.com'
			, 'it@starixsoft.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'DBSITEC3\INST3'
			, 'PROD'
		/*----------------------
		ERROR Recipients
		-----------------------*/
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixsoft.com;', '', ''
			, 'DB230'
			, 'DEV'
			
		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DB206'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'TESTDBTRANS'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixsoft.com;qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'testdb053\TESTSITEDB'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'SITDBTRANS'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'SITDBGRP01N1'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'SITDBGRP01N2'
			, 'SIT'
		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'SITDBSITEC1'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'SITDBSITEC2\INST2'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixsoft.com', 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'SITDBSITEC3\INST3'
			, 'SIT'
		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBTRANS'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBTRANS\INST2'
			, 'PROD'

		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBGRP01N1'
			, 'PROD'

		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBGRP01N2'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBSITEC1'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBSITEC2\INST2'
			, 'PROD'
		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixsoft.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixsoft.com;peter.tong@starixsoft.com;lena.huynh@starixsoft.com'
			, 'qa@starixsoft.com', 'qa@starixsoft.com'
			, 'DBSITEC3\INST3'
			, 'PROD'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)

GO
