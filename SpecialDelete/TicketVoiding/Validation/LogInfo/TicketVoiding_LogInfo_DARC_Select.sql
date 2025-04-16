/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_DARC_Select]
(	
	 @RequestId			  INT = 0
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@DARCInfo			  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type Danger Accept & Red card [Redmine: #175412]
		- 20220808@July: HF- Request only sub parlay ticket get wrong score show for template message [Redmine: #179752]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230116@July: HF - Edit Request: Log Info has the difference between START TIME void and MIM TIME highlight [Redmine: #182910]
		- 20230120@July: Add 1X2 bet type to detect Red Card - Replacement of sent-off player [Redmine: #182394]
		- 20230202@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230324@Max: [TVS] Manage Request enhancement - Phase 13 [Redmine: #185237]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230424@July: [TVS] Enhance auto cancel cash out for TVS [Redmine: #186417]
		- 20230810@July: [TVS] Cancel Cash Out - Update rules get first ticket to void [Redmine: #189644]
		- 20231004@Max: [TVS] Not display Score in message template when voiding non-live tickets only [Redmine: #193108]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240124@Max: [TVS] Display more info in the warning message for existing tickets in other requests [Redmine: #199907]
		- 20240819@July: Add more info for users to add requests with correct issue type [Redmine: #208659]
		- 20240102@July: [TVS] Display a note for Min TransId of cash out ticket [Redmine: #185495]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:
		+ @DangerAcceptedInfo, @RedCardInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterBy="" SubIssueTypeId="" AATime="" PATime="" SATime=""/></root>
		(1: By Transdate, 2: By Checktime)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			INT = 0
			,@MainParlayCount		INT = 0
			,@UnmarkTransIds		VARCHAR(MAX) =''
			,@MarkTransIds		    VARCHAR(MAX) =''
			,@OldActionId			TINYINT
			,@SiteDBGroupID			SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE	@DARCInfoInfoXML		XML = NULL
		   ,@MinAccept				TINYINT	= 0	
		   ,@VoidFromTime			DATETIME = NULL
		   ,@VoidToTime				DATETIME = NULL
		   ,@MatchId				INT	= 0
		   ,@FilterFromTransTime	DATETIME = NULL
		   ,@FilterToTransTime		DATETIME = NULL
		   ,@FilterBy				TINYINT = 1
		   ,@SubIssueTypeId			INT	= NULL
		   ,@AATime					TINYINT	= 0 
		   ,@PATime					TINYINT	= 0
		   ,@SATime					TINYINT	= 0
		   ,@TransInfoJson			VARBINARY(MAX) = NULL
		   ,@VoidFromTime_tmp		DATETIME = NULL
		   ,@CancelCOFromTime		DATETIME = NULL
		   ,@CancelCOToTime		    DATETIME = NULL

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
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			FilterBy			  TINYINT,
			IsCancelCashOut		  BIT,
			CheckTimeCashOut	  DATETIME,
			liveindicator		  BIT,
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
		,CancelCashOutCount		INT
		,TransVoidToTime		DATETIME	
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, CreatedBy INT)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT, CancelCashOutCount INT)

	CREATE TABLE #FilterInfo (
		 MatchId				INT --parent matchid
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterBy				TINYINT
		,SubIssueTypeId			SMALLINT
		,AATime					TINYINT
		,PATime					TINYINT
		,SATime					TINYINT
		,FilterVoidFromTime		DATETIME
		,FilterVoidToTime		DATETIME
		,isFinish				BIT
		,Sporttype				SMALLINT
		,MatchId_tmp			INT --child matchid
	)

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
	  ,odds SMALLMONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(4)
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
	  ,Subodds SMALLMONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(4)
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
	  ,modds SMALLMONEY
	  ,statuswinlost TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
	  ,CheckTimeCashOut DATETIME
	  ,AcceptModeCashOut  TINYINT
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,IsExistsSecondAccept	BIT DEFAULT(0) 	
			,MatchId                 INT	
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)

	SET @DARCInfoInfoXML = CONVERT(XML, @DARCInfo)
	INSERT INTO #FilterInfo (MatchID, FilterFromTransTime, FilterToTransTime, FilterBy, SubIssueTypeId, AATime, PATime, SATime)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
			,t.c.value('@FilterBy','TINYINT') AS FilterBy
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,CASE WHEN t.c.value('@AATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@AATime', 'TINYINT') END 
			,CASE WHEN t.c.value('@PATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@PATime', 'TINYINT') END 
			,CASE WHEN t.c.value('@SATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@SATime', 'TINYINT') END 
	FROM @DARCInfoInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@DARCInfoInfoXML = NULL))

		--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId
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
		INNER JOIN dbo.match m ON d.MatchId = m.MatchId

	--Cricket/Baseball - Get child match
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE Sporttype IN (50,8))
	BEGIN
		INSERT INTO #FilterInfo (MatchID, FilterFromTransTime, FilterToTransTime, FilterBy, SubIssueTypeId, AATime, PATime, SATime, Sporttype, MatchId_tmp)
		SELECT d.MatchId, d.FilterFromTransTime, d.FilterToTransTime
			  , d.FilterBy, d.SubIssueTypeId, d.AATime, d.PATime, d.SATime
			  , m.Sporttype
			  , m.MatchId AS MatchId_tmp
		FROM #FilterInfo d
		INNER JOIN dbo.match m WITH(NOLOCK) ON d.MatchId = m.ParentID
		WHERE m.sporttype IN (50,8) AND m.ChildMatchType = 200 
	END

	--Search single tickets
	INSERT INTO #tmpTransInfo(
			matchid 
			,transid
			,Subtransid 
			,custid                
			,transdate 
			,checktime 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,creator 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,statusID 
			,WalletType 
			,RefCode 
			,LiveBetAcceptTime 
			,SecAcceptTime 
			,Subcustid         
			,Sublivehomescore 
			,Subliveawayscore 
			,Subhdp1 
			,Subhdp2 
			,Subbetfrom 
			,Subbettype 
			,SubstatusID 
			,Subtransdate 
			,Subchecktime 
			,Subliveindicator 
			,SubLiveBetAcceptTime 
			,SubSecAcceptTime 
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,odds 
			,Subodds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,Subbetcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,SubStatus 
			,Subbetteam  
			,Suboddsspread 
			,SubTransdesc  
			,modds 
			,SiteDBGroupID
			,CheckTimeCashOut
			,AcceptModeCashOut
		)
	SELECT DISTINCT d.MatchId
		,b.TransId
		,b.transid AS SubTransID
		,b.custid
		,b.transdate
		,b.checktime
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.betteam
		,b.creator
		,b.refno
		,b.betid
		,b.bettype
		,b.betdaqid 
		,b.betfrom 
		,b.statusID 
		,b.WalletType 
		,b.RefCode 
		,bi.LiveBetAcceptTime 
		,bi.SecAcceptTime 
		,b.custid Subcustid         
		,b.livehomescore AS Sublivehomescore 
		,b.liveawayscore AS Subliveawayscore 
		,b.hdp1 AS Subhdp1 
		,b.hdp2 AS Subhdp2 
		,b.betfrom AS Subbetfrom 
		,b.bettype AS Subbettype 
		,b.statusID AS SubstatusID 
		,b.transdate AS Subtransdate 
		,b.checktime AS Subchecktime 
		,b.liveindicator AS Subliveindicator 
		,bi.LiveBetAcceptTime AS SubLiveBetAcceptTime 
		,bi.SecAcceptTime AS SubSecAcceptTime 
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,0 AS IsMixParlay 
		,b.odds 
		,b.odds AS Subodds 
		,b.oddsspread
		,b.oddstype 
		,b.betcheck 
		,b.betcheck AS Subbetcheck 
		,b.stake 
		,b.CurrencyName 
		,b.Transdesc 
		,b.ExtraInfo 
		,b.BonusID 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.status AS SubStatus 
		,b.betteam AS Subbetteam  
		,b.oddsspread AS Suboddsspread 
		,b.transdesc SubTransdesc  
		,b.modds 
		,b.SiteDBGroupID
		,c.CheckTime AS CheckTimeCashOut
		,c.AcceptMode AS AcceptModeCashOut
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
		INNER JOIN @bettype_tmp bt ON b.bettype = bt.bettype
		LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
		CROSS APPLY (
			SELECT CASE WHEN d.FilterBy = 1 THEN b.transdate 
					WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
					WHEN d.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
			END AS VoidTime
		)act
	WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
				   ELSE 0 END
		AND b.betfrom <> 'P'
		AND 1 = CASE WHEN act.VoidTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
					 ELSE CASE WHEN b.betdaqid = -2 AND c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
							   ELSE 0 END
					 END
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #FilterInfo d oN d.MatchId_tmp = bm.matchid
					WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  			       WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   				   ELSE 0 END
						AND bm.betfrom <> 'P' AND bm.SiteDBGroupID = @SiteDBGroupID
					)
	BEGIN		
		INSERT INTO #tmpTransInfo(
				matchid 
				,transid
				,Subtransid 
				,custid                
				,transdate 
				,checktime 
				,hdp1 
				,hdp2 
				,livehomescore 
				,liveawayscore 
				,liveindicator 
				,betteam 
				,creator 
				,refno 
				,betid 
				,bettype 
				,betdaqid 
				,betfrom 
				,statusID 
				,WalletType 
				,RefCode 
				,LiveBetAcceptTime 
				,SecAcceptTime 
				,Subcustid         
				,Sublivehomescore 
				,Subliveawayscore 
				,Subhdp1 
				,Subhdp2 
				,Subbetfrom 
				,Subbettype 
				,SubstatusID 
				,Subtransdate 
				,Subchecktime 
				,Subliveindicator 
				,SubLiveBetAcceptTime 
				,SubSecAcceptTime 
				,recommend 
				,mrecommend 
				,srecommend 
				,statuswinlost 
				,IsMixParlay 
				,odds 
				,Subodds 
				,oddsspread 
				,oddstype 
				,betcheck 
				,Subbetcheck 
				,stake 
				,CurrencyName 
				,Transdesc 
				,ExtraInfo 
				,BonusID 
				,winlost        
				,actual_stake 
				,Status
				,SubStatus 
				,Subbetteam  
				,Suboddsspread 
				,SubTransdesc  
				,modds 
				,SiteDBGroupID
			)
		SELECT DISTINCT d.MatchId
			,b.TransId
			,sub.transid AS SubTransID
			,b.custid
			,b.transdate
			,b.checktime
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.betteam
			,b.creator
			,b.refno
			,b.betid
			,b.bettype
			,b.betdaqid 
			,b.betfrom 
			,b.statusID 
			,b.WalletType 
			,b.RefCode 
			,NULL AS LiveBetAcceptTime 
			,NULL AS SecAcceptTime 
			,b.custid Subcustid         
			,sub.livehomescore AS Sublivehomescore 
			,sub.liveawayscore AS Subliveawayscore 
			,sub.hdp1 AS Subhdp1 
			,sub.hdp2 AS Subhdp2 
			,sub.betfrom AS Subbetfrom 
			,sub.bettype AS Subbettype 
			,sub.statusID AS SubstatusID 
			,sub.transdate AS Subtransdate 
			,sub.checktime AS Subchecktime 
			,sub.liveindicator AS Subliveindicator 
			,sub.LiveBetAcceptTime AS SubLiveBetAcceptTime 
			,sub.SecAcceptTime AS SubSecAcceptTime 
			,b.recommend 
			,b.mrecommend 
			,b.srecommend 
			,b.statuswinlost 
			,1 AS IsMixParlay 
			,b.odds 
			,Sub.odds AS Subodds 
			,b.oddsspread
			,b.oddstype 
			,b.betcheck 
			,sub.betcheck AS Subbetcheck 
			,b.stake 
			,b.CurrencyName 
			,b.Transdesc 
			,b.ExtraInfo 
			,b.BonusID 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,sub.status AS SubStatus 
			,sub.betteam AS Subbetteam  
			,sub.oddsspread AS Suboddsspread 
			,sub.transdesc SubTransdesc  
			,b.modds
			,sub.SiteDBGroupID
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			INNER JOIN @bettype_tmp bt ON sub.bettype = bt.bettype
		WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  	   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
				   	   ELSE 0 END
			AND sub.betfrom <> 'P'
			AND b.matchid = 29 AND b.bettype = 29
			AND CASE WHEN d.FilterBy = 1 THEN sub.transdate
					 WHEN d.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
					 WHEN d.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
				END BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
			AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID

	END

	-----Delete ticket check subissuetype exclude bettypes (single & parlay).
	DELETE b
	FROM #tmpTransInfo b
		INNER JOIN #FilterInfo d ON b.matchid = d.MatchId
	WHERE EXISTS (SELECT TOP 1 1 
						FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
						WHERE f.bettype = b.Subbettype AND f.SubIssueTypeId = d.SubIssueTypeId AND f.IssueTypeId = @IssueTypeId) --1: DangerAccepted

	------Get Return VoidFromTime/VoidToTime
	WHILE (1=1) 
	BEGIN
		SELECT @MinAccept				= 0	
			, @VoidFromTime				= NULL
			, @VoidToTime				= NULL
			, @MatchId					= 0
			, @FilterFromTransTime		= NULL
			, @FilterToTransTime		= NULL
			, @FilterBy					= 1
			, @SubIssueTypeId			= NULL
			, @AATime					= 0 
			, @PATime					= 0
			, @SATime					= 0
			, @CancelCOFromTime			= NULL
			, @CancelCOToTime			= NULL
			, @VoidFromTime_tmp			= NULL

		UPDATE TOP(1) m SET
			m.isFinish = 1
			,@MatchId = m.MatchId
			,@FilterFromTransTime = m.FilterFromTransTime
			,@FilterToTransTime = m.FilterToTransTime
			,@FilterBy = m.FilterBy
			,@SubIssueTypeId = m.SubIssueTypeId
			,@AATime = m.AATime
			,@PATime = m.PATime
			,@SATime = m.SATime
		FROM #FilterInfo m
		WHERE m.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;
		
		IF @AATime IS NULL AND @PATime IS NULL AND @SATime IS NULL --case AA,PA,SA fields blank
		BEGIN
			UPDATE #FilterInfo
			SET FilterVoidFromTime = @FilterFromTransTime, FilterVoidToTime = @FilterToTransTime
			WHERE MatchId = @MatchId
		END 
		ELSE IF @IsShowLogOnly = 0
		BEGIN
			SELECT @MinAccept = @AATime

			IF @MinAccept > @PATime SET @MinAccept = @PATime
			IF @MinAccept > @SATime SET @MinAccept = @SATime

			SELECT @VoidFromTime_tmp = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)

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
				FROM #tmpTransInfo b WITH(NOLOCK)
				WHERE b.IsMixParlay = 0
					AND ISNULL(b.betdaqid,-1) NOT IN (1)
				UNION ALL
				SELECT NULL AS transid, bm.Subtransid, bm.Subbettype AS bettype, bm.Subtransdate AS transdate, bm.Subchecktime AS checktime, bm.SubLiveBetAcceptTime AS LiveBetAcceptTime, bm.SubSecAcceptTime AS SecAcceptTime, bm.SubstatusID AS statusID
				FROM #tmpTransInfo bm 
				WHERE bm.IsMixParlay = 1
			)b
			CROSS APPLY (
					SELECT CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
								ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
										  ELSE 3 --Pending Accept
									 END
							END AS AcceptType
						  ,CASE 
								WHEN @FilterBy = 1 THEN b.transdate
								WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
						   END AS FromDate
			)act
			WHERE act.FromDate BETWEEN @VoidFromTime_tmp AND @FilterToTransTime
		
			/*	Get tickets that need to be canceled cash out (with allowance setting). Check AA/PA/SA for cancel cash out tickets based on [cashoutselling.AcceptMode]
				Auto Accept: AcceptMode = 1
				Pending Accept: AcceptMode = 0
				Second Accept: AcceptMode = 2
				AcceptMode = Null means that ticket is not accepted (Rejected or other fail to sell situation) => Not get
			*/
			SELECT @CancelCOFromTime = MIN(CASE WHEN b.CheckTimeCashOut >= DATEADD (SECOND,CASE WHEN b.AcceptModeCashOut = 1 THEN @AATime
																								WHEN b.AcceptModeCashOut = 2 THEN @SATime
																								WHEN b.AcceptModeCashOut = 0 THEN @PATime
																								END
																						,@FilterFromTransTime)
																THEN b.CheckTimeCashOut ELSE NULL END)
				  ,@CancelCOToTime = MAX(b.CheckTimeCashOut)
			FROM #tmpTransInfo b 
			WHERE b.IsMixParlay = 0
				AND b.betdaqid = -2 AND b.AcceptModeCashOut IS NOT NULL
				AND b.CheckTimeCashOut BETWEEN @VoidFromTime_tmp AND @FilterToTransTime

			IF @VoidFromTime IS NULL
			BEGIN
				SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
			END
			ELSE --Must ticket Void -> have cancel cash out.
			BEGIN
				IF @CancelCOFromTime IS NOT NULL 
				BEGIN
					IF @VoidFromTime > @CancelCOFromTime SET @VoidFromTime = @CancelCOFromTime --From Time: compare the time and get the smallest one

					IF @VoidToTime < @CancelCOToTime SET @VoidToTime = @CancelCOToTime --To Time: compare the time and get the largest one
				END
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
			,Subbettype
			,livehomescore 	
			,liveawayscore 			
			,betdaqid	
			,matchid
			,StatusId
			,SubStatusId
			,checktime
			,accepttype
			,SubIssueTypeId
			,FilterBy
			,IsCancelCashOut
			,CheckTimeCashOut
			,liveindicator
		)
	SELECT   b.transid
			,b.SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.bettype AS Subbettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.matchid
			,b.statusID
			,b.SubstatusID
			,b.checktime
			,CASE 
					WHEN b.checktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
			,d.SubIssueTypeId
			,d.FilterBy
			,CASE WHEN act.VoidTime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 0
				  ELSE CASE WHEN b.betdaqid = -2 AND b.CheckTimeCashOut BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime AND b.AcceptModeCashOut IS NOT NULL THEN 1
							ELSE 0 END
				  END AS IsCancelCashOut
			,b.CheckTimeCashOut
			,b.liveindicator
	FROM #tmpTransInfo b
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		CROSS APPLY (
			SELECT CASE WHEN d.FilterBy = 1 THEN b.transdate 
					WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
					WHEN d.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
			END AS VoidTime
		)act
	WHERE b.IsMixParlay = 0 
		AND 1 = CASE WHEN act.VoidTime BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime THEN 1
					 ELSE CASE WHEN b.betdaqid = -2 AND b.CheckTimeCashOut BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime AND b.AcceptModeCashOut IS NOT NULL THEN 1
							   ELSE 0 END
					 END
		
	UPDATE t
	SET accepttype = CASE WHEN b.AcceptModeCashOut = 0 THEN 3 ELSE b.AcceptModeCashOut END
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.transid = b.transid AND t.matchid = b.matchid
	WHERE b.IsMixParlay = 0 AND t.IsCancelCashOut = 1

	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsMixParlay = 1)
	BEGIN		
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
				,IsMixParlay
				,matchid
				,StatusId
				,SubStatusId
				,checktime
				,accepttype
				,SubIssueTypeId
				,FilterBy
				,IsCancelCashOut
				,CheckTimeCashOut
				,liveindicator
			)
		SELECT   b.transid AS TransId
				,b.SubTransID
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Subbettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.matchid
				,b.statusID
				,b.SubstatusID
				,b.Subchecktime
				,CASE 
						WHEN b.Subchecktime IS NULL THEN 1 --Auto Accept
						ELSE CASE 
									WHEN b.Subchecktime = DATEADD(SECOND,ISNULL(b.SubLiveBetAcceptTime,0) + ISNULL(b.SubSecAcceptTime,0), b.Subtransdate) THEN 2 --Second Accept
									ELSE 3 --Pending Accept
								END
					END AS accepttype
				,d.SubIssueTypeId
				,d.FilterBy
				,0 AS IsCancelCashOut
				,NULL AS CheckTimeCashOut
				,b.liveindicator
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON b.matchid = d.MatchId AND b.IsMixParlay = 1 
		WHERE CASE WHEN d.FilterBy = 1 THEN b.Subtransdate
				   WHEN d.FilterBy = 2 AND b.Subchecktime IS NOT NULL THEN b.Subchecktime
				   WHEN d.FilterBy = 2 AND b.Subchecktime IS NULL THEN b.Subtransdate
				END BETWEEN d.FilterVoidFromTime AND d.FilterVoidToTime
	END 

	IF @IssueTypeId = 10 --Red Card issue type 
	BEGIN
		--User selects the "Replacement of Sent-Off player" subtype -> When the system searches ticket, it will get from a ticket that has "Handicap(1)/1H Handicap(7)/1H 1X2(5)/FT 1X2(15)" bet type.
		DECLARE @MinTimeHDP DATETIME
		SELECT @MinTimeHDP = MIN (CASE WHEN b.FilterBy = 1 THEN b.transdate 
										WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
										WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
									END)
		FROM #TVSTicketBets b
		WHERE b.SubIssueTypeId = 21 AND b.Subbettype IN (1,7,5,15) AND b.IsCancelCashOut = 0
			
		IF @MinTimeHDP IS NULL
		BEGIN
			DELETE b FROM #TVSTicketBets b WHERE b.SubIssueTypeId = 21
		END
		ELSE 
		BEGIN
			DELETE b FROM #TVSTicketBets b 
			WHERE b.SubIssueTypeId = 21 AND b.IsCancelCashOut = 0
			AND (CASE WHEN b.FilterBy = 1 THEN b.transdate 
						WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
						WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
					END) < @MinTimeHDP
		END
	END

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
				FROM #TVSTicketBets R
				WHERE ID BETWEEN @StartRow AND @StopRow
					FOR JSON PATH))

				INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
				EXEC DBCTG.bodb02.dbo.TicketVoiding_CheckExistingRequest
					@TransInfoJson = @TransInfoJson_Request
					,@RequestId = @RequestId
					,@Mode = 1

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END
		
		IF EXISTS (SELECT TOP 1 1 FROM #TransidInRequest)
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
		END

		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MainParlayCount, HighLightMinTime, TransVoidToTime)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(act.VoidTime) AS VoidFromTime
		,MAX(act.VoidTime) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,MIN(act.VoidTime) AS HighLightMinTime
		,MAX(act.transdate) AS TransVoidToTime
	FROM #TVSTicketBets b
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		CROSS APPLY (SELECT CASE 
								WHEN b.FilterBy = 1 THEN b.transdate
								WHEN b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
								WHEN b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							 END AS VoidTime
							 ,b.transdate
					)act
	WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsCancelCashOut = 1)
	BEGIN
		UPDATE li
		SET CancelCashOutCount = b.CancelCashOutCount
		   ,VoidFromTime = CASE WHEN b.MIN_CheckTimeCashOut < li.VoidFromTime THEN b.MIN_CheckTimeCashOut ELSE li.VoidFromTime END
		   ,VoidToTime = CASE WHEN b.MAX_CheckTimeCashOut >  li.VoidToTime THEN b.MAX_CheckTimeCashOut ELSE li.VoidToTime END
		   ,HighLightMinTime = CASE WHEN b.MIN_CheckTimeCashOut < li.HighLightMinTime THEN b.MIN_CheckTimeCashOut ELSE li.HighLightMinTime END
		   ,TransVoidToTime = CASE WHEN b.MAX_CheckTimeCashOut > li.TransVoidToTime THEN b.MAX_CheckTimeCashOut ELSE li.TransVoidToTime END
		FROM #logInfo li
			CROSS APPLY(
				SELECT COUNT(b.transid) AS CancelCashOutCount
					  ,MIN(CheckTimeCashOut) AS MIN_CheckTimeCashOut
					  ,MAX(CheckTimeCashOut) AS MAX_CheckTimeCashOut
				FROM #TVSTicketBets b
				WHERE li.MatchId = b.matchid AND b.IsCancelCashOut = 1
				GROUP BY b.matchid
			)b
	END

	--Not display Score in message template when voiding non-live tickets only [193108]
	IF NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE liveindicator = 1)
	BEGIN
		UPDATE l SET l.LiveScores = ''
		FROM #logInfo l
	END

	/* Display warning message in case void second accept tickets before the allowance time of this type */
	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE accepttype = 2)
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
				WHERE t.accepttype = 2
					AND v.MatchId = l.MatchId
					AND 1 = CASE WHEN t.FilterBy = 1 AND t.transdate BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
										WHEN t.FilterBy = 2 AND t.checktime IS NOT NULL AND t.checktime BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
										WHEN t.FilterBy = 2 AND t.checktime IS NULL AND t.transdate BETWEEN s.VoidFromTime AND s.SAFromTime THEN 1
							ELSE 0 END
			)l
		
	END

	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, SingleCount INT, MainParlayCount INT, ActionId TINYINT)
	CREATE TABLE #CTE_Ticket_Single (RequestId INT, MatchId INT, TransId BIGINT, Bettype SMALLINT, IsCancelCO BIT)
	CREATE TABLE #CTE_Ticket_SubParlay (RequestId INT, MatchId INT, TransId BIGINT)

	DECLARE @cnt_s INT , @cnt_p INT	

	INSERT INTO #CTE_RequestDetail (RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, ActionId)
	SELECT rd.RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, ActionId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
	WHERE rd.RequestId = @RequestId

	INSERT INTO #CTE_Ticket_Single (RequestId, MatchId, TransId, Bettype, IsCancelCO)
	SELECT RequestId, MatchId, TransId, Bettype, IsCancelCO
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
	WHERE RequestId = @RequestId
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId)
	SELECT RequestId, MatchId, TransId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId
	SET @cnt_p = @@ROWCOUNT

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
		     , IsInValidTotalTickets
		     , IsExistedInOtherRequest
		     , IsExistsSecondAccept
		FROM @Validation

		-- 2. TransId in request table
		SELECT CAST(TransId AS VARCHAR(MAX)) AS TransIds, RequestId, MatchId
		FROM #TransidInRequest

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, InstantlySettleCount, SettleCount, CancelCashOutCount)
		SELECT @RequestId
			  ,s.matchid
			  ,COUNT(CASE WHEN b.IsCancelCashOut = 0 AND ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
			  ,COUNT(CASE WHEN s.IsCancelCO = 1 THEN s.transid ELSE NULL END) AS CancelCashOutCount
		FROM #CTE_Ticket_Single s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = s.MatchId
		WHERE b.StatusId IN (111, 112, 113)
		GROUP BY s.matchid
		
		--Check score for void message
		IF @cnt_s > 0
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT b.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
			FROM #CTE_Ticket_Single s WITH (NOLOCK)
				INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 0
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
			WHERE f.GroupName <> '2H'
		END

		IF @cnt_p > 0
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT b.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
			FROM #CTE_Ticket_SubParlay s WITH (NOLOCK)
				INNER JOIN #tmpTransInfo b ON b.Subtransid = s.TransId AND b.IsMixParlay = 1
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

		-- 3. Loginfo Table
		SELECT rd.MatchId
			,CASE WHEN @SiteDBGroupID = 0 THEN SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) ELSE NULL END AS LiveScores
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.SingleCount ELSE NULL END AS SingleCount
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.MainParlayCount ELSE NULL END AS MainParlayCount
			,CASE WHEN @SiteDBGroupID = 0 THEN a.HighLightMinTime ELSE NULL END AS HighLightMinTime
			,CASE WHEN @SiteDBGroupID = 0 THEN a.HighlightAcceptType ELSE NULL END AS HighlightAcceptType
			,CASE WHEN @SiteDBGroupID = 0 THEN a.MinTransId ELSE NULL END AS MinTransId
			,CASE WHEN @SiteDBGroupID = 0 THEN a.ActionType ELSE NULL END AS ActionType
		    ,CASE WHEN @SiteDBGroupID = 0 THEN a.TransVoidToTime ELSE NULL END AS TransVoidToTime
			,t.CashOutCount
			,t.InstantlySettleCount
			,t.SettleCount
			,t.CancelCashOutCount
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
		FROM #CTE_RequestDetail rd WITH (NOLOCK)
			CROSS APPLY (
					SELECT CONVERT(XML, rd.TransIds)
				)AS t1(xDATA)
			CROSS APPLY (
					SELECT NULLIF(t.c.value('@MinTime','DATETIME'),'')AS  HighLightMinTime
						,t.c.value('@MinType','TINYINT') AS  HighlightAcceptType
						,t.c.value('@MinTransId','BIGINT') AS  MinTransId
						,t.c.value('@ActionType','VARCHAR(100)') AS  ActionType
						,NULLIF(t.c.value('@TransVoidToTime','DATETIME'),'') AS TransVoidToTime
					FROM t1.xDATA.nodes('/r') t(c)
				) a
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreNormalTicket FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
			)s2(ScoreTicket2H)
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreOfMatch FROM @tblScoreMessage l WHERE l.MatchId = rd.MatchId FOR XML PATH('')
			)sm(ScoreOfMatch)

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo

	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId, 1 AS IsInValidTotalTickets, IsExistedInOtherRequest
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
			
		-- 3. Loginfo table (No need -> return table)
		SELECT MatchId FROM #logInfo WHERE Matchid IS NULL

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId
		
		RETURN;
	END

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l
	
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
	
	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(mt.TransId AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId mt
											WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction m WITH (NOLOCK) WHERE mt.TransId = m.TransId)
											FOR XML PATH('')), 1,1,'')
											,'')

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(mt.TransId AS VARCHAR(50)) 
										FROM @tmpMarkTransId mt
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction m WITH (NOLOCK) WHERE mt.TransId = m.TransId)
										FOR XML PATH('')), 1,1,'')
										,'')

	/*****************Return table **************************/
	-- 1. Validate table
	SELECT MatchId
		, IsInValidTotalTickets
		, IsExistedInOtherRequest
		, IsExistsSecondAccept
	FROM @Validation

	-- 2. TransId exists in other request table
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
				,MAX(TransVoidToTime) AS TransVoidToTime
			FROM #logInfo l
				CROSS APPLY(
							SELECT '|' + LiveScores
							FROM #logInfo rd
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
		,l.TransVoidToTime
	FROM _cte l
		OUTER APPLY (SELECT TOP 1 b.accepttype AS HighlightAcceptType, b.transid AS MinTransId, b.IsCancelCashOut
							    , CASE WHEN b.IsCancelCashOut = 0 AND ISNULL(b.betdaqid, -1) = -2 THEN 1 ELSE 0 END IsCashOut
						 FROM #TVSTicketBets b 
					     WHERE l.MatchId = b.matchid 
						 AND l.HighLightMinTime = (CASE 
														WHEN b.IsCancelCashOut = 0 AND b.FilterBy = 1 THEN b.transdate
													    WHEN b.IsCancelCashOut = 0 AND b.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
													    WHEN b.IsCancelCashOut = 0 AND b.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
														WHEN b.IsCancelCashOut = 1 THEN b.CheckTimeCashOut
														END)
						ORDER BY b.IsCancelCashOut ASC, b.transid ASC
			) AS h

	-- 4. List ticket unmark/mark & Transinfo table (if any)
	SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
		,t.IsCancelCashOut AS 'isCCO'
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds
		  ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #tmpTransInfo
	DROP TABLE #CTE_Ticket_Single
	DROP TABLE #CTE_Ticket_SubParlay
	DROP TABLE #CTE_RequestDetail
END
GO

