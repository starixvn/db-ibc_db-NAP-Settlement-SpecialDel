/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220831@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220831@Louisa: mapping provider BetConstruct for SOP calculate [Redmineid:#173862]

	Param's Explanation: 

*/

USE bodb02
GO

BEGIN
IF NOT EXISTS (SELECT TOP 1 1 FROM ProviderGameTypeMapping WITH(NOLOCK) WHERE sporttype = 6 AND SourceId = 29) --BetConstruct
	BEGIN
		INSERT INTO ProviderGameTypeMapping ( SourceId, GameType, Remark, OrderNo,isActive,sporttype)
		SELECT 	29, 0, '',	3, 1,	6 
	END

END
GO
