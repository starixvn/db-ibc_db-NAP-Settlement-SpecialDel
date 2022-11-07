/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_NAP_SettlementService_CalculationLogSel]
	@batch INT = 100
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20220929@Louisa: check deployment flag [Redmine:#178765]
		- 20221010@Louisa: get log which is inserted 1 second before [Redmine:#178880]
		- 20221025@Louisa: Use JSon log format for soccer [Redmine:#179449]
		- 20221101@Louisa: allow run parallell [Redmine#]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @LastLogId		BIGINT
			,@LastStatusId	TINYINT			
			,@LogId			BIGINT
			,@TransInfo		XML
			,@TransInfoJson VARBINARY(MAX)
			,@TableName		VARCHAR(128)
			,@MatchId		INT
			,@RowCount		INT = 0
			,@Action		VARCHAR(1)
			,@SettlementAction VARCHAR(20)
			,@TicketType	VARCHAR(1)
			,@SessionId		BIGINT
			,@IsParallel	BIT
			,@procName		SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT = 0
	
	DECLARE @tmpInsertedLogIds TABLE ( LogId BIGINT )

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT	@LogId AS LogId
				,@TransInfo AS TransInfo
				,@TransInfoJson AS TransInfoJson
				,@TableName AS TableName
				,@MatchId AS MatchId
				,@Action AS Action
				,@SettlementAction AS SettlementAction
				,@TicketType AS TicketType
				,@SessionId AS SessionId
				,@IsParallel AS IsParallel
		WHERE 1 = 0
		
		RETURN
	END

	SELECT TOP (1) @LastLogId = LogId 
			,@LastStatusId = StatusId		
	FROM	dbo.SiteDB_SettlementService_LastLog WITH(NOLOCK)
	ORDER BY LogId DESC
	
	IF @LastStatusId = 2 OR @LastLogId IS NULL ---the last time is done successfully or the first time running 
	BEGIN

		INSERT INTO dbo.SiteDB_SettlementService_LastLog(LogId,StatusId,Starttime)		
		OUTPUT INSERTED.LogId
		INTO @tmpInsertedLogIds (LogId)
		SELECT	TOP (@batch) l.LogId, 1, SYSDATETIME() AS Starttime
		FROM	dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
		WHERE	LogId > ISNULL(@LastLogId,0)
			AND DATEDIFF(SECOND, LogDate, GETDATE() ) >= 1
		ORDER BY LogId

		IF @@ROWCOUNT > 0

		SELECT	TOP (@batch) LogId
				,TransInfo
				,TransInfoJson
				,TableName
				,MatchId
				,Action
				,SettlementAction
				,TicketType
				,SessionId
				,IsParallel
		FROM	dbo.SiteDB_SettlementService_CalculationLog WITH(NOLOCK)
		WHERE	LogId > ISNULL(@LastLogId,0)
			AND DATEDIFF(SECOND, LogDate, GETDATE() ) >= 1
		ORDER BY LogId

	END
	ELSE
	BEGIN
		SELECT	@LogId AS LogId
				,@TransInfo AS TransInfo
				,@TransInfoJson AS TransInfoJson
				,@TableName AS TableName
				,@MatchId AS MatchId
				,@Action AS Action
				,@SettlementAction AS SettlementAction
				,@TicketType AS TicketType
				,@SessionId AS SessionId
				,@IsParallel AS IsParallel
		WHERE 1 = 0
	END
END
GO

--grant exec on SiteDB_NAP_SettlementService_CalculationLogSel_xtest to bodbAdminNet

---exec SiteDB_NAP_SettlementService_CalculationLogSel_xtest @batch  = 100
