/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Remark_Update]
	 @RemarkId			INT = 0
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
	Created by: 20251118@Lani
	Task: Update a remark [Redmine: #234937]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20251118@Lani: Update a remark [Redmine: #234937]
		
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
		   ,@LogDataContent NVARCHAR(MAX) = ''
	
	DECLARE @OperatorInfo AS TABLE (
		RemarkId		INT NOT NULL
	   ,OperatorId		INT NOT NULL
	   ,OperatorTypeId	TINYINT NOT NULL
	)

	DECLARE @LogDataInfo AS TABLE 
	(
		IsTest		 BIT
	   ,IsCheckedVar BIT
	   ,Operators	 NVARCHAR(200)
	   ,MistakenBy	 NVARCHAR(200)
	   ,DecidedBy	 NVARCHAR(200)
	   ,PerformedBy  NVARCHAR(200)
	   ,Iptv		 NVARCHAR(200)
	   ,Provider	 NVARCHAR(200)
	   ,Source		 NVARCHAR(200)
	   ,Remark		 NVARCHAR(MAX)
	   ,Message		 NVARCHAR(MAX)
	   ,Description  NVARCHAR(MAX)
	   ,ActionId	 TINYINT
	)
	SET @StartTime = GETDATE()
	SET @LogActionId = 90507
	SET @SB_Error = 0

	UPDATE dbo.TicketVoiding_Remark WITH (UPDLOCK, ROWLOCK)
	SET	IsTest			 = ISNULL(@IsTest,IsTest)
	   ,IsCheckedVar	 = ISNULL(@IsCheckedVar,IsCheckedVar)
	   ,MistakenBy		 = ISNULL(@MistakenBy, MistakenBy)
	   ,DecidedBy		 = ISNULL(@DecidedBy, DecidedBy)
	   ,PerformedBy		 = ISNULL(@PerformedBy, PerformedBy)
	   ,TV_IPTV			 = ISNULL(@Iptv, TV_IPTV)
	   ,Provider		 = ISNULL(@Provider, Provider)
	   ,Source			 = ISNULL(@Source, Source)
	   ,Remark			 = ISNULL(@Remark, Remark)
	   ,Message			 = ISNULL(@Message, Message)
	   ,Description		 = ISNULL(@Description, Description)
	   ,ActionId		 = ISNULL(@ActionId, ActionId)
	   ,LastModifiedBy	 = ISNULL(@UserId, LastModifiedBy)
	   ,LastModifiedDate = GETDATE()
	OUTPUT deleted.IsTest, deleted.IsCheckedVar, deleted.MistakenBy, deleted.DecidedBy, deleted.PerformedBy, deleted.TV_IPTV, deleted.Provider, deleted.Source, deleted.Remark, deleted.Message, deleted.Description, deleted.ActionId
	INTO @LogDataInfo (IsTest, IsCheckedVar, MistakenBy, DecidedBy, PerformedBy, Iptv, Provider, Source, Remark, Message, Description, ActionId)
	WHERE RemarkId = @RemarkId

	IF @Operators IS NOT NULL
	BEGIN
		INSERT INTO @OperatorInfo (RemarkId, OperatorId, OperatorTypeId)
		SELECT @RemarkId AS RemarkId
			  ,t.c.value('@OperatorId', 'INT') AS OperatorId
			  ,t.c.value('@Type', 'TINYINT') AS OperatorTypeId
		FROM @Operators.nodes('/r') AS t(c)

		DELETE o
		FROM TicketVoiding_OperatorInfo AS o
		WHERE o.RemarkId = @RemarkId 
			AND NOT EXISTS ( 
				SELECT TOP 1 1 
				FROM @OperatorInfo AS oi
				WHERE o.RemarkId = oi.RemarkId AND o.OperatorId = oi.OperatorId AND o.OperatorTypeId = oi.OperatorTypeId)
		
		INSERT INTO TicketVoiding_OperatorInfo (RemarkId, OperatorId, OperatorTypeId)
		SELECT o.RemarkId, o.OperatorId, o.OperatorTypeId
		FROM @OperatorInfo AS o
		WHERE NOT EXISTS (
				SELECT TOP 1 1 
				FROM TicketVoiding_OperatorInfo AS oi WITH (NOLOCK)
				WHERE oi.RemarkId = o.RemarkId AND oi.OperatorId = o.OperatorId AND oi.OperatorTypeId = o.OperatorTypeId)
	END

	--Write log
	SET @EndTime = GETDATE()

	SELECT @LogDataContent += CASE 
									WHEN @IsTest IS NOT NULL AND @IsTest <> IsTest THEN
										', Old IsTest: ' + CASE WHEN IsTest = 0 THEN 'False' ELSE 'True' END 
										+ ', New IsTest: ' + CASE WHEN @IsTest = 0 THEN 'False' ELSE 'True' END  
									ELSE '' 
							  END
						    + CASE 
									WHEN @IsCheckedVar IS NOT NULL AND @IsCheckedVar <> IsCheckedVar THEN 
										', Old IsCheckedVar: ' +  CASE WHEN IsCheckedVar = 0 THEN 'False' ELSE 'True' END 
										+ ', New IsCheckedVar: '  + CASE WHEN @IsCheckedVar = 0 THEN 'False' ELSE 'True' END
									ELSE ''
							  END
						    + CASE WHEN @MistakenBy IS NOT NULL AND @MistakenBy <> ISNULL(MistakenBy,'') THEN ', Old MistakenBy: ' +  ISNULL(MistakenBy,'NULL') + ', New MistakenBy: ' + @MistakenBy ELSE '' END
							+ CASE WHEN @DecidedBy IS NOT NULL AND @DecidedBy <> ISNULL(DecidedBy,'') THEN ', Old DecidedBy: ' + ISNULL(DecidedBy,'NULL') + ', New DecidedBy: ' + @DecidedBy ELSE '' END
						    + CASE WHEN @PerformedBy IS NOT NULL AND @PerformedBy <> ISNULL(PerformedBy,'') THEN ', Old PerformedBy: ' + ISNULL(PerformedBy,'NULL') + ', New PerformedBy: ' + @PerformedBy ELSE '' END
							+ CASE WHEN @Iptv IS NOT NULL AND @Iptv <> ISNULL(Iptv,'') THEN ', Old TV_IPTV: ' + ISNULL(Iptv,'NULL') + ', New TV_IPTVS: ' + @Iptv ELSE '' END
							+ CASE WHEN @Provider IS NOT NULL AND @Provider <> ISNULL(Provider,'') THEN ', Old Provider: ' + ISNULL(Provider,'NULL') + ', New Provider: ' + @Provider ELSE '' END
							+ CASE WHEN @Source IS NOT NULL AND @Source <> ISNULL(Source,'') THEN ', Old Source: ' +  ISNULL(Source,'NULL') + ', New Source: ' + Source ELSE '' END
						    + CASE WHEN @Remark IS NOT NULL AND @Remark <> ISNULL(Remark,'') THEN ', Old Remark: ' + ISNULL(Remark,'NULL') + ', New Remark: ' + Remark ELSE '' END
							+ CASE WHEN @Message IS NOT NULL AND @Message <> ISNULL(Message,'') THEN ', Old Message: ' + ISNULL(Message,'NULL') + ', New Message: ' + @Message ELSE '' END
							+ CASE WHEN @Description IS NOT NULL AND @Description <> ISNULL(Description,'') THEN ', Old Description: ' + ISNULL(Description,'NULL') + ', New Description' + @Description ELSE '' END
						    + CASE WHEN @ActionId IS NOT NULL AND @ActionId <> ActionId THEN ', Old ActionId: ' + CAST(ActionId AS VARCHAR(20)) + ', New ActionId: ' + CAST(@ActionId AS VARCHAR(20)) ELSE '' END
						   FROM @LogDataInfo

	SET @LogData= CAST((
		SELECT @RemarkId AS '@RequestId'
			  ,@LogActionId AS '@LogActionId'
			  ,@UserId AS '@UserId'
			  ,@IP AS '@IP'
			  ,'Duration: ' + CAST(DATEDIFF(MILLISECOND,@StartTime,@EndTime) AS VARCHAR(50)) + ' ms' + @LogDataContent AS '@LogData'
		FOR XML PATH ('r'), ROOT('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

