/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20210915@Louisa
    Task: Cleanup data in ResultDetail [Redmine:#161455]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200904@Louisa: Cleanup data in ResultDetail [Redmine:#161455]
	
	Param's Explanation: 
		
*/

USE [bodb02]
GO
	
	DECLARE @batch INT = 1000
			,@minMatchId	INT
			,@maxMatchId	INT
	
	IF OBJECT_ID('tempdb..#Active') IS not NULL
	DROP TABLE #Active
	
	CREATE TABLE #Active( Matchid INT)

	INSERT INTO #Active (Matchid)
	SELECT  m.Matchid
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.SettlementResultTableSetting ss WITH(NOLOCK)
			ON m.sporttype = ss.Sporttype OR m.sporttype = 1

	SELECT @minMatchId = MIN(m.Matchid)
		 , @maxMatchId = MAX (matchid) 
	FROM #Active m
	
	----- Delete junk data < range active
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.ResultDetail WITH(ROWLOCK, UPDLOCK)
		WHERE MatchId < @minMatchId 
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	--- delete junk data in range active
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.ResultDetail WITH(ROWLOCK, UPDLOCK)
		WHERE MatchId NOT IN (SELECT MatchId FROM #Active)
		AND MatchId <= @maxMatchId
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END
	
GO