/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Update]
(
	@RequestId				INT
	,@MatchId				INT = 0
	,@KickOffTime			DATETIME = NULL
	,@UserId				INT
	,@IP					VARCHAR(50) = NULL
	,@TransIds 				VARCHAR(MAX) = NULL
	,@ActionId				TINYINT
	,@IssueTypeId			TINYINT
	,@FilterFromTransTime	DATETIME = NULL
	,@FilterToTransTime		DATETIME = NULL
	,@FilterBy				TINYINT = NULL
	,@SingleCount			INT = NULL
	,@MainParlayCount		INT = NULL
	,@MinSingleTransId		BIGINT = NULL
	,@MaxSingleTransId		BIGINT = NULL
	,@MinMainParlayTransId	BIGINT = NULL
	,@MaxMainParlayTransId	BIGINT = NULL
	,@VoidFromTime			DATETIME = NULL
	,@VoidToTime			DATETIME = NULL
	,@LiveScores			NVARCHAR(300) = NULL
	,@SubIssueTypeId		TINYINT = NULL
	,@IsConfirmCalculator   BIT = 0
	,@UserNames				VARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)  = NULL
	,@StatusIds				VARCHAR(50)  = NULL
	,@FromDate				DATETIME     = NULL
    ,@ToDate				DATETIME     = NULL
	,@IsVoidVIPMember		BIT = 0
	,@TypeAccept			VARCHAR(MAX) = NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX) = NULL
	,@RedCardInfo			VARCHAR(MAX) = NULL
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
    ,@ErrCode				INT           = 0  OUTPUT
	,@FailedTransIds		VARCHAR(MAX) = NULL	OUTPUT
	,@NegativeBalanceUsers  VARCHAR(MAX) = ''	OUTPUT
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: update request detail [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191111@Max: Ticket Voiding System - Abnormal Bet Issue Type [Redmine: #111541]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20200216@Max: Abnormal Void Bets Automation [Redmine: #128359]
		- 20200228@Max: Auto Void Winning Bets [Redmine: #129184]
		- 20200312@Max: Hotfix - Confirm Auto Unmark not work for Early Settlement Bettype - [Redmine: #130279]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200403@Raymond: Auto void for Tennis [Redmind: #131516]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis + hotfix [Redmine:#131516]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200609@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201106@July: [TVS] - Abnormal Account + Check lock match before add request [Redmine: #143666]
		- 20210222@July: Hotfix - AC Duplicated customer getting of add request validation [Redmine: #150382]
		- 20210224@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075] 
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210401@July: TVS - Abnormal Bet - Auto void before KO time - [Redmine: #150522]
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20210402@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210413@Max: [TVS] SP tuning for EC20 - P1 [Redmine: #152817]
		- 20210427@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210524@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210621@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210714@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210802@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20210820@July: TVS - Add new status Void Instant without any policy [Redmine: #160012]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]

	Param's explanation:
		+ @WrongScoreInfo: 
		<root>
			<r RequestId="" MatchId="" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore="" LiveScores=""/>
		</root>
		+ @DangerAcceptInfo:
			<root>
				<r MatchId="" SubIssueTypeId="1" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMain=''1''" LiveScores="" FilterBy="1"/>
			</root>
		+ @RedCardInfo:
			<root>
				<r MatchId="" SubIssueTypeId="15" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMain=''1''" LiveScores="" FilterBy="1"/>
			</root>
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime				 DATETIME
			,@EndTime				 DATETIME
			,@LogActionId			 INT
			,@LogData				 VARCHAR(MAX)
			,@LogDataContent		 VARCHAR(MAX)
			,@SB_Error				 BIT
			,@OldKickOffTime		 DATETIME
			,@LeagueId				 INT = 0
			,@HomeId				 INT = 0
			,@AwayId				 INT = 0
			,@Sporttype				 SMALLINT = 0
			,@OldMatchId			 INT
			,@OldTransIds 			 VARCHAR(MAX) = NULL
			,@MarkedTransIds		 VARCHAR(MAX)
			,@Username				 NVARCHAR(200)
			,@IsCalQueue			 BIT = 0
			,@IsTransidProcessed	 BIT = 0
			,@ResettleTransids       VARCHAR(MAX) = '' 
			,@UnmarkTransids		 VARCHAR(MAX) =''
			,@RemoveTransIds		 VARCHAR(MAX) =''
			,@OldUserNames			 VARCHAR(MAX) = NULL
			,@OldFromDate			 DATETIME     = NULL
			,@OldToDate				 DATETIME     = NULL
			,@OldProductIds			 VARCHAR(50)  = NULL
			,@OldStatusIds			 VARCHAR(50)  = NULL
			,@IsLockMatch			 BIT = 0
			,@IsSB					 BIT = 0
			,@IsParlay				 BIT = 0
			,@IsBB					 BIT = 0
			,@IsOutright			 BIT = 0
			,@IsSaba				 BIT = 0
			,@IsNonSport			 BIT = 0
			,@movebetdate			 SMALLDATETIME
			,@maxdate 				 DATETIME = '9999-01-01'
			,@FromWinlostDate        DATETIME	
			,@OldActualScore		 NVARCHAR(300) = NULL
			,@NewActualScore		 NVARCHAR(300) = NULL
			,@OldTypeAccept			 VARCHAR(MAX) = NULL
			,@WrongScoreInfoXML		 XML = NULL
			,@OldSubIssueTypeId		 SMALLINT
			,@DangerAcceptedInfoXML	 XML  = NULL
			,@RedCardInfoXML		 XML = NULL
			,@refnos_29				 VARCHAR(MAX) = '' 

	CREATE TABLE #inputTransid (transid BIGINT)
	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT, refno BIGINT, matchid INT)
	CREATE TABLE #transidremove_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT, refno BIGINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)

	CREATE TABLE #TempEditMatchID ( MatchID INT, IsOutright BIT, IsFlag BIT) -- 0 Remove, 1 -- Add username -> match
	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT)
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT, recommend INT)
	CREATE TABLE #InputValidCustid_2 (custid INT PRIMARY KEY)
	CREATE TABLE #InputValidCustid_1 (custid INT PRIMARY KEY )
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT )
	CREATE TABLE #tblGetLogInfo (
			RequestID				INT
			,MatchID				INT
			,FilterFromTransTime	DATETIME 
			,FilterToTransTime		DATETIME 
			,FilterBy				TINYINT 
			,SingleCount			INT 
			,MainParlayCount		INT 
			,MinSingleTransId		BIGINT 
			,MaxSingleTransId		BIGINT 
			,MinMainParlayTransId	BIGINT 
			,MaxMainParlayTransId	BIGINT 
			,VoidFromTime			DATETIME 
			,VoidToTime				DATETIME
			,LiveHomeScore			INT
			,LiveAwayScore			INT
			,LiveScores				NVARCHAR(300)
			,TypeAccept				VARCHAR(MAX)
			,SubIssueTypeId			SMALLINT
		)
	CREATE TABLE #tblOldResulDetail (
			  RequestId INT
			, MatchId INT
			, FilterFromTransTime DATETIME
			, FilterToTransTime DATETIME
			, FilterBy TINYINT
			, LiveHomeScore INT
			, LiveAwayScore INT
			, IssueDetail VARCHAR(MAX)
			, TypeAccept VARCHAR(50)
			, ActualScore VARCHAR(50)
			, SubIssueTypeId SMALLINT
			)

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblMatchId AS TABLE (MatchId INT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90003
	SET @SB_Error = 0

	-- Check edit request after voided
	IF (EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WITH(NOLOCK) WHERE RequestId = @RequestId))
	BEGIN
		RETURN;
	END

	IF @IssueTypeId IN (11,15) -- Abnormal Bet
	BEGIN
	
		SELECT	@LeagueId = leagueid
				,@HomeId = homeid
				,@AwayId = awayid
				,@Sporttype = sporttype
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @MatchId
		
		SET @OldTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (20))
								  FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
								  WHERE RequestId = @RequestId
								  FOR XML PATH ('')),1,1,'')

		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	LeagueId = ISNULL(@LeagueId, LeagueId)
				,@OldMatchId = MatchId
				,MatchId = ISNULL(@MatchId, MatchId)
				,HomeId = ISNULL(@HomeId, HomeId)
				,AwayId = ISNULL(@AwayId, AwayId)
				,RequestType = CASE WHEN @IssueTypeId IN (11,15) AND ISNULL(@IsVoidVIPMember,0) = 1 THEN 3 -- Void ticket VIP Member
								    WHEN ISNULL(@IsVoidVIPMember,0) = 0 AND @ActionId IN (4,6,7,8) THEN 1
								    ELSE 0
								END
				,@OldSubIssueTypeId = SubIssueTypeId
				,SubIssueTypeId = ISNULL(@SubIssueTypeId, SubIssueTypeId)
		WHERE	RequestId = @RequestId
	END
	ELSE IF @IssueTypeId IN (1,10) -- Danger Accept, Red Card
	BEGIN
		IF @IssueTypeId = 1
		BEGIN
			SET @DangerAcceptedInfoXML = CONVERT(XML, @DangerAcceptedInfo)
			INSERT INTO #tblGetLogInfo( 
				   RequestID				
				  ,MatchID				
				  ,FilterFromTransTime	
				  ,FilterToTransTime			
				  ,FilterBy				
				  ,SingleCount			
				  ,MainParlayCount		
				  ,MinSingleTransId		
				  ,MaxSingleTransId		
				  ,MinMainParlayTransId	
				  ,MaxMainParlayTransId	
				  ,VoidFromTime			
				  ,VoidToTime				
				  ,LiveScores					
				  ,TypeAccept
				  ,SubIssueTypeId
				)
			SELECT @RequestId AS RequestId
				  ,t.c.value('@MatchId','INT') AS MatchID
				  ,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
				  ,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
				  ,t.c.value('@FilterBy','TINYINT') AS FilterBy
				  ,t.c.value('@SingleCount','INT') AS SingleCount
				  ,t.c.value('@MainParlayCount','INT') AS MainParlayCount
				  ,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
				  ,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
				  ,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
				  ,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
				  ,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
				  ,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
				  ,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
				  ,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS TypeAccept
				  ,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))
		END
		IF @IssueTypeId = 10
		BEGIN
			SET @RedCardInfoXML = CONVERT(XML, @RedCardInfo)
			INSERT INTO #tblGetLogInfo( 
				   RequestID				
				  ,MatchID				
				  ,FilterFromTransTime	
				  ,FilterToTransTime			
				  ,FilterBy				
				  ,SingleCount			
				  ,MainParlayCount		
				  ,MinSingleTransId		
				  ,MaxSingleTransId		
				  ,MinMainParlayTransId	
				  ,MaxMainParlayTransId	
				  ,VoidFromTime			
				  ,VoidToTime				
				  ,LiveScores					
				  ,TypeAccept
				  ,SubIssueTypeId
				)
			SELECT @RequestId AS RequestId
				  ,t.c.value('@MatchId','INT') AS MatchID
				  ,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
				  ,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
				  ,t.c.value('@FilterBy','TINYINT') AS FilterBy
				  ,t.c.value('@SingleCount','INT') AS SingleCount
				  ,t.c.value('@MainParlayCount','INT') AS MainParlayCount
				  ,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
				  ,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
				  ,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
				  ,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
				  ,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
				  ,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
				  ,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
				  ,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' 
						AS TypeAccept
				  ,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @RedCardInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@RedCardInfoXML = NULL))
		END

		INSERT INTO #tblOldResulDetail (RequestId, MatchId , FilterFromTransTime, FilterToTransTime, FilterBy, LiveHomeScore, LiveAwayScore, IssueDetail, TypeAccept, SubIssueTypeId)
		SELECT RequestId
			 , MatchId
			 , FilterFromTransTime
			 , FilterToTransTime
			 , FilterBy
			 , LiveHomeScore
			 , LiveAwayScore
			 , IssueDetail
			 , TransIds
			 , SubIssueTypeId
		FROM dbo.TicketVoiding_RequestDetail  WITH(NOLOCK)
		WHERE RequestId = @RequestId

		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	  FilterFromTransTime = l.FilterFromTransTime
			, FilterToTransTime = l.FilterToTransTime
			, FilterBy = l.FilterBy
			, SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, MinSingleTransId = l.MinSingleTransId
			, MaxSingleTransId = l.MaxSingleTransId
			, MinMainParlayTransId = l.MinMainParlayTransId
			, MaxMainParlayTransId = l.MaxMainParlayTransId
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, LiveHomeScore = l.LiveHomeScore
			, LiveAwayScore = l.LiveAwayScore
			, IssueDetail = l.LiveScores
			, TransIds = l.TypeAccept
			, SubIssueTypeId = l.SubIssueTypeId
		FROM dbo.TicketVoiding_RequestDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblGetLogInfo l ON l.RequestID = r.RequestId AND l.MatchID = r.MatchId

		INSERT INTO dbo.TicketVoiding_RequestDetail (
			RequestId
			, MatchId
			, LeagueId
			, HomeId
			, AwayId
			, KickOffTime
			, RequestType
			, FilterFromTransTime
			, FilterToTransTime
			, FilterBy
			, SingleCount
			, MainParlayCount
			, MinSingleTransId
			, MaxSingleTransId
			, MinMainParlayTransId
			, MaxMainParlayTransId
			, VoidFromTime
			, VoidToTime
			, LiveHomeScore
			, LiveAwayScore
			, IssueDetail
			, TransIds
			, SubIssueTypeId 
			)
		SELECT @RequestId
			, l.MatchID
			, m.leagueid
			, m.homeid
			, m.awayid
			, m.kickofftime
			, 0
			, l.FilterFromTransTime
			, l.FilterToTransTime
			, l.FilterBy
			, l.SingleCount
			, l.MainParlayCount
			, l.MinSingleTransId
			, l.MaxSingleTransId
			, l.MinMainParlayTransId
			, l.MaxMainParlayTransId
			, l.VoidFromTime
			, l.VoidToTime
			, l.LiveHomeScore
			, l.LiveAwayScore
			, l.LiveScores
			, l.TypeAccept
			, l.SubIssueTypeId
		FROM #tblGetLogInfo l
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
			LEFT JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = l.RequestID AND rd.MatchId = l.MatchID
		WHERE rd.RequestId IS NULL
	END
	ELSE IF @IssueTypeId = 3 --WrongScore
	BEGIN
		SET @WrongScoreInfoXML = CONVERT(xml, @WrongScoreInfo)
		INSERT INTO #tblGetLogInfo( 
				RequestID				
				,MatchID				
				,FilterFromTransTime	
				,FilterToTransTime					
				,SingleCount			
				,MainParlayCount		
				,MinSingleTransId		
				,MaxSingleTransId		
				,MinMainParlayTransId	
				,MaxMainParlayTransId	
				,VoidFromTime			
				,VoidToTime
				,LiveHomeScore
				,LiveAwayScore
				,LiveScores --ActualScore for WC
				,TypeAccept
			)
		SELECT @RequestId AS RequestId
				,@MatchId AS MatchID
				,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
				,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
				,t.c.value('@SingleCount','INT') AS SingleCount
				,t.c.value('@MainParlayCount','INT') AS MainParlayCount
				,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
				,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
				,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
				,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
				,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
				,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
				,t.c.value('@LiveHomeScore','INT') AS LiveHomeScore
				,t.c.value('@LiveAwayScore','INT') AS LiveAwayScore
				,t.c.value('@ActualScore','VARCHAR(50)') AS ActualScore
				 ,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" ScoreId="' + t.c.value('@ScoreId','VARCHAR(10)') + '" />' AS TypeAccept
		FROM @WrongScoreInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))
		
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID 
				AND rd.LiveHomeScore = t.LiveHomeScore 
				AND rd.LiveAwayScore = t.LiveAwayScore
				AND rd.FilterFromTransTime = t.FilterFromTransTime
				AND rd.FilterToTransTime = t.FilterToTransTime
		WHERE rd.matchid = @MatchId AND rd.RequestId = @RequestId AND t.RequestID IS NULL

		UPDATE	r
		SET	  @OldActualScore = r.IssueDetail
			, FilterFromTransTime = l.FilterFromTransTime
			, FilterToTransTime = l.FilterToTransTime
			, SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, MinSingleTransId = l.MinSingleTransId
			, MaxSingleTransId = l.MaxSingleTransId
			, MinMainParlayTransId = l.MinMainParlayTransId
			, MaxMainParlayTransId = l.MaxMainParlayTransId
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, LiveHomeScore = l.LiveHomeScore
			, LiveAwayScore = l.LiveAwayScore
			, IssueDetail = l.LiveScores
			, SubIssueTypeId = @SubIssueTypeId
			, TransIds = l.TypeAccept
		FROM dbo.TicketVoiding_RequestDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblGetLogInfo l ON l.RequestID = r.RequestId AND l.MatchID = r.MatchId AND r.LiveHomeScore = l.LiveHomeScore AND r.LiveAwayScore = l.LiveAwayScore
														AND r.FilterFromTransTime = l.FilterFromTransTime
														AND r.FilterToTransTime = l.FilterToTransTime

		INSERT INTO dbo.TicketVoiding_RequestDetail (
			RequestId
			, MatchId
			, LeagueId
			, HomeId
			, AwayId
			, KickOffTime
			, RequestType
			, FilterFromTransTime
			, FilterToTransTime
			, FilterBy
			, SingleCount
			, MainParlayCount
			, MinSingleTransId
			, MaxSingleTransId
			, MinMainParlayTransId
			, MaxMainParlayTransId
			, VoidFromTime
			, VoidToTime
			, LiveHomeScore
			, LiveAwayScore
			, IssueDetail
			, TransIds
			, SubIssueTypeId
			)
		SELECT @RequestId
			, l.MatchID
			, m.leagueid
			, m.homeid
			, m.awayid
			, m.kickofftime
			, 0
			, l.FilterFromTransTime
			, l.FilterToTransTime
			, l.FilterBy
			, l.SingleCount
			, l.MainParlayCount
			, l.MinSingleTransId
			, l.MaxSingleTransId
			, l.MinMainParlayTransId
			, l.MaxMainParlayTransId
			, l.VoidFromTime
			, l.VoidToTime
			, l.LiveHomeScore
			, l.LiveAwayScore
			, l.LiveScores
			, l.TypeAccept
			, @SubIssueTypeId
		FROM #tblGetLogInfo l
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
			LEFT JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = l.RequestID AND rd.MatchId = l.MatchID 
														AND rd.LiveHomeScore = l.LiveHomeScore AND rd.LiveAwayScore = l.LiveAwayScore
														AND rd.FilterFromTransTime = l.FilterFromTransTime
														AND rd.FilterToTransTime = l.FilterToTransTime
		WHERE rd.RequestId IS NULL

	END
	ELSE IF @IssueTypeId = 13 -- Abnormal Account
	BEGIN
		
		-- Get info match belong to username
		--Get Movebetdate
		EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
		SELECT @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
			 , @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
		
		IF @ToDate IS NULL
		BEGIN
	
			SET @ToDate = @maxdate
		END

		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@StatusIds, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)

		SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsBB = CASE WHEN CHARINDEX('3',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsNonSport = CASE WHEN CHARINDEX('6',@ProductIds) > 0 THEN 1 ELSE 0 END

		INSERT INTO #InputUsernameList (Username, custid, roleid, recommend)
		SELECT l.val
			  ,ci.custid
			  ,ci.roleid
			  ,ci.recommend
		FROM  dbo.f_SplitString(@UserNames, ',') l
			LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.val = ci.username
		WHERE val <> '' AND ci.custid IS NOT NULL
		OPTION (MAXRECURSION 0)
	
		INSERT INTO #InputValidCustid_2 (custid)		
		SELECT l.custid
		FROM #InputUsernameList l
		WHERE l.roleid = 2

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)	
			SELECT DISTINCT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
				LEFT JOIN #InputValidCustid_2 ag ON ag.custid = ci.custid
			WHERE l.roleid = 3 AND ci.roleid = 2 AND ag.custid IS NULL

		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)
			SELECT DISTINCT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
				LEFT JOIN #InputValidCustid_2 ag ON ag.custid = ci.custid
			WHERE l.roleid = 4 AND ci.roleid = 2 AND ag.custid IS NULL
		END

		
		-- list of member to process
		INSERT INTO #InputValidCustid_1 (CustID)
		SELECT  DISTINCT l1.CustID
		FROM #InputUsernameList l1
			LEFT JOIN #InputValidCustid_2 l2 ON l1.recommend = l2.custid 
		WHERE l1.roleid = 1 AND l2.custid IS NULL
		;
		
		------------Prepare Data------------------------
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE 1 = CASE WHEN @UserNames IS NULL THEN 1
					ELSE CASE
							WHEN (@IsSB = 1 OR @IsSaba = 1) 
								AND pt.ProductID = 1 
								AND pt.BetType NOT IN (9,29,10)
								AND pt.SubProduct NOT IN ('Bet Builder') THEN 1 -- Sportsbook
							WHEN @IsOutright = 1 AND pt.bettype IN (10) THEN 1 --Outright
							WHEN @IsParlay = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
							WHEN @IsBB = 1 AND pt.SubProduct IN ('Bet Builder') THEN 1 --Bet Builder
							WHEN @IsNonSport = 1 AND ProductID IN (3,5,27) AND pt.SportType NOT IN (168) THEN 1
						ELSE 0 END
				END
			AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
			AND pt.bettype NOT IN (31,32,33,71,72,73)  -- NOT IN [Racing, Casino]
			AND pt.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
			AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno

		IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_2)
		BEGIN
			INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
			SELECT	b.translogid AS transid
					,b.statusID  
					,b.eventID
					,b.gameID
			FROM	dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
			WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
					AND b.GameID BETWEEN 801 AND 806
					AND b.statusID = 0
					AND @IsSB = 1
				
			UNION ALL
			SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
					,b.statusID
					,b.matchid
					,b.bettype
			FROM dbo.bettrans AS b WITH (NOLOCK)
				OUTER APPLY (
					SELECT TOP 1 1 LeagueGroupID 
					FROM dbo.match m WITH (NOLOCK)
						INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
					WHERE m.matchid = b.matchid
						AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113)
				)ml
				INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
				OUTER APPLY (
					SELECT TOP 1 m.sporttype 
					FROM dbo.match m WITH (NOLOCK)
					WHERE m.matchid = b.matchid
						AND m.sporttype = 50
				)mc
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND 1 = CASE 
							WHEN @IsSB = 1 
								AND b.bettype BETWEEN 801 AND 806 
								AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
							WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
								AND b.bettype NOT BETWEEN 801 AND 806-- MG
								AND ml.LeagueGroupID IS NULL 
								AND mc.sporttype IS NULL --exclude cricket
								THEN 1
							WHEN @IsSaba = 1 
								AND ml.LeagueGroupID IS NOT NULL THEN 1								
						ELSE 0 END	
				AND statusID IN (SELECT statusID FROM @Status_tmp)
		END
		IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_1)
		BEGIN
			INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
			SELECT	b.translogid AS transid
					,b.statusID  
					,b.eventID
					,b.gameID
			FROM	dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
			WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
					AND b.GameID BETWEEN 801 AND 806
					AND b.statusID = 0
					AND @IsSB = 1
				
			UNION ALL
			SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
					,b.statusID
					,b.matchid
					,b.bettype
			FROM dbo.bettrans AS b WITH (NOLOCK)
				OUTER APPLY (
					SELECT TOP 1 1 LeagueGroupID 
					FROM dbo.match m WITH (NOLOCK)
						INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
					WHERE m.matchid = b.matchid
						AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113)
				)ml
				OUTER APPLY (
					SELECT TOP 1 m.sporttype 
					FROM dbo.match m WITH (NOLOCK)
					WHERE m.matchid = b.matchid
						AND m.sporttype = 50
				)mc
				INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND 1 = CASE 
							WHEN @IsSB = 1 
								AND b.bettype BETWEEN 801 AND 806 
								AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
							WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
								AND b.bettype NOT BETWEEN 801 AND 806-- MG
								AND ml.LeagueGroupID IS NULL 
								AND mc.sporttype IS NULL --exclude cricket
								THEN 1
							WHEN @IsSaba = 1 
								AND ml.LeagueGroupID IS NOT NULL THEN 1								
						ELSE 0 END	
				AND statusID IN (SELECT statusID FROM @Status_tmp)
		END

		IF @ActionId NOT IN (2)
		BEGIN
			INSERT INTO #TransidInRequest (TransId)
			SELECT DISTINCT rs.TransId
			FROM  dbo.TicketVoiding_Request r WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							ON rs.RequestId = r.RequestId
				CROSS APPLY (
							SELECT TOP 1 t.MatchId, t.transid
							FROM #transIdTemp t
							WHERE t.MatchId = rs.MatchId 
								AND rs.TransId = t.transid
					)t
			WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)

			DELETE 
			FROM #transIdTemp
			WHERE transid IN ( SELECT transid FROM #TransidInRequest) 
		END

		INSERT INTO #TempMatch(MatchId, IsOutright)
		SELECT  DISTINCT matchid,
				CASE WHEN bettype <> 10 THEN 0 
					 WHEN bettype = 10 THEN 1 
					 ELSE NULL END
		FROM #transIdTemp
		
		SELECT   @OldUserNames	 = UserNames
				, @OldFromDate	 = FromWinlostDate
				, @OldToDate	 = ToWinlostDate
				, @OldProductIds = ProductIds
				, @OldStatusIds  = TicketStatusIds
				, @OldSubIssueTypeId = SubIssueTypeId
		FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK)
		WHERE RequestId = @RequestId 

		INSERT INTO #TempEditMatchID (MatchID, IsOutright, IsFlag)
		SELECT rd.MatchId,0, 0 -- remove match
		FROM  dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE  NOT EXISTS ( SELECT TOP 1 1 FROM #TempMatch m WHERE rd.MatchId = m.MatchID)
			 AND rd.RequestId = @RequestId
		UNION ALL
		SELECT m.MatchId,m.IsOutright, 1  -- add match
		FROM  #TempMatch m
		OUTER APPLY  (
					SELECT rd.MatchId
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					WHERE m.MatchID = rd.MatchId AND rd.RequestId = @RequestId
			)tmp
		WHERE tmp.MatchId IS NULL

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 0 )
		BEGIN
				DELETE rd
				FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					INNER JOIN #TempEditMatchID e ON  rd.MatchId = e.MatchID
				WHERE rd.RequestId = @RequestId AND e.IsFlag = 0
		END
			IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 0)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, RequestType
					, SubIssueTypeId
				)
				SELECT @RequestId
					, e.MatchID
					, ISNULL(m.leagueid, 0) 
					, ISNULL(m.homeid, 0) 
					, ISNULL(m.awayid, 0) 
					, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
					, @SubIssueTypeId
				FROM #TempEditMatchID e 
					LEFT JOIN dbo.match m WITH(NOLOCK) ON e.MatchID = m.matchid 
				WHERE e.IsFlag = 1	AND e.IsOutright = 0	
		END  
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 1)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, RequestType
					, SubIssueTypeId
				)
				SELECT @RequestId
					, e.MatchID
					, m.leagueid
					, m.teamid
					, 0
					, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
					, @SubIssueTypeId
				FROM #TempEditMatchID e 
					INNER JOIN dbo.outright m WITH(NOLOCK) ON e.MatchID = m.orid
				WHERE e.IsFlag = 1	AND e.IsOutright = 1		
		END  
		
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   UserNames =  @UserNames
				, ProductIds = @ProductIds
				, TicketStatusIds = @StatusIds
				, FromWinlostDate = @FromDate
				, ToWinlostDate = @ToDate
				, RequestType = CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				, SubIssueTypeId = @SubIssueTypeId
		WHERE	RequestId = @RequestId

		-- Insert queue for auto void
		IF @ActionId = 4 AND EXISTS (SELECT TOP 1 1 FROM #TempMatch)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			SELECT @RequestId, m.MatchId, 'VoidInstant', 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			FROM #TempMatch m
		END
	END
	ELSE IF @IssueTypeId IN (8,9)--EKO, WKO
	BEGIN
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	@OldKickOffTime = KickOffTime
				,KickOffTime = ISNULL(@KickOffTime, KickOffTime)
				,SubIssueTypeId = ISNULL(@SubIssueTypeId, SubIssueTypeId)
		WHERE	RequestId = @RequestId
				AND MatchId = @MatchId
	END
	ELSE IF @IssueTypeId = 17 --Archived Ticket
	BEGIN
		SET @OldTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (20))
								  FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
								  WHERE RequestId = @RequestId
								  FOR XML PATH ('')),1,1,'')

		INSERT INTO #transIdTemp  (transid, statusID, MatchId, bettype)
		SELECT DISTINCT t.val, b14.statusId, b14.matchid, b14.bettype
		FROM dbo.f_SplitString(@TransIds, ',') t
			INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON CAST (t.val AS BIGINT) = b14.transid
		WHERE val <> ''
		OPTION (maxrecursion 0)

		INSERT INTO #TempMatch(MatchId, IsOutright)
		SELECT  DISTINCT matchid,
				CASE WHEN bettype <> 10 THEN 0 
					 WHEN bettype = 10 THEN 1 
					 ELSE NULL END
		FROM #transIdTemp

		INSERT INTO #TempEditMatchID (MatchID, IsOutright, IsFlag)
		SELECT rd.MatchId,0, 0 -- remove match
		FROM  dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE  NOT EXISTS ( SELECT TOP 1 1 FROM #TempMatch m WHERE rd.MatchId = m.MatchID)
			 AND rd.RequestId = @RequestId
		UNION ALL
		SELECT m.MatchId,m.IsOutright, 1  -- add match
		FROM  #TempMatch m
		OUTER APPLY  (
					SELECT rd.MatchId
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					WHERE m.MatchID = rd.MatchId AND rd.RequestId = @RequestId
			)tmp
		WHERE tmp.MatchId IS NULL

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 0 )
		BEGIN
				DELETE rd
				FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					INNER JOIN #TempEditMatchID e ON  rd.MatchId = e.MatchID
				WHERE rd.RequestId = @RequestId AND e.IsFlag = 0
		END
		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 0)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, SubIssueTypeId
				)
				SELECT @RequestId
					, e.MatchID
					, ISNULL(m14.leagueid, 0) 
					, ISNULL(m14.homeid, 0) 
					, ISNULL(m14.awayid, 0) 
					, @SubIssueTypeId
				FROM #TempEditMatchID e 
					LEFT JOIN dbo.match14 m14 WITH(NOLOCK) ON e.MatchID = m14.matchid 
				WHERE e.IsFlag = 1	AND e.IsOutright = 0	
		END  
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 1)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, SubIssueTypeId
				)
				SELECT @RequestId
					, e.MatchID
					, o14.leagueid
					, o14.teamid
					, 0
					, @SubIssueTypeId
				FROM #TempEditMatchID e 
					INNER JOIN dbo.outright14 o14 WITH(NOLOCK) ON e.MatchID = o14.orid
				WHERE e.IsFlag = 1	AND e.IsOutright = 1		
		END  

		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   FilterBy =  @FilterBy
		WHERE	RequestId = @RequestId
	END
	-- Auto mark ticket running for auto void
	IF @IssueTypeId IN (11,15) AND @Sporttype <= 99
	BEGIN
		
		INSERT INTO #TransidInRequest (TransId)
		SELECT tmp.transid
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (
						SELECT TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
						WHERE RequestId = req.RequestId
					) AS tmp
		WHERE rd.MatchId = @MatchId 
			AND req.RequestId <> @RequestId AND req.ActionId <>2

		INSERT INTO #inputTransid (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)
		
		INSERT INTO #transid_tmp (transid, bettype, StatusId, statuswinlost, refno, matchid)
		SELECT t.transid, b.bettype, b.statusID, b.statuswinlost, b.refno, b.matchid
		FROM #inputTransid t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
		WHERE b.statusID IN (0, 1) --if status of ticket is running

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		SET @IsCalQueue = ( SELECT TOP (1) 1
							FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
							WHERE StatusId IN (1,2,4) AND RequestId = 0
							AND matchid = @MatchId)

		IF @FilterBy = 1
		BEGIN
			INSERT INTO @tblMatchId (MatchId)
			SELECT DISTINCT m.matchid 
			FROM #transid_tmp tmp
			INNER JOIN dbo.bettransm m WITH(NOLOCK) ON tmp.refno = m.refno
		END

		--2.4 remove transid from request => unmark ticket & re-cal ticket
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #inputTransid it WHERE rdt.TransId=it.transid) -- exist vs input
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
												  AND EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = rdt.transid)
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		
			INSERT INTO #transidremove_tmp (transid, bettype, StatusId, statuswinlost, refno)
			SELECT t.val, b.bettype, b.statusID, b.statuswinlost, b.refno
			FROM dbo.f_SplitString(@RemoveTransIds, ',') t
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON CAST (t.val AS BIGINT) = b.transid
			WHERE t.val <> '' AND b.statusID IN (0, 1) --if status of ticket is running
			OPTION (maxrecursion 0)
			
			SELECT @ResettleTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM #transidremove_tmp
											WHERE statuswinlost IS NOT NULL
											FOR XML PATH('')
								), 1,1,'')
			--resettle ticket
			IF (@IsConfirmCalculator = 1 AND @ResettleTransids <> '')
			BEGIN
				IF @FilterBy IS NULL --single ticket
				BEGIN
					EXEC [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
								@Matchid = @Matchid	,
								@TransIds = @ResettleTransids,
								@UserId  = @UserId,
								@IP = @IP,
								@FailedTransIds = @FailedTransIds OUTPUT,
								@ErrMsg = @ErrMsg OUTPUT,
								@ErrCode = @ErrCode OUTPUT,
								@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			     
				END
				IF @FilterBy = 1 --mixparlay ticket
				BEGIN
					BEGIN TRY  
						SET @refnos_29 =''
						SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
						FROM #transidremove_tmp  
						WHERE bettype = 29 
							AND (statusID IS NULL OR statusID <> 102) 
						GROUP BY refno, transid
						SET @refnos_29 = STUFF(@refnos_29,1,1,'')

						EXEC dbo.NAP_Admin_Calculate_MP_broker  
								@matchdate = ''  
								,@strXML = @refnos_29  
								,@mode  = '29'  
					END TRY  
					BEGIN CATCH   
						SELECT @ErrCode = 100, @ErrMsg = ERROR_MESSAGE()  
					END CATCH  
				END
			END
		END

		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE statusid = 0 AND statuswinlost IS NOT NULL)
				SET @IsTransidProcessed = 1

		IF @ActionId <> 2
		BEGIN
			-- mark ticket
			SELECT @MarkedTransIds = STUFF(
				(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
				FROM #transid_tmp tp
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid AND mt.matchid = tp.matchid)
				GROUP BY TransId for XML PATH('')), 1, 1, ''
				)
			IF @MarkedTransIds IS NOT NULL
			BEGIN
				EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
															, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
			END
		END
		ELSE --update take note
		BEGIN
			SELECT @UnmarkTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM #transid_tmp tp
											WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid AND mt.matchid = tp.matchid)
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
											FOR XML PATH('')
								), 1,1,'')
			--unmark ticket
			IF @UnmarkTransids IS NOT NULL
			BEGIN
				EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @UnmarkTransids, @UserId = @UserId, @Username = @Username, @IP = @IP
																	, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
			END
			SET @ResettleTransids =''
			SELECT @ResettleTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
												FROM #transid_tmp
												WHERE statuswinlost IS NOT NULL
												FOR XML PATH('')
									), 1,1,'')
			--resettle ticket
			IF (@IsConfirmCalculator = 1 AND @ResettleTransids <> '')
			BEGIN
				IF @FilterBy IS NULL --single ticket
				BEGIN
					EXEC [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
								@Matchid = @Matchid	,
								@TransIds = @ResettleTransids,
								@UserId  = @UserId,
								@IP = @IP,
								@FailedTransIds = @FailedTransIds OUTPUT,
								@ErrMsg = @ErrMsg OUTPUT,
								@ErrCode = @ErrCode OUTPUT,
								@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			     
				END
				IF @FilterBy = 1 --mixparlay ticket
				BEGIN
					BEGIN TRY  
						SET @refnos_29 = '' 
						SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
						FROM #transid_tmp  
						WHERE bettype = 29 
							AND (statusID IS NULL OR statusID <> 102) 
						GROUP BY refno, transid
						SET @refnos_29 = STUFF(@refnos_29,1,1,'')

						EXEC dbo.NAP_Admin_Calculate_MP_broker  
								@matchdate = ''  
								,@strXML = @refnos_29  
								,@mode  = '29'  
					END TRY  
					BEGIN CATCH   
						SELECT @ErrCode = 100, @ErrMsg = ERROR_MESSAGE()  
					END CATCH  
				END
			END
		END
		
		IF @ActionId IN (4,6,7,8) OR (@ActionID = 1 AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			VALUES(@RequestId, @MatchId, CASE WHEN @ActionId = 1 THEN 'AddRequest' 
											  WHEN @ActionId = 4 THEN 'VoidInstant'
											  WHEN @ActionId = 6 THEN 'VoidInstant5m'
											  WHEN @ActionId = 7 THEN 'VoidInstant10m' 
											  WHEN @ActionId = 8 THEN 'VoidInstantNopolicy'
											  ELSE '' END 
			, 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype)
		END

		-- Abnormal Bet - Mixparlay ticket
		IF @ActionId = 1 AND @IssueTypeId = 11 AND @FilterBy = 1
		BEGIN
			--Re-insert ticket the deleted ticket
			UPDATE dbo.TicketVoiding_AutoVoidRequest_Queue WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 99, ErrMsg = NULL
			WHERE RequestId = @RequestId AND StatusId = 4
				AND MatchId IN (SELECT MatchId FROM @tblMatchId )

			--Remove ticket
			UPDATE dbo.TicketVoiding_AutoVoidRequest_Queue WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 4, ErrMsg = 'Remove Mix-parlay ticket from action Auto Void Winning'
			WHERE RequestId = @RequestId 
				AND MatchId NOT IN (SELECT MatchId FROM @tblMatchId )
			
			--Insert new ticket
		    INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			SELECT @RequestId, t.MatchId, 'MixParlay', 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			FROM @tblMatchId t
			WHERE  MatchId NOT IN (SELECT MatchId FROM TicketVoiding_AutoVoidRequest_Queue (NOLOCK) WHERE RequestId = @RequestId)
		END
	END

	-- Get content of log data
	SET @LogDataContent = ''
	IF @IssueTypeId IN (11,15) OR @TransIds IS NOT NULL
	BEGIN
		IF @MatchId <> @OldMatchId
		BEGIN
			SET @LogDataContent += ' Old MatchId: ' + CAST(@OldMatchId AS VARCHAR(20))
									+ ' New MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', '
		END
		IF @TransIds <> @OldTransIds
		BEGIN
			SET @LogDataContent += ' Old TransIds: ' + @OldTransIds + ' New TransIds: ' + @TransIds
		END
	END
	ELSE IF @IssueTypeId IN (1, 10)
	BEGIN
		SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20)) 
							   + ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							   + ', FilterFrom: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
							   + ', FilterTo: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
							   + ', SingleCount: ' + CAST(l.SingleCount AS VARCHAR(20))
							   + ', MainParlayCount: ' + CAST(l.MainParlayCount AS VARCHAR(20))
							   + ', MinSingleTransId: ' + CAST(l.MinSingleTransId AS VARCHAR(20))
							   + ', MaxSingleTransId: '+ CAST(l.MaxSingleTransId AS VARCHAR(20))
							   + ', MinMainParlayTransId: ' + CAST(l.MinMainParlayTransId AS VARCHAR(20))
					           + ', MaxMainParlayTransId: ' + CAST(l.MaxMainParlayTransId AS VARCHAR(20))
							   + ', VoidFrom: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							   + ', VoidTo: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							   + ', TypeAccept: ' + l.TypeAccept
		FROM #tblGetLogInfo l

	END
	ELSE IF @IssueTypeId = 13
	BEGIN
		IF @OldUserNames <> @UserNames
		BEGIN
			SET @LogDataContent += ' Old Usernames: ' + @OldUserNames + ' New Usernames: ' + @UserNames
		END
		IF @OldProductIds <> @ProductIds
		BEGIN
			SET @LogDataContent += ' Old ProductIds: ' + @OldProductIds + ' New ProductIds: ' + @ProductIds
		END
		IF @OldStatusIds <> @StatusIds
		BEGIN
			SET @LogDataContent += ' Old StatusIds: ' + @OldStatusIds + ' New StatusIds: ' + @StatusIds
		END
		IF @OldFromDate <> @FromDate
		BEGIN
			SET @LogDataContent += ' Old From Date: ' + CONVERT(VARCHAR(10), @OldFromDate, 23) + ' New From Date: ' + CONVERT(VARCHAR(10), @FromDate, 23)
		END
		IF @OldToDate <> @ToDate
		BEGIN
			SET @LogDataContent += ' Old To Date: ' + CONVERT(VARCHAR(10), @OldToDate, 23) + ' New To Date: ' + CONVERT(VARCHAR(10), @ToDate, 23)
		END
		
	END
	ELSE IF @IssueTypeId IN (8,9) OR @KickOffTime IS NOT NULL --EKO,WKO
	BEGIN
		IF @OldKickOffTime <> @KickOffTime
		BEGIN
			SET @LogDataContent += ' Old KickOffTime: ' + CONVERT(VARCHAR(30), @OldKickOffTime, 21)
								+ ' New KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
		END
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
	
		DECLARE @actualscore varchar(5)

		SELECT @actualscore = l.LiveScores
		FROM #tblGetLogInfo l

		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20))
								+', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20))
								+', Actual Score: ' + @actualscore
								+', Wrong Score: ' 
		SELECT @LogDataContent = @LogDataContent
								+ CAST(l.LiveHomeScore AS VARCHAR(5)) +'-'
								+ CAST(l.LiveAwayScore AS VARCHAR(5))+' ('
								+ 'From Time: '+ CONVERT(VARCHAR(30),l.FilterFromTransTime, 21)  +' - '
								+ 'To Time: '+ CONVERT(VARCHAR(30),l.FilterToTransTime, 21) +'); '
		FROM #tblGetLogInfo l
	END
	ELSE IF @IssueTypeId = 17 OR @TransIds IS NOT NULL
	BEGIN
		IF @TransIds <> @OldTransIds
		BEGIN
			SET @LogDataContent += ' Old TransIds: ' + @OldTransIds + ' New TransIds: ' + @TransIds
		END
	END
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' + @LogDataContent
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #inputTransid
	DROP TABLE #transid_tmp
	DROP TABLE #TransidInRequest
	DROP TABLE #TempEditMatchID
	DROP TABLE #TempMatch
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #transIdTemp
	DROP TABLE #tblGetLogInfo
	DROP TABLE #tblOldResulDetail
	DROP TABLE #InputValidCustid_1
	DROP TABLE #transidremove_tmp
END
GO