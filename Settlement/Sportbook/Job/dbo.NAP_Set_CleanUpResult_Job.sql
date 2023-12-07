/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_CleanUpResult_Job]  
AS
/* 
	Created:20200820@Louisa
    Task: Cleanup data in ProviderExternalResultDetailES [Redmine:#138656]
		  Cleanup data in ProviderExternalResultDetailOS [Redmine:#139627]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20200820@Louisa: Cleanup data ES
		- 20200903@Louisa: Cleanup data OS [Redmine:#139627]
		- 20201223@Louisa: Cleanup data for Other Sports [Redmine:#145651]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20210913@Louisa: Cleanup data ES if matchid not exists in table dbo.match[Redmine:##161455]
		- 20220512@Louisa: Cleanup data for AutoRefundResultOS [Redmine:#171676]
		- 20231120@louisa: Keep data in ProviderExternalResultDetailES/OS for report [Redmine:#197548]

	Param's Explanation: 

*/
BEGIN

	DECLARE @batch INT = 1000
	DECLARE @compareDate DATETIME
			,@DeletedateOS_ES DATETIME
	CREATE TABLE #tmpDataNotExits  ( ProviderExternalId INT)

	SET @compareDate =  CONVERT(VARCHAR(10),DATEADD (DAY, -7, GETDATE()), 102)
	SET @DeletedateOS_ES =  CONVERT(VARCHAR(10),DATEADD (DAY, -10, GETDATE()), 102)
	
	----- ESports
	INSERT INTO #tmpDataoNtExits(ProviderExternalId)
	SELECT es.ProviderExternalId
	FROM dbo.ProviderExternalResultDetailES es WITH(NOLOCK)
	WHERE es.CreateDate < @DeletedateOS_ES
	/*	LEFT JOIN dbo.match m WITH(NOLOCK)
			ON es.MatchId = m.matchid
	WHERE m.matchid IS NULL
		AND es.CreateDate < @compareDate
	*/

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailES WITH(ROWLOCK, UPDLOCK)
		WHERE ProviderExternalId IN ( SELECT ProviderExternalId FROM #tmpDataNotExits )
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'

	END

	----Tennis, Badminton
	TRUNCATE TABLE #tmpDataNotExits

	INSERT INTO #tmpDataNotExits (ProviderExternalId)
	SELECT ex.ProviderExternalId 
	FROM dbo.ProviderExternalResultDetailOS ex WITH(NOLOCK)
	WHERE ex.CreateDate < @DeletedateOS_ES
	/*	LEFT JOIN dbo.Match m WITH(NOLOCK)
			ON ex.MatchId = m.MatchId
	WHERE ( m.matchid IS NULL OR ISNULL(m.IsDeleted,0) = 1 )
		AND ex.CreateDate < @compareDate
	*/

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetailOS WITH(ROWLOCK, UPDLOCK)
		WHERE ProviderExternalId IN ( SELECT ProviderExternalId FROM #tmpDataNotExits )
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'
	END

	---- Other Sports (currently, apply for Basketball,Football,IceHockey,Volleyball,Baseball,TableTennis,Weightlifting,Handball,Darts)
	TRUNCATE TABLE #tmpDataNotExits
	
	INSERT INTO #tmpDataNotExits (ProviderExternalId)
	SELECT ex.ProviderExternalId 
	FROM dbo.ProviderExternalResultDetail ex WITH(NOLOCK)
		LEFT JOIN dbo.Match m WITH(NOLOCK)
			ON ex.MatchId = m.MatchId
	WHERE ( m.matchid IS NULL OR ISNULL(m.IsDeleted,0) = 1 )
		AND ex.CreateDate < @compareDate

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) FROM dbo.ProviderExternalResultDetail WITH(ROWLOCK, UPDLOCK)
		WHERE ProviderExternalId IN ( SELECT ProviderExternalId FROM #tmpDataNotExits )
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'
	END

	WHILE (1=1)
	BEGIN

		DELETE TOP(@batch) FROM dbo.AutoPayoutResultOS WITH(ROWLOCK, UPDLOCK)
		WHERE	 CreatedDate < DATEADD (DD, -14, GETDATE())
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP(@batch) FROM dbo.AutoRefundResultOS WITH(ROWLOCK, UPDLOCK)
		WHERE	 CreateDate < DATEADD (DD, -14, GETDATE())
	
		IF @@ROWCOUNT = 0
			BREAK			

		WAITFOR DELAY '00:00:00:280'
	END

END
GO