/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Update]
	@RequestId				INT
	,@SubIssueTypeId		SMALLINT	  = NULL
	,@ActionId				TINYINT		  = NULL
	,@MistakenBy			NVARCHAR(200) = NULL
	,@CheckedBy				INT			  = NULL
	,@DecidedBy				NVARCHAR(200) = NULL
	,@Operators				XML			  = NULL
	,@Provider				NVARCHAR(200) = NULL
	,@Source				NVARCHAR(200) = NULL
	,@Remark				NVARCHAR(MAX) = NULL
	,@UserId				INT			  
	,@IP					VARCHAR(50)	  = NULL
	,@IsTest				BIT			  = NULL
	,@SportType				INT			  = NULL
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
	,@IsExistParlay			BIT			  = 0
	,@IsExistFM				BIT			  = 0
	,@IsExistFM2			BIT			  = 0
	,@IsExistSingle			BIT			  = 0
	,@IsExistMG				BIT           = 0
	,@IsExistParlayVSBetradar BIT         = 0
	,@IsExistOutright		BIT           = 0
	,@IsExistNG				BIT           = 0
	,@IsExistVS				BIT           = 0
	,@IsExistBB				BIT           = 0
	,@IsVoidVIPMember		BIT			  = NULL
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
    ,@ErrCode				INT           = 0 OUTPUT
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
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210301@July: TVS - Wrong parlay count when edited request [Redmine: #150887]
		
	Param's explanation:	
		@Operator: Type: 1 - Trader
						 2 - Suspender
			Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />
		@MatchProcessXML: <root><r MatchId="1" KeyID="1"/></root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
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
			,@avaiableProcess	BIT
			,@FailedTransIds	VARCHAR(MAX)  = NULL
			,@NegativeBalanceUsers  VARCHAR(MAX)  = ''
	
	CREATE TABLE #OperatorInfo(
		[RequestId] [int] NOT NULL,
		[OperatorId] [int] NOT NULL,
		[OperatorTypeId] [tinyint] NOT NULL
	)

	CREATE TABLE #tblMatchProcess(
		Matchid		  INT,
		KeyID		  TINYINT
	);

	SET @StartTime = GETDATE()
	SET @LogActionId = 90002
	SET @SB_Error = 0

	IF @IsExistSingle  <> 0 OR @IsExistParlay <> 0 OR @IsExistFM <> 0 OR @IsExistFM2 <> 0 OR @IsExistMG <> 0
		OR @IsExistParlayVSBetradar <> 0 OR @IsExistOutright <> 0 OR @IsExistNG <> 0 OR @IsExistVS <> 0 OR @IsExistBB <> 0
	BEGIN
		-- Check Lock Match
		INSERT INTO #tblMatchProcess (Matchid, KeyID)
		SELECT   T.C.value('@MatchId', 'INT') AS MatchId
				,T.C.value('@KeyID', 'INT') AS KeyID
		FROM @MatchProcessXML.nodes('/root/r') as [T](C) --T: table, C: column

		EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay 	= @isExistParlay
				,@isExistOutright = @isExistOutright
				,@isExistMG	= @isExistMG
				,@isExistFM	= @isExistFM
				,@isExistMatch = @IsExistSingle
				,@isExistNG	= @isExistNG
				,@isExistVS	= @isExistVS
				,@isExistBB	= @isExistBB
				,@IsExistParlayVSBetradar = @IsExistParlayVSBetradar
				,@isExistFM2 = @isExistFM2
				,@avaiableProcess = @avaiableProcess OUTPUT
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT;

		IF (@ErrCode <> 0 OR @avaiableProcess = 0)
		BEGIN
			RETURN;
		END;
	END

	UPDATE	dbo.TicketVoiding_Request WITH(ROWLOCK, UPDLOCK)
		SET @OldActionId = ActionId
			,@OldSubIssueTypeId = SubIssueTypeId
			,@OldCheckedBy = CheckedBy
			,@OldSportType = Sporttype
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

	EXEC dbo.TicketVoiding_RequestDetail_Update
			@RequestId = @RequestId
			,@MatchId = @MatchId				
			,@KickOffTime = @KickOffTime			
			,@UserId = @UserId				
			,@IP = @IP					
			,@TransIds = @TransIds 				
			,@ActionId = @ActionId				
			,@IssueTypeId = @IssueTypeId			
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
			,@IsConfirmCalculator = 0 
			,@UserNames	= @UserNames				
			,@ProductIds = @ProductIds			
			,@StatusIds	= @StatusIds				
			,@FromDate = @FromDate				
			,@ToDate = @ToDate				
			,@ErrMsg = @ErrMsg	OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@FailedTransIds = @FailedTransIds OUTPUT
			,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			;

	EXEC dbo.TicketVoiding_RequestDetailTicket_Single_Insert
			@RequestId = @RequestId			
			,@MatchId = @MatchId			
			,@KickOffTime = @KickOffTime		
			,@IssueTypeId = @IssueTypeId		
			,@SubIssueTypeId = @SubIssueTypeId	
			,@MinSingleTransId = @MinSingleTransId	
			,@MaxSingleTransId = @MaxSingleTransId	
			,@TransIds = @TransIds			
			,@IsEditRequest	= 1		
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
	
	IF @IssueTypeId IN (1,8,9,10)
	BEGIN
	EXEC dbo.TicketVoiding_RequestDetailTicket_SubParlay_Insert
			@RequestId = @RequestId		
			,@MatchId = @MatchId				
			,@KickOffTime = @KickOffTime			
			,@IssueTypeId = @IssueTypeId			
			,@SubIssueTypeId = @SubIssueTypeId		
			,@MinMainParlayTransId = @MinMainParlayTransId	
			,@MaxMainParlayTransId = @MaxMainParlayTransId	
			,@IsEditRequest	= 1		
			,@UserId = @UserId				
			,@IP = @IP					
			,@ActionId = @ActionId				
			,@FilterFromTransTime = @FilterFromTransTime	
			,@FilterToTransTime	= @FilterToTransTime		
			,@FilterBy = @FilterBy				
	END

	IF @IsExistSingle <> 0 OR @IsExistParlay <> 0 OR @IsExistFM <> 0 OR @IsExistFM2 <> 0 OR @IsExistMG <> 0
		OR @IsExistParlayVSBetradar <> 0 OR @IsExistOutright <> 0 OR @IsExistNG <> 0 OR @IsExistVS <> 0 OR @IsExistBB <> 0
	BEGIN
		-- Release Match
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay 	= @isExistParlay
			,@isExistOutright = @isExistOutright
			,@isExistMG	= @isExistMG
			,@isExistFM	= @isExistFM
			,@isExistMatch = @IsExistSingle
			,@isExistNG	= @isExistNG
			,@isExistVS	= @isExistVS
			,@isExistBB	= @isExistBB
			,@IsExistParlayVSBetradar = @IsExistParlayVSBetradar
			,@isExistFM2 = @isExistFM2
			,@IsReleased = 1;
	END	

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
								+ CASE WHEN @SportType IS NOT NULL AND (ISNULL(@SportType, 0) <> ISNULL(@OldSportType,0)) THEN ' Old SportType: ' + CAST(@OldSportType AS VARCHAR(20)) + ' New SportType: ' + CAST(@SportType AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN @SubIssueTypeId IS NOT NULL AND (ISNULL(@SubIssueTypeId, 0) <> ISNULL(@OldSubIssueTypeId, 0)) THEN ', Old SubIssueTypeId: ' + CAST(@OldSubIssueTypeId AS VARCHAR(20)) + ' New SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN @ActionId IS NOT NULL AND (ISNULL(@ActionId, 0) <> ISNULL(@OldActionId, 0)) THEN ', Old ActionId: ' + CAST(@OldActionId AS VARCHAR(20)) + ' New ActionId: ' + CAST(@ActionId AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN ISNULL(@CheckedBy, 0) <> ISNULL(@OldCheckedBy,0) THEN ' Old CheckedBy: ' + CASE WHEN @OldCheckedBy IS NULL THEN 'NULL' ELSE CAST(@OldCheckedBy AS VARCHAR(20)) END
								+ ' New CheckedBy: ' + CASE WHEN @CheckedBy IS NULL THEN 'NULL' ELSE CAST(@CheckedBy AS VARCHAR(20)) END ELSE '' END
								+ CASE WHEN @MistakenBy IS NOT NULL AND (ISNULL(@MistakenBy, '') <> ISNULL(@OldMistakenBy, '')) THEN ', Old MistakenBy: ' + ISNULL(@OldMistakenBy, 'NULL') + ' New MistakenBy: ' + ISNULL(@MistakenBy, 'NULL') ELSE '' END
								+ CASE WHEN @DecidedBy IS NOT NULL AND ISNULL(@DecidedBy, '') <> ISNULL(@OldDecidedBy, '') THEN ', Old DecidedBy: ' + ISNULL(@OldDecidedBy, 'NULL') + ' New DecidedBy: ' + ISNULL(@DecidedBy, 'NULL') ELSE '' END
								+ CASE WHEN @Operators IS NOT NULL THEN ', Operators: '+ CAST(@Operators AS VARCHAR(MAX)) ELSE '' END
								+ CASE WHEN @Provider IS NOT NULL AND (ISNULL(@Provider, '') <> ISNULL(@OldProvider, '')) THEN ', Old Provider: ' + ISNULL(@OldProvider, 'NULL') + ' New Provider: ' + ISNULL(@Provider, 'NULL') ELSE '' END
								+ CASE WHEN @Source IS NOT NULL AND (ISNULL(@Source, '') <> ISNULL(@OldSource, '')) THEN ', Old Source: ' + ISNULL(@OldSource, 'NULL') + ' New Source: ' + ISNULL(@Source, 'NULL') ELSE '' END
								+ CASE WHEN @Remark IS NOT NULL AND (ISNULL(@Remark, '') <> ISNULL(@OldRemark, '')) THEN ', Old Remark: ' + ISNULL(@OldRemark, 'NULL') + ' New Remark: ' + ISNULL(@Remark, 'NULL') ELSE '' END
								+ CASE WHEN @IsTest IS NOT NULL AND (ISNULL(@IsTest, 0) <> ISNULL(@OldIsTest, 0)) THEN ', Old IsTest: ' + CASE WHEN @OldIsTest = 1 THEN 'True' ELSE 'False' END + ' New IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END ELSE '' END
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #OperatorInfo
	DROP TABLE #tblMatchProcess
	
END
GO


