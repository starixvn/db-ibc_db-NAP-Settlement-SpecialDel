/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_CalculationLogIns]
	@SiteDBGroupId SMALLINT
	,@SiteDBCalculationLog TVP_SiteDB_CalculationLog READONLY
AS
/*
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @TransInfo			XML
			,@Action			VARCHAR(1)
			,@TableName			VARCHAR(128)
			,@MatchId			INT
			,@SettlementAction	VARCHAR(20)
			,@TicketType		VARCHAR(1)
			,@SessionId			BIGINT

			,@xmlCommand		VARCHAR(MAX)
			,@MessageType		VARCHAR(200)

			,@IsExistsParallel	BIT
			,@MaxLogId			BIGINT
			,@LogId				BIGINT
			,@CurrentLogId		BIGINT
			
			,@ErrCode INT
			,@ErrMsg VARCHAR(300)
	
			,@SiteDB_RunExecDataBySSB BIT
			,@SiteDB_ExecDataQueueSize SMALLINT
			,@MessageTypePattern VARCHAR(200)

	EXEC dbo.NAP_Set_GlobalSettingSel	
			@LockName = 'SiteDB_SettlementSSB'
			,@SiteDB_RunExecDataBySSB =  @SiteDB_RunExecDataBySSB OUTPUT
			,@SiteDB_ExecDataQueueSize = @SiteDB_ExecDataQueueSize OUTPUT

	SELECT	@MaxLogId = MAX(CASE WHEN ISNULL(IsParallel,0) = 1 THEN 0 ELSE LogId END)
			,@IsExistsParallel = MAX(CASE WHEN ISNULL(IsParallel,0) = 1 THEN 1 ELSE 0 END)
	FROM	@SiteDBCalculationLog

	IF @IsExistsParallel = 1 -- run commands in parallel
	BEGIN
		SET @MessageTypePattern = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_bet_settle_msg_type_0'

		INSERT INTO dbo.SiteDB_SettlementProcessing(SiteDBGroupId, SessionId, MessageType, TransInfo, SettlementAction, TicketType)
		SELECT	@SiteDBGroupId
				,s.SessionId
				,@MessageTypePattern + CAST(s.LogId%@SiteDB_ExecDataQueueSize + CASE WHEN s.LogId%@SiteDB_ExecDataQueueSize = 0 THEN @SiteDB_ExecDataQueueSize ELSE 0 END AS VARCHAR)
				,s.TransInfoJson
				,s.SettlementAction
				,s.TicketType
		FROM	@SiteDBCalculationLog s
		WHERE	s.IsParallel = 1
		ORDER BY s.LogId
	END
	
	IF @MaxLogId > 0 -- run commands in sequence
	BEGIN
		SET @LogId = 0
		SET @MessageType = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_bet_settle_msg_type'

		WHILE (1=1)
		BEGIN
			SELECT	TOP 1 @CurrentLogId = s.LogId
					,@TransInfo = s.TransInfo
					,@TableName = s.TableName
					,@MatchId = s.MatchId
					,@Action = s.Action
					,@SettlementAction = s.SettlementAction
					,@TicketType = s.TicketType	
					,@SessionId = s.SessionId
			FROM	@SiteDBCalculationLog s
			WHERE	s.LogId > @LogId
					AND s.IsParallel = 0
			ORDER BY s.LogId

			IF @@ROWCOUNT = 0
				BREAK

			SET @xmlCommand = CAST((
					SELECT CAST(@TransInfo AS VARCHAR(MAX)) AS '@TransInfo'	
							,@TableName AS '@TableName'
							,@MatchId AS '@MatchId'
							,@Action AS '@Action'
							,@SettlementAction AS '@SettlementAction'
							,@TicketType AS '@TicketType'
							,@SiteDBGroupId AS '@SiteDBGroupId'
							,@SessionId AS '@SessionId'
							,@SiteDB_ExecDataQueueSize AS '@TotalQueue'
					FOR XML PATH ('r'), ROOT ('root'), TYPE)
				AS VARCHAR(MAX))
				
			EXEC dbo.SSB_Send_Message 
				@MessageContent = @xmlCommand
				,@FunctionName = 'settlement'
				,@MessageType = @MessageType

			SET @LogId = @CurrentLogId
		END
	END	
END