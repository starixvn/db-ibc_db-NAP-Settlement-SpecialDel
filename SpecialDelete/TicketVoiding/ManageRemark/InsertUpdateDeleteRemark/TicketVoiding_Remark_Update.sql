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
	   ,Remark		 NVARCHAR(200)
	   ,Message		 NVARCHAR(200)
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

	SELECT @LogDataContent += ' IsTest: ' + CASE WHEN IsTest = 1 THEN 'True' ELSE 'False' END
						   + ', IsCheckedVar: ' +  CASE WHEN IsCheckedVar = 1 THEN 'True' ELSE 'False' END
						   + ', MistakenBy: ' + MistakenBy
						   + ', DecidedBy: ' + DecidedBy
						   + ', PerformedBy: ' +  PerformedBy
						   + ', TV_IPTV: ' + Iptv
						   + ', Provider: ' + Provider
						   + ', Source: ' + Source
						   + ', Remark: ' + Remark
						   + ', Message: ' +  Message
						   + ', Description: ' +  Description
						   + ', ActionId: ' + CAST(ActionId AS VARCHAR(20))
						   FROM @LogDataInfo

	SET @LogData= CAST((
		SELECT @RemarkId AS '@RequestId'
			  ,@LogActionId AS '@LogActionId'
			  ,@UserId AS '@UserId'
			  ,@IP AS '@IP'
			  ,'Duration: ' + CAST(DATEDIFF(MILLISECOND,@StartTime,@EndTime) AS VARCHAR(50)) + ' ms' + @LogDataContent
		FOR XML PATH ('r'), ROOT('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

