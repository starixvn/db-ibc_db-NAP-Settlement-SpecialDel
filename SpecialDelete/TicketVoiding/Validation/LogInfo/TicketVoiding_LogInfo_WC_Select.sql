/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_WC_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 3
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
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

	Param's explanation:
		+ @WrongScoreInfo:
				<root><r MatchId ="" LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" FilterBy="" ScoreId='3966607' AATime="" PATime ="" SATime="" SubIssueTypeId ="" /></root>
		(1: By Transdate, 2: By Checktime, 4: Filter by Transdate & Checktime)
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
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@MatchId				  INT = 0
	
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

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,LiveScores				 NVARCHAR(300)
			,MatchId                 INT
			,ScoreId                 INT
			,IsExistsSecondAccept	BIT DEFAULT(0) 	
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
			,T.C.value('./@VoidFromTime', 'DATETIME') AS FilterVoidFromTime 
			,T.C.value('./@VoidToTime', 'DATETIME') AS FilterVoidToTime
	FROM @WrongScoreInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL ))

	--Init Validation
	INSERT INTO @Validation (MatchId, ScoreId, LiveScores)
	SELECT DISTINCT MatchId, ScoreId, CAST(livehomescore AS VARCHAR(10)) + '-' + CAST(liveawayscore AS VARCHAR(10)) AS LiveScores
	FROM #FilterInfo

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
	
	BEGIN -- Instant Settlement declaration
		
		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT)
		CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

		INSERT INTO #CTE_match (matchid, sporttype)
		SELECT DISTINCT t.matchid, m.sporttype
		FROM #FilterInfo t
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
			
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 1) --Soccer	 
		BEGIN 
			INSERT INTO #CTE_isCal (matchid, IsHTCal)
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM #CTE_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
			WHERE m.sporttype = 1

			--> Build bettype list supported for instant settlement based on settlement status of match
			INSERT INTO #InstantSettlementBettypes (matchid, bettype)
			SELECT c.matchid,  f.bettype
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype
						FROM dbo.f_TVS_GetInstantBettypes() 
						WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
									   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
									ELSE 0 END
				)f	 	
		END
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 2) --Basketball
		BEGIN
			INSERT INTO #CTE_isCal (matchid, ResourceId)
			SELECT m.matchid, rd.ResourceId
			FROM #CTE_match m
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
					ON rd.matchid = m.matchid
					AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 
			WHERE m.sporttype = 2

			INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
			SELECT DISTINCT c.matchid, f.bettype, f.betid
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype, betid
						FROM dbo.f_TVS_GetInstantBettypes()
						WHERE InstantType IS NULL
						AND 1 = CASE WHEN c.ResourceId IS NULL THEN 1 --NOT executed on this match.
									 WHEN c.ResourceId IS NOT NULL AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal) THEN 1
									 ELSE 0 END
				)f	 	
		END
		DROP TABLE #CTE_match
		DROP TABLE #CTE_isCal
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
			,b.matchid
			,b.statusID
			,b.statusID AS SubstatusID
			,d.ScoreId
			,b.checktime
			,CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
				  ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0) + ISNULL(bi.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
							ELSE 3 END --Pending Accept
				  END AS accepttype
			,0 AS IsCancelCashOut
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
	WHERE  1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
		AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
		AND 1 = CASE WHEN d.FilterBy = 1 AND b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
					 WHEN d.FilterBy = 2 AND ISNULL(b.checktime, b.transdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
					 WHEN d.FilterBy = 4 AND ((b.checktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime))THEN 1
					ELSE 0 END 

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
			,b.matchid
			,b.statusID
			,b.statusID AS SubstatusID
			,d.ScoreId
			,b.checktime
			,CASE WHEN c.AcceptMode = 0 THEN 3 ELSE c.AcceptMode END AS accepttype
			,1 AS IsCancelCashOut
		    ,c.CheckTime
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
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
		   AND b.SiteDBGroupID = @SiteDBGroupID

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
						AND bm.betfrom <> 'P' AND bm.SiteDBGroupID = @SiteDBGroupID
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
			)
		SELECT b.transid 
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
				,b.matchid
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
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			INNER JOIN @bettype_tmp bt ON bt.bettype = sub.bettype
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = sub.bettype
		WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
			AND b.liveindicator = 0
			AND b.statusID NOT IN (102, 103)
			AND sub.betfrom <> 'P'
			AND b.matchid = 29 AND b.bettype = 29
			AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID
			AND 1 = CASE WHEN sub.livehomescore = 0 AND sub.liveawayscore = 0 AND sub.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
			AND 1 = CASE WHEN d.FilterBy = 1 AND sub.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						    WHEN d.FilterBy = 2 AND ISNULL(sub.checktime, sub.transdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						    WHEN d.FilterBy = 4 AND ((sub.checktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (sub.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime)) THEN 1
						ELSE 0 END 
	END

	--Delete ticket having subissuetype exclude bettype
	DELETE b
	FROM #TVSTicketBets AS b
	INNER JOIN #FilterInfo AS f ON b.matchid = f.MatchId
	WHERE EXISTS (SELECT TOP 1 1
				  FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() AS d
				  WHERE d.BetType = b.Subbettype AND d.SubIssueTypeId = f.SubIssueTypeId AND d.IssueTypeId = @IssueTypeId)

	SELECT TOP (1) @FilterBy = FilterBy
	FROM #FilterInfo

	/*Get Transid in Request of range Transid*/
	DECLARE @TransInfoJson_Request		VARBINARY(MAX)
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	SET @MaxRow = (SELECT MAX(ID) FROM #TVSTicketBets)
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
				WHERE ID BETWEEN @StartRow AND @StopRow
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
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
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
	WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
	GROUP BY CASE WHEN f.FilterBy = 2 THEN CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId, f.MatchId
	ORDER BY CASE WHEN f.FilterBy = 2 THEN CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId, f.MatchId

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsCancelCashOut = 1)
	BEGIN
		
		IF NOT EXISTS ( SELECT TOP 1 1 FROM #logInfo) --For case sitedb only cancel CO
		BEGIN
			INSERT INTO #logInfo (MatchId, LiveScores, ScoreId, VoidFromTime, VoidToTime, HighLightMinTime)
			SELECT b.matchid, NULL ,b.ScoreId
				  ,MIN(b.CheckTimeCashOut) AS VoidFromTime
				  ,MAX(b.CheckTimeCashOut) AS VoidToTime
				  ,MIN(b.CheckTimeCashOut) AS HighLightMinTime
			FROM #TVSTicketBets b
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
				WHERE li.MatchId = b.matchid AND b.IsCancelCashOut = 1 AND li.ScoreId = b.ScoreId
				GROUP BY b.matchid, b.ScoreId
			)b
	END

	--Not display Score in message template when voiding non-live tickets only [193108]
	IF NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE liveindicator = 1)
	BEGIN
		UPDATE l SET l.LiveScores = ''
		FROM #logInfo l
	END

	/* Display warning message in case void second accept tickets before the allowance time of this type */
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE FilterBy = 2) AND EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE accepttype = 2)
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
					INNER JOIN #TVSTicketBets t ON t.matchid = l.MatchId
					INNER JOIN #FilterInfo f ON t.matchid = f.MatchId AND t.ScoreId = f.ScoreId
				WHERE t.accepttype = 2
					AND v.MatchId = l.MatchId
					AND v.ScoreId = l.ScoreId
					AND 1 = CASE WHEN f.FilterBy = 1 AND t.transdate BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
								 WHEN f.FilterBy = 2 AND t.checktime IS NOT NULL AND t.checktime BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
								 WHEN f.FilterBy = 2 AND t.checktime IS NULL AND t.transdate BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
							ELSE 0 END
			)l
		
	END
	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, SingleCount INT, MainParlayCount INT, ActionId TINYINT, Id INT, Livehomescore INT, Liveawayscore INT)
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
	WHERE RequestId = @RequestId AND SiteDBGroupID = @SiteDBGroupID 
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId, RequestDetailId)
	SELECT RequestId, MatchId, TransId, RequestDetailId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId AND SiteDBGroupID = @SiteDBGroupID 
	SET @cnt_p = @@ROWCOUNT

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
		WHERE tp.SubStatusId IN (0,1)
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
				LEFT JOIN #TVSTicketBets tp ON um.TransId = tp.SubTransid 
			WHERE tp.TransId IS NULL 

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
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
			SELECT MatchId
				,RequestId
				,r.ScoreId
				,c.username AS CreatedBy
				,STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND ScoreId = r.ScoreId) 
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
			FROM #TransidInRequest r
				INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
			GROUP BY r.RequestId, r.ScoreId, c.username, MatchId
		END
		ELSE
		BEGIN
			SELECT RequestId, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds, MatchId
			FROM #TransidInRequest
		END

		-- 3. Loginfo table
		SELECT MatchId
			,LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
			,SUM(InstantlySettleCount) AS InstantlySettleCount
			,SUM(SettleCount) AS SettleCount
			,SUM(MainParlayCount) AS MainParlayCount
			,ScoreId
			,MIN(CancelCashOutCount) AS CancelCashOutCount
		FROM #logInfo l
		GROUP BY MatchId, LiveScores, ScoreId

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
		
		SELECT @UnmarkTransIds AS UnmarkTransIds
			  ,@MarkTransIds AS MarkTransIds
		      ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

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
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
				,c.username AS CreatedBy
			FROM #TransidInRequest r
				INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
			GROUP BY r.RequestId, r.MatchId, c.username
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
		SELECT MatchId
			, LiveScores
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
		FROM _cte l
			OUTER APPLY (SELECT TOP 1 b.accepttype HighlightAcceptType, b.transid AS MinTransId, b.IsCancelCashOut
							        , CASE WHEN b.IsCancelCashOut = 0 AND ISNULL(b.betdaqid, -1) = -2 THEN 1 ELSE 0 END IsCashOut
						FROM #TVSTicketBets b 
						WHERE l.MatchId = b.matchid AND l.HighLightMinTime = CASE 
																				  WHEN b.IsCancelCashOut = 0 AND b.checktime IS NOT NULL THEN b.checktime 
																				  WHEN b.IsCancelCashOut = 0 AND b.checktime IS NULL THEN b.transdate 
																				  WHEN b.IsCancelCashOut = 1 THEN b.CheckTimeCashOut
																			  END 
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
		FOR JSON PATH))
		
		SELECT @UnmarkTransIds AS UnmarkTransIds
		      ,@MarkTransIds AS MarkTransIds
		      ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
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


