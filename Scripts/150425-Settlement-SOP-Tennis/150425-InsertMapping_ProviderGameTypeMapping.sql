/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210305@Louisa
	Task	  : SOP for Tennis [Redmine:#150425]
	DB		  : DBPRO/bodb02

	Revisions:
		20210305@Louisa: Mapping L-sports [Redmine:#150425]
*/

USE bodb02
GO

BEGIN

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderInfo p WITH(NOLOCK)
					WHERE p.SourceId = 25
					)
	BEGIN
		INSERT INTO dbo.ProviderInfo ( SourceId, SourceName,	isActive )
		SELECT 25, 'LSports', 1
	END

	-----------------------------------------------------------------------------------
	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
					WHERE pgm.sporttype = 5 AND SourceId = 25
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
		SELECT 25, 0, '', 1, 1, 5
	END

END