/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Insert]
(
	@RequestId				INT
	,@MatchId				INT = 0
	,@IssueTypeId			TINYINT		= NULL
	,@KickOffTime			DATETIME	= NULL
	,@TransIds				VARCHAR(MAX) = NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@FilterBy				TINYINT = NULL
	,@SubIssueTypeId		TINYINT = NULL
	,@AbnormalAccountInfo	NVARCHAR(MAX) = NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX) = NULL
	,@RedCardInfo			VARCHAR(MAX) = NULL
	,@WrongHDPInfo			VARCHAR(MAX) = NULL
	,@Wrong1stHDPInfo		VARCHAR(MAX) = NULL
	,@WrongOUInfo		    VARCHAR(MAX) = NULL
	,@Wrong1stOUInfo		VARCHAR(MAX) = NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: insert request detail [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191111@Max: Ticket Voiding System - Abnormal Bet Issue Type [Redmine:#111541]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20200213@Charles: Insert queue for auto void [127398]
		- 20200213@Helen: Refactor code [Redmine: #127398]
		- 20200221@Max: HotFix [Redmine: #128924]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
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
		- 20210304@July: TVS - Abnormal Bet - Auto void before KO time - [Redmine: #150522]
		- 20210318@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210420@July: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210524@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210625@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210714@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210802@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20210820@July: TVS - Add new status Void Instant without any policy [Redmine: #160012]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211213@July: TVS - Remove code [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220208@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220214@July: Intergrate new Saba Basketball PinGoal [Redmine: #168079]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220401@July: TVS - New issue type Wrong OU and Wrong 1H OU [Redmine: #170220]
		- 20220414@Max: [TVS] Support AB Exclusion by sub issue type [Redmine: #170771]
		- 20220420@July: TVS - Abnormal Account - Phase 2 [Redmine: #170772]
		- 20220610@July: TVS - Some minor enhancements  [Redmine: #173229]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME
			,@EndTime			 DATETIME
			,@LogActionId		 INT
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT
			,@LeagueId			 INT = 0
			,@HomeId			 INT = 0
			,@AwayId			 INT = 0
			,@Sporttype 		 SMALLINT = 0
			,@MarkedTransIds	 VARCHAR(MAX)
			,@Username			 NVARCHAR(200)
			,@IsCalQueue		 BIT = 0
			,@IsTransidProcessed BIT = 0
			,@IsSB				 BIT = 0
			,@IsParlay			 BIT = 0
			,@IsBB				 BIT = 0
			,@IsOutright		 BIT = 0
			,@IsSaba			 BIT = 0
			,@IsNonSport		 BIT = 0
			,@movebetdate		 SMALLDATETIME
			,@maxdate 			 DATETIME = '9999-01-01'
			,@FromWinlostDate    DATETIME
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@DangerAcceptedInfoXML	  XML = NULL
			,@RedCardInfoXML		  XML = NULL
			,@WrongHDPInfoXML		  XML = NULL	
			,@Wrong1stHDPInfoXML	  XML = NULL
			,@WrongOUInfoXML		  XML = NULL	
			,@Wrong1stOUInfoXML		  XML = NULL
			,@AbnormalAccountInfoXML  XML = NULL

	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT, refno BIGINT, matchid INT)
	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT )
	CREATE TABLE #InputUsernameList ( Username NVARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)
	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,FilterFromTransTime	DATETIME 
			,FilterToTransTime		DATETIME 
			,FilterFromBetId		BIGINT
			,FilterToBetId			BIGINT
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
			,TypeAccept				VARCHAR(50)
			,SubIssueTypeId			SMALLINT
			,WrongHDP				VARCHAR(200)
			)
	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblMatchId AS TABLE (MatchId INT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90001
	SET @SB_Error = 0	

	IF @IssueTypeId NOT IN (1,10,3,17) --DA,RC,WC,AT
	BEGIN
		-- get match info
		SELECT	@LeagueId = leagueid
				,@HomeId = homeid
				,@AwayId = awayid
				,@Sporttype = sporttype
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @MatchId
	END

	IF @IssueTypeId IN (11,15) --AB,AB(RealMember)
	BEGIN
		INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

		INSERT INTO #transid_tmp (transid, bettype, StatusId, statuswinlost, refno, matchid)
		SELECT t.transid, b.bettype, b.statusID, b.statuswinlost, b.refno, b.matchid
		FROM #transIdTemp t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
		
		IF @FilterBy = 1
		BEGIN
			INSERT INTO @tblMatchId (MatchId)
			SELECT DISTINCT m.matchid
			FROM #transid_tmp tmp
			INNER JOIN dbo.bettransm m WITH(NOLOCK) ON tmp.refno = m.refno
		END

		SET @IsCalQueue = ( SELECT TOP (1) 1
								FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
								WHERE StatusId IN (1,2,4) AND matchid = @MatchId  AND RequestId = 0
								)
	
		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE statusid = 0 AND statuswinlost IS NOT NULL)
			SET @IsTransidProcessed = 1
	END
	ELSE IF  @IssueTypeId IN (3) --WC
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
			  ,LiveScores --ActualScore, LiveScores for WC
			  ,SubIssueTypeId
			  ,TypeAccept
			  ,FilterBy
			)

		SELECT @RequestId AS RequestId
			  ,t.c.value('@MatchId','INT') AS MatchID
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
			  ,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' + t.c.value('@ActualScore','VARCHAR(50)') AS ActualScore
			  ,@SubIssueTypeId
			  ,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" ScoreId="' + t.c.value('@ScoreId','VARCHAR(20)') + '" />' AS TypeAccept
			  ,t.c.value('@FilterBy','TINYINT') AS FilterBy
		FROM @WrongScoreInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 1 --Danger Accept
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
					,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
					,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS TypeAccept
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 10 --Red Card
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
					,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
					,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' 
						AS TypeAccept
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @RedCardInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@RedCardInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 4 --Wrong HDP
	BEGIN
			SET @WrongHDPInfoXML = CONVERT(XML, @WrongHDPInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
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
					,SubIssueTypeId
					,WrongHDP
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
					,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
					,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
					,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
					,CASE WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (8) AND ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') <> '' THEN '<r HomeFavorite="' + REPLACE(t.c.value('@HomeFavorite','VARCHAR(50)') , '&', '&amp;') 
												+ '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
												+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />'
						  WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (8) AND ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') <> '' THEN '<r AwayFavorite="' + REPLACE(t.c.value('@AwayFavorite','VARCHAR(50)') , '&', '&amp;') 
												+ '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
												+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />'
						  WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (22,23) AND ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') <> '' THEN '<r HdpValue="' + REPLACE(t.c.value('@HdpValue','VARCHAR(50)') , '&', '&amp;') + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(50)') + '" />'
						  ELSE '' END AS WrongHDP
			FROM @WrongHDPInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 5 --Wrong 1st HDP
	BEGIN
			SET @Wrong1stHDPInfoXML = CONVERT(XML, @Wrong1stHDPInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
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
					,SubIssueTypeId
					,WrongHDP
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
					,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
					,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
					,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
					,CASE WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (9) AND ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') <> '' THEN '<r HomeFavorite="' + REPLACE(t.c.value('@HomeFavorite','VARCHAR(50)') , '&', '&amp;') 
												+ '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
												+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />'
						  WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (9) AND ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') <> '' THEN '<r AwayFavorite="' + REPLACE(t.c.value('@AwayFavorite','VARCHAR(50)') , '&', '&amp;') 
												+ '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
												+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />'
						  WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (24,25) AND ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') <> '' THEN '<r HdpValue="' + REPLACE(t.c.value('@HdpValue','VARCHAR(50)') , '&', '&amp;') + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(50)') + '" />'
						  ELSE '' END AS WrongHDP
			FROM @Wrong1stHDPInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@Wrong1stHDPInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 6 --Wrong OU
	BEGIN
			SET @WrongOUInfoXML = CONVERT(XML, @WrongOUInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
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
					,SubIssueTypeId
					,WrongHDP
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
					,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
					,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
					,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
					,'<r WrongMarket="' + REPLACE(t.c.value('@WrongMarket','VARCHAR(50)') , '&', '&amp;') + '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
								+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS WrongHDP
			FROM @WrongOUInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@WrongOUInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 7 --Wrong 1H OU
	BEGIN
			SET @Wrong1stOUInfoXML = CONVERT(XML, @Wrong1stOUInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
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
					,SubIssueTypeId
					,WrongHDP
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
					,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
					,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
					,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
					,'<r WrongMarket="' + REPLACE(t.c.value('@WrongMarket','VARCHAR(50)') , '&', '&amp;') + '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
								+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS WrongHDP
			FROM @Wrong1stOUInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@Wrong1stOUInfoXML = NULL))
	END
	
	IF @IssueTypeId IN (8,9,11,15) --EKO,WKO,AB,AB(RealMember)
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (
			RequestId
			, MatchId
			, LeagueId
			, HomeId
			, AwayId
			, KickOffTime
			, RequestType
			, SubIssueTypeId
			, FilterBy
		)
		SELECT @RequestId
			, @MatchId
			, @LeagueId
			, @HomeId
			, @AwayId
			, @KickOffTime
			, CASE WHEN @ActionId IN (4,6,7,8) THEN 1
				   ELSE 0
				END
			, @SubIssueTypeId
			, CASE WHEN @IssueTypeId = 11 THEN @FilterBy ELSE NULL END
	END
	ELSE IF @IssueTypeId IN (1,10,3) --DA,RC,WC
	BEGIN
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
	END
	ELSE IF @IssueTypeId = 13 --AC
	BEGIN 
		DECLARE @UserNames				NVARCHAR(MAX) = NULL
				,@ProductIds			VARCHAR(50) = NULL
				,@StatusIds				VARCHAR(50) = NULL
				,@FromDate				DATETIME = NULL
				,@ToDate				DATETIME = NULL

		SET @AbnormalAccountInfoXML = CONVERT(XML, @AbnormalAccountInfo)
		SELECT @UserNames = t.c.value('@Usernames','NVARCHAR(MAX)') 
			  ,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
			  ,@StatusIds = t.c.value('@StatusIds','VARCHAR(50)')
			  ,@FromDate = t.c.value('@FromDate','DATETIME')
			  ,@ToDate = t.c.value('@ToDate','DATETIME')
		FROM @AbnormalAccountInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@AbnormalAccountInfoXML = NULL))

		--Get Movebetdate
		EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT

		SELECT @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
				, @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
		
		IF @ToDate IS NULL
		BEGIN
			SET @ToDate = @maxdate
		END
	
		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@StatusIds, ',')

		SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsBB = CASE WHEN CHARINDEX('3',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsNonSport = CASE WHEN CHARINDEX('6',@ProductIds) > 0 THEN 1 ELSE 0 END

		INSERT INTO #InputUsernameList (Username, custid, roleid)
		SELECT CAST(l.value AS NVARCHAR(30))
			  ,ci.custid
			  ,ci.roleid
		FROM  STRING_SPLIT(@UserNames, ',') l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON CAST(l.value AS NVARCHAR(30)) = ci.username
	
		INSERT INTO #InputValidCustid_2 (custid)		
		SELECT l.custid
		FROM #InputUsernameList l
		WHERE l.roleid = 2

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)	
			SELECT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
			WHERE l.roleid = 3 AND ci.roleid = 2
		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)
			SELECT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
			WHERE l.roleid = 4 AND ci.roleid = 2	
		END

		-- list of member to process
		INSERT INTO #InputValidCustid_tmp (CustID)
		SELECT  CustID
		FROM #InputUsernameList l
		WHERE l.roleid =1
		UNION
		SELECT ci.CustID
		FROM #InputValidCustid_2 lt
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK)
			ON lt.custid = ci.recommend
		WHERE ci.roleid = 1
	
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
			AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
			AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno

		INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
		SELECT	b.translogid AS transid
				,b.statusID  -- add new
				,b.eventID
				,b.gameID
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
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
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122)
			)ml
			OUTER APPLY (
				SELECT TOP 1 m.sporttype 
				FROM dbo.match m WITH (NOLOCK)
				WHERE m.matchid = b.matchid
					AND m.sporttype = 50
			)mc
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
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
		
		IF @ActionId NOT IN (2)
		BEGIN
			INSERT INTO #TransidInRequest (TransId)
			SELECT DISTINCT rs.TransId
			FROM  dbo.TicketVoiding_Request r WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							ON rs.RequestId = r.RequestId
				CROSS APPLY (
							SELECT TOP 1 t.MatchId, t.transid, t.StatusId
							FROM #transIdTemp t
							WHERE t.MatchId = rs.MatchId 
								AND rs.TransId = t.transid
					)t
			WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
			AND 1 = CASE WHEN r.IssueTypeId IN (11,15) AND t.StatusId NOT IN (111,112,113) THEN 1
					     WHEN r.IssueTypeId NOT IN (11,15) THEN 1
					     ELSE 0 END

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

	   IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE IsOutright = 0)
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
				   RequestId
				 , MatchId
				 , LeagueId
				 , HomeId
				 , AwayId
				 , RequestType
				 , Usernames
				 , ProductIds
				 , TicketStatusIds
				 , FromWinlostDate
				 , ToWinlostDate
				 , SubIssueTypeId
			)
			SELECT @RequestId
				 , t.MatchId 
				 , ISNULL(m.leagueid, 0) 
				 , ISNULL(m.homeid, 0) 
				 , ISNULL(m.awayid, 0) 
				 , CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				 , @UserNames
				 , @ProductIds
				 , @StatusIds
				 , @FromDate
				 , @ToDate
				 , @SubIssueTypeId
			FROM #TempMatch t
				LEFT JOIN dbo.match m WITH(NOLOCK) ON t.MatchId = m.matchid
			WHERE t.IsOutright = 0

		END
		IF EXISTS (SELECT TOP 1 1 FROM #TempMatch WHERE IsOutright = 1) -- outright
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
				   RequestId
				 , MatchId
				 , LeagueId
				 , HomeId
				 , AwayId
				 , RequestType
				 , Usernames
				 , ProductIds
				 , TicketStatusIds
				 , FromWinlostDate
				 , ToWinlostDate
				 , SubIssueTypeId
			)
			SELECT @RequestId
				 , t.MatchId 
				 , ISNULL(m.leagueid, 0) 
				 , ISNULL(m.teamid, 0) 
				 , 0
				 , CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				 , @UserNames
				 , @ProductIds
				 , @StatusIds
				 , @FromDate
				 , @ToDate
				 , @SubIssueTypeId
			FROM #TempMatch t
				INNER JOIN dbo.outright m WITH(NOLOCK) ON t.MatchId = m.orid
			WHERE t.IsOutright = 1
		END
		
		-- Insert queue for auto void
		IF @ActionId = 4 AND EXISTS (SELECT TOP 1 1 FROM #TempMatch)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			SELECT @RequestId, m.MatchId, 'VoidInstant', 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			FROM #TempMatch m
		END
	END
	ELSE IF @IssueTypeId = 17 --Archived Ticket
	BEGIN
		INSERT INTO #transIdTemp  (transid, statusID, MatchId, bettype)
		SELECT DISTINCT t.value, b14.statusId, b14.matchid, b14.bettype
		FROM STRING_SPLIT(@TransIds, ',') t
			INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON CAST (t.value AS BIGINT) = b14.transid
		WHERE value <> ''

		INSERT INTO #TempMatch(MatchId, IsOutright)
		SELECT  DISTINCT matchid,
				CASE WHEN bettype <> 10 THEN 0 
					 WHEN bettype = 10 THEN 1 
					 ELSE NULL END
		FROM #transIdTemp

	   IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE IsOutright = 0)
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
				   RequestId
				 , MatchId
				 , LeagueId
				 , HomeId
				 , AwayId
				 , SubIssueTypeId
				 , FilterBy
			)
			SELECT @RequestId
				 , t.MatchId 
				 , ISNULL(m14.leagueid, 0) 
				 , ISNULL(m14.homeid, 0) 
				 , ISNULL(m14.awayid, 0) 
				 , @SubIssueTypeId
				 , @FilterBy
			FROM #TempMatch t
				LEFT JOIN dbo.match14 m14 WITH(NOLOCK) ON t.MatchId = m14.matchid
			WHERE t.IsOutright = 0

		END
		IF EXISTS (SELECT TOP 1 1 FROM #TempMatch WHERE IsOutright = 1) -- outright
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
				   RequestId
				 , MatchId
				 , LeagueId
				 , HomeId
				 , AwayId
				 , SubIssueTypeId
				 , FilterBy
			)
			SELECT @RequestId
				 , t.MatchId 
				 , ISNULL(o14.leagueid, 0) 
				 , ISNULL(o14.teamid, 0) 
				 , 0
				 , @SubIssueTypeId
				 , @FilterBy
			FROM #TempMatch t
				INNER JOIN dbo.outright14 o14 WITH(NOLOCK) ON t.MatchId = o14.orid
			WHERE t.IsOutright = 1
		END

	END
	ELSE IF @IssueTypeId IN (4,5,6,7) --Wrong HDP (4) & 1H HDP(5), Wrong OU(6) & 1H OU(7)
	BEGIN
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
			, FilterFromBetId
			, FilterToBetId
			, FilterBy
			, SingleCount
			, MainParlayCount
			, MinSingleTransId
			, MaxSingleTransId
			, MinMainParlayTransId
			, MaxMainParlayTransId
			, VoidFromTime
			, VoidToTime
			, IssueDetail
			, SubIssueTypeId
			, TransIds
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
			, l.FilterFromBetId
			, l.FilterToBetId
			, l.FilterBy
			, l.SingleCount
			, l.MainParlayCount
			, l.MinSingleTransId
			, l.MaxSingleTransId
			, l.MinMainParlayTransId
			, l.MaxMainParlayTransId
			, l.VoidFromTime
			, l.VoidToTime
			, l.LiveScores
			, l.SubIssueTypeId
			, l.WrongHDP
		FROM #tblGetLogInfo l
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
	END

	-- Insert queue for auto void
	IF @IssueTypeId IN (11,15) AND @Sporttype <= 99
	BEGIN
		-- mark ticket and not take note
		IF @ActionId <>2
		BEGIN
			-- mark ticket
			SELECT @MarkedTransIds = STUFF(
				(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
				FROM #transid_tmp tp
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid AND mt.matchid = tp.matchid)
					AND  tp.StatusId IN (0, 1) 
				GROUP BY TransId for XML PATH('')), 1, 1, ''
				)
		
			IF @MarkedTransIds IS NOT NULL
			BEGIN
				SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
				EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
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
		     INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			 SELECT @RequestId, MatchId, 'MixParlay', 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			 FROM @tblMatchId 
		END
	END
	-- Get content of log data 
	SET @LogDataContent = ''
	IF @IssueTypeId IN (11,15) OR @TransIds IS NOT NULL
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', TransIds: ' + @TransIds
	END
	ELSE IF @IssueTypeId IN (1,10)
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
		SET @LogDataContent += ' Username: ' + CAST(@UserNames AS NVARCHAR(MAX)) 
							+ ', ProductIds: '+ CAST(@ProductIds AS VARCHAR(50))
							+ ', SubIssueTypeID: '+ CAST(@SubIssueTypeId AS VARCHAR(50))
							+ ', StatusIds: '+ CAST(@StatusIds AS VARCHAR(50))
							+ ', From Date: '+ CONVERT(VARCHAR(10), @FromDate, 23)
							+ ', To Date: '+ CASE WHEN @ToDate IS NOT NULL THEN CONVERT(VARCHAR(10), @ToDate, 23) ELSE 'NULL' END
	END
	ELSE IF @IssueTypeId IN (8,9) OR @KickOffTime IS NOT NULL
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
		DECLARE @actualscore VARCHAR(50)

		SELECT @actualscore = SUBSTRING(l.LiveScores, CHARINDEX(';Act:',l.LiveScores) + 5, LEN(l.LiveScores))
			, @MatchId = l.MatchID, @FilterBy = l.FilterBy
		FROM #tblGetLogInfo l

		IF @FilterBy <> 2
		BEGIN
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
		ELSE
		BEGIN
			SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20)) 
							   + ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							    + ', Actual Score: ' + @actualscore
							   + ', FilterFrom: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
							   + ', FilterTo: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21) 
							   + ', VoidFrom: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							   + ', VoidTo: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							   + ', TypeAccept: ' + l.TypeAccept
			FROM #tblGetLogInfo l
		END
	END
	ELSE IF @IssueTypeId = 17 OR @TransIds IS NOT NULL
	BEGIN
		SET @LogDataContent += ' TransIds: ' + @TransIds
	END
	ELSE IF @IssueTypeId IN (4,5,6,7)
	BEGIN
		SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20))
							   + CASE WHEN @IssueTypeId IN (4,5) THEN ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20)) ELSE '' END
							   + CASE WHEN l.FilterBy = 0 THEN ', FilterFromBetId: ' + CONVERT(VARCHAR(30), l.FilterFromBetId, 21) + ', FilterToBetId: ' + CONVERT(VARCHAR(30), l.FilterToBetId, 21)
									  WHEN l.FilterBy = 1 THEN ', FilterFromTransTime: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) +  ', FilterToTransTime: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
									  ELSE '' END
							   + ', VoidFromTime: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							   + ', VoidToTime: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							   + CASE WHEN @IssueTypeId = 4 THEN ' ,WrongHDP: ' + l.WrongHDP
									  WHEN @IssueTypeId = 5 THEN ' ,Wrong1stHDP: ' + l.WrongHDP 
									  WHEN @IssueTypeId = 6 THEN ' ,WrongOU: ' + l.WrongHDP 
									  WHEN @IssueTypeId = 7 THEN ' ,Wrong1stOU: ' + l.WrongHDP 
									  ELSE '' END
								FROM #tblGetLogInfo l
	END
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
							+ @LogDataContent
						AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #transIdTemp
	DROP TABLE #transid_tmp
	DROP TABLE #TempMatch
	DROP TABLE #InputValidCustid_tmp
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #TransidInRequest
	DROP TABLE #tblGetLogInfo
	
END
GO