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
	,@ActionId			VARCHAR(50) = NULL
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
		   ,@OldActionId	VARCHAR(50)
		   ,@OldMistakenBy	NVARCHAR(200)
		   ,@OldDecidedBy	NVARCHAR(200)
		   ,@OldProvider	NVARCHAR(200)
		   ,@OldSource		NVARCHAR(200)
		   ,@OldRemark		NVARCHAR(MAX)
		   ,@OldIsTest		BIT
	
	DECLARE @OperatorInfo AS TABLE (
		RemarkId		INT NOT NULL
	   ,OperatorId		INT NOT NULL
	   ,OperatorTypeId	TINYINT NOT NULL
	)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90507
	SET @SB_Error = 0

	SELECT @OldActionId		= ActionId
		  ,@OldMistakenBy	= MistakenBy
		  ,@OldDecidedBy	= DecidedBy
		  ,@OldProvider		= Provider
		  ,@OldSource		= Source
		  ,@OldRemark		= Remark
		  ,@OldIsTest		= IsTest
	FROM dbo.TicketVoiding_Remark WITH (NOLOCK)
	WHERE RemarkId = @RemarkId

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
	WHERE RemarkId = @RemarkId

	IF @Operators IS NOT NULL
	BEGIN
		INSERT INTO @OperatorInfo (RemarkId, OperatorId, OperatorTypeId)
		SELECT @RemarkId AS RemarkId
			  ,t.c.value('@OperatorId', 'INT') AS OperatorId
			  ,t.c.value('@Type', 'TINYINT') AS OperatorTypeId
		FROM @Operators.nodes('/r') AS t(c)

		DELETE O
		FROM TicketVoiding_OperatorInfo AS o WITH (NOLOCK)
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
	SET @LogData= CAST((
		SELECT @RemarkId AS '@RequestId'
			  ,@LogActionId AS '@LogActionId'
			  ,@UserId AS '@UserId'
			  ,@IP AS '@IP'
			  ,'Duration: ' + CAST(DATEDIFF(MILLISECOND,@StartTime,@EndTime) AS VARCHAR(50)) + ' ms' 
				+ CASE WHEN @ActionId IS NOT NULL AND (ISNULL(@ActionId, 0) <> ISNULL(@OldActionId, 0)) THEN ', Old ActionId: ' + CAST(@OldActionId AS VARCHAR(20)) + ' New ActionId: ' + CAST(@ActionId AS VARCHAR(20)) ELSE '' END
				+ CASE WHEN @MistakenBy IS NOT NULL AND (ISNULL(@MistakenBy, '') <> ISNULL(@OldMistakenBy, '')) THEN ', Old MistakenBy: ' + ISNULL(@OldMistakenBy, 'NULL') + ' New MistakenBy: ' + ISNULL(@MistakenBy, 'NULL') ELSE '' END
				+ CASE WHEN @DecidedBy IS NOT NULL AND ISNULL(@DecidedBy, '') <> ISNULL(@OldDecidedBy, '') THEN ', Old DecidedBy: ' + ISNULL(@OldDecidedBy, 'NULL') + ' New DecidedBy: ' + ISNULL(@DecidedBy, 'NULL') ELSE '' END
				+ CASE WHEN @Remark IS NOT NULL AND (ISNULL(@Remark, '') <> ISNULL(@OldRemark, '')) THEN ', Old Remark: ' + ISNULL(@OldRemark, 'NULL') + ' New Remark: ' + ISNULL(@Remark, 'NULL') ELSE '' END
				+ CASE WHEN @IsTest IS NOT NULL AND (ISNULL(@IsTest, 0) <> ISNULL(@OldIsTest, 0)) THEN ', Old IsTest: ' + CASE WHEN @OldIsTest = 1 THEN 'True' ELSE 'False' END + ' New IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END ELSE '' END
				AS '@LogData'
		FOR XML PATH ('r'), ROOT('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

