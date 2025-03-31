/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250331@Hughie
	Task	  : map Provider SBO, LSports, BetConstruct, Sofascore to Beach Volleyball  [Redmine:#222355]
	DB		  : DBPRO/bodb02
	Revisions:
		20250331@Hughie: Rollback Mapping Provider [Redmine:#222355]
*/
USE bodb02
GO
BEGIN
		Update dbo.ProviderGameTypeMapping WITH (ROWLOCK,UPDLOCK)
		SET isActive = 0
		FROM dbo.ProviderGameTypeMapping pgm
		WHERE pgm.SourceId IN (1, 25, 29, 31) AND pgm.sporttype = 45
END
GO