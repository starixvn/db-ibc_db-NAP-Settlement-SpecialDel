/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Update]
	@RequestId			INT
	,@SubIssueTypeId	SMALLINT		= NULL
	,@ActionId			TINYINT			= NULL
	,@MistakenBy		NVARCHAR(200)	= NULL
	,@CheckedBy			INT				= NULL
	,@DecidedBy			NVARCHAR(200)	= NULL
	,@Operators			XML				= NULL
	,@Provider			NVARCHAR(200)	= NULL
	,@Source			NVARCHAR(200)	= NULL
	,@Remark			NVARCHAR(MAX)	= NULL
	
	,@UserId			INT
	,@IP				VARCHAR(50)		= NULL
AS
/*	Created by: Kathy
	Date 20181212
	Task: update request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
		@Operator: Type: 1 - Trader
						 2 - Suspender
			Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

	SET @StartTime = GETDATE()
	SET @LogActionId = 90001
	SET @SB_Error = 0

	UPDATE	dbo.TicketVoiding_Request WITH(ROWLOCK, UPDLOCK)
		SET SubIssueTypeId = ISNULL(@SubIssueTypeId, SubIssueTypeId)
			,ActionId = ISNULL(@ActionId, ActionId)
			,Provider = ISNULL(@Provider, Provider)
			,Source = ISNULL(@Source, Source)
			,DecidedBy = ISNULL(@DecidedBy, DecidedBy)
			,MistakenBy = ISNULL(@MistakenBy, MistakenBy)
			,CheckedBy = ISNULL(@CheckedBy,CheckedBy)
			,Remark = ISNULL(@Remark, Remark)
	WHERE	RequestId = @RequestId

	IF @Operators IS NOT NULL
	BEGIN
		MERGE dbo.TicketVoiding_OperatorInfo AS TARGET
		USING (SELECT	T.C.value('@OperatorId', 'INT') AS OperatorId
						,T.C.value('@Type', 'TINYINT') AS OperatorTypeId
				FROM	@Operators.nodes('/r') AS T(C) 
		)AS SOURCE
			ON	TARGET.OperatorId = SOURCE.OperatorId
				AND TARGET.OperatorTypeId = SOURCE.OperatorTypeId
		WHEN NOT MATCHED BY TARGET THEN INSERT (RequestId, OperatorId, OperatorTypeId) VALUES (@RequestId, SOURCE.OperatorId, SOURCE.OperatorTypeId)
		WHEN NOT MATCHED BY SOURCE THEN DELETE;
	END

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ CASE WHEN @SubIssueTypeId IS NOT NULL THEN ' SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(30)) ELSE '' END
								+ CASE WHEN @ActionId IS NOT NULL THEN ' ActionId: ' + CAST(@ActionId AS VARCHAR(30)) ELSE '' END
								+ CASE WHEN @CheckedBy IS NOT NULL THEN ' CheckedBy: ' + CAST(@CheckedBy AS VARCHAR(30)) ELSE '' END
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO


