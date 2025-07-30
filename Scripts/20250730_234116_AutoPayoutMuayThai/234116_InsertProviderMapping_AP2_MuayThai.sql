/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250730@Hughie
	Task: AutoPayout for MuayThai [Redmine:#234116]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

--MuayThai & SBO
IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 1 AND p.sporttype = 44 )
BEGIN
	INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
	SELECT 1, 0,  1, 1, 44
END		