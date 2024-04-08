/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLog_3rdSel]
	@batch INT
AS
/*
	Created by: 20221011@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20220130@Louisa: Copy code from SiteDB1 to SiteDB3 [Redmineid:#181595]
		- 20240318@Kathy: Missing LogId [Redmine:#202516]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	SET @batch = ISNULL(@batch,0)

	DECLARE @LastLogId		BIGINT
			,@LastStatusId	TINYINT			
			,@LogId			BIGINT
			,@TransInfoJson VARBINARY(MAX)
			,@TableName		VARCHAR(128)
			,@MatchId		INT
			,@RowCount		INT = 0
			,@Action		VARCHAR(1)
			,@SettlementAction VARCHAR(20)
			,@TicketType	VARCHAR(1)
			,@EventTable	TINYINT
			
			,@procName		SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT = 0
			,@LogDate		DATETIME2
			,@maxLogId		BIGINT
	
	DECLARE @tmpInsertedLogIds TABLE ( LogId BIGINT )

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT	@LogId AS LogId
				,@TransInfoJson AS TransInfoJson
				,@TableName AS TableName
				,@MatchId AS MatchId
				,@Action AS Action
				,@SettlementAction AS SettlementAction
				,@TicketType AS TicketType	
				,@EventTable AS EventTable
		WHERE 1 = 0
		
		RETURN
	END
	
	SELECT TOP (1) @LastLogId = LogId 
			,@LastStatusId = StatusId		
	FROM	dbo.SiteDB_SettlementService_LastLog_3rd WITH(NOLOCK)
	ORDER BY LogId DESC

	SET @LastLogId = ISNULL(@LastLogId,0)
	
	IF @LastStatusId = 2 OR @LastLogId = 0 ---the last time is done successfully or the first time running 
	BEGIN
		SET @LogDate = DATEADD(MILLISECOND, -1000, SYSDATETIME())
		
		SELECT @maxLogId = MAX(t.LogId)
		FROM (
			SELECT	TOP (@batch) l.LogId
			FROM	dbo.SiteDB_SettlementService_CalculationLog_3rd l WITH(NOLOCK, INDEX = CIX_SiteDB_SettlementService_CalculationLog_3rd)
			WHERE	LogId > @LastLogId
				AND LogDate <= @LogDate
			ORDER BY LogId
		) t

		INSERT INTO dbo.SiteDB_SettlementService_LastLog_3rd(LogId,StatusId,Starttime)		
		OUTPUT INSERTED.LogId
		INTO @tmpInsertedLogIds (LogId)
		SELECT	l.LogId, 1, SYSDATETIME() AS Starttime
		FROM	dbo.SiteDB_SettlementService_CalculationLog_3rd l WITH(NOLOCK, INDEX = CIX_SiteDB_SettlementService_CalculationLog_3rd)
		WHERE	LogId > @LastLogId
			AND LogId <= @maxLogId
		ORDER BY LogId

		SELECT	l.LogId				
				,l.TransInfoJson
				,l.TableName
				,l.MatchId
				,l.Action
				,l.SettlementAction
				,l.TicketType
				,l.EventTable
		FROM	dbo.SiteDB_SettlementService_CalculationLog_3rd l WITH(NOLOCK,INDEX = CIX_SiteDB_SettlementService_CalculationLog_3rd)
			INNER JOIN @tmpInsertedLogIds tmp ON l.LogId = tmp.LogId
		ORDER BY LogId

	END
	ELSE
	BEGIN
		SELECT	@LogId AS LogId				
				,@TransInfoJson AS TransInfoJson
				,@TableName AS TableName
				,@MatchId AS MatchId
				,@Action AS Action
				,@SettlementAction AS SettlementAction
				,@TicketType AS TicketType
				,@EventTable AS EventTable
		WHERE 1 = 0
	END
END
GO

