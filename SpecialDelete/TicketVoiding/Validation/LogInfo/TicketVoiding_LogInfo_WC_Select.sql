/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_WC_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 3
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@OnlineServerId	  VARCHAR(10) = NULL
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type Wrong score [Redmine: #175412]
		- 20220808@July: HF- Request only sub parlay ticket get wrong score show for template message [Redmine: #179752]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230116@July: HF - Edit Request: Log Info has the difference between START TIME void and MIM TIME highlight [Redmine: #182910]
		- 20230112@July: Wrong Score - No need to exclude Home/Away bet types [Redmine: #182805]
		- 20230120@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230324@Max: [TVS] Manage Request enhancement - Phase 13 [Redmine: #185237]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230424@July: [TVS] Enhance auto cancel cash out for TVS [Redmine: #186417]
		- 20230718@Max: WrongScore - Not show data on Void Page - Betlist. [Redmine: #191360]
		- 20230810@July: [TVS] Cancel Cash Out - Update rules get first ticket to void [Redmine: #189644]
		- 20231004@Max: [TVS] Not display Score in message template when voiding non-live tickets only [Redmine: #193108]
		- 20231107@July: HF - Wrong Score - Add request missed Non-live tickets Cash out at time the wrong score [Redmine: #196545]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240124@Max: [TVS] Display more info in the warning message for existing tickets in other requests [Redmine: #199907]
		- 20240102@July: [TVS] Display a note for Min TransId of cash out ticket [Redmine: #199907]
		- 20250403@Lani: [TVS] Get ticket of related event [Redmine: #216151]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]
		- 20250507@July: Fix bug miss filter SiteDBGroupID [Redmine: #226513]
		- 20250512@July: System didnot unmark ticket when user edit request [Redmine: #227009]
		- 20250513@July: DA/RC/WC - Update the validation to get tickets based on allowance setting [Redmine: #227029]
		- 20250716@Lani: [TVS] Enhance TVS in case 1 or many siteDBs down [Phase 2] - DA/RC/WC, Wrong Market Offered/Technical Error [Redmine: #232576]
		- 20250815@Lani: [TVS] Return both running and settle tickets of sitedbdown [Redmine: #232580]
		- 20251009@Lani: [TVS] Wrong Score - Return ExcludedTicketsCount, ExcludedTicketsJson, List of excluded bettypes [Redmine: #236067]
		- 20251117@July: [TVS] Integrate Hybrid Parlay from Jacktime for Basketball sport [Redmine:#241502]

	Param's explanation:
		+ @WrongScoreInfo:
				<root><r MatchId ="" LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" FilterBy="" ScoreId='3966607' AATime="" PATime ="" SATime="" SubIssueTypeId ="" /></root>
		(1: By Transdate, 2: By Checktime, 4: Filter by Transdate & Checktime)

		+ OnlineServerId: '0,1,2,3'
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@FilterBy				  TINYINT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson			  VARBINARY(MAX) = NULL
			,@SiteDBGroupID			  SMALLINT
			,@SiteDBDownInfoJson	  VARBINARY(MAX) = NULL
			,@ExcludedTicketsJson	  VARBINARY(MAX) = NULL
			,@ExcludedTicketsCount	  INT = 0
			,@MatchId				  INT = 0
			,@WrongScoreInfoXML		  XML = NULL
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	CREATE TABLE #TVSTicketBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			Subbettype			  SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			Sublivehomescore	  SMALLINT,
		    Subliveawayscore	  SMALLINT,
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			LiveIndicator		  BIT,
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			ScoreId				  INT,
			IsCancelCashOut		  BIT,
			CheckTimeCashOut	  DATETIME,
			betid				  BIGINT,
			SiteDBGroupID		  SMALLINT,
			IsSiteDBDown		  BIT DEFAULT(0),
			--Support for loginfo exlucded tickets
			Username			  NVARCHAR(50),
			RefCode				  BIGINT,
			ExtraInfo			  VARCHAR(1000),
			Srecommend			  INT,
			Stake				  MONEY,
			Actual_stake		  MONEY,
			Odds				  SMALLMONEY,
			SubOdds				  SMALLMONEY,
			Oddsspread			  MONEY,	
			Oddstype			  TINYINT,
			Betteam				  NVARCHAR(10),
			SubBetteam			  NVARCHAR(10),
			Hdp1				  SMALLMONEY,
			Hdp2				  SMALLMONEY,
			SubHdp1				  SMALLMONEY,			
			SubHdp2				  SMALLMONEY,
			Status				  NVARCHAR(10),
			SubStatus			  NVARCHAR(10),
			Betcheck			  NVARCHAR(50),
			SubCheckTime		  DATETIME,
			SettlementStatus	  TINYINT,
			Winlost				  MONEY,
			IsExcluded			  BIT DEFAULT(0),
			Transdesc			  NVARCHAR(1000),
			WalletType			  TINYINT,
			IsDeposit			  BIT,
			CurrencyName		  NVARCHAR(50),
			HomeId				  INT,
			AwayId				  INT,
			LeagueId			  INT,
			IsNeutral			  INT,
			MatchCode			  NVARCHAR(50),
			Sporttype			  SMALLINT,
			GroupDisplay		  INT,
		    ID					  INT IDENTITY (1,1) PRIMARY KEY
	)

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
		,HighLightMinTime		DATETIME
		,ScoreId				INT
		,CancelCashOutCount		INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, ScoreId INT, CreatedBy INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterBy				TINYINT
		,ScoreId				INT
		,LiveHomeScore			SMALLINT
		,LiveAwayScore			SMALLINT
		,AATime					TINYINT
		,PATime					TINYINT
		,SATime					TINYINT
		,SubIssueTypeId		    INT
		,FilterVoidFromTime		DATETIME
		,FilterVoidToTime		DATETIME
		,isFinish				BIT
		,Sporttype				SMALLINT
		,MatchId_tmp			INT
	)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT, ScoreId INT, CancelCashOutCount INT)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpConsolidatedBettypes AS TABLE
	(
		ParentId	INT
		,TypeId		INT PRIMARY KEY
	)

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,LiveScores				 NVARCHAR(300)
			,MatchId                 INT
			,ScoreId                 INT
			,IsFinish				 BIT
			,ExcludedTicketsJson	 NVARCHAR(MAX)
			,ExcludedTicketsCount	 INT
			,IsExistsSecondAccept	 BIT DEFAULT(0) 	
		)
	SET @WrongScoreInfoXML = CONVERT(XML, @WrongScoreInfo)
		
	INSERT INTO #FilterInfo(MatchId, LiveHomeScore, LiveAwayScore, FilterFromTransTime, FilterToTransTime, FilterBy, ScoreId, AATime, PATime, SATime, SubIssueTypeId, FilterVoidFromTime, FilterVoidToTime)
	SELECT	T.C.value('./@MatchId', 'INT')
			,T.C.value('./@LiveHomeScore', 'SMALLINT')
			,T.C.value('./@LiveAwayScore', 'SMALLINT')
			,T.C.value('./@FilterFromTransTime', 'DATETIME')
			,T.C.value('./@FilterToTransTime', 'DATETIME')
			,T.C.value('./@FilterBy', 'TINYINT')
			,T.C.value('./@ScoreId', 'INT')
			,CASE WHEN T.C.value('@AATime', 'VARCHAR(100)') = '' THEN NULL ELSE T.C.value('@AATime', 'TINYINT') END 
			,CASE WHEN T.C.value('@PATime', 'VARCHAR(100)') = '' THEN NULL ELSE T.C.value('@PATime', 'TINYINT') END 
			,CASE WHEN T.C.value('@SATime', 'VARCHAR(100)') = '' THEN NULL ELSE T.C.value('@SATime', 'TINYINT') END 
			,T.C.value('./@SubIssueTypeId', 'INT')
			,CASE WHEN T.C.value('./@VoidFromTime', 'DATETIME')  = '1900-01-01 00:00:00.000' THEN NULL ELSE T.C.value('./@VoidFromTime', 'DATETIME') END AS FilterVoidFromTime 
			,CASE WHEN T.C.value('./@VoidToTime', 'DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE T.C.value('./@VoidToTime', 'DATETIME') END AS FilterVoidToTime
	FROM @WrongScoreInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL ))

	--Init Validation
	INSERT INTO @Validation (MatchId, ScoreId, LiveScores, IsInValidTotalTickets)
	SELECT DISTINCT MatchId, ScoreId, CAST(livehomescore AS VARCHAR(10)) + '-' + CAST(liveawayscore AS VARCHAR(10)) AS LiveScores
	      ,CASE WHEN FilterVoidFromTime IS NULL AND FilterVoidToTime IS NULL THEN 1 ELSE 0 END AS IsInValidTotalTickets
	FROM #FilterInfo

	INSERT INTO @bettype_tmp (bettype)
	SELECT bettype FROM dbo.f_TVS_GetValidBettypes()

	INSERT INTO @tmpConsolidatedBettypes (ParentId, TypeId)
	SELECT f.GroupTypeId AS ParentId
		  ,f.Bettype AS TypeId
	FROM [dbo].[f_SD_GroupDisplayBettype] () AS f
	
	BEGIN -- Instant Settlement declaration

		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		DECLARE @MatchIds VARCHAR(MAX)
		SELECT @MatchIds = STRING_AGG(CAST(MatchId AS VARCHAR), ',') 
		FROM #FilterInfo
		
		INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
		SELECT matchid, bettype, betid 
		FROM dbo.f_TVS_GetInstantSettlementBettypes(@MatchIds)
		
	END

	UPDATE d
	SET d.Sporttype = m.sporttype, MatchId_tmp = d.MatchId
	FROM #FilterInfo d
		INNER JOIN dbo.match m WITH (NOLOCK) ON d.MatchId = m.MatchId

	--Cricket/Baseball - Get child match
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE Sporttype IN (50,8))
	BEGIN
		INSERT INTO #FilterInfo (MatchId, LiveHomeScore, LiveAwayScore, FilterFromTransTime, FilterToTransTime, FilterBy, ScoreId, AATime, PATime, SATime, SubIssueTypeId, Sporttype, MatchId_tmp)
		SELECT d.MatchId, d.LiveHomeScore, d.LiveAwayScore, FilterFromTransTime, FilterToTransTime, FilterBy, ScoreId, AATime, PATime, SATime, SubIssueTypeId
			  , m.Sporttype
			  , m.MatchId AS MatchId_tmp
		FROM #FilterInfo d
		INNER JOIN dbo.match m WITH(NOLOCK) ON d.MatchId = m.ParentID
		WHERE m.sporttype IN (50,8) AND m.ChildMatchType = 200 
	END

	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid				
			,transdate		
			,bettype 					
			,Subbettype
			,livehomescore 	
			,liveawayscore 			
			,Sublivehomescore
			,Subliveawayscore
			,betdaqid	
			,betid
			,SiteDBGroupID
			,LiveIndicator
			,matchid
			,StatusId
			,SubStatusId
			,ScoreId
			,checktime
			,accepttype
			,IsCancelCashOut
			,IsSiteDBDown
			,Hdp1
			,Hdp2
			,SubHdp1	
			,SubHdp2
			,Betcheck
			,SubCheckTime
			,Transdesc
			,WalletType
			,RefCode
			,ExtraInfo
			,Srecommend
			,Winlost
			,Actual_stake
			,Stake
			,Odds
			,SubOdds
			,Oddsspread	
			,Oddstype
			,Status
			,SubStatus
			,CurrencyName
			,Betteam
			,SubBetteam
			,GroupDisplay
		)
	SELECT DISTINCT  b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.bettype AS Subbettype
			,b.livehomescore
			,b.liveawayscore
			,b.livehomescore AS Sublivehomescore
			,b.liveawayscore AS Subliveawayscore
			,b.betdaqid
			,b.betid
			,b.SiteDBGroupID
			,b.liveindicator
			,d.matchid
			,b.statusID
			,b.statusID AS SubstatusID
			,d.ScoreId
			,b.checktime
			,CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
				  ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0) + ISNULL(bi.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
							ELSE 3 END --Pending Accept
				  END AS accepttype
			,0 AS IsCancelCashOut
			,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
			,b.hdp1
			,b.hdp2
			,b.hdp1 AS SubHdp1
			,b.hdp2 AS SubHdp2
			,b.betcheck
			,b.checktime AS Subchecktime
			,b.transdesc
			,b.WalletType
			,b.RefCode
			,b.ExtraInfo
			,b.srecommend
			,b.winlost
			,b.actual_stake
			,b.stake
			,b.odds
			,b.odds AS Subodds
			,b.oddsspread
			,b.oddstype
			,b.status
			,b.status AS SubStatus
			,b.CurrencyName
			,b.betteam
			,b.betteam AS SubBetteam
			,ISNULL(tb.ParentId,b.bettype) AS GroupDisplay
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
		LEFT JOIN @tmpConsolidatedBettypes AS tb ON tb.TypeId = b.bettype
	WHERE  1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END
		AND b.betfrom <> 'P'
		AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
		AND 1 = CASE WHEN d.FilterBy = 1 AND b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
					 WHEN d.FilterBy = 2 AND ISNULL(b.checktime, b.transdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
					 WHEN d.FilterBy = 4 AND ((b.checktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime))THEN 1
					ELSE 0 END
		AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,b.SiteDBGroupID,@OnlineServerId) = 1

	-- Get ticket cancel cashout
	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid				
			,transdate		
			,bettype 					
			,Subbettype
			,livehomescore 	
			,liveawayscore 
			,Sublivehomescore
			,Subliveawayscore
			,betdaqid	
			,betid
			,SiteDBGroupID
			,LiveIndicator
			,matchid
			,StatusId
			,SubStatusId
			,ScoreId
			,checktime
			,accepttype
			,IsCancelCashOut
			,CheckTimeCashOut
			,IsSiteDBDown
			,Betcheck
			,SubCheckTime
			,Transdesc
			,WalletType
			,RefCode
			,ExtraInfo
			,Srecommend
			,Winlost
			,Actual_stake
			,Stake
			,Odds
			,SubOdds
			,Oddsspread	
			,Oddstype
			,Status
			,SubStatus
			,CurrencyName
			,Betteam
			,SubBetteam
			,Hdp1
			,Hdp2
			,SubHdp1	
			,SubHdp2
			,GroupDisplay
		)
	SELECT DISTINCT b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.bettype AS Subbettype
			,b.livehomescore
			,b.liveawayscore
			,b.livehomescore AS Sublivehomescore
			,b.liveawayscore AS Subliveawayscore
			,b.betdaqid
			,b.betid
			,b.SiteDBGroupID
			,b.liveindicator
			,d.matchid
			,b.statusID
			,b.statusID AS SubstatusID
			,d.ScoreId
			,b.checktime
			,CASE WHEN c.AcceptMode = 0 THEN 3 ELSE c.AcceptMode END AS accepttype
			,1 AS IsCancelCashOut
		    ,c.CheckTime
			,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
			,b.betcheck
			,b.checktime AS Subchecktime
			,b.transdesc
			,b.WalletType
			,b.RefCode
			,b.ExtraInfo
			,b.srecommend
			,b.winlost
			,b.actual_stake
			,b.stake
			,b.odds
			,b.odds AS Subodds
			,b.oddsspread
			,b.oddstype
			,b.status
			,b.status AS SubStatus
			,b.CurrencyName
			,b.betteam
			,b.betteam AS SubBetteam
			,b.hdp1
			,b.hdp2
			,b.hdp1 AS SubHdp1
			,b.hdp2 AS SubHdp2
			,ISNULL(tb.ParentId,b.bettype) AS GroupDisplay
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
		LEFT JOIN @tmpConsolidatedBettypes AS tb ON tb.TypeId = b.bettype
	WHERE  1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END
			AND b.betdaqid = -2 AND c.AcceptMode IS NOT NULL
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN d.FilterBy = 1
							AND b.transdate NOT BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime 
							AND	c.CheckTime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime 
						THEN 1
						 WHEN d.FilterBy = 2 
							AND ISNULL(b.checktime, b.transdate) NOT BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime 
							AND	c.CheckTime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime 
						THEN 1
						 WHEN d.FilterBy = 4
							AND ((b.checktime NOT BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.transdate NOT BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime))
							AND	c.CheckTime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime 
						THEN 1
					   ELSE 0 END 
		   AND NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets t WHERE t.transid = b.transid)
		   AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,b.SiteDBGroupID,@OnlineServerId) = 1

	-- Fix case: wrong score 2 Score: Original score 1, Canel CO: Score 2
	DECLARE @tmpRemoveDuplCancelCO TABLE (TransId BIGINT)
	INSERT INTO @tmpRemoveDuplCancelCO (TransId)
	SELECT TransId
	FROM #TVSTicketBets 
	GROUP BY transid
	HAVING COUNT(TransId) >=2

	IF EXISTS (SELECT TOP 1 1 FROM @tmpRemoveDuplCancelCO)
	BEGIN
		DELETE t
		FROM #TVSTicketBets t
		WHERE t.IsCancelCashOut = 1 
		 AND t.transid IN ( SELECT transid FROM @tmpRemoveDuplCancelCO)
	END

	---get sub ticket of a mix parlay	
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #FilterInfo d ON d.MatchId_tmp = bm.matchid
					WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
								   WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								   ELSE 0 END
						AND bm.betfrom <> 'P' 
						AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,bm.SiteDBGroupID,@OnlineServerId) = 1
					)
	BEGIN		
		INSERT INTO #TVSTicketBets(
				transid		
				,SubTransid		
				,refno			
				,custid						
				,transdate		
				,bettype					
				,Subbettype
				,betid
				,SiteDBGroupID
				,livehomescore	
				,liveawayscore	
				,Sublivehomescore
				,Subliveawayscore
				,IsMixParlay
				,LiveIndicator
				,matchid
				,StatusId
				,SubStatusId
				,ScoreId
				,checktime
				,accepttype
				,IsCancelCashOut
				,IsSiteDBDown
				,Stake
				,Odds
				,SubOdds
				,Oddsspread	
				,Oddstype
				,Betcheck
				,SubCheckTime
				,Transdesc
				,WalletType
				,RefCode
				,ExtraInfo
				,Srecommend
				,Winlost
				,Actual_stake
				,Status
				,SubStatus
				,CurrencyName
				,Betteam
				,SubBetteam
				,Hdp1
				,Hdp2
				,SubHdp1	
				,SubHdp2
				,GroupDisplay
			)
		SELECT DISTINCT b.transid 
				,sub.TransID
				,b.refno
				,sub.custid				
				,sub.transdate
				,b.bettype
				,sub.bettype AS Subbettype
				,b.betid
				,b.SiteDBGroupID
				,b.livehomescore
				,b.liveawayscore
				,sub.livehomescore AS Sublivehomescore
				,sub.liveawayscore AS Subliveawayscore
				,1 AS IsMixParlay
				,sub.liveindicator
				,d.matchid
				,b.statusID
				,sub.statusID AS SubStatusId
				,d.ScoreId
				,sub.checktime
				,CASE WHEN sub.checktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN sub.checktime = DATEADD(SECOND,ISNULL(sub.LiveBetAcceptTime,0) + ISNULL(sub.SecAcceptTime,0), sub.transdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
				,0 AS IsCancelCashOut
				,CASE WHEN sub.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END AS IsSiteDBDown
				,b.stake
				,b.odds
				,sub.odds AS Subodds
				,b.oddsspread
				,b.oddstype
				,sub.betcheck
				,sub.checktime AS Subchecktime
				,b.transdesc
				,b.WalletType
				,b.RefCode
				,b.ExtraInfo
				,b.srecommend
				,b.winlost
				,b.actual_stake
				,b.status
				,sub.status AS SubStatus
				,b.CurrencyName
				,b.betteam
				,sub.betteam AS SubBetteam
				,b.hdp1
				,b.hdp2
				,sub.hdp1 AS SubHdp1
				,sub.hdp2 AS SubHdp2
				,ISNULL(tb.ParentId,sub.bettype) AS GroupDisplay
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			INNER JOIN @bettype_tmp bt ON bt.bettype = sub.bettype
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = sub.bettype
			LEFT JOIN @tmpConsolidatedBettypes AS tb ON tb.TypeId = sub.bettype
		WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
			AND b.liveindicator = 0
			AND b.statusID NOT IN (102, 103)
			AND sub.betfrom <> 'P'
			AND b.matchid = 29 AND b.bettype = 29
			AND b.SiteDBGroupID = sub.SiteDBGroupID
			AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,sub.SiteDBGroupID,@OnlineServerId) = 1
			AND 1 = CASE WHEN sub.livehomescore = 0 AND sub.liveawayscore = 0 AND sub.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
			AND 1 = CASE WHEN d.FilterBy = 1 AND sub.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						    WHEN d.FilterBy = 2 AND ISNULL(sub.checktime, sub.transdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						    WHEN d.FilterBy = 4 AND ((sub.checktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (sub.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime)) THEN 1
						ELSE 0 END 
	END

	UPDATE b
	SET MatchCode = m.matchcode
		,HomeId = m.homeid
		,AwayId = m.awayid
		,LeagueId = m.leagueid
		,IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT,0))
		,SettlementStatus = ISNULL(m.SettlementStatus,0)
		,username = ci.username
		,Sporttype = m.sporttype
	FROM #TVSTicketBets AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
		INNER JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK) ON b.custid = ci.custid

	UPDATE b
	SET IsDeposit = 1
	FROM #TVSTicketBets AS b
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH (NOLOCK) WHERE d.custid = b.srecommend)

	UPDATE b
	SET b.IsExcluded = 1
	FROM #TVSTicketBets AS b
	INNER JOIN #FilterInfo AS d ON b.matchid = d.MatchId
	WHERE EXISTS ( SELECT TOP 1 1 
				   FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
				   WHERE f.bettype = b.Subbettype AND f.SubIssueTypeId = d.SubIssueTypeId AND f.IssueTypeId = @IssueTypeId)

	SELECT TOP (1) @FilterBy = FilterBy
	FROM #FilterInfo

	/*Get Transid in Request of range Transid*/
	DECLARE @TransInfoJson_Request		VARBINARY(MAX)
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	SET @MaxRow = (SELECT MAX(ID) FROM #TVSTicketBets WHERE IsExcluded = 0)
	SET @Threshold = 20000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold
	IF @ActionId <> 2
	BEGIN
		WHILE (@MaxRow IS NOT NULL)
		BEGIN
		
				SET @TransInfoJson_Request = COMPRESS((SELECT matchid AS 'mid'
						,transid AS 't'
						,SubTransid AS 's_t'
						,ScoreId AS 'score'
				FROM #TVSTicketBets R
				WHERE (ID BETWEEN @StartRow AND @StopRow) AND IsExcluded = 0
					FOR JSON PATH))

				INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId, ScoreId, CreatedBy)
				EXEC DBCTG.bodb02.dbo.TicketVoiding_CheckExistingRequest
					@TransInfoJson = @TransInfoJson_Request
					,@RequestId = @RequestId
					,@Mode = 1
					,@IssueTypeId = @IssueTypeId

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END
		
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid) AND IsExcluded = 0
		
		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
				INNER JOIN #TransidInRequest t ON t.MatchId = v.MatchId
				INNER JOIN #FilterInfo f ON f.MatchId = t.MatchId AND f.ScoreId = v.ScoreId
			WHERE 1 = CASE WHEN f.FilterBy = 2 THEN 1
						   WHEN f.FilterBy <> 2 AND t.ScoreId = v.ScoreId THEN 1
						   ELSE 0 END
		END
	END

	--Get ticket of sitedb down 
	BEGIN
		DECLARE @tmpSiteDBDownInfo TABLE (
			MatchId INT,
			TransId BIGINT,
			IsMixParlay BIT,
			SiteDBGroupID SMALLINT,
			isMarked BIT,
			IsCancelCashOut BIT
		);
		DECLARE @SingleCountSiteDBDown INT
		       ,@ParlayCountSiteDBDown INT
			   ,@CancelCashOutSiteDBDown INT

		INSERT INTO @tmpSiteDBDownInfo (MatchId, TransId, IsMixParlay, SiteDBGroupID, isMarked, IsCancelCashOut)
		SELECT MatchId, SubTransid, IsMixParlay, SiteDBGroupID, CASE WHEN SubStatusId IN (0,1) THEN 1 ELSE 0 END AS isMarked, IsCancelCashOut
		FROM #TVSTicketBets
		WHERE IsSiteDBDown = 1 AND IsExcluded = 0;

		SELECT @SingleCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 0 AND IsCancelCashOut = 0 THEN 1 ELSE NULL END)
		      ,@ParlayCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 1 THEN 1 ELSE NULL END)
			  ,@CancelCashOutSiteDBDown = COUNT(CASE WHEN IsCancelCashOut = 1 THEN 1 ELSE NULL END)
		FROM @tmpSiteDBDownInfo
	END
	
	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MainParlayCount, ScoreId, HighLightMinTime)
	SELECT f.MatchId AS MatchId
		,CASE WHEN f.FilterBy = 2 THEN CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) ELSE NULL END AS LiveScores
		,MIN(act.VoidTime) AS VoidFromTime
		,MAX(act.VoidTime) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,b.ScoreId
		,MIN(act.VoidTime) AS HighLightMinTime
	FROM #TVSTicketBets b
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		INNER JOIN #FilterInfo f ON f.MatchId = b.matchid AND f.ScoreId = b.ScoreId
		CROSS APPLY (SELECT CASE 
								WHEN f.FilterBy IN (1,4) THEN b.transdate
								WHEN f.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN f.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							 END AS VoidTime
					)act
	WHERE b.IsCancelCashOut <> 1 AND b.IsSiteDBDown = 0 AND b.IsExcluded = 0 -- Not count ticket cancel CO
	GROUP BY CASE WHEN f.FilterBy = 2 THEN CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId, f.MatchId
	ORDER BY CASE WHEN f.FilterBy = 2 THEN CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) ELSE NULL END ASC, b.ScoreId ASC, f.MatchId ASC

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsCancelCashOut = 1 AND IsExcluded = 0)
	BEGIN
		
		IF NOT EXISTS ( SELECT TOP 1 1 FROM #logInfo) --For case sitedb only cancel CO
		BEGIN
			INSERT INTO #logInfo (MatchId, LiveScores, ScoreId, VoidFromTime, VoidToTime, HighLightMinTime)
			SELECT b.matchid, NULL ,b.ScoreId
				  ,MIN(b.CheckTimeCashOut) AS VoidFromTime
				  ,MAX(b.CheckTimeCashOut) AS VoidToTime
				  ,MIN(b.CheckTimeCashOut) AS HighLightMinTime
			FROM #TVSTicketBets b
			WHERE b.IsSiteDBDown = 0 AND IsExcluded = 0
			GROUP BY b.matchid, b.ScoreId
		END
		
		UPDATE li
		SET CancelCashOutCount = b.CancelCashOutCount
		   ,VoidFromTime = CASE WHEN b.MIN_CheckTimeCashOut < li.VoidFromTime THEN b.MIN_CheckTimeCashOut ELSE li.VoidFromTime END
		   ,VoidToTime = CASE WHEN b.MAX_CheckTimeCashOut >  li.VoidToTime THEN b.MAX_CheckTimeCashOut ELSE li.VoidToTime END
		   ,HighLightMinTime = CASE WHEN b.MIN_CheckTimeCashOut < li.HighLightMinTime THEN b.MIN_CheckTimeCashOut ELSE li.HighLightMinTime END
		FROM #logInfo li
			CROSS APPLY(
				SELECT COUNT(b.transid) AS CancelCashOutCount
					  ,MIN(CheckTimeCashOut) AS MIN_CheckTimeCashOut
					  ,MAX(CheckTimeCashOut) AS MAX_CheckTimeCashOut
				FROM #TVSTicketBets b
				WHERE li.MatchId = b.matchid AND b.IsCancelCashOut = 1 AND li.ScoreId = b.ScoreId AND b.IsSiteDBDown = 0 AND IsExcluded = 0
				GROUP BY b.matchid, b.ScoreId
			)b
	END

	--Not display Score in message template when voiding non-live tickets only [193108]
	IF NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE liveindicator = 1 AND IsSiteDBDown = 0 AND IsExcluded = 0)
	BEGIN
		UPDATE l SET l.LiveScores = ''
		FROM #logInfo l
	END

	/* Display warning message in case void second accept tickets before the allowance time of this type */
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE FilterBy = 2) AND EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE accepttype = 2 AND IsSiteDBDown = 0 AND IsExcluded = 0)
	BEGIN
		DECLARE @tmp_SAChecking AS TABLE (MatchId INT, VoidFromTime DATETIME, SAFromTime DATETIME)
		INSERT INTO @tmp_SAChecking (MatchId, VoidFromTime, SAFromTime)
		SELECT l.MatchId, MIN(l.VoidFromTime), f.SAFromTime
		FROM #logInfo l 
			CROSS APPLY (
				SELECT DATEADD(SECOND, f.SATime, f.FilterFromTransTime) AS SAFromTime
				FROM #FilterInfo f 
				WHERE f.MatchId = l.MatchId
			)f
		GROUP BY l.MatchId, f.SAFromTime

		DELETE s
		FROM @tmp_SAChecking s
		WHERE s.VoidFromTime > s.SAFromTime

		UPDATE v SET v.IsExistsSecondAccept = CASE WHEN l.IsExistsSecondAccept IS NOT NULL THEN 1 ELSE 0 END
		FROM @Validation v
		OUTER APPLY( 
				SELECT TOP 1 1 AS IsExistsSecondAccept
				FROM #logInfo l
					INNER JOIN @tmp_SAChecking s ON s.MatchId = l.MatchId
					INNER JOIN #TVSTicketBets t ON t.matchid = l.MatchId AND t.IsSiteDBDown = 0
					INNER JOIN #FilterInfo f ON t.matchid = f.MatchId AND t.ScoreId = f.ScoreId
				WHERE t.accepttype = 2
					AND t.IsExcluded = 0
					AND v.MatchId = l.MatchId
					AND v.ScoreId = l.ScoreId
					AND 1 = CASE WHEN f.FilterBy = 1 AND t.transdate BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
								 WHEN f.FilterBy = 2 AND t.checktime IS NOT NULL AND t.checktime BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
								 WHEN f.FilterBy = 2 AND t.checktime IS NULL AND t.transdate BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
							ELSE 0 END
			)l
		
	END
	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, SingleCount INT, MainParlayCount INT, ActionId TINYINT, Id INT, Livehomescore INT, Liveawayscore INT, ExcludedTickets NVARCHAR(MAX))
	CREATE TABLE #CTE_Ticket_Single (RequestId INT, MatchId INT, TransId BIGINT, Bettype SMALLINT, IsCancelCO BIT, RequestDetailId INT)
	CREATE TABLE #CTE_Ticket_SubParlay (RequestId INT, MatchId INT, TransId BIGINT, RequestDetailId INT)

	DECLARE @cnt_s INT , @cnt_p INT	

	INSERT INTO #CTE_RequestDetail (RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, ActionId, Id, Livehomescore, Liveawayscore)
	SELECT rd.RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, ActionId, rd.Id, rd.LiveHomeScore, rd.LiveAwayScore
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
	WHERE rd.RequestId = @RequestId

	INSERT INTO #CTE_Ticket_Single (RequestId, MatchId, TransId, Bettype, IsCancelCO, RequestDetailId)
	SELECT RequestId, MatchId, TransId, Bettype, IsCancelCO, RequestDetailId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
	WHERE RequestId = @RequestId 
		AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,SiteDBGroupID,@OnlineServerId) = 1
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId, RequestDetailId)
	SELECT RequestId, MatchId, TransId, RequestDetailId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId 
		AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,SiteDBGroupID,@OnlineServerId) = 1
	SET @cnt_p = @@ROWCOUNT

	--Get info detail of excluded tickets
	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsExcluded = 1)
	BEGIN
		--Update ExcludedTicketsJson and ExcludedTicketsCount
		WHILE (1=1)
		BEGIN
			SET @MatchId = (SELECT TOP 1 MatchId FROM @Validation WHERE IsFinish IS NULL)

			UPDATE v
			SET v.IsFinish = 1
			FROM @Validation AS v
			WHERE MatchId = @MatchId

			IF @@ROWCOUNT = 0 BREAK;

			SET @ExcludedTicketsJson = COMPRESS((
				SELECT t.TransId AS 'TransId'
					  ,Refno AS 'RefNo'
					  ,SubTransid AS 'SubTransId'
					  ,UserName AS 'UserName'
					  ,BetId AS 'BetId'
					  ,BetCheck AS 'BetCheck'
					  ,SubCheckTime AS 'SubCheckTime'
					  ,IsMixParlay AS 'IsMixParlay'
					  ,Transdesc AS 'Transdesc'
					  ,Betdaqid AS 'Betdaqid'
					  ,Wallettype AS 'WalletType'
					  ,RefCode AS 'RefCode'
					  ,CAST(Winlost AS VARCHAR) AS 'WinLost'
					  ,Liveindicator AS 'IsLiveIndicator'
					  ,Actual_stake AS 'ActualStake'
					  ,ExtraInfo AS 'ExtraInfo'
					  ,IsDeposit AS 'IsDeposit'
					  ,t.MatchId AS 'MatchId'
					  ,HomeId AS 'HomeId'
					  ,AwayId AS 'AwayId'
					  ,LeagueId AS 'LeagueId'
					  ,IsNeutral AS 'IsNeutral'
					  ,MatchCode AS 'MatchCode'
					  ,SettlementStatus AS 'SettlementStatus'
					  ,Sporttype AS 'Sporttype'
					  ,IsCancelCashOut AS 'IsCancelCashOut'
					  ,Transdate AS 'Transdate'
					  ,Stake AS 'Stake'
					  ,Odds AS 'Odds'
					  ,SubOdds AS 'SubOdds'
					  ,Oddsspread AS 'Oddsspread'
					  ,OddsType AS 'OddsType'
					  ,Bettype AS 'Bettype'
					  ,Subbettype AS 'Subbettype'
					  ,Status AS 'Status'
					  ,Substatus AS 'Substatus'
					  ,Currencyname AS 'CurrencyName'
					  ,Betteam AS 'Betteam'
					  ,Subbetteam AS 'Subbetteam'
					  ,Subhdp1 AS 'SubHdp1'
					  ,SubHdp2 AS 'SubHdp2'
					  ,Hdp1 AS 'Hdp1'
					  ,Hdp2 AS 'Hdp2'
					  ,Livehomescore AS 'Livehomescore'
					  ,Liveawayscore AS 'Liveawayscore'
					  ,GroupDisplay AS 'GroupBettypeId'
					  ,CASE WHEN IsMixParlay = 1 THEN 'Parlay' ELSE 'Single' END AS 'GroupName'
				FROM #TVSTicketBets AS t
				WHERE t.MatchId = @MatchId AND t.IsExcluded = 1
			FOR JSON PATH))

			SET @ExcludedTicketsCount = (SELECT COUNT(1) FROM #TVSTicketBets WHERE MatchId = @MatchId AND IsExcluded = 1)

			UPDATE v
			SET v.ExcludedTicketsJson = CONVERT(VARCHAR(MAX),@ExcludedTicketsJson,1)
			   ,v.ExcludedTicketsCount = @ExcludedTicketsCount
			FROM @Validation AS v
			WHERE MatchId = @MatchId
		END
		
		DELETE b 
		FROM #TVSTicketBets AS b
		WHERE b.IsExcluded = 1
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, InstantlySettleCount, SettleCount, ScoreId, CancelCashOutCount)
		SELECT @RequestId
			  ,s.matchid
			  ,COUNT(CASE WHEN b.IsCancelCashOut = 0 AND ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
			  ,tmp.ScoreId
			  ,COUNT(CASE WHEN s.IsCancelCO = 1 THEN s.transid ELSE NULL END) AS CancelCashOutCount
		FROM #CTE_Ticket_Single s WITH (NOLOCK)
			CROSS APPLY (
						SELECT CONVERT(XML, r.TransIds)
						FROM #CTE_RequestDetail r WITH (NOLOCK)
						WHERE r.Id = s.RequestDetailId
							AND r.RequestId = @RequestId
				)AS t(xDATA)
			CROSS APPLY (
					SELECT t.c.value('@ScoreId','INT') AS ScoreId
					FROM t.xDATA.nodes('/r') t(c)
				) tmp (ScoreId)
			LEFT JOIN #TVSTicketBets b ON s.MatchId = b.matchid AND s.TransId = b.transid AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = s.MatchId
		WHERE b.StatusId IN (111, 112, 113)
		GROUP BY s.matchid, tmp.ScoreId

		IF @FilterBy <> 2
		BEGIN
			-- 1. Validate table
			SELECT LiveScores
				,IsInValidTotalTickets
				,IsExistedInOtherRequest
				,ScoreId
				,MatchId
			FROM @Validation

			-- 2. TransId in request table
			SELECT RequestId, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds, MatchId
			FROM #TransidInRequest

			-- 3.Loginfo table
			SELECT rd.MatchId
				,CASE WHEN @SiteDBGroupID = 0 THEN SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) ELSE NULL END AS LiveScores
				,CASE WHEN @SiteDBGroupID = 0 THEN rd.IssueDetail ELSE NULL END AS ActualScore
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.SingleCount ELSE NULL END AS SingleCount
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.MainParlayCount ELSE NULL END AS MainParlayCount
				,tmp.CashOutCount
				,tmp.InstantlySettleCount
				,tmp.SettleCount
				,a.ScoreId AS ScoreId
				,tmp.CancelCashOutCount
				,a.HighLightMinTime
				,a.HighlightAcceptType
				,a.MinTransId
				,a.ActionType
				,NULL AS ExcludedTicketsJson
				,NULL AS ExcludedTicketsCount
			FROM #CTE_RequestDetail rd WITH (NOLOCK)
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					)AS t1(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@ScoreId','INT') AS ScoreId
							,NULLIF(t.c.value('@MinTime','DATETIME'),'') AS  HighLightMinTime
							,t.c.value('@MinType','TINYINT') AS  HighlightAcceptType
							,t.c.value('@MinTransId','BIGINT') AS  MinTransId
							,t.c.value('@ActionType','VARCHAR(100)') AS  ActionType
						FROM t1.xDATA.nodes('/r') t(c)
					) a
				LEFT JOIN #logInfoVoidPage tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId AND tmp.ScoreId = a.ScoreId
			WHERE rd.RequestId = @RequestId 

		END
		ELSE IF @FilterBy = 2
		BEGIN
			-- 1. Validate table
			SELECT MatchId
				,IsInValidTotalTickets
				,IsExistedInOtherRequest
			FROM @Validation

			-- 2. TransId in request table
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest
			
			--Check score for void message
			IF @cnt_s > 0
			BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
				SELECT b.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
				FROM #CTE_Ticket_Single s WITH (NOLOCK)
					INNER JOIN #TVSTicketBets b ON b.transid = s.TransId AND b.IsMixParlay = 0
					INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
				WHERE f.GroupName <> '2H' AND ISNULL(s.IsCancelCO,0) = 0 --Exclude cancel CO
			END

			IF @cnt_p > 0
			BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
				SELECT b.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
				FROM #CTE_Ticket_SubParlay s WITH (NOLOCK)
					INNER JOIN #TVSTicketBets b ON b.Subtransid = s.TransId AND b.IsMixParlay = 1
					INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype			
				WHERE f.GroupName <> '2H'
			END

			IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
			BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
				SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(10)) + '-' + CAST(m.liveawayscore AS VARCHAR(10))
				FROM #CTE_RequestDetail rd WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
			END

			SELECT rd.MatchId
				,CASE WHEN @SiteDBGroupID = 0 THEN SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) ELSE NULL END AS LiveScores
				,CASE WHEN @SiteDBGroupID = 0 THEN rd.IssueDetail ELSE NULL END AS ActualScore
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.SingleCount ELSE NULL END AS SingleCount
			    ,CASE WHEN @SiteDBGroupID = 0 THEN rd.MainParlayCount ELSE NULL END AS MainParlayCount
				,tmp.CashOutCount AS CashOutCount
				,tmp.InstantlySettleCount
				,tmp.SettleCount
				,a.HighLightMinTime
				,a.HighlightAcceptType
				,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
				,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
				,tmp.CancelCashOutCount
				,a.MinTransId
				,a.ActionType
				,v.ExcludedTicketsJson AS ExcludedTicketsJson
				,v.ExcludedTicketsCount AS ExcludedTicketsCount
			FROM #CTE_RequestDetail rd WITH (NOLOCK)
				INNER JOIN @Validation AS v ON rd.MatchId = v.MatchId
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					)AS t1(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@ScoreId','INT') AS ScoreId
							,NULLIF(t.c.value('@MinTime','DATETIME'),'') AS  HighLightMinTime
							,t.c.value('@MinType','TINYINT') AS  HighlightAcceptType
							,t.c.value('@MinTransId','BIGINT') AS  MinTransId
							,t.c.value('@ActionType','VARCHAR(100)') AS  ActionType
						FROM t1.xDATA.nodes('/r') t(c)
					) a
			   LEFT JOIN #logInfoVoidPage tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId
				CROSS APPLY(
					SELECT DISTINCT '|' + l.ScoreNormalTicket FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
				)s2(ScoreTicket2H)
				CROSS APPLY(
					SELECT DISTINCT '|' + l.ScoreOfMatch FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
				)sm(ScoreOfMatch)
			WHERE rd.RequestId = @RequestId

		END
			
		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		RETURN;
	END

	IF @FilterBy <> 2
	BEGIN
		UPDATE v 
		SET  v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		FROM @Validation v
		OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE ScoreId = v.ScoreId
				GROUP BY ScoreId
			)l
		
	END
	ELSE IF @FilterBy = 2
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

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		INSERT INTO @tmpMarkTransId (TransId)
		SELECT tp.SubTransid
		FROM #TVSTicketBets tp
		WHERE tp.SubStatusId IN (0,1) AND tp.IsSiteDBDown = 0
	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SET @OldActionId = (SELECT TOP 1 ISNULL(ActionId,0) FROM #CTE_RequestDetail WITH(NOLOCK))

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT um.TransId
			FROM ( 
					SELECT TransId FROM #CTE_Ticket_Single s
					UNION ALL 
					SELECT TransId FROM #CTE_Ticket_SubParlay p
				)um
				LEFT JOIN #TVSTicketBets tp ON um.TransId = tp.SubTransid AND tp.IsSiteDBDown = 0
			WHERE tp.TransId IS NULL

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1) AND tp.IsSiteDBDown = 0
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1) AND tp.IsSiteDBDown = 0
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			--Unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT TransId FROM #CTE_Ticket_Single s
			UNION ALL 
			SELECT TransId FROM #CTE_Ticket_SubParlay p
		END

	END
	
	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,''),'')

	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId
											FOR XML PATH('')), 1,1,''),'')

	/*****************Return table **************************/

	IF @FilterBy <> 2
	BEGIN
		-- 1. Validate table
		SELECT LiveScores
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,ScoreId
			,MatchId
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			;WITH ChildListCTE AS (
				SELECT 
					r.ScoreId,
					r.RequestId, 
					r.MatchId, 
					r.MainTransId, 
					c.username AS CreatedBy,
					COUNT(r.TransId) AS TotalCount,
					MIN(CASE WHEN r.MainTransId = r.TransId THEN 1 ELSE 0 END) AS HasMainSelf,
					STUFF((
						SELECT ',' + CAST(r2.TransId AS VARCHAR(50))
						FROM #TransidInRequest r2
						WHERE r2.MainTransId = r.MainTransId
						ORDER BY r2.TransId ASC 
						FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS ChildList
				FROM #TransidInRequest r
				INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
				GROUP BY r.ScoreId, r.RequestId, r.MatchId, r.MainTransId, c.username
			)
			SELECT 
				r.ScoreId,
				r.RequestId, 
				r.MatchId,
				STUFF((
					SELECT ', ' + 
						CASE 
							WHEN r2.TotalCount > 1 -- If MainTransId >=2 child → combine MainTransId(child1,child2,...) => hybrid parlay
							THEN CAST(r2.MainTransId AS VARCHAR(50)) + '(' + REPLACE(r2.ChildList, CAST(r2.MainTransId AS VARCHAR(50)) + ',', '') + ')' 
							ELSE CAST(r2.MainTransId AS VARCHAR(50))
						END
					FROM ChildListCTE r2
					WHERE r2.ScoreId = r.ScoreId AND r2.RequestId = r.RequestId AND r2.MatchId = r.MatchId 
					ORDER BY r2.MainTransId ASC
					FOR XML PATH(''), TYPE
				).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS TransIds,
				r.CreatedBy
			FROM ChildListCTE r
			GROUP BY r.ScoreId, r.RequestId, r.MatchId, r.CreatedBy;

		END
		ELSE
		BEGIN
			SELECT RequestId, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds, MatchId
			FROM #TransidInRequest
		END

		-- 3. Loginfo table
		SELECT l.MatchId
			,l.LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
			,SUM(InstantlySettleCount) AS InstantlySettleCount
			,SUM(SettleCount) AS SettleCount
			,SUM(MainParlayCount) AS MainParlayCount
			,l.ScoreId
			,MIN(CancelCashOutCount) AS CancelCashOutCount
			,NULL AS ExcludedTicketsJson
			,NULL AS ExcludedTicketsCount
		FROM #logInfo l
		GROUP BY l.MatchId, l.LiveScores, l.ScoreId 

		-- 4. List ticket unmark/mark & Transinfo table (if any)
		SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
			,transid AS 't'
			,Subtransid  AS 's_t'
			,custid AS  'c'           
			,bettype AS 'btype'
			,betid AS 'bid'
			,CAST (li.ScoreId AS VARCHAR(20)) AS 'ScoreId'
			,IsMixParlay AS 'isP'
			,SiteDBGroupID AS 'sitedb'
			,IsCancelCashOut AS 'isCCO'
		FROM #TVSTicketBets t
			INNER JOIN #logInfo li ON t.ScoreId = li.ScoreId
		FOR JSON PATH))

		--List ticket insert table TicketVoiding_PendingMarkTickets
		SET @SiteDBDownInfoJson = COMPRESS((SELECT MatchId AS 'mid'
			,transid AS 't'
			,IsMixParlay AS 'isP'
			,SiteDBGroupID AS 'sitedb'
			,isMarked AS 'isMarked'
		FROM @tmpSiteDBDownInfo 
		WHERE isMarked = 1
		FOR JSON PATH))
		
		SELECT @UnmarkTransIds AS UnmarkTransIds
			  ,@MarkTransIds AS MarkTransIds
		      ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
			  ,CONVERT(VARCHAR(MAX), @SiteDBDownInfoJson, 1) AS SiteDBDownInfoJson
		  	  ,@SingleCountSiteDBDown AS SingleCount
		      ,@ParlayCountSiteDBDown AS ParlayCount
			  ,@CancelCashOutSiteDBDown AS CancelCashOutCount

	END
	ELSE IF @FilterBy = 2
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,IsExistsSecondAccept
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			;WITH ChildListCTE AS (
				SELECT 
					r.RequestId, 
					r.MatchId, 
					r.MainTransId, 
					c.username AS CreatedBy,
					COUNT(r.TransId) AS TotalCount,
					MIN(CASE WHEN r.MainTransId = r.TransId THEN 1 ELSE 0 END) AS HasMainSelf,
					STUFF((
						SELECT ',' + CAST(r2.TransId AS VARCHAR(50))
						FROM #TransidInRequest r2
						WHERE r2.MainTransId = r.MainTransId
						ORDER BY r2.TransId ASC 
						FOR XML PATH(''), TYPE
					).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS ChildList
				FROM #TransidInRequest r
				INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
				GROUP BY r.RequestId, r.MatchId, r.MainTransId, c.username
			)
			SELECT 
				r.RequestId, 
				r.MatchId,
				STUFF((
					SELECT ', ' + 
						CASE 
							WHEN r2.TotalCount > 1 -- If MainTransId >=2 child → combine MainTransId(child1,child2,...) => hybrid parlay
							THEN CAST(r2.MainTransId AS VARCHAR(50)) + '(' + REPLACE(r2.ChildList, CAST(r2.MainTransId AS VARCHAR(50)) + ',', '') + ')' 
							ELSE CAST(r2.MainTransId AS VARCHAR(50))
						END
					FROM ChildListCTE r2
					WHERE r2.RequestId = r.RequestId AND r2.MatchId = r.MatchId
					ORDER BY r2.MainTransId ASC
					FOR XML PATH(''), TYPE
				).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS TransIds,
				r.CreatedBy
			FROM ChildListCTE r
			GROUP BY r.RequestId, r.MatchId, r.CreatedBy;
		END
		ELSE
		BEGIN
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds 
			FROM #TransidInRequest
		END
	
		-- 3. Loginfo table
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
					,MIN(HighLightMinTime) AS HighLightMinTime
					,MIN(CancelCashOutCount) AS CancelCashOutCount
				FROM #logInfo l
					CROSS APPLY(
								SELECT '|' + LiveScores
								FROM #logInfo rd WITH(NOLOCK)
								where l.MatchId = rd.MatchId
								FOR XML PATH('')
								)w (scores) 
				GROUP BY MatchId, w.scores
			)
		SELECT l.MatchId
			, l.LiveScores
			,VoidFromTime
			,VoidToTime
			,SingleCount
			,CashOutCount
			,InstantlySettleCount
			,SettleCount
			,MainParlayCount
			,HighLightMinTime
			,h.HighlightAcceptType
			,CancelCashOutCount
			,h.MinTransId
			,CASE WHEN h.IsCancelCashOut = 1 THEN '(Cancel Cash Out)' 
			      WHEN h.IsCashOut = 1 THEN '(Cash Out)' 
			      ELSE NULL END AS ActionType
			,v.ExcludedTicketsCount
			,v.ExcludedTicketsJson
		FROM _cte l
			INNER JOIN @Validation AS v ON l.MatchId = v.MatchId 
			OUTER APPLY (SELECT TOP 1 b.accepttype HighlightAcceptType, b.transid AS MinTransId, b.IsCancelCashOut
							        , CASE WHEN b.IsCancelCashOut = 0 AND ISNULL(b.betdaqid, -1) = -2 THEN 1 ELSE 0 END IsCashOut
						FROM #TVSTicketBets b 
						WHERE l.MatchId = b.matchid AND l.HighLightMinTime = CASE 
																				  WHEN b.IsCancelCashOut = 0 AND b.checktime IS NOT NULL THEN b.checktime 
																				  WHEN b.IsCancelCashOut = 0 AND b.checktime IS NULL THEN b.transdate 
																				  WHEN b.IsCancelCashOut = 1 THEN b.CheckTimeCashOut
																			  END 
													AND b.IsSiteDBDown = 0
						ORDER BY b.IsCancelCashOut ASC, b.transid ASC
				) AS h

		-- 4. List ticket unmark/mark & Transinfo table (if any)
		SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
			,transid AS 't'
			,Subtransid  AS 's_t'
			,custid AS  'c'           
			,bettype AS 'btype'
			,betid AS 'bid'
			,CAST (t.ScoreId AS VARCHAR(20)) AS 'ScoreId'
			,IsMixParlay AS 'isP'
			,SiteDBGroupID AS 'sitedb'
			,IsCancelCashOut AS 'isCCO'
		FROM #TVSTicketBets t
		WHERE t.IsSiteDBDown = 0
		FOR JSON PATH))

		--List ticket insert table TicketVoiding_PendingMarkTickets
		SET @SiteDBDownInfoJson = COMPRESS((SELECT MatchId AS 'mid'
			,transid AS 't'
			,IsMixParlay AS 'isP'
			,SiteDBGroupID AS 'sitedb'
			,isMarked AS 'isMarked'
		FROM @tmpSiteDBDownInfo 
		FOR JSON PATH))
		
		SELECT @UnmarkTransIds AS UnmarkTransIds
		      ,@MarkTransIds AS MarkTransIds
		      ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
			  ,CONVERT(VARCHAR(MAX), @SiteDBDownInfoJson, 1) AS SiteDBDownInfoJson
			  ,@SingleCountSiteDBDown AS SingleCount
			  ,@ParlayCountSiteDBDown AS ParlayCount
			  ,@CancelCashOutSiteDBDown AS CancelCashOutCount
	
	END

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #CTE_Ticket_Single
	DROP TABLE #CTE_Ticket_SubParlay
	DROP TABLE #CTE_RequestDetail
END
GO


