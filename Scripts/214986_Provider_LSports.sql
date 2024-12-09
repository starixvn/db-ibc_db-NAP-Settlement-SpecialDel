/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20241121@Louisa
	Task	  : map Provider Lsport to Basketball [Redmine:#214986]
	DB		  : DBPRO/bodb02

	Revisions:
		20241209@Louisa: Maping LSports to basketball [Redmine:#214986]
*/

USE bodb02
GO

BEGIN
	
	IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderGameTypeMapping p WITH(NOLOCK) WHERE p.SourceId = 25 AND p.sporttype = 2 )
	BEGIN
		INSERT INTO dbo.ProviderGameTypeMapping	(SourceId, GameType, OrderNo, isActive, sporttype)
		SELECT 25, 0,  25, 1, 2
	END		 

END
GO