/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_WC_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 3
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@TransInfo		      XML = NULL
)
AS
/*	
	Created by: July
	Date 20220808
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type Wrong score [Redmine: #175412]

	Param's explanation:
		+ @WrongScoreInfo:
				<root><r MatchId ="" LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" FilterBy="" ScoreId='3966607' AATime="" PATime ="" SATime="" SubIssueTypeId ="" /></root>
		(1: By Transdate, 2: By Checktime, 4: Filter by Transdate & Checktime)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@MatchProcessXML		  XML = NULL
			,@MatchParlayProcessXML	  XML = NULL
			,@TotalRefnoParlay		  INT = 0
			,@ThreadHold			  INT = 0
			,@FilterBy				  TINYINT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@MinAccept				  TINYINT = 0	
		    ,@VoidFromTime			  DATETIME = NULL
		    ,@VoidToTime			  DATETIME = NULL
		    ,@FilterFromTransTime	  DATETIME = NULL
		    ,@FilterToTransTime		  DATETIME = NULL
		    ,@AATime				  TINYINT = 0 
		    ,@PATime				  TINYINT = 0
		    ,@SATime				  TINYINT = 0
			,@ScoreId				  INT = NULL
			,@MatchId				  INT = 0
			,@SubIssueTypeId		  INT 

	CREATE TABLE #TVSTicketBets (
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
			matchid               INT,
			LiveIndicator		  BIT,
			StatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			ScoreId				  INT
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
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, ScoreId INT)
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
	)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT, ScoreId INT)
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,Subtransid BIGINT
	  ,refno BIGINT
	  ,custid INT	
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
	  ,odds MONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(1)
      ,bettype SMALLINT
      ,betteam NVARCHAR(10)
	  ,betcheck NVARCHAR(50)
	  ,Status NVARCHAR(10)
      ,transdate DATETIME
	  ,checktime DATETIME
	  ,betid BIGINT
	  ,Transdesc NVARCHAR(1000)
	  ,statusID TINYINT
	  ,Subcustid INT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Sublivehomescore SMALLINT
      ,Subliveawayscore SMALLINT
	  ,Subliveindicator BIT
	  ,Subodds MONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(1)
	  ,Subbettype SMALLINT
	  ,Subbetteam  NVARCHAR(10)
	  ,Subbetcheck NVARCHAR(50)
	  ,SubStatus NVARCHAR(10)
	  ,Subtransdate DATETIME
	  ,Subchecktime DATETIME
	  ,SubTransdesc  NVARCHAR(1000)
	  ,SubstatusID TINYINT
	  ,srecommend INT
	  ,mrecommend INT
	  ,recommend INT
      ,creator INT
	  ,stake MONEY
	  ,oddstype TINYINT
	  ,CurrencyName NVARCHAR(50)
	  ,betdaqid BIGINT
	  ,ExtraInfo VARCHAR(1000)
	  ,BonusID INT
	  ,winlost	MONEY
	  ,actual_stake MONEY
	  ,winlostdate SMALLDATETIME
	  ,modds MONEY
	  ,statuswinlost MONEY
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsMove14 BIT
	)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblHighlightTransId TABLE (MatchId INT, Transid BIGINT, AcceptType TINYINT, VoidTime DATETIME)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,LiveScores				 NVARCHAR(300)
			,MatchId                 INT
			,ScoreId                 INT
		)
	SET @WrongScoreInfoXML = CONVERT(XML, @WrongScoreInfo)
		
	INSERT INTO #FilterInfo(MatchId, LiveHomeScore, LiveAwayScore, FilterFromTransTime, FilterToTransTime, FilterBy, ScoreId, AATime, PATime, SATime, SubIssueTypeId)
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
	FROM @WrongScoreInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL ))

	SELECT TOP (1) @FilterBy = FilterBy 
				 , @SubIssueTypeId = SubIssueTypeId
				 , @MatchId = MatchId 
	FROM #FilterInfo
	
	INSERT INTO #tmpTransInfo( 
		matchid 
	    ,transid 
		,Subtransid 
	    ,refno 
	    ,custid 	
        ,hdp1 
        ,hdp2 
        ,livehomescore 
        ,liveawayscore 
        ,liveindicator 
	    ,odds 
	    ,oddsspread 
        ,betfrom 
        ,bettype 
        ,betteam 
	    ,betcheck 
	    ,Status 
        ,transdate 
	    ,checktime 
	    ,betid 
	    ,Transdesc 
	    ,statusID 
	    ,Subcustid 
	    ,Subhdp1 
        ,Subhdp2 
	    ,Sublivehomescore 
        ,Subliveawayscore 
	    ,Subliveindicator 
	    ,Subodds 
	    ,Suboddsspread 
	    ,Subbetfrom 
	    ,Subbettype 
	    ,Subbetteam  
	    ,Subbetcheck 
	    ,SubStatus 
	    ,Subtransdate 
	    ,Subchecktime 
	    ,SubTransdesc  
	    ,SubstatusID 
	    ,srecommend 
	    ,mrecommend 
	    ,recommend 
        ,creator 
	    ,stake 
	    ,oddstype 
	    ,CurrencyName 
	    ,betdaqid 
	    ,ExtraInfo 
	    ,BonusID 
	    ,winlost	
	    ,actual_stake 
	    ,winlostdate 
	    ,modds 
	    ,statuswinlost 
	    ,LiveBetAcceptTime 
	    ,SecAcceptTime 
	    ,SubLiveBetAcceptTime 
	    ,SubSecAcceptTime 
        ,IsMixParlay 
	    ,SiteDBGroupID 
	    ,IsMove14 
	)
	SELECT t.c.value('@mid','INT') AS matchid	
		,t.c.value('@t','BIGINT') AS transid
		,t.c.value('@s_t','BIGINT') AS Subtransid
		,t.c.value('@ref','BIGINT') AS refno
		,t.c.value('@c','INT') AS custid
		,t.c.value('@hdp1','SMALLMONEY') AS hdp1
		,t.c.value('@hdp2','SMALLMONEY') AS hdp2
		,t.c.value('@lh','SMALLINT') AS livehomescore
		,t.c.value('@la','SMALLINT') AS liveawayscore
		,t.c.value('@li','BIT') AS liveindicator
		,t.c.value('@o','MONEY') AS odds
		,t.c.value('@os','MONEY') AS oddsspread
		,t.c.value('@bfr','NVARCHAR(1)') AS betfrom
		,t.c.value('@btype','SMALLINT') AS bettype
		,t.c.value('@bteam','NVARCHAR(10)') AS betteam
		,t.c.value('@bcheck','NVARCHAR(50)') AS betcheck
		,t.c.value('@s','NVARCHAR(10)') AS Status
		,t.c.value('@tdate','DATETIME') AS transdate
		,CASE WHEN t.c.value('@checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@checkt','DATETIME') END AS checktime
		,t.c.value('@bid','BIGINT') AS betid
		,t.c.value('@tdes','NVARCHAR(1000)') AS Transdesc
		,t.c.value('@sid','TINYINT') AS statusID
		,t.c.value('@s_c','INT') AS Subcustid
		,t.c.value('@s_hdp1','SMALLMONEY') AS Subhdp1
		,t.c.value('@s_hdp2','SMALLMONEY') AS Subhdp2
		,t.c.value('@s_lh','SMALLINT') AS Sublivehomescore
		,t.c.value('@s_la','SMALLINT') AS Subliveawayscore
		,t.c.value('@s_li','BIT') AS Subliveindicator
		,t.c.value('@s_o','MONEY') AS Subodds
		,t.c.value('@s_os','MONEY') AS Suboddsspread
		,t.c.value('@s_bfr','NVARCHAR(1)') AS Subbetfrom
		,t.c.value('@s_btype','SMALLINT') AS Subbettype
		,t.c.value('@s_bteam','NVARCHAR(10)') AS Subbetteam
		,t.c.value('@s_bcheck','NVARCHAR(50)') AS Subbetcheck
		,t.c.value('@s_s','NVARCHAR(10)') AS SubStatus
		,t.c.value('@s_tdate','DATETIME') AS Subtransdate
		,CASE WHEN t.c.value('@s_checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@s_checkt','DATETIME') END AS Subchecktime
		,t.c.value('@s_tdes','NVARCHAR(1000)') AS SubTransdesc
		,t.c.value('@s_sid', 'MONEY') AS SubstatusID
		,t.c.value('@sre','INT') AS srecommend
		,t.c.value('@mre','INT') AS mrecommend
		,t.c.value('@re','INT') AS recommend
		,t.c.value('@cr','INT') AS creator
		,t.c.value('@stake','MONEY') AS stake
		,t.c.value('@ost','TINYINT') AS oddstype
		,t.c.value('@curr','NVARCHAR(50)') AS CurrencyName
		,t.c.value('@bdaq','BIGINT') AS betdaqid
		,t.c.value('@ex','VARCHAR(1000)') AS ExtraInfo
		,t.c.value('@bo','INT') AS BonusID
		,t.c.value('@w','MONEY') AS winlost
		,t.c.value('@acstake','MONEY') AS actual_stake
		,CASE WHEN t.c.value('@wld','SMALLDATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@wld','SMALLDATETIME') END AS winlostdate
		,t.c.value('@m', 'MONEY') AS modds
		,t.c.value('@statuswl', 'MONEY') AS statuswinlost
		,t.c.value('@lbat', 'SMALLINT') AS LiveBetAcceptTime
		,t.c.value('@sat', 'TINYINT') AS SecAcceptTime
		,t.c.value('@s_lbat', 'SMALLINT') AS SubLiveBetAcceptTime
		,t.c.value('@s_sat', 'TINYINT') AS SubSecAcceptTime
		,t.c.value('@isP','BIT') AS IsMixParlay
		,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
		,t.c.value('@isM','BIT') AS IsMoved14 
	FROM @TransInfo.nodes('root/r') t(c)	
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	

		--> Get status of match
		;WITH cte_match AS
		(
			SELECT DISTINCT t.matchid
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
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							       ELSE 0 END
			)f	 	
	END	

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
	
	--Init Validation
	INSERT INTO @Validation (MatchId, ScoreId, LiveScores)
	SELECT DISTINCT MatchId, ScoreId, CAST(livehomescore AS VARCHAR(10)) + '-' + CAST(liveawayscore AS VARCHAR(10)) AS LiveScores
	FROM #FilterInfo

	WHILE (1=1) 
	BEGIN
		SELECT @MinAccept				= 0	
			, @VoidFromTime				= NULL
			, @VoidToTime				= NULL
			, @FilterFromTransTime		= NULL
			, @FilterToTransTime		= NULL
			, @AATime					= 0 
			, @PATime					= 0
			, @SATime					= 0
			, @ScoreId					= NULL
		
		UPDATE TOP(1) m SET
			m.isFinish = 1
			,@FilterFromTransTime = m.FilterFromTransTime
			,@FilterToTransTime = m.FilterToTransTime
			,@AATime = m.AATime
			,@PATime = m.PATime
			,@SATime = m.SATime
			,@ScoreId = m.ScoreId
		FROM #FilterInfo m
		WHERE m.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;
		
		IF (@FilterBy <> 2) OR (@AATime IS NULL AND @PATime IS NULL AND @SATime IS NULL) --case AA,PA,SA fields blank
		BEGIN
			UPDATE #FilterInfo
			SET FilterVoidFromTime = @FilterFromTransTime, FilterVoidToTime = @FilterToTransTime
			WHERE MatchId = @MatchId AND ScoreId = @ScoreId
		END 
		ELSE IF @IsShowLogOnly = 0
		BEGIN
			SELECT @MinAccept = @AATime

			IF @MinAccept > @PATime SET @MinAccept = @PATime
			IF @MinAccept > @SATime SET @MinAccept = @SATime

			SELECT @VoidFromTime = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)

			SELECT @VoidFromTime = MIN(CASE WHEN act.FromDate >= DATEADD (SECOND,CASE WHEN act.AcceptType = 1 THEN @AATime
																					  WHEN act.AcceptType = 2 THEN @SATime
																					  ELSE @PATime --act.AcceptType = 3
																				 END
																				,@FilterFromTransTime
																			  )
												 THEN act.FromDate ELSE NULL END
											)
				  ,@VoidToTime = MAX(act.FromDate)
			FROM (
				SELECT b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, b.LiveBetAcceptTime, b.SecAcceptTime, b.statusID
				FROM #tmpTransInfo b 
				WHERE b.matchid = @MatchId AND b.IsMixParlay = 0
					AND b.betfrom <> 'P'
					AND ISNULL(b.betdaqid,-1) NOT IN (1)
				UNION ALL
				SELECT NULL AS transid, bm.Subtransid, bm.Subbettype AS bettype, bm.Subtransdate AS transdate, bm.Subchecktime AS checktime, bm.SubLiveBetAcceptTime AS LiveBetAcceptTime, bm.SubSecAcceptTime AS SecAcceptTime, bm.SubstatusID AS statusID
				FROM #tmpTransInfo bm 
				WHERE bm.matchid = @MatchId AND bm.IsMixParlay = 1
					AND bm.Subbetfrom <> 'P'
			)b
			CROSS APPLY (
					SELECT CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
								ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
										  ELSE 3 --Pending Accept
									 END
							END AS AcceptType
						  ,CASE WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
						   END AS FromDate
			)act
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE act.FromDate BETWEEN @VoidFromTime AND @FilterToTransTime
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.bettype AND f.SubIssueTypeId = @SubIssueTypeId AND f.IssueTypeId = @IssueTypeId)
				AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
		
			IF @VoidFromTime IS NULL
			BEGIN
				SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
			END

			UPDATE #FilterInfo
			SET FilterVoidFromTime = @VoidFromTime, FilterVoidToTime = @VoidToTime
			WHERE MatchId = @MatchId
		END 
	END			

	
		
	INSERT INTO #TVSTicketBets(
			transid		
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
			,ScoreId
			,checktime
			,accepttype
		)
	SELECT   b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.liveindicator
			,@MatchId
			,b.statusID
			,d.ScoreId
			,b.checktime
			,CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
				  ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
							ELSE 3 END --Pending Accept
				  END AS accepttype
	FROM #tmpTransInfo b
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
	WHERE	b.matchid = @matchid AND b.IsMixParlay = 0 
			AND 1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
			AND 1 = CASE WHEN @FilterBy = 1 AND b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						 WHEN @FilterBy = 2 AND ISNULL(b.checktime, b.transdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						 WHEN @FilterBy = 4 AND ((b.checktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.transdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime))THEN 1
					   ELSE 0 END 
			AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.bettype 
									AND f.SubIssueTypeId = @SubIssueTypeId
									AND f.IssueTypeId = @IssueTypeId)
				
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo bm  WHERE bm.IsMixParlay = 1)
	BEGIN		
		INSERT INTO #TVSTicketBets(
				transid		
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
				,accepttype
			)
		SELECT b.transid 
				,b.SubTransID
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.Subliveindicator
				,@MatchId
				,b.statusID
				,d.ScoreId
				,b.Subchecktime
				,CASE WHEN b.Subchecktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN b.Subchecktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.Subtransdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON d.MatchId = b.matchid AND b.IsMixParlay = 1
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.Subbettype
		WHERE 1= CASE WHEN @ActionId <> 2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.liveindicator = 0
				AND b.statusID NOT IN (102, 103)
				AND 1 = CASE WHEN b.Sublivehomescore = 0 AND b.Subliveawayscore = 0 AND b.Subliveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
				AND 1 = CASE WHEN @FilterBy = 1 AND b.Subtransdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						     WHEN @FilterBy = 2 AND ISNULL(b.Subchecktime, b.Subtransdate) BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
						     WHEN @FilterBy = 4 AND ((b.Subchecktime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime) OR (b.Subtransdate BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime)) THEN 1
							ELSE 0 END 
				AND NOT EXISTS (SELECT TOP 1 1 
								FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
								WHERE f.bettype = b.Subbettype
									AND f.SubIssueTypeId = @SubIssueTypeId
									AND f.IssueTypeId = @IssueTypeId)
	END

	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		IF @FilterBy = 2
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
			SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
			FROM #TVSTicketBets t
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId, rs.RequestId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
							UNION ALL
							SELECT rp.TransId, rp.MainTransId, rp.RequestId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
							WHERE rp.TransId = t.SubTransid AND rp.MatchId = t.matchid
					)tmp
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
			WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
		END
		ELSE
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, ScoreId, MatchId)
			SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.ScoreId, @MatchId
			FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.RequestId = r.RequestId AND rs.MatchId = @MatchId
							UNION ALL
							SELECT rp.TransId, rp.MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
							WHERE rp.RequestId = r.RequestId AND rp.MatchId = @MatchId
					)tmp
				INNER JOIN #TVSTicketBets t ON t.SubTransid = tmp.transid
			WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
		END

		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			IF @FilterBy = 2
			BEGIN
				UPDATE v SET v.IsExistedInOtherRequest = 1
				FROM @Validation v
				WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
			END
			ELSE
			BEGIN
				UPDATE v SET v.IsExistedInOtherRequest = 1
				FROM @Validation v
				WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.ScoreId = v.ScoreId)
			END
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MainParlayCount, ScoreId, HighLightMinTime)
	SELECT @MatchId AS MatchId
		,CASE WHEN @FilterBy = 2 THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END AS LiveScores
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
		LEFT JOIN #TransidInRequest t ON t.TransId = b.SubTransid
		CROSS APPLY (SELECT CASE 
								WHEN @FilterBy IN (1,4) THEN b.transdate
								WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							 END AS VoidTime
					)act
	WHERE t.TransId IS NULL
	GROUP BY CASE WHEN @FilterBy = 2 THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId
	ORDER BY CASE WHEN @FilterBy = 2 THEN CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ELSE NULL END, b.ScoreId

		--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		  ,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		IF @FilterBy <> 2
		BEGIN
			-- 1. Validate table
			SELECT LiveScores
				,1 AS IsInValidTotalTickets
				,IsExistedInOtherRequest
				,ScoreId
			FROM @Validation

			-- 2. TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN
				SELECT RequestId, MatchId,
					STUFF((
					SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
					FROM #TransidInRequest
					WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
					ORDER BY TransId
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
					,1,2,'') AS TransIds
				FROM #TransidInRequest r
				GROUP BY r.RequestId, r.MatchId
			END
			ELSE
			BEGIN 
				SELECT r.RequestId, r.MatchId, CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				FROM #TransidInRequest r
			END
			
			-- 3. Loginfo Table
			DELETE #logInfo
			SELECT MatchId, ScoreId FROM #logInfo

			-- 4. Unmark table
			SELECT NULL AS UnmarkTransIds
		
			-- 5. Transinfo table
			DELETE #tmpTransInfo
		    SELECT Matchid FROM #tmpTransInfo

		END
		ELSE 
		BEGIN 
			-- 1. Validate table
			SELECT MatchId
				,1 AS IsInValidTotalTickets
				,IsExistedInOtherRequest
			FROM @Validation
		
			-- 2. TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN
				SELECT RequestId, NULL AS LiveScores, r.ScoreId, 
					STUFF((
					SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
					FROM #TransidInRequest
					WHERE (RequestId = r.RequestId AND ScoreId = r.ScoreId) 
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
					,1,2,'') AS TransIds
				FROM #TransidInRequest r
				GROUP BY r.RequestId, r.ScoreId
			END
			ELSE
			BEGIN 
				SELECT RequestId, NULL AS LiveScores, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
				FROM #TransidInRequest
			END
			
			-- 3. Loginfo Table
			DELETE #logInfo
			SELECT MatchId, ScoreId FROM #logInfo

			-- 4. Unmark table
			SELECT NULL AS UnmarkTransIds

			-- 5. TransInfo table
			DELETE #tmpTransInfo
		    SELECT Matchid FROM #tmpTransInfo
		END

		RETURN;
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, InstantlySettleCount, SettleCount, ScoreId)
		SELECT @RequestId
			  ,b.matchid
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
			  ,tmp.ScoreId
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
			INNER JOIN #tmpTransInfo b ON s.MatchId = b.matchid AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = s.MatchId
		WHERE s.RequestId = @RequestId
			AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid, tmp.ScoreId

		IF @FilterBy <> 2
		BEGIN
			-- 1. Validate table
			SELECT LiveScores
				,IsInValidTotalTickets
				,IsExistedInOtherRequest
				,ScoreId
			FROM @Validation

			-- 2. TransId in request table
			SELECT RequestId, NULL AS LiveScores, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest

			-- 3.Loginfo table
			SELECT rd.MatchId
				,CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) AS LiveScores
				,rd.IssueDetail AS ActualScore
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,tmp.CashOutCount
				,tmp.InstantlySettleCount
				,tmp.SettleCount
				,a.ScoreId AS ScoreId
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				CROSS APPLY (
						SELECT CONVERT(XML, rd.TransIds)
					)AS t1(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@ScoreId','INT') AS ScoreId
						FROM t1.xDATA.nodes('/r') t(c)
					) a (ScoreId)
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
			IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
			BEGIN
					INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
					SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
						INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 0
					WHERE s.RequestId = @RequestId AND f.GroupName <> '2H'
			END

			IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
			BEGIN
					INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
					SELECT s.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
						INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 1
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype			
					WHERE s.RequestId = @RequestId AND f.GroupName <> '2H'
			END

			IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
			BEGIN
				INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
				SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(2)) + '-' + CAST(m.liveawayscore AS VARCHAR(2))
				FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
				WHERE rd.RequestId = @RequestId
			END

			SELECT rd.MatchId
				,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,tmp.CashOutCount AS CashOutCount
				,tmp.InstantlySettleCount
				,tmp.SettleCount
				,rd.MainParlayCount
				,rd.VoidFromTime AS HighLightTime
				,h.HighlightAcceptType
				,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
				,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			   LEFT JOIN #logInfoVoidPage tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId
			   OUTER APPLY (
						SELECT  TOP 1 b.accepttype AS HighlightAcceptType
						FROM #TVSTicketBets b
						WHERE b.matchId = rd.MatchId
						AND rd.VoidFromTime = (CASE WHEN b.checktime IS NOT NULL THEN b.checktime
													WHEN b.checktime IS NULL THEN b.transdate END)
				)h
				CROSS APPLY(
					SELECT DISTINCT '|' + l.ScoreNormalTicket FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
				)s2(ScoreTicket2H)
				CROSS APPLY(
					SELECT DISTINCT '|' + l.ScoreOfMatch FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
				)sm(ScoreOfMatch)
			WHERE rd.RequestId = @RequestId

		END
			
		-- 4.Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table (No need return data)
		DELETE #tmpTransInfo
		SELECT Matchid FROM #tmpTransInfo

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

	IF @RequestId = 0
	BEGIN
		--Mark ticket when add request
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 0 
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

		IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

		SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 1 
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.transid AND tp.IsMixParlay = 0
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL AND tr.TransId is NULL
												AND rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')

			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','

			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
													LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.SubTransid AND tp.IsMixParlay = 1
													LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											  WHERE tp.SubTransid IS NULL AND tr.TransId IS NULL
													  AND rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')

			--Add mark ticket when edit request
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
											FROM #TVSTicketBets t
												LEFT JOIN #TransidInRequest tr on tr.TransId = t.SubTransid
											WHERE t.IsMixParlay = 0 AND tr.TransId IS NULL
												AND NOT EXISTS( SELECT TOP 1 1 FROM TicketVoiding_RequestDetailTicket_Single rdt WHERE t.transid = rdt.transid AND rdt.RequestId = @RequestId)
											FOR XML PATH('')), 1, 1, '')
									, '')

			IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
											FROM #TVSTicketBets t
												LEFT JOIN #TransidInRequest tr on tr.TransId = t.TransId
											WHERE t.IsMixParlay = 1
												AND NOT EXISTS( SELECT TOP 1 1 FROM TicketVoiding_RequestDetailTicket_SubParlay rdt WHERE t.SubTransid = rdt.transid AND rdt.RequestId = @RequestId)
											FOR XML PATH('')), 1, 1, '')
									, '')
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 0 
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')

			IF @MarkTransIds <> ''
					SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 1 
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')
			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','
			
			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
											  WHERE rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')
		END

	END
	/*****************Return table **************************/

	IF @FilterBy <> 2
	BEGIN
		-- 1. Validate table
		SELECT LiveScores
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,ScoreId
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
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
		ELSE
		BEGIN
			SELECT RequestId, NULL AS LiveScores, ScoreId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
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
		FROM #logInfo l
		GROUP BY MatchId, LiveScores, ScoreId

	END
	ELSE IF @FilterBy = 2
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
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
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest r
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
		FROM _cte l
			OUTER APPLY (SELECT TOP 1 b.accepttype HighlightAcceptType
						FROM #TVSTicketBets b 
						WHERE l.MatchId = b.matchid AND l.HighLightMinTime = CASE WHEN b.checktime IS NOT NULL THEN b.checktime 
																			  WHEN b.checktime IS NULL THEN b.transdate END 
				) AS h
	END
	
	-- 4. List ticket unmark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SELECT DISTINCT 
			t.matchid
		    ,t.transid
			,t.Subtransid
			,t.refno
			,b.custid 
			,b.bettype 
			,b.betid 
			,b.statusID 
			,b.Subcustid 
			,b.Subbettype
			,t.transdate
			,t.checktime
			,b.IsMixParlay 
			,b.SiteDBGroupID 
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
END
GO


