/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20210113@Louisa
    Task:  Cleanup wrong data [Redmine:#153396]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210113@Louisa: Cleanup wrong data [Redmine:#153396]
*/


USE [bodb02]
GO
	DECLARE @batch INT = 1000

	 
	--STEP 1: Delete wrong data in range Active
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.ProviderExternalResultDetailOS  WITH(ROWLOCK, UPDLOCK)
		WHERE  ResourceId ='06'
			AND  MatchId IN (SELECT m.matchid FROM dbo.Match m WITH(NOLOCK) WHERE m.sporttype = 5 ) --Tennis

		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END


	--STEP 2: Delete wrong data in range 14
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.ProviderExternalResultDetailOS14  WITH(ROWLOCK, UPDLOCK)
		WHERE  ResourceId ='06'
			AND  MatchId IN (SELECT m.matchid FROM dbo.Match14 m WITH(NOLOCK) WHERE m.sporttype = 5 ) --Tennis

		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'
	END


GO

