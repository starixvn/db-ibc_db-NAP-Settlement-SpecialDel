/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210524@Louisa
	Task	  : SOP for Badminton, Basketball [Redmine:#155361,#155361]
	DB		  : DBPRO/bodb02

	Revisions:
		20210524@Louisa: INSERT more SBO info [Redmine:#155361]
*/

USE bodb02
GO

BEGIN

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderInfo p WITH(ROWLOCK)
					WHERE p.SourceId = 1
					)
	BEGIN
		INSERT INTO dbo.ProviderInfo ( SourceId, SourceName, isActive )
		SELECT 1,  'SBO', 1
	END

	-----------------------------------------------------------------------------------
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping pgm WITH(ROWLOCK)
					WHERE pgm.sporttype = 9 AND SourceId = 1	)
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
		SELECT 1, 0, '', 1, 1, 9
	END

	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping pgm WITH(ROWLOCK)
					WHERE pgm.sporttype = 2 AND SourceId = 1	)
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
		SELECT 1, 0, '', 1, 1, 2
	END

END