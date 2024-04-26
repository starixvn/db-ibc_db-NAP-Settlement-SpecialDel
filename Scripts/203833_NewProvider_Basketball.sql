/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20240407@Louisa
	Task	  : New Provider for Basketball [Redmine:#203833]
	DB		  : DBPRO/bodb02

	Revisions:
		20231027@Louisa: Initial data [Redmine:#203833]
*/

USE bodb02
GO

BEGIN
	SET NOCOUNT ON

	DROP TABLE IF EXISTS #tmpProviderBasketball
	CREATE TABLE #tmpProviderBasketball ( SourceId SMALLINT, SourceName VARCHAR(50) )

	INSERT INTO #tmpProviderBasketball (SourceId, SourceName)
	VALUES (10, 'RunningBall2'), (12,'RTS'), (13,'BetGenius')

	INSERT INTO dbo.ProviderInfo ( SourceId, SourceName,	isActive )
	SELECT tmp.SourceId, tmp.SourceName, 1
	FROM #tmpProviderBasketball tmp
	LEFT JOIN ProviderInfo p WITH(NOLOCK)
		ON tmp.SourceId = p.SourceId
	WHERE p.SourceId IS NULL

	INSERT INTO dbo.ProviderGameTypeMapping (SourceId,GameType,Remark,OrderNo,isActive,sporttype)
	SELECT tmp.SourceId, 0, NULL, tmp.SourceId, 1, 2
	FROM #tmpProviderBasketball tmp
	LEFT JOIN ProviderGameTypeMapping pgm WITH(NOLOCK)
		ON tmp.SourceId = pgm.SourceId AND pgm.sporttype = 2
	WHERE pgm.PGId IS NULL
END