/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20250723@Louisa
	Task	  : Map provider [Redmine:#233916]
	DB		  : DBPRO/bodb02

	Revisions:
		20250723@Louisa: Create [Redmine:#233916]
*/

USE bodb02
GO
SET NOCOUNT ON

BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping
				(
				SourceId
				,GameType
				,Remark
				,OrderNo
				,isActive
				,sporttype
				)
	SELECT 24, 0, '', 24, 1, 47
END
