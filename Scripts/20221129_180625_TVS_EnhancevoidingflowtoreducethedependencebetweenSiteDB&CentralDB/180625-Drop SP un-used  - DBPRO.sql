/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221207@July
	Task: Drop SP un-used - Special Delete & TVS  [Redmine:#180625]  
	DB: DBPRO-bodb02
		   
*/
USE bodb02
GO

IF OBJECT_ID('NAP_PlayerSelect', 'P') IS NOT NULL
	DROP PROCEDURE NAP_PlayerSelect;
GO
IF OBJECT_ID('NAP_EventSelect', 'P') IS NOT NULL
	DROP PROCEDURE NAP_EventSelect;
GO
