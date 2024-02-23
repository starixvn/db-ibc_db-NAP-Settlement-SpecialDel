/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20240206@Aries
    Task: Enhance the archive process for Settlement
    DB: DBTXN-bodb02

	 Revisions:
		- 20240206@Aries: Enhance the archive process for Settlement [Redmine:#200890]    
*/
USE bodb02
TRUNCATE TABLE [dbo].[BalancePendingProcessed]



/**********************************************************************************/
GO
DECLARE @Date DATETIME = DATEADD (DD, -14, GETDATE())

WHILE (1=1)
BEGIN
	DELETE TOP (1000)
	FROM dbo.Single_Calculate_Queue_3rd WITH(ROWLOCK, UPDLOCK)
	WHERE Starttime < @Date 
	AND IsCalculating NOT IN (0, 1)  

	IF @@ROWCOUNT < 1000
		BREAK

	WAITFOR DELAY '00:00:00.050' 
END


/**********************************************************************************/
GO
DECLARE  @Date		DATETIME = DATEADD (DD, -14, GETDATE())
		,@LogId		BIGINT = 0

SELECT	TOP 1 @LogId = SessionId 
FROM	dbo.Settlement_SettledSession WITH(NOLOCK)
WHERE	CreatedTime   < @Date
ORDER BY SessionId DESC

WHILE (1=1)
BEGIN
	DELETE	TOP (1000)
	FROM	dbo.Settlement_SettledSession WITH(ROWLOCK,UPDLOCK)
	WHERE	SessionId <= @LogId

	IF @@ROWCOUNT < 1000
		BREAK

	WAITFOR DELAY '00:00:00.050' 
END