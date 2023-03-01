/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLastLog_Sel
AS
/*
	Created:20221020@Louisa
    Task: Tool support hold sync log service  [RedmineId:#178694]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20221020@Louisa: Get info  [RedmineId:#178694]
		- 20230208@Louisa: support queue 3rd [RedmineId:#179505]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @LastLogId		BIGINT
			,@StatusId		TINYINT

	DECLARE @tmpLastLog TABLE (LastLogId BIGINT ,LastStatusId TINYINT ,WaitingCount INT, QueueType TINYINT)

	SELECT TOP 1 @LastLogId = ll.LogId
				,@StatusId = ll.StatusId
	FROM dbo.SiteDB_SettlementService_LastLog ll WITH(NOLOCK)
	ORDER BY ll.LogId DESC

	INSERT INTO @tmpLastLog (LastLogId ,LastStatusId ,WaitingCount, QueueType )
	SELECT @LastLogId, @StatusId, COUNT(l.LogID), 1
	FROM dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
	WHERE l.LogId > ISNULL(@LastLogId,0)

	SET @LastLogId = NULL
	SET @StatusId = NULL

	SELECT TOP 1 @LastLogId = ll.LogId
				,@StatusId = ll.StatusId
	FROM dbo.SiteDB_SettlementService_LastLog_3rd ll WITH(NOLOCK)
	ORDER BY ll.LogId DESC

	INSERT INTO @tmpLastLog (LastLogId ,LastStatusId ,WaitingCount, QueueType )
	SELECT @LastLogId	, @StatusId	, COUNT(l.LogID) , 3
	FROM dbo.SiteDB_SettlementService_CalculationLog_3rd l WITH(NOLOCK)
	WHERE l.LogId > ISNULL(@LastLogId,0)

	SELECT @@SERVERNAME AS ServerName, LastLogId, LastStatusId, WaitingCount, QueueType
	FROM @tmpLastLog

END
GO