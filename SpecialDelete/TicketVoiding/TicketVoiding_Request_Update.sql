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
	,@IsTest			BIT				= NULL
	,@SportType			INT				= NULL
AS
/*	Created by: Kathy
	Date 20181212
	Task: update request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20191218@Helen:  fix bug for TVS - [Redmine: 111541]
		- 20191220@Charles:  Fix write log when data is null [125828]
		
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
			,@LogDataContent	VARCHAR(MAX)
			,@SB_Error			BIT

			,@OldSportType		INT
			,@OldSubIssueTypeId SMALLINT
			,@OldActionId		TINYINT
			,@OldCheckedBy		INT
			,@OldMistakenBy		NVARCHAR(200)
			,@OldDecidedBy		NVARCHAR(200)
			,@OldProvider		NVARCHAR(200)
			,@OldSource			NVARCHAR(200)
			,@OldRemark			NVARCHAR(MAX)
			,@OldIsTest			BIT
	
	CREATE TABLE #OperatorInfo(
		[RequestId] [int] NOT NULL,
		[OperatorId] [int] NOT NULL,
		[OperatorTypeId] [tinyint] NOT NULL
	)
	SET @StartTime = GETDATE()
	SET @LogActionId = 90002
	SET @SB_Error = 0

	UPDATE	dbo.TicketVoiding_Request WITH(ROWLOCK, UPDLOCK)
		SET @OldActionId = ActionId
			,@OldSubIssueTypeId = SubIssueTypeId
			,@OldCheckedBy = CheckedBy
			,@OldSportType = Sporttype
			,@OldCheckedBy = CheckedBy
			,@OldMistakenBy = MistakenBy
			,@OldDecidedBy = DecidedBy
			,@OldProvider = Provider
			,@OldSource = Source
			,@OldRemark = Remark
			,@OldIsTest = IsTest

			,SubIssueTypeId = ISNULL(@SubIssueTypeId, SubIssueTypeId)
			,ActionId = ISNULL(@ActionId, ActionId)
			,Provider = ISNULL(@Provider, Provider)
			,Source = ISNULL(@Source, Source)
			,DecidedBy = ISNULL(@DecidedBy, DecidedBy)
			,MistakenBy = ISNULL(@MistakenBy, MistakenBy)
			-- @SubIssueTypeId IS NULL update @CheckBy
			,CheckedBy = CASE WHEN @SubIssueTypeId IS NULL THEN @CheckedBy ELSE CheckedBy END 
			,Remark = ISNULL(@Remark, Remark)
			,IsTest = ISNULL(@IsTest, IsTest)
			,Sporttype =  ISNULL(@SportType, Sporttype)
			,LastModifiedBy = ISNULL(@UserId, LastModifiedBy)
	WHERE	RequestId = @RequestId

	
	IF @Operators IS NOT NULL
	BEGIN
		INSERT INTO #OperatorInfo (RequestId, OperatorId,OperatorTypeId)
		SELECT	@RequestId AS RequestID
				,T.C.value('@OperatorId', 'INT') AS OperatorId
				,T.C.value('@Type', 'TINYINT') AS OperatorTypeId
		FROM	@Operators.nodes('/r') AS T(C) 
		
		DELETE oi
		FROM TicketVoiding_OperatorInfo oi WITH (ROWLOCK)
		WHERE oi.RequestId = @RequestID 
				AND NOT EXISTS (SELECT TOP (1) 1 FROM #OperatorInfo tv WITH (NOLOCK) 
								WHERE tv.RequestId = oi.RequestId AND tv.OperatorId = oi.OperatorId
									AND tv.OperatorTypeId = oi.OperatorTypeId)
								
		INSERT INTO TicketVoiding_OperatorInfo (RequestId, OperatorId,OperatorTypeId)
		SELECT oi.RequestId, OperatorId, OperatorTypeId
		FROM #OperatorInfo oi
		WHERE NOT EXISTS (SELECT TOP (1)1 FROM TicketVoiding_OperatorInfo tv WITH (NOLOCK) 
						  WHERE tv.RequestId = oi.RequestId AND tv.OperatorId = oi.OperatorId
								AND tv.OperatorTypeId = oi.OperatorTypeId)
				
	END

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ CASE WHEN ISNULL(@SportType, 0) <> ISNULL(@OldSportType,0) THEN ' Old SportType: ' + CAST(ISNULL(@OldSportType,0) AS VARCHAR(20)) + ' New SportType: ' + CAST(ISNULL(@SportType, 0) AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN ISNULL(@SubIssueTypeId, 0) <> ISNULL(@OldSubIssueTypeId, 0) THEN ', Old SubIssueTypeId: ' + CAST(ISNULL(@OldSubIssueTypeId, 0) AS VARCHAR(20)) + ' New SubIssueTypeId: ' + CAST(ISNULL(@SubIssueTypeId, 0) AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN ISNULL(@ActionId, 0) <> ISNULL(@OldActionId, 0) THEN ', Old ActionId: ' + CAST(ISNULL(@OldActionId, 0) AS VARCHAR(20)) + ' New ActionId: ' + CAST(ISNULL(@ActionId, 0) AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN ISNULL(@MistakenBy, '') <> ISNULL(@OldMistakenBy, '') THEN ', Old MistakenBy: ' + ISNULL(@OldMistakenBy, 'NULL') + ' New MistakenBy: ' + ISNULL(@MistakenBy, 'NULL') ELSE '' END
								+ CASE WHEN ISNULL(@DecidedBy, '') <> ISNULL(@OldDecidedBy, '') THEN ', Old DecidedBy: ' + ISNULL(@OldDecidedBy, 'NULL') + ' New DecidedBy: ' + ISNULL(@DecidedBy, 'NULL') ELSE '' END
								+ ', Operators: '+ CAST(@Operators AS VARCHAR(MAX))
								+ CASE WHEN ISNULL(@Provider, '') <> ISNULL(@OldProvider, '') THEN ', Old Provider: ' + ISNULL(@OldProvider, 'NULL') + ' New Provider: ' + ISNULL(@Provider, 'NULL') ELSE '' END
								+ CASE WHEN ISNULL(@Source, '') <> ISNULL(@OldSource, '') THEN ', Old Source: ' + ISNULL(@OldSource, 'NULL') + ' New Source: ' + ISNULL(@Source, 'NULL') ELSE '' END
								+ CASE WHEN ISNULL(@Remark, '') <> ISNULL(@OldRemark, '') THEN ', Old Remark: ' + ISNULL(@OldRemark, 'NULL') + ' New Remark: ' + ISNULL(@Remark, 'NULL') ELSE '' END
								+ CASE WHEN ISNULL(@IsTest, 0) <> ISNULL(@OldIsTest, 0) THEN ', Old IsTest: ' + CASE WHEN ISNULL(@OldIsTest, 0) = 1 THEN 'True' ELSE 'False' END + ' New IsTest: ' + CASE WHEN ISNULL(@IsTest, 0) = 1 THEN 'True' ELSE 'False' END ELSE '' END
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #OperatorInfo
	
END
GO


