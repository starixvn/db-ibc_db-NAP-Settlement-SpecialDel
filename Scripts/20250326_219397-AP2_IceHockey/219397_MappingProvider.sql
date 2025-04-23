/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250326@Aries
	Task: Support AutoPayout2 for Ice Hockey [Redmine:#219397]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

--Ice-Hockey & SBO
IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 1 AND p.sporttype = 4 )
BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	SELECT 1, 0,  1, 1, 4
END		 

--Ice-Hockey & SofaScore
IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 31 AND p.sporttype = 4 )
BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	SELECT 31, 0,  2, 1, 4
END	


--Handball  & SBO
IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 1 AND p.sporttype = 24 )
BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	SELECT 1, 0,  1, 1, 24
END		 

--Handball  & SofaScore
IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 31 AND p.sporttype = 24 )
BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	SELECT 31, 0,  2, 1, 24
END	

