/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Insert]
	@Sporttype			SMALLINT
	,@SubIssueTypeId	SMALLINT
	,@ActionId			TINYINT
	,@MistakenBy		NVARCHAR(200)	= NULL
	,@DecidedBy			NVARCHAR(200)	= NULL
	,@Operators			XML				= NULL
	,@Provider			NVARCHAR(200)	= NULL
	,@Source			NVARCHAR(200)	= NULL
	,@Remark			NVARCHAR(MAX)	= NULL
	,@UserId			INT
	,@IP				VARCHAR(50)		= NULL
	,@IsTest			BIT				= NULL
	,@IssueTypeId		TINYINT			= NULL
	,@UserName			NVARCHAR(MAX)	= NULL
	,@Products			VARCHAR(50)		= NULL
	,@StatusIds			VARCHAR(50)		= NULL
	,@FromDate			DATETIME		= NULL
    ,@ToDate			DATETIME		= NULL
	,@RequestId			INT				= 0 OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: insert new request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191112@Max: AdnormalBet TVS [Redmine:#123691]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20201106@July: [TVS] - Abnormal Account  [Redmine: #143666]

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
	SET @LogActionId = 90000
	SET @SB_Error = 0

	INSERT INTO dbo.TicketVoiding_Request (Sporttype, SubIssueTypeId, ActionId, Provider, Source, DecidedBy, MistakenBy, Remark, UserId, LastModifiedBy, IsTest, IssueTypeId)
	SELECT @Sporttype, @SubIssueTypeId, @ActionId, @Provider, @Source, @DecidedBy, @MistakenBy, @Remark, @UserId, @UserId, @IsTest, @IssueTypeId


	SET @RequestId = SCOPE_IDENTITY()
	
	IF @Operators IS NOT NULL
	BEGIN
		INSERT INTO dbo.TicketVoiding_OperatorInfo (RequestId, OperatorId, OperatorTypeId)
		SELECT	@RequestId
				,T.C.value('@OperatorId', 'INT') AS OperatorId
				,T.C.value('@Type', 'TINYINT') AS OperatorTypeId
		FROM	@Operators.nodes('/r') AS T(C)
	END
	
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
							+ CASE WHEN @IssueTypeId = 13 THEN ' Username: ' + CAST(@Username AS VARCHAR(30))
															ELSE ' Sporttype: ' + CAST(@Sporttype AS VARCHAR(20)) END
								+ ', IssueTypeId: ' + CAST(@IssueTypeId AS VARCHAR(20))
								+ CASE WHEN @IssueTypeId <> 13 THEN ', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20)) ELSE '' END
								+ ', ActionId: ' + CAST(@ActionId AS VARCHAR(20))
								+ CASE WHEN @IssueTypeId = 13 THEN ', ProductId: '+ CAST(@Products AS VARCHAR(50))
																	+ ', TicketStatusId: '+ CAST(@StatusIds AS VARCHAR(50))
																	+ ', From Date:	'+ CAST(@FromDate AS VARCHAR(50))
																	+ ', To Date:	'+ CASE WHEN @ToDate IS NOT NULL THEN CAST(@ToDate AS VARCHAR(50)) ELSE 'NULL' END
															 ELSE '' END										
								+ ', DecidedBy: ' + CASE WHEN @DecidedBy IS NOT NULL THEN @DecidedBy ELSE 'NULL' END
								+ CASE WHEN @IssueTypeId <> 13 THEN ', MistakenBy: ' + CASE WHEN @MistakenBy IS NOT NULL THEN @MistakenBy ELSE 'NULL' END
																	+ ', Operators: '+ CAST(@Operators AS VARCHAR(MAX))
																	+ ', Provider: ' + CASE WHEN @Provider IS NOT NULL THEN @Provider ELSE 'NULL' END
																	+ ', Source: ' + CASE WHEN @Source IS NOT NULL THEN @Source ELSE 'NULL' END
																ELSE '' END
								+ ', Remark: ' + CASE WHEN @Remark IS NOT NULL THEN @Remark ELSE 'NULL' END
								+ ', IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

