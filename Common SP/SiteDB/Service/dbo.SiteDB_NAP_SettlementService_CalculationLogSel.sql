/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogSel]
	
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20220929@Louisa: check deployment flag [Redmine:#178765]
		- 20221010@Louisa: get log which is inserted 1 second before [Redmine:#178880]

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
			,@RowCount INT
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
		WHERE ISNULL(@RowCount,0) = 1
		
		RETURN
	END

	SELECT TOP (1) @LastLogId = LogId 
			,@LastStatusId = StatusId		
	FROM	dbo.SiteDB_SettlementService_LastLog WITH(NOLOCK)
	ORDER BY LogId DESC
	
	IF @LastStatusId = 2 
	BEGIN
		SELECT	TOP 1 @LogId = LogId
				,@TransInfo = TransInfo
				,@TableName = TableName
				,@MatchId = MatchId
				,@Action = Action
				,@SettlementAction = SettlementAction
				,@TicketType = TicketType
		FROM	dbo.SiteDB_SettlementService_CalculationLog WITH(NOLOCK)
		WHERE	LogId > @LastLogId
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