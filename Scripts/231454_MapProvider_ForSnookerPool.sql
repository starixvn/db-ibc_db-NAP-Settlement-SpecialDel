/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20250625@Louisa
	Task	  : Map SBO & LSports to Snooker/Pool  [Redmine:#231454]
	DB		  : DBPRO/bodb02

	Revisions:
		20250625@Louisa: Map SBO & LSports to Snooker/Pool  [Redmine:#231454]
*/

USE bodb02
GO

BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping
				(
				SourceId
				,GameType 
				,OrderNo
				,isActive
				,sporttype
				)
	VALUES   (1,  0, 1,  1, 7) --SBO
			,(25, 0, 25, 1, 7) --LSport
END
 