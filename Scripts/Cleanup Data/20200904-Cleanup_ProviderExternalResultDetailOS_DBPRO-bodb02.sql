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

DECLARE @batch INT = 1000


CREATE TABLE #ActiveMatch( MatchID INT)

INSERT INTO #ActiveMatch
SELECT  m.MatchId
FROM dbo.match m WITH(NOLOCK)
WHERE m.eventdate >= '2020-08-31 00:00:00.000'
AND m.sporttype = 5 --TENNIS

WHILE (1=1)

BEGIN

	DELETE TOP(@batch) FROM r
	FROM dbo.ProviderExternalResultDetailOS r WITH(ROWLOCK, UPDLOCK)
	WHERE r.MatchId NOT IN ( SELECT am.MatchID FROM #ActiveMatch am )


	IF @@ROWCOUNT = 0
		BREAK			

	WAITFOR DELAY '00:00:00:280'

END
GO