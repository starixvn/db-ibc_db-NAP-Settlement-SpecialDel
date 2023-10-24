/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20231012@Louisa
	Task	  : Update Provider TheSports from SourceID=31 to SourceID=32 [Redmine:#193975]
	DB		  : DBPRO/bodb02

	Revisions:
		20231012@Louisa: Update Provider TheSports from SourceID=31 to SourceID=32 [Redmine:#193975]
*/

USE bodb02
GO
	
	---1 row effected
	UPDATE dbo.ProviderInfo WITH(ROWLOCK,UPDLOCK)
	SET SourceId = 32
	WHERE SourceId = 31

	---1 row effected
	UPDATE dbo.ProviderGameTypeMapping WITH(ROWLOCK,UPDLOCK)
	SET SourceId = 32
	WHERE SourceId = 31

	