/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Insert]
	@Sporttype				SMALLINT	  = NULL
	,@SubIssueTypeId		SMALLINT	  = NULL
	,@ActionId				TINYINT		  
	,@MistakenBy			NVARCHAR(200) = NULL
	,@DecidedBy				NVARCHAR(200) = NULL
	,@Operators				XML			  = NULL
	,@Provider				NVARCHAR(200) = NULL
	,@Source				NVARCHAR(200) = NULL
	,@Remark				NVARCHAR(MAX) = NULL
	,@UserId				INT			  
	,@IP					VARCHAR(50)	  = NULL
	,@IsTest				BIT			  = NULL
	,@IssueTypeId			TINYINT		  = NULL
	,@MatchId				INT			  = 0
	,@KickOffTime			DATETIME	  = NULL
	,@TransIds				VARCHAR(MAX)  = NULL
	,@FilterFromTransTime	DATETIME	  = NULL
	,@FilterToTransTime		DATETIME	  = NULL
	,@FilterFromBetId		BIGINT		  = NULL
	,@FilterToBetId			BIGINT		  = NULL
	,@FilterBy				TINYINT		  = 1
	,@SingleCount			INT			  = NULL
	,@MainParlayCount		INT			  = NULL
	,@MinSingleTransId		BIGINT		  = NULL
	,@MaxSingleTransId		BIGINT		  = NULL
	,@MinMainParlayTransId	BIGINT		  = NULL
	,@MaxMainParlayTransId	BIGINT		  = NULL
	,@VoidFromTime			DATETIME	  = NULL
	,@VoidToTime			DATETIME	  = NULL
	,@LiveScores			NVARCHAR(300) = NULL
	,@IsCheckedHomeTeam		BIT			  = NULL
	,@IsCheckedAwayTeam		BIT			  = NULL
	,@UserNames				NVARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)	  = NULL
	,@StatusIds				VARCHAR(50)	  = NULL
	,@FromDate				DATETIME	  = NULL
	,@ToDate				DATETIME	  = NULL
	,@MatchProcessXML		XML           = NULL
	,@IsExistSingle			BIT			  = 0
	,@IsExistParlay			BIT			  = 0
	,@IsExistFM				BIT			  = 0
	,@IsExistFM2			BIT			  = 0
	,@RequestId				INT			  = 0 OUTPUT
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
    ,@ErrCode				INT           = 0 OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: insert new request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191112@Max: AdnormalBet TVS [Redmine:#123691]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20201106@July: [TVS] - Abnormal Account + Check lock match before add request [Redmine: #143666]

	Param's explanation:	
		@Operator: Type: 1 - Trader
						 2 - Suspender
			Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />

		@MatchProcessXML: <root><r MatchId="1" KeyID="1" IsExistSingle="1" IsExistParlay="0" IsExistFM="0" IsExistFM2="0"/></root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@avaiableProcess	BIT
			
	CREATE TABLE #tblMatchProcess(
		Matchid		  INT,
		KeyID		  TINYINT
	);
	SET @StartTime = GETDATE()
	SET @LogActionId = 90000
	SET @SB_Error = 0

	INSERT INTO #tblMatchProcess (Matchid, KeyID)
	SELECT   T.C.value('@MatchId', 'INT') AS MatchId
			,T.C.value('@KeyID', 'INT') AS KeyID
	FROM @MatchProcessXML.nodes('/root/r') as [T](C)

	-- Check Lock Match
	EXEC dbo.NAP_Admin_CheckingProcess @isExistMatch = @IsExistSingle
			,@isExistParlay = @IsExistParlay
			,@IsExistFM = @IsExistFM
			,@IsExistFM2 = @IsExistFM2
			,@avaiableProcess = @avaiableProcess OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT;

	IF (@ErrCode <> 0 OR @avaiableProcess = 0)
	BEGIN
		RETURN;
	END;

	INSERT INTO dbo.TicketVoiding_Request (Sporttype, SubIssueTypeId, ActionId, Provider, Source, DecidedBy, MistakenBy, Remark, UserId, LastModifiedBy, IsTest, IssueTypeId)
	SELECT @Sporttype, @SubIssueTypeId, @ActionId, @Provider, @Source, @DecidedBy, @MistakenBy, @Remark, @UserId, @UserId, @IsTest, @IssueTypeId

	SET @RequestId = SCOPE_IDENTITY()

	EXEC dbo.TicketVoiding_RequestDetail_Insert 
				 @RequestId = @RequestId
				,@MatchId = @MatchId
				,@IssueTypeId = @IssueTypeId
				,@KickOffTime = @KickOffTime
				,@TransIds = @TransIds
				,@UserId = @UserId
				,@IP = @IP
				,@ActionId = @ActionId
				,@FilterFromTransTime = @FilterFromTransTime
				,@FilterToTransTime	= @FilterToTransTime
				,@FilterFromBetId = @FilterFromBetId		
				,@FilterToBetId	= @FilterToBetId			
				,@FilterBy = @FilterBy				
				,@SingleCount = @SingleCount			
				,@MainParlayCount = @MainParlayCount		
				,@MinSingleTransId = @MinSingleTransId		
				,@MaxSingleTransId = @MaxSingleTransId		
				,@MinMainParlayTransId = @MinMainParlayTransId	
				,@MaxMainParlayTransId = @MaxMainParlayTransId	
				,@VoidFromTime = @VoidFromTime			
				,@VoidToTime = @VoidToTime			
				,@LiveScores = @LiveScores			
				,@IsCheckedHomeTeam	= @IsCheckedHomeTeam		
				,@IsCheckedAwayTeam	= @IsCheckedAwayTeam		
				,@SubIssueTypeId = @SubIssueTypeId	
				,@UserNames	= @UserNames				
				,@ProductIds = @ProductIds			
				,@StatusIds	= @StatusIds				
				,@FromDate = @FromDate				
				,@ToDate = @ToDate
	
	IF (@IssueTypeId NOT IN (1,10) OR (@IssueTypeId IN (1,10) AND @SingleCount > 0))
	BEGIN
	EXEC dbo.TicketVoiding_RequestDetailTicket_Single_Insert
				@RequestId = @RequestId			
				,@MatchId = @MatchId			
				,@KickOffTime = @KickOffTime		
				,@IssueTypeId = @IssueTypeId		
				,@SubIssueTypeId = @SubIssueTypeId	
				,@MinSingleTransId = @MinSingleTransId	
				,@MaxSingleTransId = @MaxSingleTransId	
				,@TransIds = @TransIds			
				,@IsEditRequest	= 0		
				,@UserId = @UserId			
				,@IP = @IP				
				,@ActionId = @ActionId			
				,@FilterFromTransTime = @FilterFromTransTime
				,@FilterToTransTime = @FilterToTransTime	
				,@FilterBy = @FilterBy			
				,@UserNames	= @UserNames			
				,@ProductIds = @ProductIds		
				,@StatusIds = @StatusIds			
				,@FromDate = @FromDate			
				,@ToDate = @ToDate
	END

	IF (@IssueTypeId IN (8,9) OR (@IssueTypeId IN (1,10) AND @MainParlayCount > 0))
	BEGIN
	EXEC dbo.TicketVoiding_RequestDetailTicket_SubParlay_Insert
				@RequestId = @RequestId		
				,@MatchId = @MatchId				
				,@KickOffTime = @KickOffTime			
				,@IssueTypeId = @IssueTypeId			
				,@SubIssueTypeId = @SubIssueTypeId		
				,@MinMainParlayTransId = @MinMainParlayTransId	
				,@MaxMainParlayTransId = @MaxMainParlayTransId	
				,@IsEditRequest	= 0			
				,@UserId = @UserId				
				,@IP = @IP					
				,@ActionId = @ActionId				
				,@FilterFromTransTime = @FilterFromTransTime	
				,@FilterToTransTime	= @FilterToTransTime		
				,@FilterBy = @FilterBy				
	END

	-- Release Match
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = @IsExistSingle,
		@isExistParlay = @IsExistParlay,
		@IsExistFM = @IsExistFM,
		@IsExistFM2 = @IsExistFM2,
		@IsReleased = 1;		

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
								+ CASE WHEN @Sporttype IS NOT NULL THEN ' Sporttype: ' + CAST(@Sporttype AS VARCHAR(20)) ELSE '' END
								+ ', IssueTypeId: ' + CAST(@IssueTypeId AS VARCHAR(20))
								+ CASE WHEN @SubIssueTypeId IS NOT NULL THEN ', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20)) ELSE '' END
								+ ', ActionId: ' + CAST(@ActionId AS VARCHAR(20))
								+ CASE WHEN @IssueTypeId <> 13 THEN ', MistakenBy: ' + CASE WHEN @MistakenBy IS NOT NULL THEN @MistakenBy ELSE 'NULL' END
															   ELSE '' END
								+ ', DecidedBy: ' + CASE WHEN @DecidedBy IS NOT NULL THEN @DecidedBy ELSE 'NULL' END
								+ CASE WHEN @IssueTypeId <> 13 THEN ', Operators: '+ CAST(@Operators AS VARCHAR(MAX))
																  + ', Provider: ' + CASE WHEN @Provider IS NOT NULL THEN @Provider ELSE 'NULL' END
																  + ', Source: ' + CASE WHEN @Source IS NOT NULL THEN @Source ELSE 'NULL' END
															   ELSE '' END
								+ ', Remark: ' + CASE WHEN @Remark IS NOT NULL THEN @Remark ELSE 'NULL' END
								+ ', IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))


	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblMatchProcess
END
GO

