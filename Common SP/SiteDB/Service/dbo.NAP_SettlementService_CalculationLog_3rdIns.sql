/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_CalculationLog_3rdIns]
	@SiteDBGroupId SMALLINT
	,@SiteDBCalculationLog_3rd TVP_SiteDB_CalculationLog READONLY
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
	
	DECLARE @TransInfoJson		VARBINARY(MAX)
			,@Action			VARCHAR(1)
			,@TableName			VARCHAR(128)
			,@MatchId			INT
			,@SettlementAction	VARCHAR(20)
			,@TicketType		VARCHAR(1)
			
			,@xmlCommand		VARCHAR(MAX)
			,@MessageType		VARCHAR(200)

			,@MaxLogId			BIGINT
			,@LogId				BIGINT
			,@CurrentLogId		BIGINT
			
			,@ErrCode INT
			,@ErrMsg VARCHAR(300)
	
			,@MessageTypePattern VARCHAR(200)

	SELECT	@MaxLogId = LogId
	FROM	@SiteDBCalculationLog_3rd

	IF @MaxLogId > 0 -- run commands in sequence
	BEGIN
		SET @LogId = 0
		SET @MessageType = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_bet_settle_msg_type_3rd'

		WHILE (1=1)
		BEGIN
			SELECT	TOP 1 @CurrentLogId = s.LogId
					,@TransInfoJson = s.TransInfoJson
					,@TableName = s.TableName
					,@MatchId = s.MatchId
					,@Action = s.Action
					,@SettlementAction = s.SettlementAction
					,@TicketType = s.TicketType	
				
			FROM	@SiteDBCalculationLog_3rd s
			WHERE	s.LogId > @LogId
					
			ORDER BY s.LogId

			IF @@ROWCOUNT = 0
				BREAK

			SET @xmlCommand = CAST((
					SELECT @TableName AS '@TableName'
							,@MatchId AS '@MatchId'
							,@Action AS '@Action'
							,@SettlementAction AS '@SettlementAction'
							,@TicketType AS '@TicketType'
							,@SiteDBGroupId AS '@SiteDBGroupId'		
							,CONVERT(nvarchar(max), @TransInfoJson, 1) AS '@TransInfoJson'	
					FOR XML PATH ('r'), ROOT ('root'), TYPE)
				AS VARCHAR(MAX))
				
			EXEC dbo.SSB_Send_Message 
				@MessageContent = @xmlCommand
				,@FunctionName = 'settlement'
				,@MessageType = @MessageType

			SET @LogId = @CurrentLogId

			INSERT INTO  dbo.SiteDB_SettlementService_CalculationLog_3rd_History (LogId, SiteDBGroupId, LogDate)
			SELECT @LogId, @SiteDBGroupId, SYSDATETIME()
		END
	END	
END