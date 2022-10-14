/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLog_3rdSel]
	
AS
/*
	Created by: 20221011@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @LastLogId BIGINT
			,@LastStatusId TINYINT			
			,@LogId BIGINT
			,@TransInfo XML
			,@TableName VARCHAR(128)
			,@MatchId INT
			,@RowCount INT = 0
			,@Action VARCHAR(1)
			,@SettlementAction VARCHAR(20)
			,@TicketType VARCHAR(1)
			,@procName SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting BIT = 0
	
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT	@LogId AS LogId
				,@TransInfo AS TransInfo
				,@TableName AS TableName
				,@MatchId AS MatchId
				,@Action AS Action
				,@SettlementAction AS SettlementAction
				,@TicketType AS TicketType
		WHERE 1 = 0
		
		RETURN
	END

	SELECT TOP (1) @LastLogId = LogId 
			,@LastStatusId = StatusId		
	FROM	dbo.SiteDB_SettlementService_LastLog_3rd WITH(NOLOCK)
	ORDER BY LogId DESC
	
	IF @LastStatusId = 2 OR @LastLogId IS NULL ---the last time is done successfully or the first time running 
	BEGIN
		SELECT	TOP 1 @LogId = LogId
				,@TransInfo = TransInfo
				,@TableName = TableName
				,@MatchId = MatchId
				,@Action = Action
				,@SettlementAction = SettlementAction
				,@TicketType = TicketType
		FROM	dbo.SiteDB_SettlementService_CalculationLog_3rd WITH(NOLOCK)
		WHERE	LogId > ISNULL(@LastLogId,0)
			AND DATEDIFF(SECOND, LogDate, GETDATE() ) >= 1
		ORDER BY LogId
		
		SET @RowCount = @@ROWCOUNT
	END

	SELECT	@LogId AS LogId
			,@TransInfo AS TransInfo
			,@TableName AS TableName
			,@MatchId AS MatchId
			,@Action AS Action
			,@SettlementAction AS SettlementAction
			,@TicketType AS TicketType
	WHERE @RowCount = 1
END
GO