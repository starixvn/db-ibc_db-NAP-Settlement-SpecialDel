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
		- 20211005@Kathy: Change email on Prod [Redmine:#159714]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
		
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
			, CAST('kathy.nguyen@starixvn.com' 	AS VARCHAR(500)) AS Deposit_Recipients --deposit model
			, 'DB230' 	AS ServerName
			, 'DEV' 	AS Environment
			
		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'DB206'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'TESTDBTRANS'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com'
			, 'testdb053\TESTSITEDB'
			, 'LOCAL'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'SITDBTRANS'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'SITDBGRP01N1'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'qa@starixvn.com'
			, 'SITDBGRP01N2'
			, 'SIT'

		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixvn.com'
			--,'qa@starixvn.com'
			--,'qa@starixvn.com'
			, 'it@starixvn.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'csoneonone@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'DBTRANS'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixvn.com'
			--,'qa@starixvn.com'
			--,'qa@starixvn.com'
			, 'it@starixvn.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'csoneonone@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'DBGRP01N1'
			, 'PROD'

		UNION ALL 
		SELECT 'NOTIFY'
			--,'qa@starixvn.com'
			--,'qa@starixvn.com'
			--,'qa@starixvn.com'
			, 'it@starixvn.com;'
			, 'csd.one1@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'csoneonone@enpine.com;nsd3rdparty@enpine.com;thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'DBGRP01N2'
			, 'PROD'

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

		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com', 'qa@starixvn.com', 'qa@starixvn.com'
			, 'TESTDBTRANS'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'kathy.nguyen@starixvn.com;qa@starixvn.com', 'qa@starixvn.com', 'qa@starixvn.com'
			, 'testdb053\TESTSITEDB'
			, 'LOCAL'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixvn.com', 'qa@starixvn.com', 'qa@starixvn.com'
			, 'SITDBTRANS'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixvn.com', 'qa@starixvn.com', 'qa@starixvn.com'
			, 'SITDBGRP01N1'
			, 'SIT'

		UNION ALL 
		SELECT 'ERROR'
			, 'qa@starixvn.com', 'qa@starixvn.com', 'qa@starixvn.com'
			, 'SITDBGRP01N2'
			, 'SIT'
		
		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixvn.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'qa@starixvn.com', 'qa@starixvn.com'
			, 'DBTRANS'
			, 'PROD'

		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixvn.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'qa@starixvn.com', 'qa@starixvn.com'
			, 'DBGRP01N1'
			, 'PROD'

		UNION ALL 
		SELECT 'ERROR'
			--,'qa@starixvn.com'
			, 'thomas.chou@onelab.tw;sobi.chen@onelab.tw;eric.fu@onelab.tw;charles.chung@onelab.tw;it@starixvn.com;peter.tong@starixvn.com;lena.huynh@starixvn.com'
			, 'qa@starixvn.com', 'qa@starixvn.com'
			, 'DBGRP01N2'
			, 'PROD'
			
	) AS vs
	WHERE vs.ServerName = @@SERVERNAME
)

GO
