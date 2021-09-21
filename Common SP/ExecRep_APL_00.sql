/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_APL_00]
AS
/*
	Creator:	20210920@Louisa
	Task:		Cleanup data in ResultDetail - [Redmine:#161455]
	Database:	DBPRO.bodb02
	
	Revisions:
		- 20210920@Louisa:	Cleanup data in ResultDetail - [Redmine:#161455]
		
	Developer's Notes:
		- @Example:			NULL		- Explaination [DEFAULT]
		
*/
BEGIN;
	
	DECLARE @batch INT = 1000
		,@minMatchId	INT		
		,@maxMatchId	INT		
		,@MaxProviderExternalId INT  
	
	IF OBJECT_ID('tempdb..#Active') IS NOT NULL
	DROP TABLE #Active
	
	CREATE TABLE #Active( Matchid INT)

	INSERT INTO #Active (Matchid)
	SELECT  m.Matchid
	FROM dbo.match m WITH(NOLOCK)

	SELECT @minMatchId = MIN(m.Matchid)
		 , @maxMatchId = MAX (matchid) 
	FROM #Active m

	SELECT @MaxProviderExternalId = MAX(ProviderExternalId) 
	FROM dbo.ProviderExternalResultDetailES r WITH(NOLOCK)
	WHERE r.MatchId < @minMatchId
	
	-----1.  Delete ResultDetail:  all data < range active
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.ResultDetail WITH(ROWLOCK, UPDLOCK)
		WHERE MatchId < @minMatchId 
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	---2.  Delete ResultDetail: junk data in range active
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
	
	---3. Delete ProviderExternalResultDetailES: all data < range active
	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch)
		FROM dbo.ProviderExternalResultDetailES WITH(ROWLOCK, UPDLOCK)
		WHERE ProviderExternalId <= @MaxProviderExternalId
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END		
	
	
END
GO
