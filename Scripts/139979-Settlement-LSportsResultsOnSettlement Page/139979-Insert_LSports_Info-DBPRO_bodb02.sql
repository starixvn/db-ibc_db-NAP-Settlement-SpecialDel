/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200904@Louisa
    Task: Insert LSports info [Redmine:#139979]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200904@Louisa: Insert LSports info [Redmine:#139979]

*/

USE [bodb02]
GO

INSERT INTO dbo.ProviderInfo (SourceId, SourceName, Remark,isActive)
SELECT 25, 'LSports', '', 1
