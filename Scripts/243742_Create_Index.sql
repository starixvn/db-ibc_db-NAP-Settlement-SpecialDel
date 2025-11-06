/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	20251106@Louisa: Create Index [Redmine:#243742]

*/

USE bodb02
GO

CREATE NONCLUSTERED INDEX IDX_TempVariableNumber_KeyValue_KeyID_KeyValue2 ON dbo.TempVariableNumber (KeyValue, KeyID, KeyValue2)
