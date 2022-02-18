/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_Select]
(	
	@MatchId              INT = 0
	,@RequestId			  INT = 0
	,@UserID			  INT
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@SubIssueTypeId	  INT = NULL
	,@KickOffTime		  DATETIME = NULL
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo  VARCHAR(MAX) = NULL
	,@RedCardInfo		  VARCHAR(MAX) = NULL
	,@WrongHDPInfo		  VARCHAR(MAX) = NULL
	,@Wrong1stHDPInfo	  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20201002@Max: [TVS] - Modify bet type list on Home/Away Team filter of Danger Accept [Redmine: #142883]
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201015@Max: [TVS] - HotFix - Danger accept add by accept time can add ticket super live [Redmine: #143308]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201102@Max: TVS - Enhance for Danger Accept - Phase 4 - Show LogInfo when voided [Redmine: #143091]
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210322@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210510@Max: [TVS] Danger Accept/Red Card Enhancement - Search and save not same log info [Redmine: #154772]
		- 20210511@Max: TVS - Wrong Score [Redmine: #140953]
		- 20210524@Max: [TVS] Wrong Score - Void 2H tickets in range time [Redmine: #155598]
		- 20210528@Max: Exclude some group bettypes [Redmine: #155598]
		- 20210531@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210526@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210611@Max: [TVS] Hotfix Highlight Min TransId [Redmine: #156832]
		- 20210617@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210619@Helen: SP Tuning [Redmine: #157249]
		- 20210621@Max: [TVS] EKO & Wrong Kick Off Time - Warning tickets existed on other request not show Transid [Redmine: #156728]
		- 20210803@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20210817@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20211012@July: TVS - Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211210@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220110@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220208@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]

	Param's explanation:
		+ @WrongScoreInfo:
		<root>
			<r LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" ScoreId='3966607' FilterBy="" />
		</root>
		+ @DangerAcceptedInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterBy="" SubIssueTypeId=""/></root>
		+ @RedCardInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterBy="" SubIssueTypeId=""/></root>
		+ @WrongHDPInfo, @Wrong1stHDPInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterFromBetId ="" FilterToBetId = "" FilterBy="" HomeFavorite ="" AwayFavorite ="" HdpValue ="" SubIssueTypeId=""/></root>
	
		(Filterby 1: By Transdate, 2: By Checktime, 4: Filter by Transdate & Checktime)
*/
BEGIN
	SET NOCOUNT ON 

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	
			SET @sqlCommand = 'EXEC dbo.TicketVoiding_LogInfo_Select '
					+ CASE WHEN @MatchId IS NULL THEN '' ELSE '@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
					+ CASE WHEN @RequestId IS NULL THEN '' ELSE ',@RequestId = ' + CONVERT(NVARCHAR(50), @RequestId) END
					+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
					+ CASE WHEN @IssueTypeId IS NULL THEN '' ELSE ',@IssueTypeId = ' + CONVERT(NVARCHAR(50), @IssueTypeId) END
					+ CASE WHEN @ActionId IS NULL THEN '' ELSE ',@ActionId = ' + CONVERT(NVARCHAR(50), @ActionId) END
					+ CASE WHEN @IsShowLogOnly IS NULL THEN '' ELSE ',@IsShowLogOnly = ' + CONVERT(NVARCHAR(50), @IsShowLogOnly) END
					+ CASE WHEN @SubIssueTypeId IS NULL THEN '' ELSE ',@SubIssueTypeId = ' + CONVERT(NVARCHAR(50), @SubIssueTypeId) END
					+ CASE WHEN @KickOffTime IS NULL THEN '' ELSE ',@KickOffTime = ''' + CONVERT(NVARCHAR(50), @KickOffTime, 21) + '''' END
					+ CASE WHEN @WrongScoreInfo IS NULL THEN '' ELSE ',@WrongScoreInfo = ''' + CONVERT(NVARCHAR(MAX), @WrongScoreInfo) + '''' END
					+ CASE WHEN @DangerAcceptedInfo IS NULL THEN '' ELSE ',@DangerAcceptedInfo = ''' + CONVERT(NVARCHAR(MAX), @DangerAcceptedInfo) + '''' END
					+ CASE WHEN @RedCardInfo IS NULL THEN '' ELSE ',@RedCardInfo = ''' + CONVERT(NVARCHAR(MAX), @RedCardInfo) + '''' END	
					+ CASE WHEN @WrongHDPInfo IS NULL THEN '' ELSE ',@WrongHDPInfo = ''' + CONVERT(NVARCHAR(MAX), @WrongHDPInfo) + '''' END
					+ CASE WHEN @Wrong1stHDPInfo IS NULL THEN '' ELSE ',@Wrong1stHDPInfo = ''' + CONVERT(NVARCHAR(MAX), @Wrong1stHDPInfo) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserID, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @IsInvalidTransId		  BIT = 0
			,@IsInValidTotalTickets   BIT = 0
			,@IsExistedInOtherRequest BIT = 0
			,@SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@IsExistSingle			  BIT = 0
			,@IsExistParlay			  BIT = 0
			,@IsExistFM				  BIT = 0
			,@IsExistFM2			  BIT = 0
			,@MatchProcessXML		  XML = NULL
			,@MatchParlayProcessXML	  XML = NULL
			,@TotalRefnoParlay		  INT = 0
			,@ThreadHold			  INT = 0-- over threadhold, the parlay process will be locked in systemsetting
			,@FilterBy				  TINYINT = 0
	
	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@DangerAcceptedInfoXML	  XML = NULL
			,@RedCardInfoXML		  XML = NULL
			,@WrongHDPInfoXML		  XML = NULL	
			,@Wrong1stHDPInfoXML	  XML = NULL
		
	CREATE TABLE #SpecialDeleteBets (
			GroupID               BIGINT,
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			sporttype             SMALLINT,
			ExtraInfo             VARCHAR(1000),
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			BonusID               INT,
			MainTransId           BIGINT,
			LiveIndicator		  BIT,
			StatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			ScoreId				  INT,
			FilterBy			  TINYINT		
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode		BIGINT,
			custid		INT,
			bettype		SMALLINT,
			transid		BIGINT,
			MatchId		INT,
			SubIssueTypeId SMALLINT,
			ScoreId		INT,
			FilterBy TINYINT
	)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	CREATE TABLE #logInfo (
		 MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,CashOutCount			INT
		,InstantlySettleCount	INT
		,SettleCount            INT
		,MainParlayCount		INT
		,MinSingleTransId		BIGINT
		,MaxSingleTransId		BIGINT
		,MinMainParlayTransId	BIGINT
		,MaxMainParlayTransId	BIGINT
		,HighLightTransId		BIGINT
		,HighlightAcceptType	TINYINT
		,ScoreId				INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, ScoreId INT, Refno BIGINT)
	CREATE TABLE #CashOuts (RequestId INT, MatchId INT, transid BIGINT, bettype SMALLINT, ScoreId INT)
	--CREATE TABLE #WrongScores (ScoreId INT, MatchId INT, LiveHomeScore SMALLINT, LiveAwayScore SMALLINT, FilterFromTime DATETIME, FilterToTime DATETIME, FilterBy TINYINT)
	CREATE TABLE #FilterInfo (
		MatchId INT
		, FilterFromTransTime DATETIME
		, FilterToTransTime DATETIME
		, FilterBy	TINYINT
		, SubIssueTypeId SMALLINT
		, ScoreId INT
		, LiveHomeScore SMALLINT
		, LiveAwayScore SMALLINT
	)
	CREATE TABLE #WrongHDP (MatchId INT, FilterFromTransTime DATETIME, FilterToTransTime DATETIME, FilterFromBetId BIGINT, FilterToBetId BIGINT, FilterBy TINYINT, HomeFavorite VARCHAR(50), AwayFavorite VARCHAR(50), HdpValue VARCHAR(50), SubIssueTypeId SMALLINT)
	CREATE TABLE #FilterBetId (MatchId INT, totalBetId INT, totalRecord INT, MinTransdate DATETIME, MaxTransdate DATETIME)
	CREATE TABLE #transIdTemp (matchid INT, transid BIGINT, transdate DATETIME)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblHighlightTransId TABLE (MatchId INT, Transid BIGINT, AcceptType TINYINT, VoidTime DATETIME)
	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreTicket2H VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			livehomescore			 SMALLINT
			,liveawayscore			 SMALLINT
			,IsInvalidTransId		 BIT 
			,IsInValidTotalTickets   BIT 
			,IsExistedInOtherRequest BIT 
			,IsExistSingle			 BIT 
			,IsExistParlay			 BIT 
			,IsExistFM				 BIT 
			,IsExistFM2				 BIT 
			,MatchProcessXML		 XML 
			,MatchParlayProcessXML	 XML
			,LiveScores				 NVARCHAR(300)
			,MatchId                 INT
			,ScoreId                 INT
		)
	DECLARE @InstantlySettleCount_tmp AS TABLE (InstantlySettleCount BIGINT, SettleCount BIGINT, ScoreId INT, RequestId INT, MatchId INT)

	IF @IssueTypeId = 1 --Danger Accept
	BEGIN
		SET @DangerAcceptedInfoXML = CONVERT(XML, @DangerAcceptedInfo)
		INSERT INTO #FilterInfo( 
				MatchID				
				,FilterFromTransTime	
				,FilterToTransTime			
				,FilterBy				
				,SubIssueTypeId
			)
		SELECT t.c.value('@MatchId','INT') AS MatchID
				,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
				,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
				,t.c.value('@FilterBy','TINYINT') AS FilterBy
				,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
		FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))

	END
	ELSE IF @IssueTypeId = 10 --Red Card
	BEGIN
		SET @RedCardInfoXML = CONVERT(XML, @RedCardInfo)
		INSERT INTO #FilterInfo( 
				MatchID				
				,FilterFromTransTime	
				,FilterToTransTime			
				,FilterBy				
				,SubIssueTypeId
			)
		SELECT t.c.value('@MatchId','INT') AS MatchID
			  ,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			  ,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
			  ,t.c.value('@FilterBy','TINYINT') AS FilterBy
			  ,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
		FROM @RedCardInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@RedCardInfoXML = NULL))

	END
	ELSE IF @IssueTypeId IN (3)--WC
	BEGIN
		SET @WrongScoreInfoXML = CONVERT(XML, @WrongScoreInfo)
		
		INSERT INTO #FilterInfo(MatchId, LiveHomeScore, LiveAwayScore, FilterFromTransTime, FilterToTransTime, ScoreId, FilterBy, SubIssueTypeId)
		SELECT	@MatchId
				,T.C.value('./@LiveHomeScore', 'smallint')
				,T.C.value('./@LiveAwayScore', 'smallint')
				,T.C.value('./@FilterFromTransTime', 'datetime')
				,T.C.value('./@FilterToTransTime', 'datetime')
				,T.C.value('./@ScoreId', 'int')
				,T.C.value('./@FilterBy', 'tinyint')
				,@SubIssueTypeId
		FROM	@WrongScoreInfoXML.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL ))

		SET @FilterBy = (SELECT DISTINCT FilterBy FROM #FilterInfo)
	END
	ELSE IF @IssueTypeId IN (8,9)--WC, E
	BEGIN
		INSERT INTO #FilterInfo( 
				MatchID				
				,FilterFromTransTime	
				,FilterToTransTime			
				,FilterBy				
				,SubIssueTypeId
			)
		SELECT @MatchId, NULL, NULL, @FilterBy, @SubIssueTypeId
	END

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype_matchid ON #InstantSettlementBettypes(bettype, matchid)

		--> Get status of match
		;WITH cte_match AS
		(
			SELECT t.matchid
			FROM #FilterInfo t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
		)
		,cte_isCalHT AS
		(
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM cte_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		)
		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO #InstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM cte_isCalHT c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_Set_Instant_GetBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	 	
	END	

	IF @IssueTypeId IN (1,10)
	BEGIN
		/*Generate LogInfo*/
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

		--Init Validation
		INSERT INTO @Validation (MatchId)
		SELECT MatchId
		FROM #FilterInfo
		
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid				
				,transdate		
				,bettype 					
				,livehomescore 	
				,liveawayscore 			
				,betdaqid	
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,LiveIndicator
				,matchid
				,StatusId
				,checktime
				,accepttype
				,SubIssueTypeId
				,FilterBy
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.transdate
				,b.bettype
				,b.livehomescore
				,b.liveawayscore
				,b.betdaqid
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.liveindicator
				,b.matchid
				,b.statusID
				,b.checktime
				,CASE 
							WHEN b.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN b.checktime = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0) + ISNULL(bi.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
						END AS accepttype
				,d.SubIssueTypeId
				,d.FilterBy
		FROM	bettrans b WITH (NOLOCK)	
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
			INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
			AND b.betfrom <> 'P'
			AND CASE WHEN d.FilterBy = 1 THEN b.transdate 
					    WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
					    WHEN d.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
					    END BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
			AND NOT EXISTS (SELECT TOP 1 1 
							FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
							WHERE f.bettype = b.bettype 
								AND f.SubIssueTypeId = d.SubIssueTypeId 
								AND f.IssueTypeId = @IssueTypeId)
		
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #FilterInfo d ON d.MatchId = bm.matchid
				WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
								 WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								 ELSE 0 END
					AND bm.betfrom <> 'P'
				)
		BEGIN		
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid						
					,transdate		
					,bettype					
					,livehomescore	
					,liveawayscore			
					,IsMixParlay
					,LiveIndicator
					,matchid
					,StatusId
					,checktime
					,accepttype
					,SubIssueTypeId
					,FilterBy
				)
			SELECT 
					main.transid AS GroupID
					,main.transid AS TransId
					,sub.transid AS SubTransID
					,sub.refno
					,sub.custid				
					,sub.transdate
					,main.bettype
					,sub.livehomescore
					,sub.liveawayscore
					,1 AS IsMixParlay
					,sub.liveindicator
					,sub.matchid
					,main.statusID
					,sub.checktime
					,CASE 
							WHEN sub.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN sub.checktime = DATEADD(SECOND,ISNULL(sub.LiveBetAcceptTime,0) + ISNULL(sub.SecAcceptTime,0), sub.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
					 END AS accepttype
					 ,d.SubIssueTypeId
					 ,d.FilterBy
			FROM	#FilterInfo d
					INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = d.MatchId
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno 
			WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						   ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND CASE WHEN d.FilterBy = 1 THEN sub.transdate
							 WHEN d.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							 WHEN d.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
						END BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
					AND NOT EXISTS (SELECT TOP 1 1 
									FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
									WHERE f.bettype = sub.bettype 
										AND f.SubIssueTypeId = d.SubIssueTypeId 
										AND f.IssueTypeId = @IssueTypeId)
		END 

	END
	IF @IssueTypeId IN (8,9)
	BEGIN
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid					
				,transdate		
				,bettype 				
				,livehomescore 	
				,liveawayscore 		
				,betdaqid	
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,LiveIndicator
				,matchid
				,StatusId
				,checktime
				,FilterBy
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.transdate
				,b.bettype
				,b.livehomescore
				,b.liveawayscore
				,b.betdaqid
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.liveindicator
				,@MatchId
				,b.statusID
				,b.checktime
				,1 AS FilterBy
		FROM	bettrans b WITH (NOLOCK)	
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			OUTER APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
								INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
							WHERE rs.TransId = b.transid
								AND rs.MatchId = @MatchId
								AND r.ActionId NOT IN (2)
								AND 1= CASE WHEN @RequestId <> 0 AND rs.RequestId = @RequestId THEN 0
											ELSE 1 END
					)tmp
		WHERE	b.matchid = @matchid
				AND b.transdate >= @KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.liveindicator = 0
				AND b.bettype NOT IN (805, 806, 9, 29)			
				AND b.bettype NOT BETWEEN 901 AND 920
				AND b.betfrom <> 'P'	
		
		-- Metric Gaming Super Live
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid					
				,transdate		
				,bettype 				
				,livehomescore 	
				,liveawayscore 		
				,betdaqid
				,LiveIndicator
				,matchid
				,StatusId
				,checktime
				,FilterBy
			)	
		SELECT 
				b.TranslogID AS GroupID
				,b.TranslogID AS TransId
				,b.TranslogID AS SubTransID
				,b.TranslogID refno
				,b.custid
				,b.transdate
				,b.GameID
				,NULL livehomescore
				,NULL liveawayscore
				,-1 AS betdaqid -- normal ticket
				,b.liveindicator
				,@MatchId
				,b.statusID
				,NULL
				,1 AS FilterBy
		FROM	Translog b WITH (NOLOCK)
				LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId		
		WHERE	b.EventID = @matchid
				AND b.transdate >= @KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.liveindicator = 0
				AND b.GameID IN (805, 806) 
				AND b.betfrom <> 'P'
									
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
					AND bm.transdate >= @KickOffTime
					AND 1= CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND bm.liveindicator = 0
					AND bm.betfrom <> 'P'
				)
		BEGIN		
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid							
					,transdate		
					,bettype					
					,livehomescore	
					,liveawayscore		
					,IsMixParlay
					,LiveIndicator
					,matchid
					,StatusId
					,checktime
					,FilterBy
				)
			SELECT 
					main.transid AS GroupID
					,main.transid AS TransId
					,sub.transid AS SubTransID
					,sub.refno
					,sub.custid				
					,sub.transdate
					,main.bettype
					,sub.livehomescore
					,sub.liveawayscore
					,1 AS IsMixParlay
					,sub.liveindicator
					,@MatchId
					,main.statusID
					,sub.checktime
					,1 AS FilterBy
			FROM	dbo.bettransm sub WITH (NOLOCK)				
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
					OUTER APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
								INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId
							WHERE rs.TransId = sub.transid
								AND rs.MatchId = @MatchId
								AND r.ActionId NOT IN (2)
								AND 1= CASE WHEN @RequestId <> 0 AND rs.RequestId = @RequestId THEN 0
										ELSE 1 END
						)tmp
			WHERE	sub.transdate >= @KickOffTime
					AND 1= CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
								WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND sub.liveindicator = 0
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND main.liveindicator = 0
					AND main.transdate >= @KickOffTime
					AND main.statusID NOT IN (101, 102, 103)
		END 
	END
	IF @IssueTypeId = 3 --Wrong Score
	BEGIN
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
				
		--Init Validation
		INSERT INTO @Validation (livehomescore, liveawayscore, LiveScores, ScoreId, MatchId)
		SELECT DISTINCT livehomescore, liveawayscore, CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores, ScoreId, MatchId
		FROM #FilterInfo
		
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid				
				,transdate		
				,bettype 					
				,livehomescore 	
				,liveawayscore 			
				,betdaqid	
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,LiveIndicator
				,matchid
				,StatusId
				,ScoreId
				,checktime
				,FilterBy
				,accepttype
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.transdate
				,b.bettype
				,b.livehomescore
				,b.liveawayscore
				,b.betdaqid
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.liveindicator
				,@MatchId
				,b.statusID
				,d.ScoreId
				,b.checktime
				,d.FilterBy
				,CASE 
							WHEN b.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN b.checktime = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0) + ISNULL(bi.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
						END AS accepttype
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
			INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
		WHERE	b.matchid = @matchid
				AND 1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.betfrom <> 'P'
				AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
				AND 1 = CASE WHEN d.FilterBy = 1 AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 2 AND ISNULL(b.checktime, b.transdate) BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 4 
								AND ((b.checktime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime) OR (b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime))
							THEN 1
						ELSE 0 END 
				AND NOT EXISTS (SELECT TOP 1 1 
									FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
									WHERE f.bettype = b.bettype 
										AND f.SubIssueTypeId = d.SubIssueTypeId 
										AND f.IssueTypeId = @IssueTypeId)
				
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
					AND 1= CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND bm.betfrom <> 'P'
					AND EXISTS (SELECT TOP 1 1 
								FROM #FilterInfo
								WHERE matchid = @MatchId)
				)
		BEGIN		
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid						
					,transdate		
					,bettype					
					,livehomescore	
					,liveawayscore		
					,IsMixParlay
					,LiveIndicator
					,matchid
					,StatusId
					,ScoreId
					,checktime
					,FilterBy
					,accepttype
				)
			SELECT 
					main.transid AS GroupID
					,main.transid AS TransId
					,sub.transid AS SubTransID
					,sub.refno
					,sub.custid				
					,sub.transdate
					,main.bettype
					,sub.livehomescore
					,sub.liveawayscore
					,1 AS IsMixParlay
					,sub.liveindicator
					,@MatchId
					,main.statusID
					,d.ScoreId
					,sub.checktime
					,d.FilterBy
					,CASE 
							WHEN sub.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN sub.checktime = DATEADD(SECOND,ISNULL(sub.LiveBetAcceptTime,0) + ISNULL(sub.SecAcceptTime,0), sub.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
					 END AS accepttype
			FROM	#FilterInfo d
					INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = d.MatchId			
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
					INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = sub.bettype
					INNER JOIN @bettype_tmp bt ON bt.bettype = sub.bettype
			WHERE 1= CASE WHEN @ActionId <> 2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND main.liveindicator = 0
					AND main.statusID NOT IN (102, 103)
					AND 1 = CASE WHEN sub.livehomescore = 0 AND sub.liveawayscore = 0 AND sub.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
					AND 1 = CASE WHEN d.FilterBy = 1 AND sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 2 AND ISNULL(sub.checktime, sub.transdate) BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 4 
								AND ((sub.checktime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime) OR (sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime))
							THEN 1
						ELSE 0 END 
					AND NOT EXISTS (SELECT TOP 1 1 
									FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
									WHERE f.bettype = sub.bettype 
										AND f.SubIssueTypeId = d.SubIssueTypeId 
										AND f.IssueTypeId = @IssueTypeId)
		END
		
	END
	IF @IssueTypeId IN (4,5) --Wrong HDP, Wrong 1st HDP
	BEGIN
		IF @IssueTypeId = 4
		BEGIN
			SET @WrongHDPInfoXML = CONVERT(XML, @WrongHDPInfo)
			INSERT INTO #WrongHDP( 
					MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
					,FilterBy
					,HomeFavorite
					,AwayFavorite
					,HdpValue
					,SubIssueTypeId
				)
			SELECT t.c.value('@MatchId','INT') AS MatchID
				  ,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
				  ,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
				  ,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
				  ,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
				  ,t.c.value('@FilterBy','TINYINT') AS FilterBy
				  ,CASE WHEN ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') ='' THEN NULL ELSE t.c.value('@HomeFavorite','VARCHAR(50)')  END AS HomeFavorite
				  ,CASE WHEN ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@AwayFavorite','VARCHAR(50)')  END AS AwayFavorite
				  ,CASE WHEN ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@HdpValue','VARCHAR(50)')  END AS HdpValue
				  ,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @WrongHDPInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))
		END
		IF @IssueTypeId = 5
		BEGIN
			SET @Wrong1stHDPInfoXML = CONVERT(XML, @Wrong1stHDPInfo)
			INSERT INTO #WrongHDP( 
					MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
					,FilterFromBetId
					,FilterToBetId
					,FilterBy				
					,HomeFavorite
					,AwayFavorite
					,HdpValue
					,SubIssueTypeId
				)
			SELECT t.c.value('@MatchId','INT') AS MatchID
				  ,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
				  ,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
				  ,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
				  ,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
				  ,t.c.value('@FilterBy','TINYINT') AS FilterBy
				  ,CASE WHEN ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') ='' THEN NULL ELSE t.c.value('@HomeFavorite','VARCHAR(50)')  END AS HomeFavorite
				  ,CASE WHEN ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@AwayFavorite','VARCHAR(50)')  END AS AwayFavorite
				  ,CASE WHEN ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@HdpValue','VARCHAR(50)')  END AS HdpValue
				  ,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @Wrong1stHDPInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@Wrong1stHDPInfoXML = NULL))
		END

		--Init Validation
		INSERT INTO @Validation (MatchId)
		SELECT MatchId FROM #WrongHDP

		/*Check valid transid*/
		IF EXISTS ( SELECT TOP 1 1 FROM #WrongHDP WHERE FilterBy = 0)
		BEGIN
			INSERT INTO #transIdTemp (matchid, transid, transdate)
			SELECT b.matchid, b.transid, b.transdate
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN #WrongHDP f ON b.matchid = f.MatchId        
			WHERE f.FilterBy = 0 AND b.transid IN ( f.FilterFromBetId, f.FilterToBetId)

			INSERT INTO #FilterBetId (MatchId, totalBetId, totalRecord, MinTransdate, MaxTransdate)
			SELECT f.matchid 
				  ,CASE WHEN f.FilterFromBetId = f.FilterToBetId THEN 1 ELSE 2 END AS totalBetId
				  ,b.totalRecord
				  ,MinTransdate
				  ,MaxTransdate
			FROM #WrongHDP f  
			OUTER APPLY (
						  SELECT COUNT (1) totalRecord, MIN (b.transdate) MinTransdate, MAX(transdate) MaxTransdate
						  FROM #transIdTemp  b WITH (NOLOCK) 
						  WHERE b.matchid = f.MatchId
						)b
			WHERE f.FilterBy = 0

			IF  EXISTS ( SELECT TOP 1 1 FROM #FilterBetId
										WHERE 1 = CASE WHEN totalBetId = 2 AND totalRecord <> 2 THEN 1
													   WHEN totalBetId = 1 AND totalRecord <> 1 THEN 1
													   ELSE 0 END
						)
			BEGIN
				SELECT @IsInvalidTransId = 1
			
				--Error Table
				SELECT f.MatchId AS MatchId
					,@IsInvalidTransId AS IsInvalidTransId
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,@IsExistedInOtherRequest AS IsExistedInOtherRequest
					,@IsExistSingle AS IsExistSingle
					,@IsExistParlay AS IsExistParlay
					,@IsExistFM AS IsExistFM
					,@IsExistFM2 AS IsExistFM2
					,@MatchProcessXML AS MatchProcessXML
					,@MatchParlayProcessXML AS MatchParlayProcessXML
				FROM #FilterBetId f 
				WHERE 1 = CASE WHEN totalBetId = 2 AND totalRecord <> 2 THEN 1
							   WHEN totalBetId = 1 AND totalRecord <> 1 THEN 1
							   ELSE 0 END
				
				--TransId in request table
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
					,r.RequestId
				FROM #TransidInRequest r
			
				--Loginfo Table
				SELECT l.MatchId, l.LiveScores, l.VoidFromTime, l.VoidToTime, l.SingleCount, l.MainParlayCount, l.SettleCount, l.MinSingleTransId, l.MaxSingleTransId, l.MinMainParlayTransId, l.MaxMainParlayTransId
				FROM #logInfo l

				RETURN;
			END

			UPDATE w
			SET FilterFromTransTime = t.MinTransdate
			   ,FilterToTransTime = t.MaxTransdate
			FROM #WrongHDP w
				INNER JOIN #FilterBetId t ON w.MatchId = t.matchid

		END
	
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid				
				,transdate		
				,bettype 					
				,livehomescore 	
				,liveawayscore 			
				,betdaqid	
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,LiveIndicator
				,matchid
				,StatusId
				,checktime
				,SubIssueTypeId
				,FilterBy
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.transdate
				,b.bettype
				,b.livehomescore
				,b.liveawayscore
				,b.betdaqid
				,b.ExtraInfo
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.liveindicator
				,b.matchid
				,b.statusID
				,b.checktime
				,d.SubIssueTypeId
				,d.FilterBy
		FROM	bettrans b WITH (NOLOCK)	
			INNER JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.sporttype = 1 --soccer
			INNER JOIN #WrongHDP d ON d.MatchId = b.matchid
			OUTER APPLY (
				SELECT DISTINCT val 
				FROM dbo.f_SplitString(d.HomeFavorite, '&')
				WHERE val <> ''				
			)xHDPHome
			OUTER APPLY (
				SELECT DISTINCT val 
				FROM dbo.f_SplitString(d.AwayFavorite, '&')
				WHERE val <> ''				
			)xHDPAway
			OUTER APPLY (
				SELECT DISTINCT val 
				FROM dbo.f_SplitString(d.HdpValue, '&')
				WHERE val <> ''				
			)xHDPvalue
		WHERE b.betfrom <> 'P'  
			AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND 1 = CASE WHEN @IssueTypeId = 4 AND b.bettype = 1 THEN 1
						 WHEN @IssueTypeId = 5 AND b.bettype = 7 THEN 1 
						 ELSE 0 END
			AND 1 = CASE WHEN d.SubIssueTypeId IN (8,9) AND b.hdp1 = xHDPHome.val AND d.HomeFavorite IS NOT NULL THEN 1
						 WHEN d.SubIssueTypeId IN (8,9) AND b.hdp2 = xHDPAway.val AND d.AwayFavorite IS NOT NULL THEN 1
						 WHEN d.SubIssueTypeId IN (22,24) AND b.hdp2 = xHDPvalue.val AND d.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
						 WHEN d.SubIssueTypeId IN (23,25) AND b.hdp1 = xHDPvalue.val AND d.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
						 ELSE 0 END
			OPTION (MAXRECURSION 0)
	
		---get sub ticket of a mix parlay	
		IF EXISTS ( SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #WrongHDP d ON d.MatchId = bm.matchid
					WHERE 1 = CASE WHEN @ActionId <> 2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
								WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
						AND bm.betfrom <> 'P')
		BEGIN		
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid						
					,transdate		
					,bettype					
					,livehomescore	
					,liveawayscore			
					,IsMixParlay
					,LiveIndicator
					,matchid
					,StatusId
					,checktime
					,SubIssueTypeId
					,FilterBy
				)
			SELECT 
					main.transid AS GroupID
					,main.transid AS TransId
					,sub.transid AS SubTransID
					,sub.refno
					,sub.custid				
					,sub.transdate
					,main.bettype
					,sub.livehomescore
					,sub.liveawayscore
					,1 AS IsMixParlay
					,sub.liveindicator
					,sub.matchid
					,main.statusID
					,sub.checktime
					,d.SubIssueTypeId
					,d.FilterBy
			FROM	#WrongHDP d
					INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = d.MatchId
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) ON	main.refno = sub.refno 
					OUTER APPLY (
						SELECT DISTINCT val 
						FROM dbo.f_SplitString(d.HomeFavorite, '&')
						WHERE val <> ''				
					)xHDPHome
					OUTER APPLY (
						SELECT DISTINCT val 
						FROM dbo.f_SplitString(d.AwayFavorite, '&')
						WHERE val <> ''				
					)xHDPAway
					OUTER APPLY (
						SELECT DISTINCT val 
						FROM dbo.f_SplitString(d.HdpValue, '&')
						WHERE val <> ''				
					)xHDPvalue
			WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
					AND 1 = CASE WHEN @IssueTypeId = 4 AND sub.bettype = 1 THEN 1
								 WHEN @IssueTypeId = 5 AND sub.bettype = 7 THEN 1 
								 ELSE 0 END
					AND 1 = CASE WHEN d.SubIssueTypeId IN (8,9) AND sub.hdp1 = xHDPHome.val AND d.HomeFavorite IS NOT NULL THEN 1
								 WHEN d.SubIssueTypeId IN (8,9) AND sub.hdp2 = xHDPAway.val AND d.AwayFavorite IS NOT NULL THEN 1
								 WHEN d.SubIssueTypeId IN (22,24) AND sub.hdp2 = xHDPvalue.val AND d.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
								 WHEN d.SubIssueTypeId IN (23,25) AND sub.hdp1 = xHDPvalue.val AND d.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
								 ELSE 0 END
					OPTION (MAXRECURSION 0)
		END  
	END
	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #SpecialDeleteBets main
				INNER JOIN #SpecialDeleteBets sub
						ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1					
		  
		-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets  
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, transid, MatchId, SubIssueTypeId, ScoreId, FilterBy)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
				, matchid, SubIssueTypeId, ScoreId, FilterBy
		FROM #SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, matchid, SubIssueTypeId, ScoreId, FilterBy
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #SpecialDeleteBets(
						GroupID			
						,transid		
						,SubTransid		
						,refno			
						,custid					
						,transdate		
						,bettype 					
						,livehomescore 	
						,liveawayscore 			
						,betdaqid
						,ExtraInfo	
						,WalletType
						,RefCode
						,BonusID
						,MainTransId
						,LiveIndicator
						,matchid
						,StatusId
						,checktime
						,SubIssueTypeId
						,ScoreId
						,FilterBy
					)
				SELECT 
						b.transid AS GroupID
						,b.transid
						,b.transid AS SubTransID
						,b.refno
						,b.custid
						,b.transdate
						,b.bettype
						,b.livehomescore
						,b.liveawayscore
						,b.betdaqid
						,b.ExtraInfo
						,b.WalletType
						,b.RefCode
						,b.BonusID
						,t.transid AS MainTransId
						,b.liveindicator
						,b.matchid
						,b.statusID
						,b.checktime
						,t.SubIssueTypeId
						,t.ScoreId
						,t.FilterBy
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = t.MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.bettype 
									AND f.SubIssueTypeId = ISNULL(t.SubIssueTypeId, @SubIssueTypeId)
									AND f.IssueTypeId = @IssueTypeId)
		END  			    				    					    				    					    	
	END
	
	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		IF @IssueTypeId IN (8,9)
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
			SELECT tmp.transid, rd.RequestId, tmp.MainTransId, @MatchId
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.RequestId = r.RequestId
								AND rs.MatchId = @MatchId
							UNION ALL
							SELECT rp.TransId, b.transid AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
								INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
								INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
							WHERE rp.RequestId = r.RequestId
								AND rp.MatchId = @MatchId
					)tmp
			WHERE rd.MatchId = @MatchId
				AND r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2)
		END
		ELSE IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId,Refno)
			SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid,tmp.Refno
			FROM #SpecialDeleteBets t
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId, RequestId, NULL AS Refno
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.TransId = t.transid
								AND rs.MatchId = t.MatchId
							UNION ALL
							SELECT rp.TransId, 0 AS MainTransId, RequestId, bm.refno
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
								INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
							WHERE rp.TransId = t.SubTransid
								AND rp.MatchId = t.matchid
					)tmp
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
			WHERE r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2)
			
			IF EXISTS (SELECT TOP 1 1 FROM #TransidInRequest t WHERE t.Refno IS NOT NULL)
			BEGIN
				UPDATE   t
				  SET MainTransId = b.transid
				FROM   #TransidInRequest  t
				  INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
				WHERE t.Refno IS NOT NULL
			END
			
		END
		ELSE -- 3: Wrong score
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, ScoreId, MatchId)
			SELECT tmp.transid, rd.RequestId, tmp.MainTransId, t.ScoreId, @MatchId
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.RequestId = r.RequestId
								AND rs.MatchId = @MatchId
								AND rs.RequestDetailId = rd.Id
							UNION ALL
							SELECT rp.TransId, b.transid AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
								INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
								INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
							WHERE rp.RequestId = r.RequestId
								AND rp.MatchId = @MatchId
								AND rp.RequestDetailId = rd.Id
					)tmp
				INNER JOIN #SpecialDeleteBets t ON t.SubTransid = tmp.transid
			WHERE rd.MatchId = @MatchId
				AND r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2)
		END

		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1

			IF EXISTS (SELECT TOP (1) 1 FROM @Validation)
			BEGIN
				IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
				BEGIN
					UPDATE v SET v.IsExistedInOtherRequest = 1
					FROM @Validation v
					WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
				END
				ELSE IF @IssueTypeId = 3 AND @FilterBy <> 2
				BEGIN
					UPDATE v SET v.IsExistedInOtherRequest = 1
					FROM @Validation v
					WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.ScoreId = v.ScoreId)
				END
			END
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId, ScoreId)
	SELECT b.matchid AS MatchId
		,CASE WHEN @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2) THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END AS LiveScores
		,MIN(act.VoidTime) AS VoidFromTime
		,MAX(act.VoidTime) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount
		,MIN(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS MinSingleTransId
		,MAX(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS MaxSingleTransId
		,COUNT(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MainParlayCount
		,MIN(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MinMainParlayTransId
		,MAX(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MaxMainParlayTransId
		,b.ScoreId
	FROM #SpecialDeleteBets b WITH (NOLOCK)
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		OUTER APPLY (
				SELECT TOP 1 t.TransId
				FROM #TransidInRequest t 
				WHERE t.TransId = b.SubTransid
		)tmp
		CROSS APPLY (SELECT CASE 
								WHEN b.FilterBy IN (0,1) THEN b.transdate
								WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
								WHEN @FilterBy = 4 THEN b.transdate
							 END AS VoidTime
					)act
	WHERE tmp.TransId IS NULL
	GROUP BY CASE WHEN @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2) THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END
		, b.matchid, b.ScoreId
	ORDER BY b.ScoreId, CASE WHEN @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2) THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		IF @IssueTypeId IN (8,9)
		BEGIN
			SELECT @IsInvalidTransId AS IsInvalidTransId
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,@IsExistedInOtherRequest AS IsExistedInOtherRequest
					,@IsExistSingle AS IsExistSingle
					,@IsExistParlay AS IsExistParlay
					,@IsExistFM AS IsExistFM
					,@IsExistFM2 AS IsExistFM2
					,@MatchProcessXML AS MatchProcessXML
					,@MatchParlayProcessXML AS MatchParlayProcessXML
		END
		ELSE IF @IssueTypeId = 3 AND @FilterBy <> 2
		BEGIN
			SELECT CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
				,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
				,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
				,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
				,ISNULL(IsExistSingle,0) AS IsExistSingle
				,ISNULL(IsExistParlay,0) AS IsExistParlay
				,ISNULL(IsExistFM,0) AS IsExistFM
				,ISNULL(@IsExistFM2,0) AS IsExistFM2
				,MatchProcessXML AS MatchProcessXML
				,MatchParlayProcessXML AS MatchParlayProcessXML
				,ScoreId
			FROM @Validation
		END
		ELSE IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
		BEGIN
			SELECT MatchId
				,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
				,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
				,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
				,ISNULL(IsExistSingle,0) AS IsExistSingle
				,ISNULL(IsExistParlay,0) AS IsExistParlay
				,ISNULL(IsExistFM,0) AS IsExistFM
				,ISNULL(@IsExistFM2,0) AS IsExistFM2
				,MatchProcessXML AS MatchProcessXML
				,MatchParlayProcessXML AS MatchParlayProcessXML
			FROM @Validation
		END

		--TransId in request table
		IF @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2)
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest r
		END
		ELSE
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId
				,NULL AS LiveScores
				,r.ScoreId
			FROM #TransidInRequest r
		END

		/*Get log info for Void Page*/
		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, ScoreId)
		SELECT @RequestId, s.MatchId, s.TransId, b.bettype, CASE WHEN @IssueTypeId = 3 AND @FilterBy <> 2 THEN tmp.ScoreId ELSE NULL END AS ScoreId 
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			CROSS APPLY (
						SELECT CONVERT(XML, r.TransIds)
						FROM dbo.TicketVoiding_RequestDetail r WITH (NOLOCK)
						WHERE r.Id = s.RequestDetailId
							AND r.RequestId = @RequestId
				)AS t(xDATA)
			CROSS APPLY (
					SELECT t.c.value('@ScoreId','INT') AS ScoreId
					FROM t.xDATA.nodes('/r') t(c)
				) tmp (ScoreId)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid AND b.matchid = s.MatchId
		WHERE s.RequestId = @RequestId
			AND b.betdaqid = -2 

		/*Get Instant settlement*/
		IF @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2)
		BEGIN
			INSERT INTO @InstantlySettleCount_tmp (InstantlySettleCount, SettleCount, RequestId, MatchId)
			SELECT COUNT(CASE WHEN i.bettype IS NOT NULL THEN s.TransId ELSE NULL END) AS InstantlySettleCount
				   , COUNT(s.TransId) AS SettleCount
				, @RequestId, b.matchid
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid AND s.MatchId =  b.matchid
				LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
			WHERE s.RequestId = @RequestId
				AND b.statusID IN (111,112,113) AND ISNULL(b.betdaqid, -1) <> -2
			GROUP BY b.matchid

			--Highlight Min TransId (based on the acceptance type of the ticket)
			IF @IssueTypeId IN (1,10) OR (@IssueTypeId = 3 AND @FilterBy = 2)
			BEGIN

				IF EXISTS( SELECT TOP 1 RequestId FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) WHERE RequestId = @RequestId AND MinSingleTransId IS NOT NULL)
				BEGIN
					INSERT INTO @tblHighlightTransId (MatchId, Transid, AcceptType, VoidTime)
					SELECT rd.MatchId, B.transid , CASE 
											WHEN b.checktime IS NULL THEN 1 --Auto Accept
											ELSE CASE 
													  WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
													  ELSE 3 --Pending Accept
												 END
										END AS AcceptType, rd.VoidFromTime
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						CROSS APPLY (
								SELECT b.matchid, b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, bi.LiveBetAcceptTime, bi.SecAcceptTime
								FROM dbo.bettrans b WITH(NOLOCK) 
									LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
								WHERE rd.MatchId = b.matchid AND rd.MinSingleTransId = b.transid
						)b 
						CROSS APPLY (SELECT CASE WHEN rd.FilterBy = 1 THEN b.transdate
												 WHEN rd.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
												 WHEN rd.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
												 WHEN rd.FilterBy = 4 THEN b.transdate
												 END AS VoidTime
									)act
					WHERE rd.VoidFromTime = act.VoidTime AND rd.RequestId = @RequestId

				END
			
				IF EXISTS( SELECT TOP 1 RequestId FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) WHERE RequestId = @RequestId AND MinMainParlayTransId IS NOT NULL)
				BEGIN
					INSERT INTO @tblHighlightTransId (MatchId, Transid, AcceptType, VoidTime)
					SELECT rd.MatchId, s.MainTransId , CASE 
										WHEN b.checktime IS NULL THEN 1 --Auto Accept
										ELSE CASE 
												  WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
												  ELSE 3 --Pending Accept
											 END
									END AS AcceptType, rd.VoidFromTime
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
					INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH(NOLOCK) ON rd.MatchId = s.MatchId AND rd.MinMainParlayTransId = s.MainTransId AND s.RequestId = @RequestId
					CROSS APPLY  (
								SELECT bm.matchid, NULL AS transid, bm.transid AS subtransid, bm.bettype, bm.transdate, bm.checktime, bm.LiveBetAcceptTime, bm.SecAcceptTime
								FROM dbo.bettransm bm WITH(NOLOCK)
								WHERE rd.MatchId = bm.matchid AND s.TransId = bm.transid
							)b
					CROSS APPLY (SELECT CASE WHEN rd.FilterBy = 1 THEN b.transdate
											 WHEN rd.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
											 WHEN rd.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
											 END AS VoidTime
									)act
					WHERE rd.VoidFromTime = act.VoidTime
						AND rd.RequestId = @RequestId
				END
			
			END

			--Check score for void message
			IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
			BEGIN
					INSERT INTO @tblScoreMessage (MatchId, ScoreTicket2H)
					SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.TransId
					WHERE s.RequestId = @RequestId
						AND f.GroupName = '2H'
			END

			IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
			BEGIN
					INSERT INTO @tblScoreMessage (MatchId, ScoreTicket2H)
					SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
						INNER JOIN dbo.bettransm b WITH (NOLOCK) ON b.transid = s.TransId
					WHERE s.RequestId = @RequestId
						AND f.GroupName = '2H'
			END

			IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) 
												INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype			
										WHERE s.RequestId = @RequestId 
											AND f.GroupName <> '2H')

				AND NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) 
												INNER JOIN dbo.bettransm b WITH (NOLOCK) ON b.transid = s.TransId
												INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype			
										WHERE s.RequestId = @RequestId 
											AND f.GroupName <> '2H')
			BEGIN
				UPDATE s 
				SET s.ScoreOfMatch = CAST(m.livehomescore AS VARCHAR(2)) + '-' + CAST(m.liveawayscore AS VARCHAR(2))
				FROM @tblScoreMessage s
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = s.MatchId
			END

			SELECT rd.MatchId
				,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,c.CashOutCount AS CashOutCount
				,t.InstantlySettleCount
				,t.SettleCount
				,rd.MainParlayCount
				,rd.MinSingleTransId
				,rd.MaxSingleTransId
				,rd.MinMainParlayTransId
				,rd.MaxMainParlayTransId
				,h.HighLightTransId
				,h.HighlightAcceptType
				,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreTicket2H
				,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			  OUTER APPLY (
						SELECT COUNT(transid) AS CashOutCount
						FROM #CashOuts
						WHERE RequestId = rd.RequestId AND MatchId = rd.MatchId
				) c
			   OUTER APPLY (
						 SELECT  MatchId, Transid AS HighLightTransId , AcceptType AS HighlightAcceptType
						 FROM @tblHighlightTransId
						 WHERE matchId = rd.MatchId
							AND rd.VoidFromTime = VoidTime
							AND 1 = (CASE WHEN rd.MinSingleTransId IS NOT NULL AND rd.MinSingleTransId = TransId THEN 1
										  WHEN rd.MinMainParlayTransId IS NOT NULL AND rd.MinMainParlayTransId = TransId THEN 1
										  END
									)

					)h
				LEFT JOIN @InstantlySettleCount_tmp t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
				CROSS APPLy(
					SELECT DISTINCT '|' + l.ScoreTicket2H
					FROM @tblScoreMessage l
						where l.MatchId = rd.MatchId
					FOR XML PATH('')
				)s2(ScoreTicket2H)

				CROSS APPLy(
					SELECT DISTINCT '|' + l.ScoreOfMatch
					FROM @tblScoreMessage l
						where l.MatchId = rd.MatchId
					FOR XML PATH('')
				)sm(ScoreOfMatch)
			WHERE rd.RequestId = @RequestId
		END
		ELSE
		BEGIN
			INSERT INTO @InstantlySettleCount_tmp (InstantlySettleCount, SettleCount, ScoreId, RequestId)
			SELECT COUNT(CASE WHEN i.bettype IS NOT NULL THEN s.TransId ELSE NULL END) AS InstantlySettleCount
				  ,COUNT(s.TransId) AS SettleCount
				, tmp.ScoreId, @RequestId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				CROSS APPLY (
							SELECT CONVERT(XML, r.TransIds)
							FROM dbo.TicketVoiding_RequestDetail r WITH (NOLOCK)
							WHERE r.Id = s.RequestDetailId
								AND r.RequestId = @RequestId
					)AS t(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@ScoreId','INT') AS ScoreId
						FROM t.xDATA.nodes('/r') t(c)
					) tmp (ScoreId)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid
				LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
			WHERE s.RequestId = @RequestId
				AND s.MatchId = @MatchId
				AND b.statusID IN (111,112,113) AND ISNULL(b.betdaqid, -1) <> -2
			GROUP BY tmp.ScoreId

			SELECT rd.MatchId
				,CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) AS LiveScores
				,rd.IssueDetail AS ActualScore
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,c.CashOutCount AS CashOutCount
				,t.InstantlySettleCount
				,t.SettleCount
				,rd.MainParlayCount
				,rd.MinSingleTransId
				,rd.MaxSingleTransId
				,rd.MinMainParlayTransId
				,rd.MaxMainParlayTransId
				,tmp.ScoreId AS ScoreId
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					)AS t1(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@ScoreId','INT') AS ScoreId
						FROM t1.xDATA.nodes('/r') t(c)
					) tmp (ScoreId)
				OUTER APPLY (
						SELECT COUNT(transid) AS CashOutCount
						FROM #CashOuts
						WHERE RequestId = rd.RequestId	
							AND MatchId = rd.MatchId
							AND ScoreId = tmp.ScoreId
						GROUP BY ScoreId
					) c
				LEFT JOIN @InstantlySettleCount_tmp t ON t.RequestId = rd.RequestId AND t.ScoreId = tmp.ScoreId
			WHERE rd.RequestId = @RequestId
		END

		-- Write useraction log	
		BEGIN TRY
			IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
			BEGIN	       
				INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
				VALUES (@ID, @spName, NULL, @UserID, @MatchId, GETDATE(),@SubmittedDate)
			END        
		END TRY
		BEGIN CATCH
		END CATCH
		RETURN;
	END

	--For case no ticket valid
	IF @IssueTypeId IN (1,10,3,4,5)
	BEGIN
		SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
			,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
		FROM #logInfo

		IF @SingleCount = 0 AND @MainParlayCount = 0
		BEGIN
			SELECT @IsInValidTotalTickets = 1

			IF @IssueTypeId = 3 AND @FilterBy <> 2
			BEGIN
				SELECT CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
					,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
					,ISNULL(IsExistSingle,0) AS IsExistSingle
					,ISNULL(IsExistParlay,0) AS IsExistParlay
					,ISNULL(IsExistFM,0) AS IsExistFM
					,ISNULL(@IsExistFM2,0) AS IsExistFM2
					,MatchProcessXML AS MatchProcessXML
					,MatchParlayProcessXML AS MatchParlayProcessXML
					,ScoreId
				FROM @Validation
			END
			ELSE IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
			BEGIN 
				SELECT MatchId
					,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
					,ISNULL(IsExistSingle,0) AS IsExistSingle
					,ISNULL(IsExistParlay,0) AS IsExistParlay
					,ISNULL(IsExistFM,0) AS IsExistFM
					,ISNULL(@IsExistFM2,0) AS IsExistFM2
					,MatchProcessXML AS MatchProcessXML
					,MatchParlayProcessXML AS MatchParlayProcessXML
				FROM @Validation
			END

			--TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN
				IF @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2)
				BEGIN
					SELECT RequestId,
						STUFF((
						SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
						FROM #TransidInRequest
						WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
						ORDER BY TransId
						FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
						,1,2,'') AS TransIds
						,MatchId
					FROM #TransidInRequest r
					GROUP BY r.RequestId, r.MatchId
				END
				ELSE 
				BEGIN
					SELECT RequestId,
						STUFF((
						SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
						FROM #TransidInRequest
						WHERE (RequestId = r.RequestId AND ScoreId = r.ScoreId) 
						FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
						,1,2,'') AS TransIds
						,NULL AS LiveScores
						,r.ScoreId
					FROM #TransidInRequest r
					GROUP BY r.RequestId, r.ScoreId
				END
			END
			ELSE
			BEGIN 
				IF @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2)
				BEGIN
					SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
						,r.RequestId, r.MatchId
					FROM #TransidInRequest r
				END
				ELSE
				BEGIN
					SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
						,r.RequestId
						,NULL AS LiveScores
						,r.ScoreId
					FROM #TransidInRequest r
				END
			END
			
			--Loginfo Table
			DELETE #logInfo
			SELECT MatchId, ScoreId FROM #logInfo

			RETURN;
		END
	END
	
	IF @IssueTypeId = 3 AND @FilterBy <> 2
	BEGIN
		UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		FROM @Validation v
			OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE ScoreId = v.ScoreId
				GROUP BY ScoreId
			)l
	END

	IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
	BEGIN
		UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		FROM @Validation v
			OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE MatchId = v.MatchId
				GROUP BY MatchId
			)l
	END 

	---Prepare for lock match---
	IF @IssueTypeId IN (8,9)
	BEGIN
		SELECT @IsExistSingle = MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
				,@IsExistParlay = MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END)
				,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
				,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
		FROM #SpecialDeleteBets AS t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	END
	ELSE IF @IssueTypeId = 3 AND @FilterBy <> 2
	BEGIN
		UPDATE v SET 
				v.IsExistSingle = tmp.IsExistSingle
			, v.IsExistParlay = tmp.IsExistParlay
			, v.IsExistFM = tmp.IsExistFM
			, v.IsExistFM2 = tmp.IsExistFM2
		FROM @Validation v
		CROSS APPLY (
				SELECT   MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END) AS IsExistSingle
						, MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END) AS IsExistParlay
						, MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END) AS  IsExistFM
						, MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END) AS IsExistFM2
				FROM #SpecialDeleteBets AS t
					OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = t.Bettype
					)f
				WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
					AND t.ScoreId = v.ScoreId
				GROUP BY t.ScoreId
			)tmp
	END
	ELSE IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
	BEGIN 
		UPDATE v SET 
				v.IsExistSingle = tmp.IsExistSingle
			, v.IsExistParlay = tmp.IsExistParlay
			, v.IsExistFM = tmp.IsExistFM
			, v.IsExistFM2 = tmp.IsExistFM2
		FROM @Validation v
		CROSS APPLY (
				SELECT   MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END) AS IsExistSingle
						, MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END) AS IsExistParlay
						, MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END) AS  IsExistFM
						, MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END) AS IsExistFM2
				FROM #SpecialDeleteBets AS t
					OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = t.Bettype
					)f
				WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
					AND t.matchid = v.MatchId
				GROUP BY t.matchid
			)tmp
	END

	SET @MatchProcessXML = (
		SELECT DISTINCT t.matchid "@MatchId"
			,CASE 
				WHEN f.GroupId IS NULL THEN 1 --SB
				WHEN f.GroupId = 1 THEN 6 -- Fast Market
				WHEN f.GroupId = 2 THEN 7 -- Fast market 228
				ELSE 0
				END AS "@KeyID"
		FROM #SpecialDeleteBets t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)
	
	--Lock Refno process - SportBook
	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT '' AS MatchId, t.Refno --Many matches with same Refno  
	FROM #SpecialDeleteBets t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
			AND t.IsMixParlay = 1
	GROUP BY t.Refno  
	HAVING COUNT(*) > 1

	SET @TotalRefnoParlay = @@ROWCOUNT
	
	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT  t.MatchId, t.RefNo
	FROM #SpecialDeleteBets t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	  AND NOT EXISTS (SELECT 1 FROM @tblMatchParlay m WHERE m.RefNo = t.refno) 
			AND t.IsMixParlay = 1
	
	SELECT @TotalRefnoParlay = @TotalRefnoParlay + @@ROWCOUNT

	IF @TotalRefnoParlay <= @ThreadHold
	BEGIN
		SET @MatchParlayProcessXML = (
		SELECT  DISTINCT MatchId "@MatchId"
				,refno AS "@RefNo"
		FROM @tblMatchParlay 
		FOR XML PATH('r'), ROOT('root'))
	END	
	ELSE
	BEGIN
		SET @MatchParlayProcessXML = NULL
	END

	UPDATE @Validation SET MatchProcessXML = @MatchProcessXML, MatchParlayProcessXML = @MatchParlayProcessXML

	--Error Table
	IF @IssueTypeId IN (8,9)
	BEGIN
		SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest
				,@IsExistSingle AS IsExistSingle
				,@IsExistParlay AS IsExistParlay
				,@IsExistFM AS IsExistFM
				,@IsExistFM2 AS IsExistFM2
				,@MatchProcessXML AS MatchProcessXML
				,@MatchParlayProcessXML AS MatchParlayProcessXML
	END
	ELSE IF @IssueTypeId = 3 AND @FilterBy <> 2
	BEGIN
		SELECT CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
			,ISNULL(IsExistSingle,0) AS IsExistSingle
			,ISNULL(IsExistParlay,0) AS IsExistParlay
			,ISNULL(IsExistFM,0) AS IsExistFM
			,ISNULL(@IsExistFM2,0) AS IsExistFM2
			,MatchProcessXML AS MatchProcessXML
			,MatchParlayProcessXML AS MatchParlayProcessXML
			,ScoreId
		FROM @Validation
	END
	ELSE IF @IssueTypeId IN (1,10,4,5) OR (@IssueTypeId = 3 AND @FilterBy = 2)
	BEGIN
		SELECT MatchId
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
			,ISNULL(IsExistSingle,0) AS IsExistSingle
			,ISNULL(IsExistParlay,0) AS IsExistParlay
			,ISNULL(IsExistFM,0) AS IsExistFM
			,ISNULL(@IsExistFM2,0) AS IsExistFM2
			,MatchProcessXML AS MatchProcessXML
			,MatchParlayProcessXML AS MatchParlayProcessXML
		FROM @Validation
	END

	--TransId in request table
	--For EKO check transid exists in request		
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		IF @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2)
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE 
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND ScoreId = r.ScoreId) 
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,NULL AS LiveScores
				,r.ScoreId
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.ScoreId
		END
	END
	ELSE
	BEGIN
		IF @IssueTypeId <> 3 OR (@IssueTypeId = 3 AND @FilterBy = 2)
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest r
		END
		ELSE
		BEGIN
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId
				,NULL AS LiveScores
				,r.ScoreId
			FROM #TransidInRequest r
		END
	END

	--Loginfo table
	IF @IssueTypeId IN (8,9,4,5)
	BEGIN
		SELECT MatchId
			,STUFF(w.scores,1,1,'') AS LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
			,SUM(InstantlySettleCount) AS InstantlySettleCount
			,SUM(SettleCount) AS SettleCount
			,SUM(MainParlayCount) AS MainParlayCount
			,MIN(MinSingleTransId) AS MinSingleTransId
			,MAX(MaxSingleTransId) AS MaxSingleTransId
			,MIN(MinMainParlayTransId) AS MinMainParlayTransId
			,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
		FROM #logInfo l
			CROSS APPLY(
						SELECT '|' + LiveScores
						FROM #logInfo rd WITH(NOLOCK)
						where l.MatchId = rd.MatchId
						FOR XML PATH('')
						)w (scores)
		GROUP BY MatchId, w.scores
	END
	ELSE IF @IssueTypeId IN (1,10) OR (@IssueTypeId = 3 AND @FilterBy = 2)
	BEGIN
		;WITH _cte AS (
				SELECT MatchId
					,STUFF(w.scores,1,1,'') AS LiveScores
					,MIN(VoidFromTime) AS VoidFromTime
					,MAX(VoidToTime) AS VoidToTime
					,SUM(SingleCount) AS SingleCount
					,SUM(CashOutCount) AS CashOutCount
					,SUM(InstantlySettleCount) AS InstantlySettleCount
					,SUM(SettleCount) AS SettleCount
					,SUM(MainParlayCount) AS MainParlayCount
					,MIN(MinSingleTransId) AS MinSingleTransId
					,MAX(MaxSingleTransId) AS MaxSingleTransId
					,MIN(MinMainParlayTransId) AS MinMainParlayTransId
					,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
				FROM #logInfo l
					CROSS APPLY(
								SELECT '|' + LiveScores
								FROM #logInfo rd WITH(NOLOCK)
								where l.MatchId = rd.MatchId
								FOR XML PATH('')
								)w (scores) 
				GROUP BY MatchId, w.scores
			)
		SELECT MatchId
			, LiveScores
			,VoidFromTime
			,VoidToTime
			,SingleCount
			,CashOutCount
			,InstantlySettleCount
			,SettleCount
			,MainParlayCount
			,MinSingleTransId
			,MaxSingleTransId
			,MinMainParlayTransId
			,MaxMainParlayTransId
			,tmpHighlight.HighLightTransId AS HighLightTransId
			,tmpHighlight.HighlightAcceptType AS HighlightAcceptType
		FROM _cte l
			CROSS APPLY (SELECT MIN(VoidFromTime) AS VoidFromTime_min
							FROM #logInfo lg 
							WHERE l.matchid = lg.matchid
							) AS Voidtime
			OUTER APPLY (SELECT TOP 1 b.transid AS HighLightTransId
								,b.accepttype HighlightAcceptType
						FROM #SpecialDeleteBets b 
								CROSS APPLY (SELECT CASE WHEN b.FilterBy = 1 THEN b.transdate
															WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
															WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
															END AS VoidTime
								)act
						WHERE l.MatchId = b.matchid AND Voidtime.VoidFromTime_min = act.VoidTime 
							AND 1 = (CASE WHEN l.MinSingleTransId IS NOT NULL AND b.transid = l.MinSingleTransId  THEN 1
											WHEN l.MinMainParlayTransId IS NOT NULL AND b.transid = l.MinMainParlayTransId THEN 1
										END
									)
							ORDER BY CASE WHEN l.MinSingleTransId IS NOT NULL THEN 1 ELSE 0 END DESC
							
				) AS tmpHighlight
	END
	ELSE IF @IssueTypeId = 3 AND @FilterBy <> 2
	BEGIN
		SELECT MatchId
			,LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
			,SUM(InstantlySettleCount) AS InstantlySettleCount
			,SUM(SettleCount) AS SettleCount
			,SUM(MainParlayCount) AS MainParlayCount
			,MIN(MinSingleTransId) AS MinSingleTransId
			,MAX(MaxSingleTransId) AS MaxSingleTransId
			,MIN(MinMainParlayTransId) AS MinMainParlayTransId
			,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
			,ScoreId
		FROM #logInfo l
		GROUP BY MatchId, LiveScores, ScoreId
	END
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	       
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserID, @MatchId, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #CashOuts
	DROP TABLE #InstantSettlementBettypes
	--DROP TABLE #WrongScores
	DROP TABLE #FilterInfo
	DROP TABLE #WrongHDP
	DROP TABLE #FilterBetId
	DROP TABLE #transIdTemp
END
GO

