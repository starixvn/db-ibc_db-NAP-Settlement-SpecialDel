/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200820@Louisa
    Task: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200820@Louisa: Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
	
	Param's Explanation: 
		
*/

USE [bodb02]
GO

DECLARE @batch INT = 1000


CREATE TABLE #OldResult( MatchID INT)

INSERT INTO #OldResult
SELECT DISTINCT o.MatchId
FROM dbo.ProviderExternalResultDetailOS o WITH(NOLOCK)
INNER JOIN 
	(
		SELECT matchid, eventdate, m.Sporttype
		FROM dbo.match m WITH(NOLOCK)
		UNION ALL
		SELECT  m14.matchid, m14.eventdate, m14.Sporttype
		FROM dbo.match14 m14 WITH(NOLOCK)
		UNION ALL
		SELECT mbk.matchid, mbk.eventdate, mbk.Sporttype
		FROM DB06.BODB_ARCHIVE.dbo.match_bk mbk WITH(NOLOCK)
	)m
	ON o.matchid = m.matchid
WHERE m.eventdate < '2020-08-31 00:00:00.000'
	AND m.sporttype = 5 --TENNIS


WHILE (1=1)

BEGIN

	DELETE TOP(@batch) FROM r
	FROM dbo.ProviderExternalResultDetailOS r 
	INNER JOIN #OldResult om 
		ON r.MatchID = om.MatchID


	IF @@ROWCOUNT = 0
		BREAK			

	WAITFOR DELAY '00:00:00:280'

END
GO
