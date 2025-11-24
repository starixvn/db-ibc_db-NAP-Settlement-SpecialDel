/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_KO_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@KickOffInfo		  VARCHAR(MAX) = NULL
	,@OnlineServerId	  VARCHAR(10) = NULL
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Refactor code issue type EKO & WKO [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20231013@July: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240809@July: [TVS] EKO/WKOT - Add warning popup when there is a settled ticket [Redmine: #208617]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]
		- 20250507@July: Fix bug miss filter SiteDBGroupID [Redmine: #226513]
		- 20250729@Lani: [TVS] ScaleOut DBTrans [Phase 5] - Abnormal Account/EKO/WKO/Wrong Offered Name [Redmine: #232582]
		- 20250930@Lani: [TVS] Basketball AIO - Integrate new bet types for Basketball Player Props [Redmine: #234941]
		- 20251104@Lani: [TVS] Integrate Hybrid Parlay from Jacktime for Basketball sport [Redmine:#241502]
		- 20251124@July: Exclude mark/unmark transid from function SD [Redmine:#238929]

	Param's explanation:
	+ @KickOffInfo: 
			<root><r MatchId="0" KickOffTime=""/></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @KickOffInfoXML		  XML = NULL	
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT
			,@TransInfoJson			  VARBINARY(MAX) = NULL
			,@MatchId				   INT
			,@LogInfoTicketsJson      VARBINARY(MAX) = NULL
			,@SiteDBGroupID			  SMALLINT
			,@SiteDBDownInfoJson	  VARBINARY(MAX) = NULL
			,@TotalMarkedTickets	  INT = 0

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo (
		 MatchId				INT --parent matchid
		,KickOffTime			DATETIME
		,Sporttype				SMALLINT
		,MatchId_tmp			INT --child matchid
	)
	DECLARE @Validation AS TABLE (
			 MatchId                 INT
			,IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,IsHasSettledTicket		 BIT DEFAULT(0) 
			,IsHasInstantlySettledTicket BIT DEFAULT(0) 
			,LogInfoTicketsJson		 VARCHAR(MAX)
			,IsFinish				 BIT
		)

	SET @KickOffInfoXML = CONVERT(XML, @KickOffInfo)
	INSERT INTO #FilterInfo (MatchId, KickOffTime)
	SELECT  t.c.value('@MatchId','INT')
		   ,t.c.value('@KickOffTime','DATETIME')
	FROM @KickOffInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@KickOffInfoXML = NULL)) 

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId
	FROM #FilterInfo

	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT, MainTransId BIGINT, IsMixParlay BIT DEFAULT(0))
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT, MainTransId BIGINT, IsMixParlay BIT DEFAULT(0))
	DECLARE @tmpLogInfoTickets TABLE (TransId BIGINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
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
	  ,homeid INT
      ,awayid INT
	  ,leagueid INT
	  ,isNeutral BIT
	  ,matchcode NVARCHAR(50)
	  ,sporttype SMALLINT
	  ,eventstatus NVARCHAR(50)
	  ,SettlementStatus TINYINT
	  ,username NVARCHAR(50)
	  ,IsDeposit BIT DEFAULT(0)
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,SettledType TINYINT -- 1: Instant Settlement, 2: Normal Settlement
	  ,GroupName VARCHAR(50)
	  ,IsSiteDBDown BIT DEFAULT(0)
	  ,IsHybrid BIT DEFAULT(0)
	  ,FinalOdds SMALLMONEY
	  ,ID INT IDENTITY (1,1) PRIMARY KEY
	)

	BEGIN -- Instant Settlement declaration
		DECLARE @SupportInstantSettleSABABettype TABLE (bettype SMALLINT);
		INSERT INTO @SupportInstantSettleSABABettype (bettype)
		VALUES (228) --SABA OU Time Machine
			 , (229) --SABA HDP Time Machine

		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		DECLARE @MatchIds VARCHAR(MAX)
		SELECT @MatchIds = STRING_AGG(CAST(MatchId AS VARCHAR), ',') 
		FROM #FilterInfo
		
		INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
		SELECT matchid, bettype, betid 
		FROM dbo.f_TVS_GetInstantSettlementBettypes(@MatchIds);
		
	END

	UPDATE d
	SET d.Sporttype = m.sporttype, MatchId_tmp = d.MatchId
	FROM #FilterInfo d
		INNER JOIN dbo.match m ON d.MatchId = m.MatchId

	--Cricket/Baseball - Get child match
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE Sporttype IN (50,8))
	BEGIN
		INSERT INTO #FilterInfo (MatchId, KickOffTime, Sporttype, MatchId_tmp)
		SELECT d.MatchId, d.KickOffTime, m.sporttype, m.MatchId AS MatchId_tmp
		FROM #FilterInfo d
			INNER JOIN dbo.match m WITH(NOLOCK) ON d.MatchId = m.ParentID
		WHERE m.sporttype IN (50,8) AND m.ChildMatchType = 200 
	END

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
		)
	SELECT  DISTINCT d.MatchId
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
			,b.transdesc AS SubTransdesc  
			,b.modds 
			,b.SiteDBGroupID
			,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON b.matchid = d.MatchId_tmp
	WHERE b.transdate >= d.KickOffTime
			AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.liveindicator = 0
			AND b.betfrom <> 'P'
			AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,b.SiteDBGroupID,@OnlineServerId) = 1
						
	---get sub ticket of a mix parlay	
	IF EXISTS (
				SELECT TOP(1) 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #FilterInfo d ON bm.matchid = d.MatchId_tmp
				WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  			   WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   			   ELSE 0 END
					AND bm.betfrom <> 'P' 
					AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,bm.SiteDBGroupID,@OnlineServerId) = 1
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
					,IsHybrid
					,FinalOdds
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
				,sub.transdesc AS SubTransdesc  
				,b.modds
				,sub.SiteDBGroupID
				,CASE WHEN sub.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END AS IsSiteDBDown
				,CASE WHEN ISNULL(b.oddsspread,0) = 3 THEN 1 ELSE 0 END AS IsHybrid
				,sub.finalodds AS FinalOdds
		FROM #FilterInfo d
			 INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
			 INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
		WHERE	 sub.transdate >= d.KickOffTime  AND b.transdate >= d.KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.matchid = 29 AND b.bettype = 29
				AND b.liveindicator = 0 AND sub.liveindicator = 0
				AND sub.betfrom <> 'P'
				AND b.statusID NOT IN (101, 102, 103)
				AND b.SiteDBGroupID = sub.SiteDBGroupID
				AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,sub.SiteDBGroupID,@OnlineServerId) = 1
	END 

	---UPDATE column show loginfo details
	BEGIN
		UPDATE b
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
			,username = ci.username
		FROM #TVSTicketBets b
			INNER JOIN dbo.match m WITH (NOLOCK) ON	b.matchid = m.matchid
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON b.custid = ci.custid
	
		-- update Isdeposit
		UPDATE b
			SET IsDeposit = 1
		FROM	#TVSTicketBets b
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = b.srecommend)
	
		-- update get instant/settle
		UPDATE b
		SET  b.SettledType = CASE 
								WHEN ISNULL(m.eventstatus, '') <> 'completed'
									THEN CASE
											WHEN m.sporttype = 1 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype
												) THEN 1
											WHEN m.sporttype = 2 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype AND (b.betid = i.betid OR b.betid IS NULL)
												) THEN 1
											WHEN ib.bettype IS NOT NULL THEN 3
											ELSE 2
										END
								WHEN ib.bettype IS NOT NULL THEN 3
								ELSE 2
							END
		FROM #TVSTicketBets b 
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN @SupportInstantSettleSABABettype ib ON b.Subbettype = ib.bettype
		WHERE ISNULL(b.betdaqid,0) <> -2
			  AND b.SubStatusId IN (111, 112, 113) 
	
		UPDATE b
		SET GroupName = CASE WHEN gr.GroupName = 'Credit' AND b.betdaqid = -2 THEN 'Credit (CO)'
			                 WHEN gr.GroupName = 'Credit' AND b.IsMixParlay = 1 THEN 'Credit (Parlay)'
							 WHEN gr.GroupName = 'Deposit' AND b.betdaqid = -2 THEN 'Deposit (CO)'
							 WHEN gr.GroupName = 'Deposit' AND b.IsMixParlay = 1 THEN 'Deposit (Parlay)'
							 WHEN b.SettledType IN (1,3) THEN gr.GroupName + ' (Instant Settlement)'
							 ELSE gr.GroupName
							 END
		FROM #TVSTicketBets b
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f ON b.custid = f.CustID
			CROSS APPLY (SELECT CASE
								WHEN f.CustID IS NULL
									AND b.username <> '12EU'
									AND b.IsDeposit = 0
									AND b.mrecommend NOT IN (105181, 118473, 105183) -- MHC
									AND b.recommend NOT IN (11196380, 13423967, 52466) -- Foobet, 1E, 8RM
									AND b.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
										THEN 'Credit' --1. For Normal bets
								WHEN b.recommend IN (52466, 5707545)
										THEN '8RM/BARM' ----2: For 8RM/BARM
								WHEN f.CustID IS NULL -- Betdaq
									AND b.username <> '12EU' 
									AND b.IsDeposit = 1	
									AND b.mrecommend NOT IN (105181, 118473, 105183)
									AND b.recommend NOT IN (11196380, 13423967, 52466) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466
									AND b.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
										THEN 'Deposit' ----3. For Deposit bets
								WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
										THEN 'BetFair' ----8: For Betfair
								ELSE NULL
							END AS GroupName) AS gr	

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
		SELECT MatchId, SubTransid, IsMixParlay, SiteDBGroupID, CASE WHEN SubStatusId IN (0,1) AND Subbettype NOT IN (38) THEN 1 ELSE 0 END AS isMarked
		FROM #TVSTicketBets
		WHERE IsSiteDBDown = 1;

		SELECT @SingleCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 0 THEN 1 ELSE NULL END)
		      ,@ParlayCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 1 THEN 1 ELSE NULL END)
		FROM @tmpSiteDBDownInfo
	END

	UPDATE v 
	SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	   ,v.IsHasSettledTicket = l.IsHasSettledTicket
	   ,v.IsHasInstantlySettledTicket = l.IsHasInstantlySettledTicket
	FROM @Validation v
	OUTER APPLY( 
			SELECT COUNT(CASE WHEN IsMixParlay = 0 THEN transid ELSE NULL END) AS SingleCount
				 , COUNT(CASE WHEN IsMixParlay = 1 THEN transid ELSE NULL END) AS MainParlayCount
				 , MAX(CASE WHEN SettledType = 2 THEN 1 ELSE 0 END) AS IsHasSettledTicket
				 , MAX(CASE WHEN SettledType IN (1,3) THEN 1 ELSE 0 END) AS IsHasInstantlySettledTicket
			FROM #TVSTicketBets
			WHERE MatchId = v.MatchId AND IsSiteDBDown = 0
			GROUP BY MatchId
		)l
	
	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, MainParlayCount INT, ActionId TINYINT)
	CREATE TABLE #CTE_Ticket_Single (RequestId INT, MatchId INT, TransId BIGINT, Bettype SMALLINT)
	CREATE TABLE #CTE_Ticket_SubParlay (RequestId INT, MatchId INT, TransId BIGINT, MainTransId BIGINT)

	DECLARE @cnt_s INT , @cnt_p INT	

	INSERT INTO #CTE_RequestDetail (RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, MainParlayCount, ActionId)
	SELECT rd.RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, MainParlayCount, ActionId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
	WHERE rd.RequestId = @RequestId

	INSERT INTO #CTE_Ticket_Single (RequestId, MatchId, TransId, Bettype)
	SELECT RequestId, MatchId, TransId, Bettype
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
	WHERE RequestId = @RequestId
		AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,SiteDBGroupID,@OnlineServerId) = 1
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId, MainTransId)
	SELECT RequestId, MatchId, TransId, MainTransId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId 
		AND dbo.f_TVS_CheckIsSiteDbDown(@SiteDBGroupID,SiteDBGroupID,@OnlineServerId) = 1
	SET @cnt_p = @@ROWCOUNT

	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT SubTransid
		FROM #TVSTicketBets
		WHERE IsSiteDBDown = 0
	END
	ELSE --Edit request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT TransId
		FROM #CTE_Ticket_Single WITH (NOLOCK) 
		UNION ALL
		SELECT TransId
		FROM #CTE_Ticket_SubParlay WITH (NOLOCK) 
			
	END
		
	--Update odds support show betlist for Hybrid parlay
	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsHybrid = 1) 
	BEGIN
		;WITH CTE_MaxSubOdds AS (
			SELECT t.transid, MAX(bm.odds) AS Max_SubOdds
			FROM #TVSTicketBets t
				INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON t.Refno = bm.Refno AND t.matchid = bm.matchid
			WHERE t.IsMixParlay = 1 AND t.oddsspread = 3
			GROUP BY t.transid
		)
		UPDATE b
		SET b.SubOdds = x.Max_SubOdds
		FROM #TVSTicketBets AS b
		INNER JOIN CTE_MaxSubOdds AS x ON b.transid = x.transid
		WHERE b.IsMixParlay = 1 AND b.oddsspread = 3;
	END 

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) v
		SET v.IsFinish = 1, @MatchId = v.MatchId
		FROM @Validation v
		WHERE IsFinish IS NULL 

		IF @@ROWCOUNT = 0 BREAK;
	
		SET @LogInfoTicketsJson = COMPRESS((SELECT m.transid AS 'transid'
			,m.refno AS 'refno'		
			,m.SubTransId AS 'SubTransId'	
			,m.username AS 'username'		
			,m.transdate AS 'transdate'	
			,m.Stake AS 'Stake'	
			,m.odds AS 'odds'	
			,m.SubOdds AS 'SubOdds'
			,m.oddsspread AS 'oddsspread'	
			,m.OddsType AS 'OddsType'
			,m.bettype AS 'bettype'
			,m.SubBettype AS 'SubBettype'
			,m.STATUS AS 'STATUS'
			,m.SubStatus AS 'SubStatus'
			,m.currencyname AS 'currencyname'
			,m.betteam AS 'betteam'
			,m.SubBetTeam AS 'SubBetTeam'
			,m.Subhdp1 AS 'Subhdp1'
			,m.Subhdp2 AS 'Subhdp2'
			,m.hdp1 AS 'hdp1'
			,m.hdp2 AS 'hdp2'
			,m.livehomescore AS 'livehomescore'
			,m.liveawayscore AS 'liveawayscore'
			,m.betid AS 'betid'
			,m.betcheck AS 'betcheck'
			,m.Subchecktime AS 'Subchecktime'
			,m.IsMixParlay AS 'IsMixParlay'
			,m.SubTransdesc AS 'Transdesc'
			,m.betdaqid AS 'betdaqid'
			,m.WalletType AS 'WalletType'
			,m.RefCode AS 'RefCode'
			,CAST(m.winlost AS VARCHAR) AS 'winlost'
			,m.LiveIndicator AS 'IsLiveIndicator' 
			,m.actual_stake AS 'ActualStake'
			,m.ExtraInfo AS 'ExtraInfo'
			,m.winlostdate AS 'winlostdate'
			,m.IsDeposit AS 'IsDeposit'
			,m.matchid AS 'matchid'
			,m.homeid AS 'homeid'
			,m.awayid AS 'awayid'
			,m.leagueid AS 'leagueid'
			,m.IsNeutral AS 'IsNeutral'
			,m.matchcode AS 'matchcode'
			,m.SettlementStatus AS 'SettlementStatus'
			,m.sporttype AS 'sporttype'
			,f.GroupId AS 'GroupId'
			,m.GroupName AS 'GroupName'
			,CAST (CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS BIT) AS 'IsMarked'
			,m.IsHybrid AS 'IsHybrid'
			,m.FinalOdds AS 'FinalOdds'
		FROM @tmpLogInfoTickets s
			INNER JOIN #TVSTicketBets m ON s.transid = m.Subtransid
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON s.TransId = mt.TransId
			LEFT JOIN dbo.f_TVS_GetGroupId() f ON m.GroupName = f.GroupName
		WHERE m.matchid = @MatchId
		FOR JSON PATH))

		UPDATE v
		SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
		FROM @Validation v
		WHERE MatchId = @MatchId
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
		     , IsInValidTotalTickets
		     , IsExistedInOtherRequest
		     , IsHasSettledTicket
		     , IsHasInstantlySettledTicket
		FROM @Validation

		-- 2. TransId in request table
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds 
		FROM #TransidInRequest

		-- 3. Loginfo table 
		SELECT MatchId, LogInfoTicketsJson FROM @Validation

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		RETURN;
	END
	
	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		INSERT INTO @tmpMarkTransId (TransId, MainTransId, IsMixParlay)
		SELECT tp.SubTransid, tp.Transid, tp.IsMixParlay
		FROM #TVSTicketBets tp
		WHERE tp.SubStatusId IN (0,1)
			AND tp.Subbettype NOT IN (38) --Exclude Betbuilder
			AND IsSiteDBDown = 0
	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SET @OldActionId = (SELECT TOP 1 ISNULL(ActionId,0) FROM #CTE_RequestDetail WITH(NOLOCK))

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId, MainTransId, IsMixParlay)
			SELECT um.TransId, um.MainTransId, um.IsMixParlay
			FROM ( 
					SELECT TransId, TransId AS MainTransId, 0 AS IsMixParlay FROM #CTE_Ticket_Single s
					UNION ALL 
					SELECT TransId, MainTransId, 1 AS IsMixParlay FROM #CTE_Ticket_SubParlay p
				)um
				LEFT JOIN #TVSTicketBets tp ON um.TransId = tp.SubTransid AND tp.IsSiteDBDown = 0
			WHERE tp.TransId IS NULL 

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId, MainTransId, ISMixParlay)
			SELECT tp.SubTransid, tp.Transid, tp.IsMixParlay
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
				AND tp.Subbettype NOT IN (38) --Exclude Betbuilder
				AND tp.IsSiteDBDown = 0
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			INSERT INTO @tmpMarkTransId (TransId, MainTransId, ISMixParlay)
			SELECT tp.SubTransid, tp.Transid, tp.IsMixParlay
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
				AND tp.Subbettype NOT IN (38) --Exclude Betbuilder
				AND tp.IsSiteDBDown = 0
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			--Unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId, MainTransId, ISMixParlay)
			SELECT TransId, TransId AS MainTransId, 0 AS IsMixParlay FROM #CTE_Ticket_Single s
			UNION ALL 
			SELECT TransId, MainTransId, 1 AS IsMixParlay FROM #CTE_Ticket_SubParlay p
		END

	END

	SELECT @TotalMarkedTickets = COUNT(1) FROM @tmpMarkTransId
	
	--For case ticket marked function and then save request. Expect: NOT marked this ticket.
	BEGIN
		--For single
		DELETE m
		FROM @tmpMarkTransId m
		WHERE m.IsMixParlay = 0
			AND EXISTS (
				SELECT TOP 1 1 
				FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
				WHERE mt.TransId = m.TransId
			)

		--For sub parlay (normal & hybrid)
		DELETE m
		FROM @tmpMarkTransId m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.TransId = bm.TransId
		WHERE m.IsMixParlay = 1
			AND EXISTS (
				SELECT TOP 1 1 
				FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
				WHERE bm.matchid = mt.MatchId 
					AND (mt.TransId = m.MainTransId -- normal
					OR   mt.TransId = m.TransId) -- hybrid
			)
	END

	--For case Unmark ticket when edit request and then save request.
	BEGIN
		--For single
		DELETE m
		FROM @tmpUnmarkTransId m
		WHERE m.IsMixParlay = 0
			AND NOT EXISTS (
				SELECT TOP 1 1 
				FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
				WHERE mt.TransId = m.TransId
			)

		--For sub parlay (normal & hybrid)
		DELETE m
		FROM @tmpUnmarkTransId m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.TransId = bm.TransId
		WHERE m.IsMixParlay = 1
			AND NOT EXISTS (
				SELECT TOP 1 1 
				FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
				WHERE bm.matchid = mt.MatchId 
					AND (mt.TransId = m.MainTransId -- normal
					OR   mt.TransId = m.TransId) -- hybrid
			)
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
		, IsInValidTotalTickets
		, IsExistedInOtherRequest
	    , IsHasSettledTicket
		, IsHasInstantlySettledTicket
	FROM @Validation
		  
	-- 2. TransId exists in other request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		;WITH ChildListCTE AS (
			SELECT 
				r.RequestId, r.MatchId, r.MainTransId, 
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
			GROUP BY r.RequestId, r.MatchId, r.MainTransId
		)
		SELECT 
			r.RequestId, r.MatchId,
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
			).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS TransIds
		FROM ChildListCTE r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds 
		FROM #TransidInRequest
	END

	-- 3. Loginfo table 
	SELECT MatchId, LogInfoTicketsJson FROM @Validation

	-- 4. List ticket unmark/mark & Transinfo table (if any)
	SET @TransInfoJson = COMPRESS((SELECT b.matchid AS 'mid'
		,b.transid AS 't'
		,b.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.Subbettype AS 's_btype'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets b
	WHERE b.IsSiteDBDown = 0
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
		  ,@TotalMarkedTickets AS TotalMarkedTickets

	DROP TABLE #FilterInfo
	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #CTE_Ticket_Single
	DROP TABLE #CTE_Ticket_SubParlay
	DROP TABLE #CTE_RequestDetail
END
GO

