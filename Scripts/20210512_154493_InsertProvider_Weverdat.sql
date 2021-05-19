/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210512@Louisa
	Task	  : Integration with Weverdat [Redmine:#154493]
	DB		  : DBPRO/bodb02

	Revisions:
		20210512@Louisa: INSERT Provider info Weverdat [Redmine:#154493]
*/

USE bodb02
GO

BEGIN

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderInfo p WITH(ROWLOCK)
					WHERE p.SourceId = 24
					)
	BEGIN
		INSERT INTO dbo.ProviderInfo ( SourceId, SourceName,	isActive )
		SELECT 24,  'Weverdat', 1
	END

	-----------------------------------------------------------------------------------
	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderGameTypeMapping pgm WITH(ROWLOCK)
					WHERE pgm.sporttype = 50 AND SourceId = 24
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
		SELECT 24, 0, '', 1, 1, 50
	END

END