/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250509@Louisa
	Task	  : map Provider for ESports  [Redmine:#226653]
	DB		  : DBPRO/bodb02
	Revisions:
		20250509@Louisa: map Provider for ESports [Redmine:#226653]
*/
USE bodb02
GO

BEGIN
	;WITH cte_GameType AS
	(
		SELECT DISTINCT gametype 
		FROM ProviderGameTypeMapping p WITH(NOLOCK)
		WHERE sporttype = 43
		AND sourceid < 1001
	)

	INSERT INTO dbo.ProviderGameTypeMapping
	(
	SourceId
	,GameType
	,Remark
	,isActive
	,sporttype
	,OrderNo
	)
	SELECT 39 AS SourceID
			,cte.GameType
			,NULL Remark
			,1 As isActive
			,43 AS sporttype
			,39 AS OrderNo
	FROM cte_GameType cte
	LEFT JOIN dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
		ON pgm.SourceId = 39 
			AND pgm.sporttype = 43
			AND pgm.GameType = cte.GameType
	WHERE pgm.PGId IS NULL
END
GO