/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20230424@Louisa
	Task	  : mapping BetConstruct for Badminton [Redmine:#187384]
	DB		  : DBPRO/bodb02

	Revisions:
		20230424@Louisa: mapping BetConstruct for Badminton [Redmine:#187384]
*/

USE bodb02
GO

BEGIN
 
	IF NOT EXISTS ( SELECT TOP 1 1 
					FROM dbo.ProviderGameTypeMapping pgm WITH(ROWLOCK)
					WHERE pgm.sporttype = 9 AND SourceId = 29
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
		SELECT 29, 0, '', 2, 1, 9
	END

END