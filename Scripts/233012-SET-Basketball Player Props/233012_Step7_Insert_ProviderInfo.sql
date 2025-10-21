/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20250822@Louisa
	Task	  : INSERT provider DST [Redmine:#233012]
	DB		  : DBPRO/bodb02

	Revisions:
		20250822@Louisa: INSERT provider DST [Redmine:#233012]
*/

USE bodb02
GO

	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderInfo p WITH(NOLOCK)
					WHERE p.SourceId = 40
					)
	BEGIN
		INSERT INTO dbo.ProviderInfo ( SourceId, SourceName, isActive )
		SELECT 40,  'DST', 1
	END

