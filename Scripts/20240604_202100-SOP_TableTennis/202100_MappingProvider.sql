/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240603@Aries
	- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO


IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping WITH(NOLOCK) WHERE sporttype = 18 AND SourceId = 1) --SBO
BEGIN
	INSERT INTO ProviderGameTypeMapping ( SourceId, GameType, Remark, OrderNo,isActive,sporttype)
	SELECT 	1, 0, '',	1, 1,	18 
END


IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping WITH(NOLOCK) WHERE sporttype = 18 AND SourceId = 25) --LSports
BEGIN
	INSERT INTO ProviderGameTypeMapping ( SourceId, GameType, Remark, OrderNo,isActive,sporttype)
	SELECT 	25, 0, '',	2, 1,	18 
END



IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping WITH(NOLOCK) WHERE sporttype = 18 AND SourceId = 31) --SofaScore
BEGIN
	INSERT INTO ProviderGameTypeMapping ( SourceId, GameType, Remark, OrderNo,isActive,sporttype)
	SELECT 	31, 0, '',	3, 1,	18 
END


