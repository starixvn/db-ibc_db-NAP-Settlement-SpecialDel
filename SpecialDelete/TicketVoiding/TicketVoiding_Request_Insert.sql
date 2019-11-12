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

	,@RequestId			INT				= 0 OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: insert new request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191112@Max: AdnormalBet TVS [Redmine:#123691]
		
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
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms' AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

