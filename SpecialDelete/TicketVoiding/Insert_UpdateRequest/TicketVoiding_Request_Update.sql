/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Update]
(
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
	,@TransIds				VARCHAR(MAX)  = NULL
	,@FilterBy				TINYINT		  = NULL
	,@KickOffInfo			VARCHAR(MAX)  = NULL
	,@AbnormalAccountInfo	NVARCHAR(MAX) = NULL
	,@WrongScoreInfo		VARCHAR(MAX)  = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX)  = NULL
	,@RedCardInfo			VARCHAR(MAX)  = NULL
	,@WrongHDPInfo			VARCHAR(MAX)  = NULL
	,@Wrong1stHDPInfo		VARCHAR(MAX)  = NULL
	,@WrongOUInfo		    VARCHAR(MAX)  = NULL
	,@Wrong1stOUInfo		VARCHAR(MAX)  = NULL
	,@IsVoided				BIT			  = 0
	,@TransInfo				VARCHAR(MAX)  = NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: update request [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20191218@Helen:  fix bug for TVS - [Redmine: 111541]
		- 20191220@Charles:  Fix write log when data is null [125828]
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210301@July: TVS - Wrong parlay count when edited request [Redmine: #150887]
		- 20210302@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210318@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210412@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210420@July: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210506@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210524@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210622@Max: [TVS] Submit new allowance setting for Main Match [Redmine: #157226]
		- 20210803@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210817@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20210920@Max: TVS - Update other info of request after voided always loading [Redmine: #161852]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211213@July: TVS - Remove code [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220401@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
		- 20220610@July: TVS - Some minor enhancements  [Redmine: #173229]
		- 20220808@July: TVS - Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:	
		+ @Operator: Type: 1 - Trader
						   2 - Suspender
			Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />
		+ @MatchProcessXML: <root><r MatchId="1" KeyID="1"/></root>
		+ @MatchParlayProcessXML: : <root><r MatchId="1" RefNo="1"/></root>
		+ @WrongScoreInfo: 
			<root><r MatchId="" SubIssueTypeId="1" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore="" LiveScores=""/></root>
		+ @DangerAcceptInfo, @RedCardInfo:
			<root><r MatchId="" SubIssueTypeId="1" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMainMatch=''1''" LiveScores="" FilterBy="1"/></root>
		+ @WrongHDPInfo, @Wrong1stHDPInfo:
			<root><r MatchId="0" SubIssueTypeId="" FilterFromTransTime="1" FilterToTransTime ="" SingleCount="5" MainParlayCount="1" VoidFromTime="" VoidToTime="" FilterBy="" HomeFavorite ="" AwayFavorite ="" ActualMarket ="" HDPValue ="" IsMainMatch= "" /></root>
		+ @WrongOUInfo, @Wrong1stOUInfo:
			<root><r MatchId="0" SubIssueTypeId="" FilterFromTransTime="1" FilterToTransTime ="" SingleCount="5" MainParlayCount="1" VoidFromTime="" VoidToTime="" FilterBy="" WrongMarket ="" IsMainMatch =""/></root>
		+ @AbnormalAccountInfo:
			<root><r Usernames="" ProductIds="1" StatusIds ="" FromDate ="" ToDate = ""/></root>

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT
			,@OldSportType		INT
			,@OldActionId		TINYINT
			,@OldCheckedBy		INT
			,@OldMistakenBy		NVARCHAR(200)
			,@OldDecidedBy		NVARCHAR(200)
			,@OldProvider		NVARCHAR(200)
			,@OldSource			NVARCHAR(200)
			,@OldRemark			NVARCHAR(MAX)
			,@OldIsTest			BIT
			,@FailedTransIds	VARCHAR(MAX)  = NULL
			,@NegativeBalanceUsers  VARCHAR(MAX)  = ''
			,@IsEditRequest     INT = 1

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
			,@OldCheckedBy = CheckedBy
			,@OldSportType = Sporttype
			,@OldMistakenBy = MistakenBy
			,@OldDecidedBy = DecidedBy
			,@OldProvider = Provider
			,@OldSource = Source
			,@OldRemark = Remark
			,@OldIsTest = IsTest
			,ActionId = ISNULL(@ActionId, ActionId)
			,Provider = ISNULL(@Provider, Provider)
			,Source = ISNULL(@Source, Source)
			,DecidedBy = ISNULL(@DecidedBy, DecidedBy)
			,MistakenBy = ISNULL(@MistakenBy, MistakenBy)
			,CheckedBy = CASE WHEN @SubIssueTypeId IS NULL THEN @CheckedBy ELSE CheckedBy END 
			,Remark = ISNULL(@Remark, Remark)
			,IsTest = ISNULL(@IsTest, IsTest)
			,Sporttype =  ISNULL(@SportType, Sporttype)
			,LastModifiedBy = ISNULL(@UserId, LastModifiedBy)
			,LastModifiedDate = GETDATE()
	WHERE	RequestId = @RequestId
	
	IF @IsVoided = 0
	BEGIN
		IF @IssueTypeId IN (1)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_DARC_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@DARCInfo		 = @DangerAcceptedInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (3)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_WC_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@WrongScoreInfo = @WrongScoreInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest	
		END
		ELSE IF @IssueTypeId IN (4)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_HDP_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@WrongHDPInfo	 = @WrongHDPInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest	
		END
		ELSE IF @IssueTypeId IN (5)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_HDP_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@WrongHDPInfo	 = @Wrong1stHDPInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (6)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_OU_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@WrongOUInfo	 = @WrongOUInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (7)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_OU_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@WrongOUInfo	 = @Wrong1stOUInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (8,9)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_KO_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@SubIssueTypeId = @SubIssueTypeId
					,@KickOffInfo	 = @KickOffInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest	
		END
		ELSE IF @IssueTypeId IN (10)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_DARC_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@DARCInfo		 = @RedCardInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (11,15)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_AB_Update
					 @RequestId		 = @RequestId		
					,@MatchId		 = @MatchId		
					,@IssueTypeId	 = @IssueTypeId	
					,@TransIds		 = @TransIds		
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@ActionId		 = @ActionId		
					,@OldActionId	 = @OldActionId
					,@FilterBy		 = @FilterBy		
					,@SubIssueTypeId = @SubIssueTypeId
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (13) 
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_ACC_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@UserId		 = @UserId		
					,@IP			 = @IP		
					,@ActionId		 = @ActionId
					,@SubIssueTypeId = @SubIssueTypeId
					,@AbnormalAccountInfo = @AbnormalAccountInfo
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		ELSE IF @IssueTypeId IN (17)
		BEGIN
			EXEC dbo.TicketVoiding_RequestDetail_ARC_Update
					 @RequestId		 = @RequestId		
					,@IssueTypeId	 = @IssueTypeId	
					,@TransIds		 = @TransIds		
					,@UserId		 = @UserId		
					,@IP			 = @IP			
					,@FilterBy		 = @FilterBy		
					,@SubIssueTypeId = @SubIssueTypeId
					,@TransInfo		 = @TransInfo		
					,@IsEditRequest	 = @IsEditRequest
		END
		
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
								+ CASE WHEN @ActionId IS NOT NULL AND (ISNULL(@ActionId, 0) <> ISNULL(@OldActionId, 0)) THEN ', Old ActionId: ' + CAST(@OldActionId AS VARCHAR(20)) + ' New ActionId: ' + CAST(@ActionId AS VARCHAR(20)) ELSE '' END
								+ CASE WHEN ISNULL(@CheckedBy, 0) <> ISNULL(@OldCheckedBy,0) THEN ', Old CheckedBy: ' + CASE WHEN @OldCheckedBy IS NULL THEN 'NULL' ELSE CAST(@OldCheckedBy AS VARCHAR(20)) END
								+ ' New CheckedBy: ' + CASE WHEN @CheckedBy IS NULL THEN 'NULL' ELSE CAST(@CheckedBy AS VARCHAR(20)) END ELSE '' END
								+ CASE WHEN @MistakenBy IS NOT NULL AND (ISNULL(@MistakenBy, '') <> ISNULL(@OldMistakenBy, '')) THEN ', Old MistakenBy: ' + ISNULL(@OldMistakenBy, 'NULL') + ' New MistakenBy: ' + ISNULL(@MistakenBy, 'NULL') ELSE '' END
								+ CASE WHEN @DecidedBy IS NOT NULL AND ISNULL(@DecidedBy, '') <> ISNULL(@OldDecidedBy, '') THEN ', Old DecidedBy: ' + ISNULL(@OldDecidedBy, 'NULL') + ' New DecidedBy: ' + ISNULL(@DecidedBy, 'NULL') ELSE '' END
								+ CASE WHEN ISNULL(CAST(@Operators AS VARCHAR(MAX)),'') <> '' THEN ', Operators: '+ CAST(@Operators AS VARCHAR(MAX)) ELSE '' END
								+ CASE WHEN @Provider IS NOT NULL AND (ISNULL(@Provider, '') <> ISNULL(@OldProvider, '')) THEN ', Old Provider: ' + ISNULL(@OldProvider, 'NULL') + ' New Provider: ' + ISNULL(@Provider, 'NULL') ELSE '' END
								+ CASE WHEN @Source IS NOT NULL AND (ISNULL(@Source, '') <> ISNULL(@OldSource, '')) THEN ', Old Source: ' + ISNULL(@OldSource, 'NULL') + ' New Source: ' + ISNULL(@Source, 'NULL') ELSE '' END
								+ CASE WHEN @Remark IS NOT NULL AND (ISNULL(@Remark, '') <> ISNULL(@OldRemark, '')) THEN ', Old Remark: ' + ISNULL(@OldRemark, 'NULL') + ' New Remark: ' + ISNULL(@Remark, 'NULL') ELSE '' END
								+ CASE WHEN @IsTest IS NOT NULL AND (ISNULL(@IsTest, 0) <> ISNULL(@OldIsTest, 0)) THEN ', Old IsTest: ' + CASE WHEN @OldIsTest = 1 THEN 'True' ELSE 'False' END + ' New IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END ELSE '' END
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #OperatorInfo
	
END
GO


