/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20240508@Louisa
	Task	  : New Provider for Basketball [Redmine:#203833]
	DB		  : DBPRO/bodb02

	Revisions:
		20240508@Louisa: Initial data [Redmine:#203833]
*/

USE bodb02
GO

BEGIN
	SET NOCOUNT ON
  
	INSERT INTO dbo.ProviderGameTypeMapping (SourceId,GameType,Remark,OrderNo,isActive,sporttype)
	SELECT 201, 0, '', 201, 1, 2
END