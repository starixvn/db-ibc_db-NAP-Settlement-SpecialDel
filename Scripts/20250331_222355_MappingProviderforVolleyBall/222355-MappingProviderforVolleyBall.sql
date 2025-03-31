/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250331@Hughie
	Task	  : map Provider SBO, LSports, BetConstruct, Sofascore to Beach Volleyball  [Redmine:#222355]
	DB		  : DBPRO/bodb02
	Revisions:
		20250331@Hughie: Mapping Provider [Redmine:#222355]
*/
USE bodb02
GO
BEGIN
	;WITH cte_Source AS
	(
		SELECT * FROM (VALUES (1),(25),(29),(31) )AS  T(SourceID)
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
		SELECT cte.SourceId
				,0 AS GameType
				,NULL Remark
				,1 As isActive
				,45 AS sporttype
				,cte.SourceID AS OrderNo
		FROM dbo.ProviderGameTypeMapping pgm WITH(NOLOCK)
		RIGHT JOIN cte_Source cte ON pgm.SourceId = cte.SourceID AND pgm.sporttype = 45
		WHERE pgm.PGId IS NULL
END
GO