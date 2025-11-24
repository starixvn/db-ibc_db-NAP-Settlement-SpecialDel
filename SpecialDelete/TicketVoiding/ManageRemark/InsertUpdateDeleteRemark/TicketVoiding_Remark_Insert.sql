/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Remark_Insert]
	 @RemarkId			INT = 0 OUTPUT
	,@MatchId			INT
	,@IsTest			BIT = NULL
	,@IsCheckedVar		BIT = NULL
	,@Operators			XML = NULL
	,@MistakenBy		NVARCHAR(200) = NULL
	,@DecidedBy			NVARCHAR(200) = NULL
	,@PerformedBy		NVARCHAR(200) = NULL
	,@Iptv 				NVARCHAR(200) = NULL
	,@Provider			NVARCHAR(200) = NULL
	,@Source			NVARCHAR(200) = NULL
	,@Remark			NVARCHAR(MAX) = NULL
	,@Message			NVARCHAR(MAX) = NULL
	,@Description		NVARCHAR(MAX) = NULL
	,@ActionId			TINYINT = NULL
	,@UserId			INT
	,@IP				VARCHAR(50) = NULL
AS
/*	
	Created by: 20251117@Lani
	Task: Add new remark [Redmine: #234937]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20251117@Lani: Add new remark [Redmine: #234937]
		
	Param's explanation:	
		- @Operator: Type: 1 - Trader
						   2 - Suspender
		  Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime		DATETIME
		   ,@EndTime		DATETIME
		   ,@LogActionId	INT
		   ,@LogData		NVARCHAR(MAX)
		   ,@SB_Error		BIT

	SET @StartTime = GETDATE()
	SET @LogActionId = 90506
	SET @SB_Error = 0

	INSERT INTO dbo.TicketVoiding_Remark (MatchId, IsTest, IsCheckedVar, MistakenBy, DecidedBy, PerformedBy, UserId, TV_IPTV, Provider, Source, Remark, Message, Description, ActionId, LastModifiedBy)
	SELECT @MatchId, @IsTest, @IsCheckedVar, @MistakenBy, @DecidedBy, @PerformedBy, @UserId, @Iptv, @Provider, @Source, @Remark, @Message, @Description, @ActionId, @UserId

	SET @RemarkId = SCOPE_IDENTITY()

	IF @Operators IS NOT NULL
	BEGIN
		INSERT INTO dbo.TicketVoiding_OperatorInfo(RemarkId, OperatorId, OperatorTypeId)
		SELECT @RemarkId
			  ,t.c.value('@OperatorId','INT') AS OperatorId
			  ,t.c.value('@Type','TINYINT') AS OperatorTypeId
		FROM @Operators.nodes('/r') AS t(c)
	END

	SET @EndTime = GETDATE()
	SET @LogData= CAST((
		SELECT @RemarkId AS '@RequestId'
			  ,@MatchId AS '@MatchId'
			  ,@LogActionId AS '@LogActionId'
			  ,@UserId AS '@UserId'
			  ,@IP AS '@IP'
			  ,'Duration: ' + CAST(DATEDIFF(MILLISECOND,@StartTime,@EndTime) AS VARCHAR(50)) + ' ms' 
				+ ', ActionId: ' + CAST(@ActionId AS VARCHAR(20))
				+ ', MistakenBy: ' + ISNULL(@MistakenBy,'')
				+ ', DecidedBy: ' + ISNULL(@DecidedBy,'')
				+ ', PerformedBy: ' + ISNULL(@PerformedBy, '')
				+ ', TV_IPTV: ' + ISNULL(@Iptv, '')
				+ ', Provider: ' + ISNULL(@Provider, '')
				+ ', Source: ' + ISNULL(@Source, '')
				+ ', Message: ' + ISNULL(@Message, '')
				+ ', Remark: ' + ISNULL(@Remark,'')
				+ ', Description: ' + ISNULL(@Description, '')
				+ ', IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END
				+ ', IsCheckedVar: ' + CASE WHEN @IsCheckedVar = 1 THEN 'True' ELSE 'False' END
				AS '@LogData'
		FOR XML PATH ('r'), ROOT('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

