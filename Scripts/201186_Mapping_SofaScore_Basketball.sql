/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20240306@Louisa
	Task	  : Mapping Sofas Score to Basketball [Redmine:#201186] 
	DB		  : DBPRO/bodb02
*/

USE bodb02
GO

IF NOT EXISTS ( SELECT TOP 1 1 
				FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
				WHERE pgm.sporttype = 2 AND SourceId = 31
				)
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
	SELECT 31, 0, '', 31, 1, 2
END

GO