/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Insert]
	@Sporttype				SMALLINT	  = NULL
	,@SubIssueTypeId		SMALLINT	  = 0
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
	,@TransIds				VARCHAR(MAX)  = NULL
	,@FilterBy				TINYINT		  = NULL
	,@KickOffInfo			VARCHAR(MAX)  = NULL
	,@AbnormalAccountInfo	NVARCHAR(MAX)  = NULL
	,@WrongScoreInfo		VARCHAR(MAX)  = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX)  = NULL
	,@RedCardInfo			VARCHAR(MAX)  = NULL
	,@WrongHDPInfo			VARCHAR(MAX)  = NULL
	,@Wrong1stHDPInfo		VARCHAR(MAX)  = NULL
	,@WrongOUInfo		    VARCHAR(MAX)  = NULL
	,@Wrong1stOUInfo		VARCHAR(MAX)  = NULL
	,@WrongOddsInfo			VARCHAR(MAX)  = NULL
	,@ReducedOverInfo		VARCHAR(MAX)  = NULL
	,@NotParticipateInfo	VARCHAR(MAX)  = NULL
	,@DuplicateTicketsInfo	VARCHAR(MAX)  = NULL
	,@RecoverTicketInfo		VARCHAR(MAX) = NULL
	,@AbnormalBetInfo		VARCHAR(MAX) = NULL
	,@WrongMarketOfferedInfo	VARCHAR(MAX) = NULL
	,@TechnicalErrorInfo	VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX)  = NULL
	,@RequestId				INT			  = 0 OUTPUT
AS
/*	Created by: 20181212@Kathy
	Task: insert new request [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191112@Max: AdnormalBet TVS [Redmine:#123691]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20201106@July: [TVS] - Abnormal Account + Check lock match before add request [Redmine: #143666]
		- 20210219@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210318@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210420@July: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210528@Max: Fix bug insert ticket [Redmine: #155598]
		- 20210531@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210524@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210803@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210817@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211213@July: TVS - Remove code [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220401@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
	    - 20220610@July: TVS - Some minor enhancements  [Redmine: #173229]
		- 20220808@July: TVS - Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230612@July: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240422@Max: [TVS] Abnormal Bet - Add single tickets of many matches to a request [Redmine: #196027]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]

	Param's explanation:	
		+ @Operator: Type: 1 - Trader
						 2 - Suspender
			Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT
		    ,@IsEditRequest		INT = 0

	SET @StartTime = GETDATE()
	SET @LogActionId = 90000
	SET @SB_Error = 0
	INSERT INTO dbo.TicketVoiding_Request (Sporttype, ActionId, Provider, Source, DecidedBy, MistakenBy, Remark, UserId, LastModifiedBy, IsTest, IssueTypeId)
	SELECT @Sporttype, @ActionId, @Provider, @Source, @DecidedBy, @MistakenBy, @Remark, @UserId, @UserId, @IsTest, @IssueTypeId

	SET @RequestId = SCOPE_IDENTITY()

	IF @IssueTypeId IN (1)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_DARC_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@DARCInfo		 = @DangerAcceptedInfo
				,@TransInfoJson	 = @TransInfoJson		
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (2)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_WO_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@WrongOddsInfo	 = @WrongOddsInfo
				,@TransInfoJson	 = @TransInfoJson		
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
				,@TransInfoJson	 = @TransInfoJson		
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
				,@TransInfoJson	 = @TransInfoJson	
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
				,@TransInfoJson	 = @TransInfoJson			
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
				,@TransInfoJson	 = @TransInfoJson		
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
				,@TransInfoJson	 = @TransInfoJson		
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (8,9)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_KO_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@KickOffInfo	 = @KickOffInfo
				,@TransInfoJson	 = @TransInfoJson	
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
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (11)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_AB_Update
				 @RequestId		 = @RequestId			
				,@IssueTypeId	 = @IssueTypeId	
				,@AbnormalBetInfo = @AbnormalBetInfo	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@ActionId		 = @ActionId		
				,@TransInfoJson	 = @TransInfoJson		
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (12)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_WMO_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@WrongMarketOfferedInfo = @WrongMarketOfferedInfo
				,@TransInfoJson	 = @TransInfoJson			
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
				,@TransInfoJson	 = @TransInfoJson		
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
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (19,23) --Reduced Over, Abandoned
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_RO_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@ActionId		 = @ActionId		
				,@ReducedOverInfo = @ReducedOverInfo
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (20) --Duplicate Ticket
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_DT_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@ActionId		 = @ActionId		
				,@DuplicateTicketsInfo = @DuplicateTicketsInfo
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (21) --Not Participate (Use same SP with Reduced Over)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_RO_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@ActionId		 = @ActionId		
				,@ReducedOverInfo = @NotParticipateInfo
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (22) --Recover Ticket
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_RT_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@RecoverTicketInfo = @RecoverTicketInfo
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END
	ELSE IF @IssueTypeId IN (24)
	BEGIN
		EXEC dbo.TicketVoiding_RequestDetail_TE_Update
				 @RequestId		 = @RequestId		
				,@IssueTypeId	 = @IssueTypeId	
				,@UserId		 = @UserId		
				,@IP			 = @IP			
				,@TechnicalErrorInfo = @TechnicalErrorInfo
				,@TransInfoJson	 = @TransInfoJson			
				,@IsEditRequest	 = @IsEditRequest
	END

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
								+ ', Sporttype: ' + CAST(@Sporttype AS VARCHAR(20))
								+ ', IssueTypeId: ' + CAST(@IssueTypeId AS VARCHAR(20))
								+ ', ActionId: ' + CAST(@ActionId AS VARCHAR(20))
								+ CASE WHEN @IssueTypeId IN (1,2,3,8,9,10,4,5,6,7,19,23) THEN ', MistakenBy: ' + CASE WHEN @MistakenBy IS NOT NULL THEN @MistakenBy ELSE 'NULL' END
															   ELSE '' END
								+ ', DecidedBy: ' + CASE WHEN @DecidedBy IS NOT NULL THEN @DecidedBy ELSE 'NULL' END
								+ CASE WHEN @IssueTypeId IN (1,2,3,8,9,10)
															   THEN ', Operators: '+ CAST(@Operators AS VARCHAR(MAX))
																  + ', Provider: ' + CASE WHEN @Provider IS NOT NULL THEN @Provider ELSE 'NULL' END
																  + ', Source: ' + CASE WHEN @Source IS NOT NULL THEN @Source ELSE 'NULL' END
															   ELSE '' END
								+ ', Remark: ' + CASE WHEN @Remark IS NOT NULL THEN @Remark ELSE 'NULL' END
								+ ', IsTest: ' + CASE WHEN @IsTest = 1 THEN 'True' ELSE 'False' END
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))


	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

END
GO

