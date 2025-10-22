/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_NP_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 19
	,@NotParticipateInfo  VARCHAR(MAX) = NULL
	,@OnlineServerId	  VARCHAR(10) = NULL
)
AS
/*	
	Created: 20250311@July  
    Task : Clone SP for Not Participate
    DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
      
    Revisions:      
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]
		- 20250507@July: Fix bug miss filter SiteDBGroupID [Redmine: #226513]
		- 20250512@July: System didnot unmark ticket when user edit request [Redmine: #227009]
		- 20250619@July: Not show table loginfo when invalid ticket [Redmine: #227162]
		- 20250728@Lani: [TVS] ScaleOut DBTrans [Phase 4] - Reduced Over/Abandoned/Not Participate/Match Early Completed/Other Issues [Redmine: #232581]
		- 20250923@Lani: [TVS] Log Info - Add Details for some issue types [Redmine: #238132]
		- 20251022@Lani: [TVS] Not Participate - Add new bet types (Basketball player props) [Redmine: #241923]

	Param's explanation:	
		- @OnlineServerId = '0,1,3'
		- @NotParticipateInfo: 
		<root>
			<r MatchId="" SubIssueTypeId="" PlayerId="1001" BetTypeIds="1"/>
			<r MatchId="" SubIssueTypeId="" PlayerId="1002" BetTypeIds="1,2,3"/>
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
			,@NotParticipateInfoXML   XML = NULL
			,@MatchId				  INT = 0
			,@SiteDBGroupID			  SMALLINT
			,@SiteDBDownInfoJson	  VARBINARY(MAX) = NULL
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo(
		MatchId				INT
		,Bettype			SMALLINT
		,FilterTransdesc	NVARCHAR(2000)
	)
	DECLARE @tmpMatchId TABLE (MatchId INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

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
	  ,username NVARCHAR(50)
	  ,isDeposit BIT
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
	  ,homeid INT
	  ,awayid INT
	  ,leagueid INT
	  ,isNeutral BIT
	  ,matchcode NVARCHAR(50)
	  ,settlementstatus TINYINT
	  ,eventstatus NVARCHAR(50)
	  ,sporttype SMALLINT
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
	  ,FilterTransdesc NVARCHAR(1000)
	  ,FilterBettype	SMALLINT
	  ,IsSiteDBDown BIT DEFAULT(0)
	  --For count ticket follow bettype
	  ,GroupDisplay INT
	  ,GroupBettype SMALLINT
	  ,GroupTransdesc NVARCHAR(1000)
	  ,ID INT IDENTITY (1,1) PRIMARY KEY
	)

	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpOnlineServerId AS TABLE (ServerId SMALLINT)
	DECLARE @tmpLogInfoTickets AS TABLE (TransId BIGINT)
	DECLARE @tmpConsolidatedBettypes AS TABLE
	(
		ParentId	INT
		,TypeId		INT PRIMARY KEY
	)

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0)
			,IsExistedInOtherRequest BIT DEFAULT(0)
			,MatchId                 INT
			,LogInfoTicketsJson		 NVARCHAR(MAX)
		)

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmpOnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	INSERT INTO @tmpConsolidatedBettypes (ParentId, TypeId)
	SELECT f.GroupTypeId AS ParentId
		  ,f.Bettype AS TypeId
	FROM [dbo].[f_SD_GroupDisplayBettype] () AS f
	
	SET @NotParticipateInfoXML = CONVERT(XML, @NotParticipateInfo)
	INSERT INTO #FilterInfo (MatchId, FilterTransdesc, Bettype)
	SELECT t.c.value('@MatchId','INT')		
		,t.c.value('@PlayerId','NVARCHAR(1000)')
		,bt.bettype
	FROM @NotParticipateInfoXML.nodes('root/r') t(c)
		CROSS APPLY (
			SELECT value AS BetType
			FROM STRING_SPLIT (t.c.value('@BetTypeIds','VARCHAR(2000)'),',')
		)bt
	OPTION (OPTIMIZE FOR (@NotParticipateInfoXML = NULL))
	
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
			,FilterTransdesc
			,FilterBettype
			,IsSiteDBDown
			,GroupDisplay
			,GroupBettype
			,GroupTransdesc
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
		,CASE WHEN (b.bettype BETWEEN 653 AND 688) AND (b.bettype NOT BETWEEN 680 AND 684) THEN JSON_VALUE(b.transdesc,'$.pid') --36 new bettype basketball except bettype 'Most...'
			  WHEN b.bettype BETWEEN 680 AND 684 THEN JSON_VALUE(b.transdesc, '$.p[0].pid')-- Bettype Most of basketball
			  ELSE b.transdesc END AS FilterTransdesc
		,b.bettype AS FilterBettype
		,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
		,ISNULL(tb.ParentId,b.bettype) AS GroupDisplay
		,b.bettype AS GroupBettype
		,CASE WHEN (b.bettype BETWEEN 653 AND 688) AND (b.bettype NOT BETWEEN 680 AND 684) THEN JSON_VALUE(b.transdesc,'$.pid') --36 new bettype basketball except bettype 'Most...'
			  WHEN b.bettype BETWEEN 680 AND 684 THEN JSON_VALUE(b.transdesc, '$.p[0].pid')-- Bettype Most of basketball
			  ELSE b.transdesc END AS GroupTransdesc
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
				,FilterTransdesc
				,FilterBettype
				,IsSiteDBDown
				,GroupDisplay
				,GroupBettype
				,GroupTransdesc
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
			,CASE WHEN (sub.bettype BETWEEN 653 AND 688) AND (sub.bettype NOT BETWEEN 680 AND 684) THEN JSON_VALUE(sub.transdesc,'$.pid') --36 new bettype basketball except bettype 'Most...'
				  WHEN sub.bettype BETWEEN 680 AND 684 THEN JSON_VALUE(sub.transdesc, '$.p[0].pid')-- Bettype Most of basketball
				  ELSE sub.transdesc END AS FilterTransdesc
			,sub.bettype AS FilterBettype
			,CASE WHEN sub.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END AS IsSiteDBDown
			,ISNULL(tb.ParentId, sub.bettype) AS GroupDisplay
			,sub.bettype AS GroupBettype
			,CASE WHEN (sub.bettype BETWEEN 653 AND 688) AND (sub.bettype NOT BETWEEN 680 AND 684) THEN JSON_VALUE(sub.transdesc,'$.pid') --36 new bettype basketball except bettype 'Most...'
				  WHEN sub.bettype BETWEEN 680 AND 684 THEN JSON_VALUE(sub.transdesc, '$.p[0].pid')-- Bettype Most of basketball
				  ELSE sub.transdesc END AS GroupTransdesc
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
				AND b.FilterTransdesc = f.FilterTransdesc
		)t
	WHERE t.Bettype IS NULL

	---UPDATE column show loginfo details
	BEGIN
		UPDATE s
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
			,username = ci.username
		FROM #TVSTicketBets s
			INNER JOIN dbo.match m WITH (NOLOCK) ON	s.matchid = m.matchid
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON s.custid = ci.custid
	
		-- update Isdeposit
		UPDATE s 
			SET IsDeposit = 1
		FROM	#TVSTicketBets s
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = s.srecommend)
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
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.SubBettype AND i.matchid = b.matchid
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

	-- Get info for affected ticket popup
	IF @IsShowLogOnly = 0 -- Add request 
	BEGIN
		INSERT INTO @tmpLoginfoTickets (TransId)
		SELECT Subtransid
		FROM #TVSTicketBets 
		WHERE IsSiteDBDown = 0
	END
	ELSE -- Edit request
	BEGIN
		INSERT INTO @tmpLoginfoTickets (TransId)
		SELECT Transid
		FROM #CTE_Ticket_Single AS s
		UNION ALL
		SELECT s.TransId
		FROM #CTE_Ticket_SubParlay AS s
	END

	SET @LogInfoTicketsJson = COMPRESS((
		SELECT b.transid AS 'TransId'
			 , b.refno AS 'Refno'
			 , b.subtransid AS 'SubTransId'
			 , b.username AS 'UserName'
			 , b.transdate AS 'Transdate'
			 , b.stake AS 'Stake' 
			 , b.odds AS 'Odds'
			 , b.Subodds AS 'SubOdds'
			 , b.oddsspread AS 'Oddsspread'
			 , b.oddstype AS 'OddsType'
			 , b.bettype AS 'Bettype'
			 , b.Subbettype AS 'SubBettype'
			 , b.status AS 'Status'
			 , b.SubStatus AS 'Substatus'
			 , b.CurrencyName AS 'CurrencyName'
			 , b.betteam AS 'Betteam'
			 , b.Subbetteam AS 'SubBetteam'
			 , b.Subhdp1 AS 'SubHdp1'
			 , b.Subhdp2 AS 'SubHdp2'
			 , b.hdp1 AS 'Hdp1'
			 , b.hdp2 AS 'Hdp2'
			 , b.livehomescore AS 'LiveHomeScore'
			 , b.liveawayscore AS 'LiveAwayScore'
			 , b.betid AS 'BetId'
			 , b.betcheck AS 'BetCheck'
			 , b.Subchecktime AS 'SubCheckTime'
			 , b.IsMixParlay AS 'IsMixParlay'
			 , b.Transdesc AS 'Transdesc'
			 , b.betdaqid AS 'Betdaqid'
			 , b.WalletType AS 'WalletType'
			 , b.refcode AS 'RefCode'
			 , CAST(b.winlost AS VARCHAR) AS 'WinLost'
			 , b.liveindicator AS 'LiveIndicator' 
			 , b.actual_stake AS 'ActualStake'
			 , b.ExtraInfo AS 'ExtraInfo'
			 , b.winlostdate AS 'WinLostDate'
			 , b.matchid AS 'MatchId'
			 , b.homeid AS 'HomeId'
			 , b.awayid AS 'AwayId'
			 , b.leagueid AS 'LeagueId'
			 , b.isNeutral AS 'IsNeutral'
			 , b.matchcode AS 'MatchCode'
			 , b.settlementstatus AS 'SettlementStatus'
			 , b.sporttype AS 'Sporttype'
			 , b.isDeposit AS 'IsDeposit' 
			 , b.GroupDisplay AS 'GroupBettypeId'
			 , CASE WHEN b.IsMixParlay = 1 THEN 'Parlay' ELSE 'Single' END AS 'GroupName'
		FROM @tmpLogInfoTickets AS s
			INNER JOIN #TVSTicketBets AS b ON s.transId = b.Subtransid
	FOR JSON PATH))

	UPDATE v
	SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
	FROM @Validation AS v

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

		-- 5. Count ticket follow bettype, playerid
		IF @SiteDBGroupID = 0
		BEGIN
			;WITH cte AS
			(
				SELECT s.transid
					  ,s.requestid
					  ,CASE WHEN (b.bettype BETWEEN 653 AND 688) AND (b.bettype NOT BETWEEN 680 AND 684) THEN JSON_VALUE(b.transdesc,'$.pid') --36 new bettype basketball except bettype 'Most...'
							WHEN b.bettype BETWEEN 680 AND 684 THEN JSON_VALUE(b.transdesc, '$.p[0].pid')-- Bettype Most of basketball
							ELSE b.transdesc END AS PlayerId
					  ,s.Bettype
				FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single AS s WITH (NOLOCK)
				INNER JOIN bettrans AS b WITH (NOLOCK) ON b.transid = s.transid
				WHERE s.RequestId = @RequestId

				UNION ALL 

				SELECT sub.transid
					  ,sub.requestid
					  ,CASE WHEN (bm.bettype BETWEEN 653 AND 688) AND (bm.bettype NOT BETWEEN 680 AND 684) THEN JSON_VALUE(bm.transdesc,'$.pid') --36 new bettype basketball except bettype 'Most...'
							WHEN bm.bettype BETWEEN 680 AND 684 THEN JSON_VALUE(bm.transdesc, '$.p[0].pid')-- Bettype Most of basketball
							ELSE bm.transdesc END AS PlayerId
					  ,bm.bettype
				FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay AS sub WITH (NOLOCK)
				INNER JOIN bettransm AS bm WITH (NOLOCK) ON bm.transid = sub.TransId
				INNER JOIN bettrans AS b WITH (NOLOCK) ON bm.refno = b.refno 
				WHERE sub.RequestId =  @RequestId
			)
			SELECT b.typeid AS BetTypeId
				 , tm.teamname AS PlayerName
				 , tm.teamid AS PlayerId
				 , b.typenamee AS OriginalBetTypeName
				 , NULL AS BetId
				 , COUNT(1) AS TicketsCount
			FROM cte AS c
				INNER JOIN dbo.bettype AS b WITH (NOLOCK) ON c.Bettype = b.typeid
				INNER JOIN dbo.team AS tm WITH (NOLOCK) ON tm.teamid = TRY_CAST(c.PlayerId AS BIGINT)
			GROUP BY b.typeid, b.typenamee, tm.teamid, tm.teamname
		END	

		RETURN;
	END

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

	--5. Count ticket follow bettype
	--Added
	SELECT b.GroupDisplay AS BetTypeId
		  ,bt.typenamee AS OriginalBetTypeName
		  ,CONVERT(BIGINT,b.GroupTransdesc) AS PlayerId
		  ,t.teamname AS PlayerName
		  ,NULL AS BetId
		  ,NULL AS PlayerAndOdds
		  ,COUNT(b.transid) AS TicketsCount
	FROM #TVSTicketBets AS b
	INNER JOIN dbo.bettype AS bt WITH (NOLOCK) ON b.GroupDisplay = bt.typeid
	INNER JOIN dbo.Team AS t WITH (NOLOCK) ON t.teamid = TRY_CAST(b.GroupTransdesc AS BIGINT)
	WHERE EXISTS (SELECT 1 FROM f_TVS_BettypesUsingTransdesc() t1 WHERE t1.bettype = b.GroupBettype AND t1.TypeId = 0) AND b.IsSiteDBDown = 0
	GROUP BY b.GroupDisplay, bt.typenamee, CONVERT(BIGINT, b.grouptransdesc), t.teamname
	ORDER BY b.GroupDisplay ASC, bt.typenamee ASC

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


