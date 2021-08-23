/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210819@Louisa
	Task	  : Show Provider Results for remain sports [Redmine:#160192] 
	DB		  : DBPRO/bodb02

	Revisions:
		20210819@Louisa: Mapping Provider [Redmine:#160192]
*/

USE bodb02
GO

BEGIN

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
					WHERE pgm.sporttype = 5 AND SourceId = 1
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
		SELECT 1, 0, '', 1, 1, 5
	END

END