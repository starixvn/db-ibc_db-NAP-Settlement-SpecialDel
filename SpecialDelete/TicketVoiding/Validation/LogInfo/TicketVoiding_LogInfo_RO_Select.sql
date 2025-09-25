/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_RO_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 19
	,@ReducedOverInfo	  VARCHAR(MAX) = NULL
	,@OnlineServerId	  VARCHAR(10) = NULL
)
AS
/*	
	Created: 20230608@Max  
    Task : [TVS] Support void Cricket when reducing over [Redmine: #185833]
    DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
      
    Revisions:      
        - 20230608@Max: Create SP - [Redmine: #185833]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]
		- 20250507@July: Fix bug miss filter SiteDBGroupID [Redmine: #226513]
		- 20250512@July: System didnot unmark ticket when user edit request [Redmine: #227009]
		- 20250619@July: Not show table loginfo when invalid ticket [Redmine: #227009]
		- 20250728@Lani: [TVS] ScaleOut DBTrans [Phase 4] - Reduced Over/Abandoned/Not Participate/Match Early Completed/Other Issues [Redmine: #232581]
		- 20250923@Lani: [TVS] Log Info - Add Details for some issue types [Redmine: #238132]

	Param's explanation:
		- @OnlineServerId = '0,1,3'
		- @ReducedOverInfo: 
		<root>
			<r MatchId="" SubIssueTypeId="" BetTypes="1" WicketOver ="" PlayerIds="" Runs="" Live="" NonLive=""/>
			<r MatchId="" SubIssueTypeId="" BetTypes="1,2" WicketOver ="" PlayerIds="" Runs="" Live="" NonLive=""/>
		</root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson			  VARBINARY(MAX) = NULL
			,@SiteDBGroupID			  SMALLINT
			,@SiteDBDownInfoJson	  VARBINARY(MAX) = NULL
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo(
		MatchId				INT
		,Bettype				SMALLINT
		,FilterSet          NVARCHAR(50)
        ,FilterRuns		    SMALLMONEY
		,FilterTransdesc	NVARCHAR(2000)
		,FilterLive			BIT
		,FilterNonLive		BIT
		,IsFancy			BIT DEFAULT (0)
	)
	DECLARE @tmpMatchId TABLE (MatchId INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	DECLARE	 @ReducedOverInfoXML		  XML = NULL
		    ,@VoidFromTime			  DATETIME = NULL
		    ,@VoidToTime			  DATETIME = NULL
			,@MatchId				  INT = 0
	
	CREATE TABLE #logInfo (
		 MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,InstantlySettleCount	INT
		,SettleCount            INT
		,MainParlayCount		INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)

	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, InstantlySettleCount INT, SettleCount INT)
	CREATE TABLE #TVSTicketBets(
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
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,FilterSet  NVARCHAR(50)
	  ,FilterLiveIndicator BIT
	  ,FilterTransdesc NVARCHAR(1000)
	  ,FilterHdp1 SMALLMONEY
	  ,FilterHdp2 SMALLMONEY
	  ,FilterBettype	SMALLINT
	  ,FilterBetteam NVARCHAR(10)
	  ,IsSiteDBDown BIT DEFAULT(0)
	  ,ID INT IDENTITY (1,1) PRIMARY KEY
	  --For bettype count
	  ,GroupDisplay INT
	  ,GroupBettype SMALLINT
	  ,GroupTransdesc NVARCHAR(1000)
	  ,GroupBetId NVARCHAR(50)
	)

	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpOnlineServerId AS TABLE (ServerId SMALLINT)
	DECLARE @tmpLogInfoTickets AS TABLE (TransId BIGINT)
	DECLARE @tmpInputtedRuns TABLE (BetTypeId SMALLINT, InputtedRuns INT, PlayerId INT)
	DECLARE @tmpConsolidatedBettypes AS TABLE
	(
		ParentId	INT
		,TypeId		INT PRIMARY KEY
	)

	DECLARE @tmpTicketInfo TABLE
	(
	     TransId			BIGINT
	    ,Transdesc			NVARCHAR(1000)
		,Bettype			SMALLINT
		,BetId				NVARCHAR(50)  
	)

	DECLARE @tmpBettypeCount TABLE
	(
		BetTypeId			SMALLINT
		,BetId				VARCHAR(100)
		,PlayerId			VARCHAR(MAX)
		,PlayerName         VARCHAR(100)
	    ,TicketsCount       INT
	)

	DECLARE @BettypeCountDetail TABLE(
		 BetTypeId			SMALLINT
	    ,InputtedRuns       VARCHAR(100)
		,BetId				VARCHAR(100)
		,PlayerId			VARCHAR(MAX)
		,PlayerName         VARCHAR(100)
	    ,TicketsCount       INT
	)

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmpOnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,MatchId                 INT
			,LogInfoTicketsJson		 NVARCHAR(MAX)
		)
	
	INSERT INTO @tmpConsolidatedBettypes (ParentId, TypeId)
	SELECT f.GroupTypeId AS ParentId
		  ,f.Bettype AS TypeId
	FROM [dbo].[f_SD_GroupDisplayBettype] () AS f
	
	SET @ReducedOverInfoXML = CONVERT(XML, @ReducedOverInfo)
	INSERT INTO #FilterInfo (MatchId, Bettype, FilterTransdesc, FilterSet, FilterRuns, FilterLive, FilterNonLive)
	SELECT t.c.value('@MatchId','INT')		
		,bt.bettype
		,pl.Transdesc
		,t.c.value('@FilterWicketOver','NVARCHAR(50)')
		,t.c.value('@Runs','SMALLMONEY')
		,t.c.value('@Live','BIT')
		,t.c.value('@NonLive','BIT')
	FROM @ReducedOverInfoXML.nodes('root/r') t(c)
		CROSS APPLY (
			SELECT value AS bettype
			FROM STRING_SPLIT (t.c.value('@BetTypeIds','VARCHAR(2000)'),',')
		)bt
		CROSS APPLY (
			SELECT value AS Transdesc
			FROM STRING_SPLIT (t.c.value('@PlayerIds','VARCHAR(2000)'),',')
		)pl
	OPTION (OPTIMIZE FOR (@ReducedOverInfoXML = NULL))
	
	UPDATE d SET d.IsFancy = 1
	FROM #FilterInfo d
		INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = d.Bettype
	WHERE bt.typenamee LIKE '%Fancy'

	SET @MatchId = (SELECT TOP(1) MatchId FROM #FilterInfo)

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT @MatchId	

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

	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match WITH(NOLOCK)
	WHERE (matchid = @MatchId OR ParentID = @MatchId)

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT bettype
	FROM #FilterInfo
	
	--Search single tickets
	INSERT INTO #TVSTicketBets(
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
			,IsSiteDBDown
			,FilterSet
			,FilterLiveIndicator
			,FilterTransdesc
			,FilterHdp1
			,FilterHdp2
			,FilterBettype
			,FilterBetteam
			--For ticket count
			,GroupDisplay
		    ,GroupBettype
			,GroupTransdesc
			,GroupBetId
		)
	SELECT @MatchId AS matchid
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
		,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
		,CONVERT(NVARCHAR(50), b.betid) AS FilterSet
		,b.liveindicator AS FilterLiveIndicator
		,b.transdesc AS FilterTransdesc
		,b.hdp1 AS FilterHdp1
		,b.hdp2 AS FilterHdp2
		,b.bettype AS FilterBettype
		,b.betteam AS FilterBetteam
		,ISNULL(tb.parentid, b.bettype) AS GroupDisplay
		,b.bettype AS GroupBettype
		,b.transdesc AS GroupTransdesc
		,CONVERT(NVARCHAR(50), b.betid) AS GroupBetId
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @tmpMatchId m ON m.MatchId = b.matchid
		INNER JOIN @bettype_tmp d ON b.bettype = d.bettype
		LEFT JOIN @tmpConsolidatedBettypes AS tb ON tb.TypeId = b.bettype
	WHERE  1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
				   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
				   ELSE 0 END
		AND b.betfrom <> 'P'
		AND 1 = CASE WHEN b.SiteDBGroupID = @SiteDBGroupID AND EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = b.SiteDBGroupID) THEN 1
					 WHEN NOT EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = b.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
					 ELSE 0 END


	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN @tmpMatchId d oN d.MatchId = bm.matchid
					WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  			       WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   				   ELSE 0 END
						AND bm.betfrom <> 'P' 
						AND 1 = CASE WHEN bm.SiteDBGroupID = @SiteDBGroupID AND EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = bm.SiteDBGroupID) THEN 1
									 WHEN NOT EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = bm.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
									 ELSE 0 END

					)
	BEGIN		
		INSERT INTO #TVSTicketBets(
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
				,IsSiteDBDown
				,FilterSet
				,FilterLiveIndicator
				,FilterTransdesc
				,FilterHdp1
				,FilterHdp2
				,FilterBettype
				,FilterBetteam
				--For ticket count
				,GroupDisplay
				,GroupBettype
				,GroupTransdesc
				,GroupBetId
			)
		SELECT @MatchId AS matchid
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
			,CASE WHEN sub.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END AS IsSiteDBDown
			,sub.betcheck AS FilterSet
			,sub.liveindicator AS FilterLiveIndicator
			,sub.transdesc AS FilterTransdesc
			,sub.hdp1 AS FilterHdp1
			,sub.hdp2 AS FilterHdp2
			,sub.bettype AS FilterBettype
			,sub.betteam AS FilterBetteam
			,ISNULL(tb.ParentId,sub.bettype) AS GroupDisplay
			,sub.bettype AS GroupBettype
			,sub.transdesc AS GroupTransdesc
			,sub.betcheck AS GroupBetId
		FROM @tmpMatchId d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			INNER JOIN @bettype_tmp t ON t.bettype = sub.bettype
			LEFT JOIN @tmpConsolidatedBettypes AS tb ON tb.TypeId = sub.bettype
		WHERE  1= CASE WHEN @ActionId <> 2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
					   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
			AND sub.betfrom <> 'P'
			AND b.matchid = 29 AND b.bettype = 29
			AND b.liveindicator = 0
			AND b.statusID NOT IN (102, 103)
			AND b.SiteDBGroupID = sub.SiteDBGroupID
			AND 1 = CASE WHEN sub.SiteDBGroupID = @SiteDBGroupID AND EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = sub.SiteDBGroupID) THEN 1
						 WHEN NOT EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = sub.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
						 ELSE 0 END

	END
	
	--Remove invalid data
	DELETE b
	FROM #TVSTicketBets b
		OUTER APPLY (
			SELECT TOP 1 Bettype
			FROM #FilterInfo f
			WHERE f.Bettype = b.FilterBettype
				AND 1 = CASE WHEN f.FilterLive = 1 AND b.FilterLiveIndicator = 1 THEN 1
							WHEN f.FilterNonLive = 1 AND b.FilterLiveIndicator = 0 THEN 1
					ELSE 0 END
				AND (f.FilterSet = '' OR b.FilterSet LIKE f.FilterSet + '%')
				AND (f.FilterTransdesc = '' OR b.FilterTransdesc = f.FilterTransdesc)
				AND 1 = CASE WHEN f.FilterRuns = '' THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 0 AND b.FilterHdp1 > FilterRuns THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 1 AND b.FilterBetteam = 'y' AND b.FilterHdp2 > f.FilterRuns THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 1 AND b.FilterBetteam = 'n' AND b.FilterHdp1 > f.FilterRuns THEN 1
					ELSE 0 END
		)t
	WHERE t.Bettype IS NULL

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
		
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
		END
		
	END

	--Get ticket of sitedb down 
	BEGIN
		DECLARE @tmpSiteDBDownInfo TABLE (
			MatchId INT,
			TransId BIGINT,
			IsMixParlay BIT,
			SiteDBGroupID SMALLINT,
			isMarked BIT
		);
		DECLARE @SingleCountSiteDBDown INT
		       ,@ParlayCountSiteDBDown INT

		INSERT INTO @tmpSiteDBDownInfo (MatchId, TransId, IsMixParlay, SiteDBGroupID, isMarked)
		SELECT MatchId, SubTransid, IsMixParlay, SiteDBGroupID, CASE WHEN SubStatusId IN (0,1) THEN 1 ELSE 0 END AS isMarked
		FROM #TVSTicketBets
		WHERE IsSiteDBDown = 1;

		SELECT @SingleCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 0 THEN 1 ELSE NULL END)
		      ,@ParlayCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 1 THEN 1 ELSE NULL END)
		FROM @tmpSiteDBDownInfo
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, InstantlySettleCount, SettleCount, MainParlayCount)
	SELECT b.matchid AS MatchId
		,NULL AS LiveScores
		,MIN(b.Subtransdate) AS VoidFromTime
		,MAX(b.Subtransdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
	FROM #TVSTicketBets b
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
	WHERE b.IsSiteDBDown = 0
	GROUP BY b.matchid

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
		AND 1 = CASE WHEN SiteDBGroupID = @SiteDBGroupID AND EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = SiteDBGroupID) THEN 1
					 WHEN NOT EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = SiteDBGroupID) THEN 1  -- Get ticket sitedb down
					 ELSE 0 END 
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId)
	SELECT RequestId, MatchId, TransId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId 
		AND 1 = CASE WHEN SiteDBGroupID = @SiteDBGroupID AND EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = SiteDBGroupID) THEN 1
					 WHEN NOT EXISTS (SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = SiteDBGroupID) THEN 1  -- Get ticket sitedb down
					 ELSE 0 END 
	SET @cnt_p = @@ROWCOUNT

	--Get info for affected ticket popup
	IF @IsShowLogOnly = 0 -- Add request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT subtransid
		FROM #TVSTicketBets
		WHERE IsSiteDBDown = 0
	END
	ELSE -- Edit request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT TransId
		FROM #CTE_Ticket_Single AS s
		UNION ALL
		SELECT TransId
		FROM #CTE_Ticket_SubParlay
	END

	SET @LogInfoTicketsJson = COMPRESS((
		SELECT b.transid AS 'TransId'
			  ,b.refno AS 'Refno'
			  ,b.Subtransid AS 'SubTransId'
			  ,b.transdate AS 'Transdate'
			  ,b.stake AS 'Stake'
			  ,b.odds AS 'Odds'
			  ,b.Subodds AS 'SubOdds'
			  ,b.oddsspread AS 'Oddsspread'
			  ,b.oddstype AS 'OddsType'
			  ,b.bettype AS 'Bettype'
			  ,b.Subbettype AS 'SubBettype'
			  ,b.Status AS 'Status'
			  ,b.SubStatus AS 'SubStatus'
			  ,b.CurrencyName AS 'CurrencyName'
			  ,b.betteam AS 'Betteam'
			  ,b.Subbetteam AS 'SubBetteam'
			  ,b.Subhdp1 AS 'SubHdp1'
			  ,b.Subhdp2 AS 'SubHdp2'
			  ,b.hdp1 AS 'Hdp1'
			  ,b.hdp2 AS 'Hdp2'
			  ,b.livehomescore AS 'Livehomescore'
			  ,b.liveawayscore AS 'Liveawayscore'
			  ,b.betid AS 'BetId'
			  ,b.betcheck AS 'BetCheck'
			  ,b.Subchecktime AS 'SubChecktime'
			  ,b.IsMixParlay AS 'IsMixParlay'
			  ,b.Transdesc AS 'Transdesc'
			  ,b.betdaqid AS 'Betdaqid'
			  ,b.WalletType AS 'WalletType'
			  ,b.RefCode AS 'RefCode'
			  ,CAST(b.winlost AS VARCHAR) AS 'Winlost'
			  ,b.LiveIndicator AS 'IsLiveIndicator' 
			  ,b.actual_stake AS 'ActualStake'
			  ,b.ExtraInfo AS 'ExtraInfo'
			  ,b.winlostdate AS 'WinLostDate'
			  ,b.matchid AS 'matchid'
			  ,ISNULL(tb.parentid, b.Subbettype) AS 'GroupBettypeId' --Return for web filter bettype
			  ,CASE WHEN b.IsMixParlay = 1 THEN 'Parlay' ELSE 'Single' END AS 'GroupName'
		FROM @tmpLogInfoTickets AS s
			INNER JOIN #TVSTicketBets AS b ON s.TransId = b.Subtransid
			LEFT JOIN @tmpConsolidatedBettypes AS tb ON tb.TypeId = b.Subbettype
	FOR JSON PATH))

	UPDATE v
	SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
	FROM @Validation v

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, InstantlySettleCount, SettleCount)
		SELECT @RequestId
			  ,s.matchid
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
		FROM #CTE_Ticket_Single s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets b ON s.TransId = b.transid AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND s.MatchId = @MatchId
		WHERE b.StatusId IN (111, 112, 113)
		GROUP BY s.matchid

		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest

		-- 3.Loginfo table
		SELECT DISTINCT rd.MatchId
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.SingleCount ELSE NULL END AS SingleCount
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.MainParlayCount ELSE NULL END AS MainParlayCount
			,tmp.InstantlySettleCount
			,tmp.SettleCount
			,v.LogInfoTicketsJson
		FROM #CTE_RequestDetail AS rd
			LEFT JOIN #logInfoVoidPage AS tmp ON rd.RequestId = tmp.RequestId AND rd.MatchId = tmp.MatchId
			INNER JOIN @Validation AS v ON rd.MatchId = v.MatchId
			
		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		--5. Count detail group by bettype
		--Added
		IF @SiteDBGroupID = 0
		BEGIN
			INSERT INTO @tmpTicketInfo (TransId, Transdesc, BetId, Bettype)
			SELECT s.TransId, b.transdesc, CONVERT(NVARCHAR(50),b.BetId) AS BetId, s.Bettype
			FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single AS s WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON s.TransId = b.TransId
			WHERE s.RequestId = @RequestId
			UNION ALL 
			SELECT sub.TransId, bm.transdesc, CASE WHEN ISNULL(bm.betcheck,'') = '' THEN 0 ELSE b.betcheck END AS BetId,  bm.bettype
			FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay AS sub WITH (NOLOCK)
				INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON sub.TransId = bm.transid
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
			WHERE sub.RequestId = @RequestId

			INSERT INTO @tmpBettypeCount (BetTypeId, BetId, TicketsCount)
			SELECT s.Bettype, s.BetId, COUNT(1) AS TicketsCount
			FROM @tmpTicketInfo AS s
			WHERE NOT EXISTS (SELECT 1 FROM f_TVS_BettypesUsingTransdesc() AS b WHERE b.Bettype = s.Bettype)
			GROUP BY s.Bettype, s.BetId
			
			IF EXISTS (SELECT TOP 1 1 
					   FROM @tmpTicketInfo AS t 
					   WHERE EXISTS (SELECT TOP 1 1 FROM f_TVS_BettypesUsingTransdesc() AS b WHERE b.bettype = t.Bettype AND TypeId = 0))
			BEGIN
				INSERT INTO @tmpBettypeCount (BetTypeId, PlayerId, TicketsCount)
				SELECT s.Bettype, s.Transdesc, COUNT(1) AS TicketCounts
				FROM @tmpTicketInfo AS s
				WHERE EXISTS (SELECT 1 FROM f_TVS_BettypesUsingTransdesc() AS b WHERE b.Bettype = s.Bettype AND b.TypeId = 0)
				GROUP BY s.Bettype, s.Transdesc

				UPDATE b
				SET b.PlayerName = t.teamname
				FROM @tmpBettypeCount AS b
				LEFT JOIN dbo.team AS t ON b.PlayerId = t.teamid				
			END

			INSERT INTO @tmpInputtedRuns (BetTypeId, InputtedRuns, PlayerId)
			SELECT b.BetTypeId, infor.Runs, p.PlayerId
			FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
					CROSS APPLY (
							SELECT CONVERT(XML, rd.TransIds)
						) AS t1(xDATA)
					CROSS APPLY (
							SELECT ISNULL(t.c.value('@BetTypeIds','VARCHAR(MAX)'),0) AS BetTypeIds
								  ,ISNULL(t.c.value('@Runs','VARCHAR(20)'),NULL) AS Runs
								  ,t.c.value('@PlayerIds','VARCHAR(MAX)') AS PlayerIds
							FROM t1.xDATA.nodes('/r') t(c)
						) AS infor
					CROSS APPLY (
							SELECT DISTINCT value AS BetTypeId
							FROM STRING_SPLIT(infor.BetTypeIds, ',')
							WHERE value <> ''
						) b
					CROSS APPLY (
							SELECT DISTINCT value AS PlayerId
							FROM STRING_SPLIT(infor.PlayerIds,',')
					) AS p
			WHERE rd.RequestId = @RequestId

			INSERT INTO @BettypeCountDetail (BetTypeId, InputtedRuns, BetId, b.PlayerId, PlayerName, TicketsCount)
			SELECT DISTINCT b.BetTypeId, r.InputtedRuns, BetId, r.PlayerId, PlayerName, TicketsCount
			FROM @tmpBettypeCount AS b
			LEFT JOIN @tmpInputtedRuns AS r ON b.BetTypeId = r.BetTypeId
			WHERE r.PlayerId = 0
			UNION ALL 
			SELECT b.BetTypeId, r.InputtedRuns, BetId, r.PlayerId, PlayerName, TicketsCount
			FROM @tmpBettypeCount AS b
			LEFT JOIN @tmpInputtedRuns AS r ON b.BetTypeId = r.BetTypeId AND b.PlayerId = r.PlayerId
			WHERE r.PlayerId <> 0
			
			;WITH CTE AS (
			SELECT 
					BetTypeId,
					InputtedRuns,
					BetId,
					PlayerName,
					TicketsCount,
					ROW_NUMBER() OVER (PARTITION BY b.bettypeId, b.PlayerId, b.betid ORDER BY b.bettypeId, b.PlayerId, b.betid, b.InputtedRuns) AS RowId
			FROM @BettypeCountDetail b
			)
			SELECT BetTypeId, b.typenamee AS OriginalBetTypeName, InputtedRuns, BetId, PlayerName, TicketsCount 
			FROM CTE AS c
			INNER JOIN bettype AS b WITH (NOLOCK) ON c.BetTypeId = b.typeid
			WHERE RowId < 2
			ORDER BY BetTypeId ASC, InputtedRuns ASC, BetId ASC
		END

		RETURN;
	END

	INSERT INTO @tmpBettypeCount (BetTypeId, BetId, TicketsCount, PlayerId)
	SELECT b.GroupDisplay AS BetTypeId, GroupBetId AS BetId, COUNT(1) AS TicketsCount, 0
	FROM #TVSTicketBets AS b
	WHERE b.IsSiteDBDown = 0 AND NOT EXISTS (SELECT 1 FROM f_TVS_BettypesUsingTransdesc() AS t WHERE t.Bettype = b.GroupBettype)
	GROUP BY b.GroupDisplay, b.GroupBetId

	IF EXISTS (SELECT TOP 1 1 
					   FROM #TVSTicketBets AS t 
					   WHERE EXISTS (SELECT TOP 1 1 FROM f_TVS_BettypesUsingTransdesc() AS b WHERE b.bettype = t.Bettype AND TypeId = 0))
	BEGIN
		INSERT INTO @tmpBettypeCount (BetTypeId, PlayerId, TicketsCount)
		SELECT s.GroupDisplay AS BetTypeId, s.SubTransdesc, COUNT(1) AS TicketCounts
		FROM #TVSTicketBets AS s
		WHERE EXISTS (SELECT 1 FROM f_TVS_BettypesUsingTransdesc() AS b WHERE b.Bettype = s.GroupBettype AND b.TypeId = 0) AND s.IsSiteDBDown = 0
		GROUP BY s.GroupDisplay, s.SubTransdesc

		UPDATE b
		SET b.PlayerName = t.teamname
		FROM @tmpBettypeCount AS b
		LEFT JOIN dbo.team AS t ON b.PlayerId = t.teamid				
	END

	INSERT INTO @tmpInputtedRuns (BetTypeId, PlayerId, InputtedRuns)
	SELECT DISTINCT b.GroupDisplay, CASE WHEN ISNULL(b.GroupTransdesc,'') = '' THEN 0 ELSE b.GroupTransdesc END AS PlayerId, CAST(f.FilterRuns AS INT) AS InputtedRuns
	FROM #TVSTicketBets AS b
	INNER JOIN #FilterInfo AS f ON b.GroupBettype = f.Bettype
	WHERE b.IsSiteDBDown = 0

	INSERT INTO @BettypeCountDetail (BetTypeId, InputtedRuns, BetId, b.PlayerId, PlayerName, TicketsCount)
	SELECT DISTINCT b.BetTypeId, r.InputtedRuns, BetId, r.PlayerId, PlayerName, TicketsCount
	FROM @tmpBettypeCount AS b
	LEFT JOIN @tmpInputtedRuns AS r ON b.BetTypeId = r.BetTypeId
	WHERE r.PlayerId = 0
	UNION ALL 
	SELECT b.BetTypeId, r.InputtedRuns, BetId, r.PlayerId, PlayerName, TicketsCount
	FROM @tmpBettypeCount AS b
	LEFT JOIN @tmpInputtedRuns AS r ON b.BetTypeId = r.BetTypeId AND b.PlayerId = r.PlayerId
	WHERE r.PlayerId <> 0


	UPDATE v 
	SET  v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
		)l

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

	-- 1. Validate table
	SELECT MatchId
		,IsInValidTotalTickets
		,IsExistedInOtherRequest
	FROM @Validation

	-- 2. TransId in request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT RequestId
			,STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId) 
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,r.MatchId
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT RequestId, Matchid, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	SELECT l.MatchId
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,SUM(InstantlySettleCount) AS InstantlySettleCount
		,SUM(SettleCount) AS SettleCount
		,SUM(MainParlayCount) AS MainParlayCount
		,v.LogInfoTicketsJson
	FROM #logInfo AS l
	INNER JOIN @Validation AS v ON l.MatchId = v.MatchId
	GROUP BY l.MatchId, v.LogInfoTicketsJson

	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
		,Subtransid  AS 's_t'
		,custid AS  'c'           
		,bettype AS 'btype'
		,betid AS 'bid'
		,IsMixParlay AS 'isP'
		,SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets
	WHERE IsSiteDBDown = 0
	FOR JSON PATH))

	--List ticket insert table TicketVoiding_PendingMarkTickets
	SET @SiteDBDownInfoJson = COMPRESS((SELECT MatchId AS 'mid'
		,transid AS 't'
		,IsMixParlay AS 'isP'
		,SiteDBGroupID AS 'sitedb'
		,isMarked AS 'isMarked'
	FROM @tmpSiteDBDownInfo 
	FOR JSON PATH))
	
	-- 4. List ticket unmark/mark & Transinfo table (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds
		  ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
		  ,CONVERT(VARCHAR(MAX), @SiteDBDownInfoJson, 1) AS SiteDBDownInfoJson
		  ,@SingleCountSiteDBDown AS SingleCount
		  ,@ParlayCountSiteDBDown AS ParlayCount

	-- 5. Count ticket follow bettype
	;WITH CTE AS (
		SELECT 
				BetTypeId,
				InputtedRuns,
				BetId,
				PlayerName,
				TicketsCount,
				ROW_NUMBER() OVER (PARTITION BY b.bettypeId, b.PlayerId, b.betid ORDER BY b.bettypeId, b.PlayerId, b.betid, b.InputtedRuns) AS RowId
		FROM @BettypeCountDetail b)
	SELECT BetTypeId, b.typenamee AS OriginalBetTypeName, InputtedRuns, BetId, PlayerName, NULL AS PlayerAndOdds, TicketsCount 
	FROM CTE AS c
	INNER JOIN bettype AS b WITH (NOLOCK) ON c.BetTypeId = b.typeid
	WHERE RowId < 2
	ORDER BY BetTypeId ASC, InputtedRuns ASC, BetId ASC

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


