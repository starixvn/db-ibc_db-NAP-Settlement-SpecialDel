/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250616@Aries
	Task: Provider » Volleyball » Add [31] Sofascore  [Redmine:#230650]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

--Volleyball   & SofaScore
IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 31 AND p.sporttype = 6 )
BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	SELECT 31, 0,  4, 1, 6
END	

