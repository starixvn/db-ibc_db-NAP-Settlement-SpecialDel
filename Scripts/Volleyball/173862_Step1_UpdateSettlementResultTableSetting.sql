/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220629@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220629@Louisa: Apply SOP for Volleyball [Redmineid:#173862]

	Param's Explanation: 

*/

USE bodb02
GO

BEGIN
	SET NOCOUNT ON

	UPDATE SettlementResultTableSetting
	SET IsAppliedSOP = 1	
	WHERE Sporttype = 6

	IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping WITH(NOLOCK) WHERE sporttype = 6 AND SourceId = 1) --SBO
	BEGIN
		INSERT INTO ProviderGameTypeMapping ( SourceId, GameType, Remark, OrderNo,isActive,sporttype)
		SELECT 	1, 0, '',	1, 1,	6 
	END

	IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping WITH(NOLOCK) WHERE sporttype = 6 AND SourceId = 25) --L-Sports
	BEGIN
		INSERT INTO ProviderGameTypeMapping ( SourceId, GameType, Remark, OrderNo,isActive,sporttype)
		SELECT 	25, 0, '',	1, 2,	6 
	END

END
GO
