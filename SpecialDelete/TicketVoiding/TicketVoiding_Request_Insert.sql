/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
	,@MatchId				INT			  = 0
	,@KickOffTime			DATETIME	  = NULL
	,@TransIds				VARCHAR(MAX)  = NULL
	,@FilterBy				TINYINT		  = NULL
	,@UserNames				NVARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)	  = NULL
	,@StatusIds				VARCHAR(50)	  = NULL
	,@FromDate				DATETIME	  = NULL
	,@ToDate				DATETIME	  = NULL
	,@MatchProcessXML		XML           = NULL
	,@MatchParlayProcessXML XML           = NULL
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
	,@IsVoidVIPMember		BIT			  = 0
	,@WrongScoreInfo		VARCHAR(MAX)  = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX)  = NULL
	,@RedCardInfo			VARCHAR(MAX)  = NULL
	,@WrongHDPInfo			VARCHAR(MAX)  = NULL
	,@Wrong1stHDPInfo		VARCHAR(MAX)  = NULL
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

	Param's explanation:	
		+ @Operator: Type: 1 - Trader
						 2 - Suspender
			Example: <r OperatorId="232093" Type="1" /><r OperatorId="5045342" Type="2" />

		+ @MatchProcessXML: <root><r MatchId="1" KeyID="1"/></root>
		+ @MatchParlayProcessXML: : <root><r MatchId="1" RefNo="1"/></root>
		+ @WrongScoreInfo: 
			<root><r RequestId="" MatchId="" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxSingleTransId="" MinMainParlayTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore="" LiveScores=""/></root>
		+ @DangerAcceptInfo:
			<root><r MatchId="" SubIssueTypeId="1" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxSingleTransId="" MinMainParlayTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMain=''1''" LiveScores="" FilterBy="1"/></root>
		+ @RedCardInfo:
			<root><r MatchId="" SubIssueTypeId="15" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxSingleTransId="" MinMainParlayTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMain=''1''" LiveScores="" FilterBy="1"/></root>
		+ @WrongHDPInfo, @Wrong1stHDPInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterFromBetId ="" FilterToBetId = "" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxSingleTransId="" MinMainParlayTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" FilterBy="" HomeFavorite ="" AwayFavorite ="" ActualMarket ="" SubIssueTypeId=""/></root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			NVARCHAR(MAX)
			,@SB_Error			BIT
			,@avaiableProcess	BIT
			,@TotalParlay		INT = 0
			,@ThreadHold		INT = 0-- over threadhold, the parlay process will be locked in systemsetting
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@Session			NVARCHAR(50) = CAST(NEWID() AS NVARCHAR(50))
	
	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@DangerAcceptedInfoXML	  XML = NULL
			,@RedCardInfoXML		  XML = NULL
			,@WrongHDPInfoXML		  XML = NULL	
			,@Wrong1stHDPInfoXML	  XML = NULL

	DECLARE @SingleCount			INT
		   ,@MainParlayCount		INT
		   ,@WrongScoreInfoXML		XML = NULL
		   ,@DangerAcceptedInfoXML	XML = NULL
		   ,@RedCardInfoXML			XML = NULL

	CREATE TABLE #tblMatchProcess(
		Matchid		  INT,
		KeyID		  TINYINT
	);
	CREATE TABLE #tblMatchParlayProcess (
		MatchId INT,
		RefNo	BIGINT
	);

	SET @StartTime = GETDATE()
	SET @LogActionId = 90000
	SET @SB_Error = 0

	INSERT INTO #tblMatchProcess (Matchid, KeyID)
	SELECT   T.C.value('@MatchId', 'INT') AS MatchId
			,T.C.value('@KeyID', 'INT') AS KeyID
	FROM @MatchProcessXML.nodes('/root/r') as [T](C)

	IF @MatchParlayProcessXML IS NOT NULL 
	BEGIN
		INSERT INTO #tblMatchParlayProcess (MatchId, RefNo)
		SELECT   T.C.value('@MatchId', 'INT') AS MatchId
				,T.C.value('@RefNo', 'BIGINT') AS RefNo
		FROM @MatchParlayProcessXML.nodes('/root/r') as [T](C)
		SET @TotalParlay = @@ROWCOUNT
	END

	EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

	/*Apply new way to lock parlay tickets - SportBook*/
	IF (@TotalParlay = 0 OR @TotalParlay <= @ThreadHold) AND @IssueTypeId <> 17 
	BEGIN
		IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @IsExistSingle = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright			= @isExistOutright
				,@isExistMG					= @isExistMG
				,@isExistFM					= @isExistFM
				,@isExistMatch				= @IsExistSingle
				,@isExistNG					= @isExistNG
				,@isExistVS					= @isExistVS
				,@isExistBB					= @isExistBB
				,@IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				,@isExistFM2				= @isExistFM2
				,@SPName					= @SPName
				,@avaiableProcess			= @avaiableProcess OUTPUT
				,@ErrCode					= @ErrCode OUTPUT
				,@ErrMsg					= @ErrMsg OUTPUT;

			IF (@ErrCode <> 0 OR @avaiableProcess = 0)
			BEGIN
				RETURN;
			END;
		END

		IF @TotalParlay > 0 
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= 1
				,@SPName				= @SPName
				,@Session				= @Session
				,@avaiableProcess 		= @avaiableProcess OUTPUT
				,@ErrCode				= @ErrCode OUTPUT
				,@ErrMsg				= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @IsExistSingle
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @IsReleased				= 1
				RETURN;	
			END
		END
	END
	ELSE IF @TotalParlay > @ThreadHold
	BEGIN
		IF @isExistParlay = 1 OR @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @IsExistSingle = 1 
			OR @isExistNG = 1 OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 
		BEGIN
			-- Check Lock Match
			EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					,@isExistOutright			= @isExistOutright
					,@isExistMG					= @isExistMG
					,@isExistFM					= @isExistFM
					,@isExistMatch				= @IsExistSingle
					,@isExistNG					= @isExistNG
					,@isExistVS					= @isExistVS
					,@isExistBB					= @isExistBB
					,@IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					,@isExistFM2				= @isExistFM2
					,@SPName					= @SPName
					,@avaiableProcess			= @avaiableProcess OUTPUT
					,@ErrCode					= @ErrCode OUTPUT
					,@ErrMsg					= @ErrMsg OUTPUT;

			IF (@ErrCode <> 0 OR @avaiableProcess = 0)
			BEGIN
				RETURN
			END
		END
	END
	IF @IssueTypeId IN (3) --WC
	BEGIN
		SET @WrongScoreInfoXML = CONVERT(xml, @WrongScoreInfo)
		SELECT @SingleCount = SUM(t.c.value('@SingleCount','INT'))
			  ,@MainParlayCount = SUM(t.c.value('@MainParlayCount','INT'))
		FROM @WrongScoreInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))
	END
	IF @IssueTypeId = 1
	BEGIN
		SET @DangerAcceptedInfoXML = CONVERT(xml, @DangerAcceptedInfo)
		SELECT @SingleCount = SUM(t.c.value('@SingleCount','INT'))
			  ,@MainParlayCount = SUM(t.c.value('@MainParlayCount','INT'))
		FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))
	END
	IF @IssueTypeId = 10 --Red Card
	BEGIN
		SET @RedCardInfoXML = CONVERT(xml, @RedCardInfo)
		SELECT @SingleCount = SUM(t.c.value('@SingleCount','INT'))
			  ,@MainParlayCount = SUM(t.c.value('@MainParlayCount','INT'))
		FROM @RedCardInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@RedCardInfoXML = NULL))	
	END
	IF @IssueTypeId = 4 --Wrong HDP
	BEGIN
		SET @WrongHDPInfoXML = CONVERT(xml, @WrongHDPInfo)
		SELECT @SingleCount = SUM(t.c.value('@SingleCount','INT'))
			  ,@MainParlayCount = SUM(t.c.value('@MainParlayCount','INT'))
		FROM @WrongHDPInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))
	END
	IF @IssueTypeId = 5 --Wrong 1st HDP
	BEGIN
		SET @Wrong1stHDPInfoXML = CONVERT(xml, @Wrong1stHDPInfo)
		SELECT @SingleCount = SUM(t.c.value('@SingleCount','INT'))
			  ,@MainParlayCount = SUM(t.c.value('@MainParlayCount','INT'))
		FROM @Wrong1stHDPInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@Wrong1stHDPInfoXML = NULL))	
	END
	INSERT INTO dbo.TicketVoiding_Request (Sporttype, ActionId, Provider, Source, DecidedBy, MistakenBy, Remark, UserId, LastModifiedBy, IsTest, IssueTypeId)
	SELECT @Sporttype, @ActionId, @Provider, @Source, @DecidedBy, @MistakenBy, @Remark, @UserId, @UserId, @IsTest, @IssueTypeId

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
				,@FilterBy = @FilterBy				
				,@SubIssueTypeId = @SubIssueTypeId	
				,@UserNames	= @UserNames				
				,@ProductIds = @ProductIds			
				,@StatusIds	= @StatusIds				
				,@FromDate = @FromDate				
				,@ToDate = @ToDate
				,@IsVoidVIPMember = @IsVoidVIPMember
				,@WrongScoreInfo = @WrongScoreInfo
				,@DangerAcceptedInfo = @DangerAcceptedInfo
				,@RedCardInfo = @RedCardInfo
				,@WrongHDPInfo = @WrongHDPInfo
				,@Wrong1stHDPInfo = @Wrong1stHDPInfo
	
	IF (@IssueTypeId IN(8,9,11,13,15,17) OR (@IssueTypeId IN (1,10,3,4,5) AND @SingleCount > 0))
	BEGIN
	EXEC dbo.TicketVoiding_RequestDetailTicket_Single_Insert
				@RequestId = @RequestId			
				,@MatchId = @MatchId			
				,@KickOffTime = @KickOffTime		
				,@IssueTypeId = @IssueTypeId		
				,@SubIssueTypeId = @SubIssueTypeId	
				,@TransIds = @TransIds			
				,@IsEditRequest	= 0		
				,@UserId = @UserId			
				,@IP = @IP				
				,@ActionId = @ActionId			
				,@FilterBy = @FilterBy			
				,@UserNames	= @UserNames			
				,@ProductIds = @ProductIds		
				,@StatusIds = @StatusIds			
				,@FromDate = @FromDate			
				,@ToDate = @ToDate
				,@WrongScoreInfo = @WrongScoreInfo
				,@DangerAcceptedInfo = @DangerAcceptedInfo
				,@RedCardInfo = @RedCardInfo
				,@WrongHDPInfo = @WrongHDPInfo
				,@Wrong1stHDPInfo = @Wrong1stHDPInfo
	END

	IF (@IssueTypeId IN (8,9) OR (@IssueTypeId IN (1,10,3,4,5) AND @MainParlayCount > 0))
	BEGIN
	EXEC dbo.TicketVoiding_RequestDetailTicket_SubParlay_Insert
				@RequestId = @RequestId		
				,@MatchId = @MatchId				
				,@KickOffTime = @KickOffTime			
				,@IssueTypeId = @IssueTypeId			
				,@SubIssueTypeId = @SubIssueTypeId		
				,@IsEditRequest	= 0			
				,@UserId = @UserId				
				,@IP = @IP					
				,@ActionId = @ActionId				
				,@WrongScoreInfo = @WrongScoreInfo
				,@DangerAcceptedInfo = @DangerAcceptedInfo
				,@RedCardInfo = @RedCardInfo
				,@WrongHDPInfo = @WrongHDPInfo
				,@Wrong1stHDPInfo = @Wrong1stHDPInfo
	END


	IF (@TotalParlay = 0 OR @TotalParlay <= @ThreadHold) AND @IssueTypeId <> 17 
	BEGIN
		IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @IsExistSingle = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 
		BEGIN
			------ releasing single process
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
				, @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @IsExistSingle
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @IsReleased				= 1
		END
		IF @TotalParlay > 0
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
				,@Session	= @Session
				,@IsReleased = 1
		END
	END
	ELSE IF @TotalParlay  > @ThreadHold
	BEGIN
		IF @isExistParlay = 1 OR @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @IsExistSingle = 1 
			OR @isExistNG = 1 OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1 
		BEGIN
			-- Release Match
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay 				= @isExistParlay
				,@isExistOutright			= @isExistOutright
				,@isExistMG					= @isExistMG
				,@isExistFM					= @isExistFM
				,@isExistMatch				= @IsExistSingle
				,@isExistNG					= @isExistNG
				,@isExistVS					= @isExistVS
				,@isExistBB					= @isExistBB
				,@IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				,@isExistFM2				= @isExistFM2
				,@IsReleased				= 1;
		END
	END	

	IF @Operators IS NOT NULL
	BEGIN
		INSERT INTO dbo.TicketVoiding_OperatorInfo (RequestId, OperatorId, OperatorTypeId)
		SELECT	@RequestId
				,T.C.value('@OperatorId', 'INT') AS OperatorId
				,T.C.value('@Type', 'TINYINT') AS OperatorTypeId
		FROM	@Operators.nodes('/r') AS T(C)
	END

	--For Auto Void Instant
	BEGIN
		UPDATE q SET q.StatusId = 0
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH (ROWLOCK, UPDLOCK)
		WHERE q.RequestId = @RequestId AND q.StatusId = 99
			AND [Action] <> 'MixParlay'
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
								+ CASE WHEN @IssueTypeId IN (1,3,8,9,10,15,4,5) OR (@IssueTypeId = 11 AND @FilterBy IS NULL) THEN ', MistakenBy: ' + CASE WHEN @MistakenBy IS NOT NULL THEN @MistakenBy ELSE 'NULL' END
															   ELSE '' END
								+ ', DecidedBy: ' + CASE WHEN @DecidedBy IS NOT NULL THEN @DecidedBy ELSE 'NULL' END
								+ CASE WHEN @IssueTypeId IN (1,3,8,9,10,15) OR (@IssueTypeId = 11 AND @FilterBy IS NULL)
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

	DROP TABLE #tblMatchProcess
	DROP TABLE #tblMatchParlayProcess
END
GO

