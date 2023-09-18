/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20230913@Louisa
	Task	  : New Provider mapping to Cricket [Redmine:#193975]
	DB		  : DBPRO/bodb02

	Revisions:
		20230913@Louisa: Mapping TheSports [Redmine:#193975]
*/

USE bodb02
GO

	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderInfo p WITH(NOLOCK)	WHERE p.SourceId = 31 )
	BEGIN
		INSERT INTO dbo.ProviderInfo ( SourceId, SourceName,	isActive )
		SELECT 31, 'TheSports', 1
	END

	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK) WHERE pgm.sporttype = 50 AND SourceId = 31	)
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
		SELECT 31, 0, '', 31, 1, 50
	END