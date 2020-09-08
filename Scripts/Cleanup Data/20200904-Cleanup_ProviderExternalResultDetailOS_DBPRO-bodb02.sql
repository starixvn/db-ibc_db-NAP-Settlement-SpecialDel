/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200904@Louisa
    Task: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200904@Louisa: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
	
	Param's Explanation: 
		
*/

USE [bodb02]
GO

	DECLARE @maxProviderExternalId INT 


	CREATE TABLE #Active( ProviderExternalId INT)

	INSERT INTO #Active (ProviderExternalId)
	SELECT  t.ProviderExternalId
	FROM ProviderExternalResultDetailOS t WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON t.MatchId = m.matchid

	SET @maxProviderExternalId  = (SELECT  MAX(ProviderExternalId) FROM #Active )

	DELETE
	FROM ProviderExternalResultDetailOS WITH(ROWLOCK, UPDLOCK)
	WHERE ProviderExternalId NOT IN (SELECT a.ProviderExternalId FROM #Active a)
	AND  ProviderExternalId <  @maxProviderExternalId

GO