/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Select] 
(
	 @MatchId			INT
    ,@RequestId			INT = NULL
    ,@IssueTypeId		INT = NULL
	,@RequestDetailId INT = NULL --Support WMO(12) issuetype
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200405@Max: Enhance EKO Issue Type - [Redmine: #126418]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200819@Max: HotFix - [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
	    - 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785] 
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201127@Charles: God of fortune [Redmine: #146053]
		- 20201216@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210401@Max: [TVS] EC2020 Preparation [Redmine: #151103]
		- 20210420@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20210427@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210504@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20211117@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211207@July: Implement New Cash Out Model - Remove code CO [Redmine: #165097] 
		- 20220110@Max: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220221@Max: Remove SABA of league name for China View sites [Redmine: #168651]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220620@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230424@July: [TVS] Enhance auto cancel cash out for TVS [Redmine: #186417]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230823@Max: [TVS] Instant Settlement of Basketball [Redmine: #185492]
		- 20230830@July: Remove SABA of league name for Jolly View sites [Redmine: #193213]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20231206@July: [TVS] Update message template when Pool House bet types are affected [Redmine: #196467]
		- 20240129@July: Update the Advance Mode for bet types of Basketball [Redmine: #199605]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240307@July: [TVS] Abnormal Bet - Support void System Parlay tickets [Redmine: #196462]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240514@July: [TVS] EKO/WKOT - Add message template to the Add Request page [Redmine: #203776]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240916@Max: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]
		- 20240925@July: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
		- 20241021@Max: [TVS] New Issue Type - Other Issues [Redmine: #211913]
		- 20241028@Max: [TVS] Virtual Sports 6 (Betby) - Virtual Betby Basketball [Redmine: #212502]
		- 20241126@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]
		- 20250121@Lani: [TVS] Return 'GroupBettypeId' column [Redmine: #217176]
		- 20250219@July: [TVS] Apply new Void Request page for some issue types of TVS [Redmine: #191397]
		- 20250321@Lani: [TVS] Enhance out of memory issue [Redmine: #217771]
		- 20250324@Max: [TVS] Virtual Sports 7 (Kiron Virtual Sports) [Redmine: #219045]
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @SiteDBGroupID SMALLINT
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmp_MissingTransId AS TABLE (TransId BIGINT PRIMARY KEY)

	CREATE TABLE #TVSTicketBets (
		GroupID               BIGINT,
        transid               BIGINT,
        SubTransid            BIGINT,
        refno                 BIGINT,
        custid                INT,
        username              VARCHAR(30),
        odds                  SMALLMONEY,
        SubOdds               SMALLMONEY,
        oddsspread            MONEY,
        OddsType              INT,
        transdate             DATETIME,
        bettype               SMALLINT,
        betteam               NVARCHAR(10),
        SubBetTeam            NVARCHAR(10),
        betcheck              NVARCHAR(50),
        SubBetcheck           NVARCHAR(50),
        Subhdp1               SMALLMONEY,
        Subhdp2               SMALLMONEY,
        hdp1                  SMALLMONEY,
        hdp2                  SMALLMONEY,
        livehomescore         SMALLINT,
        liveawayscore         SMALLINT,
        creator               INT,
        creatorName           VARCHAR(30),
        Stake                 MONEY,
        currencyname          VARCHAR(20),
        IsDeposit             BIT DEFAULT(0),
        STATUS                NVARCHAR(10),
        SubStatus             NVARCHAR(10),
        srecommend            INT,
        mrecommend            INT,
        recommend             INT,
        SubLeagueId           INT,
        betid                 BIGINT DEFAULT(0),
        Transdesc             NVARCHAR(1000),
        betdaqid              BIGINT,
        ParlayType            SMALLINT DEFAULT(0),-- sub bettype of parlay  
        IsMixParlay           BIT DEFAULT(0),
        sporttype             SMALLINT,
        modds                 SMALLMONEY,
        ExtraInfo             VARCHAR(1000),
        IsCashOut			  BIT DEFAULT(0), 
        matchid               INT,
        WalletType            TINYINT,
        RefCode               BIGINT,
        BonusID               INT,
        MainTransId           BIGINT,
        WinLost               MONEY,
        IsMarked              BIT DEFAULT(0),
		LiveIndicator		  BIT,
		mainstatusid		  TINYINT, -- store statusid of normal ticket
		ActualStake			  MONEY,
		oddsid                INT,
		homeid                INT,
        awayid                INT,
		leagueid              INT,
		isNeutral             BIT,
		matchcode             NVARCHAR(50),
		showtime              NVARCHAR(50),
		SettlementStatus	  TINYINT,
		winlostdate			  DATETIME,
		statusID			  TINYINT,
		eventstatus			  NVARCHAR(50),
		SiteDBGroupID		  SMALLINT,
		IsCancelCashOut		  BIT DEFAULT(0), --Apply for issuetype: DA,RC,WC
		CheckTimeCashOut	  DATETIME,
		statuswinlost		  TINYINT,
		GroupPHaffected		  TINYINT, --  0: both 1X2 and AIO are NOT affected, 1:  only 1X2 is affected , 2: only AIO is affected
		VendorMatchId		  VARCHAR(50),
		GroupBettypeId		  SMALLINT
    )

	CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT, betid BIGINT)	
	
	--1: single(exclude cancel CO), 2: parlay, 3: cancel CO
	CREATE TABLE #TmpTransid
	(
		TransId		BIGINT PRIMARY KEY
	   ,TicketType  TINYINT
	)

	INSERT INTO #TmpTransid (TransId,TicketType)
	SELECT DISTINCT s.TransId, 1   --Single ticket (exclude cancel CO)
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single AS s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId 
		AND ISNULL(IsCancelCO,0) = 0 
		AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
		AND s.SiteDBGroupID = @SiteDBGroupID

	UNION ALL 
	SELECT DISTINCT s.TransId, 2 --Parlay ticket
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay AS s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId
		AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
		AND s.SiteDBGroupID = @SiteDBGroupID

	UNION ALL 
	SELECT DISTINCT s.TransId, 3 --Cancel CO ticket
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single AS s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId AND IsCancelCO = 1
		AND (s.RequestDetailId = @RequestDetailId OR ISNULL(@RequestDetailId,0) = 0)
		AND s.SiteDBGroupID = @SiteDBGroupID

	IF EXISTS (SELECT TOP 1 1 FROM #TmpTransid WHERE TicketType = 3)
	BEGIN
		--Fix case Cancel Cashout -> Cashout again. Expect: NO show betlist
		DELETE t
		FROM  #TmpTransid AS t
			INNER JOIN dbo.zzzbettrans z WITH (NOLOCK) ON t.transid = z.transid AND z.comstatus ='CO'
		WHERE TicketType = 3 AND z.SiteDBGroupID = @SiteDBGroupID
	END

	IF @IssueTypeId IN (11,20,13) --11: AbnormalBet, 20: Duplicate Tickets, 13: Abnormal account
	BEGIN
		INSERT INTO #TVSTicketBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid	
				,ExtraInfo
				,IsCashOut
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
				,ActualStake
				,matchid
				,winlostdate
				,SiteDBGroupID
				,statuswinlost
				,modds
				,oddsid
				,IsMixParlay
				,statusID
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.creator
				,b.stake
				,b.CurrencyName
				,b.Status
				,b.status AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.Transdesc
				,b.betdaqid
				,b.ExtraInfo
				,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
				,b.actual_stake AS ActualStake
				,b.matchid
				,b.winlostdate
				,b.SiteDBGroupID
				,b.statuswinlost
				,b.modds
				,b.oddsid
				,CASE WHEN b.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END AS IsMixParlay
				,b.statusID
		FROM #TmpTransid AS d
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON d.TransId = b.TransId
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE  b.statusID NOT IN (101, 102, 103) -- reject, void, refund
			   AND b.SiteDBGroupID = @SiteDBGroupID
			   AND d.TicketType <> 2
			   AND b.matchid = @MatchId
	
		IF @IssueTypeId = 13
		BEGIN
			DECLARE @StatusIds	 VARCHAR(50) =''

			SELECT @StatusIds = TicketStatusIds
			FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail WITH (NOLOCK)
			WHERE RequestId = @RequestId

			DELETE b
			FROM #TVSTicketBets AS b
			WHERE b.statusID NOT IN (SELECT DISTINCT value FROM STRING_SPLIT(@StatusIds, ','))
		END
		
	END
	ELSE IF @IssueTypeId IN (1, 10, 3, 4, 5, 6, 7, 2, 19, 21, 23, 12, 24, 25, 18) -- Danger Accept, Red Card, WrongScore, WrongHDP, Wrong OU, WrongOdds, ReducedOver, Not Participate, Abandoned
	BEGIN
		INSERT INTO #TVSTicketBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid	
				,ExtraInfo
				,IsCashOut
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
				,ActualStake
				,matchid
				,SiteDBGroupID
				,statuswinlost
				,modds
				,IsCancelCashOut
				,CheckTimeCashOut
				,GroupPHaffected
				,GroupBettypeId
			)
		SELECT DISTINCT
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.creator
				,b.stake
				,b.CurrencyName
				,b.STATUS
				,b.status AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.Transdesc
				,b.betdaqid
				,b.ExtraInfo
				,CASE WHEN b.betdaqid = -2 AND ISNULL(CASE WHEN d.TicketType = 3 AND b.betdaqid = -2 THEN 1 ELSE 0 END,0) = 0 THEN 1 ELSE 0 END AS IsCashOut
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
				,b.actual_stake AS ActualStake
				,b.matchid
				,b.SiteDBGroupID
				,b.statuswinlost
				,b.modds
				,CASE WHEN d.TicketType = 3 AND b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCancelCashOut
				,CASE WHEN d.TicketType = 3 AND b.betdaqid = -2 THEN c.CheckTime ELSE NULL END AS CheckTimeCashOut
				,CASE WHEN f.GroupMatch IS NULL THEN 0 
						WHEN f.GroupMatch IS NOT NULL THEN 
														CASE WHEN f.GroupMatch = 0 AND f.BetType IN (5,15) THEN 1
																WHEN f.GroupMatch <> 0 THEN 2
																ELSE 2 END
						ELSE 0 END AS GroupPHaffected
				,CASE WHEN @IssueTypeId IN (25) AND g.GroupBettypeId IS NOT NULL THEN g.GroupBettypeId
					  WHEN @IssueTypeId IN (25) AND g.GroupBettypeId IS NULL THEN b.bettype 
					  ELSE NULL END AS GroupBettypeId
		FROM	#TmpTransid AS d
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON d.TransId = b.transid
			LEFT JOIN dbo.CashOutSelling AS c WITH (NOLOCK) ON b.TransId = c.TransID
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
			LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON b.bettype = f.BetType AND f.IssueTypeId = @IssueTypeId
			LEFT JOIN f_TVS_GroupBettypeIdDisplayActualMarket() g ON g.typeid = b.bettype
		WHERE b.matchid = @MatchId 
			AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND d.TicketType <> 2
			AND 1 = CASE WHEN TicketType = 3 AND b.betdaqid = - 1 THEN 0 ELSE 1 END--case cancel CO voided -> running - NO show betlist
					
		---get sub ticket of a mix parlay	
		IF EXISTS (SELECT TOP 1 1 FROM #TmpTransid AS d
								  INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.TransId = bm.TransId
								  WHERE bm.matchid = @MatchId AND d.TicketType = 2 AND bm.statusID NOT IN (101, 102, 103))
		BEGIN		
			INSERT INTO #TVSTicketBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid					
					,odds			
					,SubOdds	
					,oddsspread
					,OddsType		
					,transdate		
					,bettype		
					,betteam		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,Subhdp1
					,Subhdp2
					,hdp1 			
					,hdp2 			
					,livehomescore	
					,liveawayscore	
					,creator		
					,Stake			
					,currencyname						
					,STATUS			
					,SubStatus	
					,srecommend		
					,mrecommend		
					,recommend						
					,Transdesc		
					,ParlayType		
					,IsMixParlay
					,modds
					,WinLost
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ExtraInfo
					,ActualStake
					,matchid
					,SiteDBGroupID
					,IsCancelCashOut
					,statuswinlost
					,GroupPHaffected
					,GroupBettypeId
				)
			SELECT DISTINCT
					b.transid AS GroupID
					,b.transid AS TransId
					,bm.transid AS SubTransID
					,bm.refno
					,b.custid				
					,b.odds
					,bm.odds AS SubOdds
					,bm.oddsspread AS Suboddsspread
					,b.OddsType
					,bm.transdate AS Subtransdate
					,b.bettype
					,b.betteam
					,bm.betteam AS Subbetteam
					,b.betcheck				
					,bm.betcheck AS Subbetcheck
					,bm.hdp1 AS Subhdp1
					,bm.hdp2 AS Subhdp2
					,b.hdp1
					,b.hdp2
					,bm.livehomescore AS Sublivehomescore
					,bm.liveawayscore AS Subliveawayscore
					,b.creator
					,b.stake
					,b.currencyname				
					,b.status
					,bm.status AS SubStatus
					,b.srecommend
					,b.mrecommend
					,b.recommend
					,bm.transdesc AS SubTransdesc
					,bm.bettype AS Subbettype
					,1 AS IsMixParlay
					,b.modds
					,b.winlost - b.actual_stake AS WinLost
					,0
					,bm.liveindicator AS Subliveindicator
					,b.statusID AS mainstatusid
					,b.ExtraInfo
					,b.actual_stake AS ActualStake
					,bm.matchid
					,bm.SiteDBGroupID
					,0 AS IsCancelCashOut
					,b.statuswinlost
					,CASE WHEN f.GroupMatch IS NULL THEN 0 
						  WHEN f.GroupMatch IS NOT NULL THEN 
															CASE WHEN f.GroupMatch = 0 AND f.BetType IN (5,15) THEN 1
																	WHEN f.GroupMatch <> 0 THEN 2
																	ELSE 2 END
						    ELSE 0 END AS GroupPHaffected
					,CASE WHEN @IssueTypeId IN (25) AND g.GroupBettypeId IS NOT NULL THEN g.GroupBettypeId
						  WHEN @IssueTypeId IN (25) AND g.GroupBettypeId IS NULL THEN bm.bettype
					      ELSE NULL END AS GroupBettypeId
			FROM	#TmpTransid AS d
					INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.TransId = bm.TransId
					INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
					LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON bm.bettype = f.BetType AND f.IssueTypeId = @IssueTypeId
					LEFT JOIN f_TVS_GroupBettypeIdDisplayActualMarket() g ON g.typeid = bm.bettype
			WHERE	bm.matchid = @MatchId
					AND bm.statusID NOT IN (101, 102, 103) -- reject, void, refund
					AND bm.betfrom <> 'P'
					AND bm.SiteDBGroupID = @SiteDBGroupID
					AND d.TicketType = 2
					AND b.matchid = 29
					AND b.bettype = 29
		END 
		
	END
	ELSE IF @IssueTypeId in (8,9,26) AND @RequestId <> 0 --EKO, WKO, WOName
	BEGIN
		INSERT INTO #TVSTicketBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid	
				,ExtraInfo
				,IsCashOut
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
			    ,ActualStake
				,matchid
				,SiteDBGroupID
				,statuswinlost
				,modds
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.creator
				,b.stake
				,b.CurrencyName
				,b.STATUS
				,b.status AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.Transdesc
				,b.betdaqid
				,b.ExtraInfo
				,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
			    ,b.actual_stake AS ActualStake
				,b.matchid
				,b.SiteDBGroupID
				,b.statuswinlost
				,b.modds
		FROM #TmpTransid AS d
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON d.TransId = b.TransId
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE b.statusID NOT IN (101, 102, 103) 
			  AND b.SiteDBGroupID = @SiteDBGroupID
			  AND d.TicketType <> 2
			  AND b.matchid = @MatchId
			
		
		---get sub ticket of a mix parlay	
		IF EXISTS (SELECT TOP 1 1 FROM #TmpTransid AS d
								  INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.TransId = bm.TransId
								  WHERE bm.matchid = @MatchId AND d.TicketType = 2 AND bm.statusID NOT IN (101, 102, 103))
		BEGIN		
			INSERT INTO #TVSTicketBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid					
					,odds			
					,SubOdds	
					,oddsspread
					,OddsType		
					,transdate		
					,bettype		
					,betteam		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,Subhdp1
					,Subhdp2
					,hdp1 			
					,hdp2 			
					,livehomescore	
					,liveawayscore	
					,creator		
					,Stake			
					,currencyname						
					,STATUS			
					,SubStatus	
					,srecommend		
					,mrecommend		
					,recommend						
					,Transdesc		
					,ParlayType		
					,IsMixParlay
					,modds
					,WinLost
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ExtraInfo
					,ActualStake
					,matchid
					,SiteDBGroupID
					,statuswinlost
				)
			SELECT 
					b.transid AS GroupID
					,b.transid 
					,bm.transid AS SubTransID
					,bm.refno
					,bm.custid AS Subcustid				
					,b.odds
					,bm.odds AS SubOdds
					,bm.oddsspread AS Suboddsspread
					,b.OddsType
					,bm.transdate AS Subtransdate
					,b.bettype
					,b.betteam
					,bm.betteam AS Subbetteam
					,b.betcheck				
					,bm.betcheck AS Subbetcheck
					,bm.hdp1 AS Subhdp1
					,bm.hdp2 AS Subhdp2
					,bm.hdp1
					,bm.hdp2
					,bm.livehomescore AS Sublivehomescore
					,bm.liveawayscore AS Subliveawayscore
					,b.creator
					,b.stake
					,b.currencyname				
					,b.Status
					,bm.status AS SubStatus
					,b.srecommend
					,b.mrecommend
					,b.recommend
					,bm.Transdesc AS SubTransdesc
					,bm.bettype AS Subbettype
					,1 AS IsMixParlay
					,b.modds
					,b.winlost - b.actual_stake AS WinLost
					,0
					,bm.liveindicator AS Subliveindicator
					,b.statusID AS mainstatusid
					,b.ExtraInfo
					,b.actual_stake AS ActualStake
					,bm.matchid
					,bm.SiteDBGroupID
					,b.statuswinlost
			FROM	#TmpTransid AS d
					INNER JOIN bettransm AS bm WITH (NOLOCK) ON d.TransId = bm.TransId
					INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON bm.refno = b.refno
			WHERE	bm.statusID NOT IN (101, 102, 103)
					AND bm.betfrom <> 'P'
					AND bm.SiteDBGroupID = @SiteDBGroupID
					AND d.TicketType = 2
					AND b.matchid = 29
					AND b.bettype = 29
					AND bm.matchid  = @MatchId
		END 
	END

	--Re-scan data for case miss by page split
	INSERT INTO @tmp_MissingTransId (TransId)
	SELECT d.TransId
	FROM #TmpTransid AS d
	INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.TransId = bm.TransId
	WHERE bm.statusID NOT IN (101, 102, 103)
		AND d.TicketType = 2
		AND NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets t WHERE t.Subtransid = d.transid)
		AND bm.SiteDBGroupID = @SiteDBGroupID

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #TVSTicketBets(
			GroupID			
			,transid		
			,SubTransid		
			,refno			
			,custid					
			,odds			
			,SubOdds	
			,oddsspread
			,OddsType		
			,transdate		
			,bettype		
			,betteam		
			,SubBetTeam
			,betcheck	
			,SubBetcheck	
			,Subhdp1
			,Subhdp2
			,hdp1 			
			,hdp2 			
			,livehomescore	
			,liveawayscore	
			,creator		
			,Stake			
			,currencyname						
			,STATUS			
			,SubStatus	
			,srecommend		
			,mrecommend		
			,recommend						
			,Transdesc		
			,ParlayType		
			,IsMixParlay
			,modds
			,WinLost
			,IsMarked
			,LiveIndicator
			,mainstatusid
			,ExtraInfo
			,ActualStake
			,matchid
			,SiteDBGroupID
			,IsCancelCashOut
			,statuswinlost
			,GroupPHaffected
			,GroupBettypeId
		)
		SELECT DISTINCT
				b.transid AS GroupID
				,b.transid AS TransId
				,bm.transid AS SubTransID
				,bm.refno
				,b.custid				
				,b.odds
				,bm.odds AS SubOdds
				,bm.oddsspread AS Suboddsspread
				,b.OddsType
				,bm.transdate AS Subtransdate
				,b.bettype
				,b.betteam
				,bm.betteam AS Subbetteam
				,b.betcheck				
				,bm.betcheck AS Subbetcheck
				,bm.hdp1 AS Subhdp1
				,bm.hdp2 AS Subhdp2
				,b.hdp1
				,b.hdp2
				,bm.livehomescore AS Sublivehomescore
				,bm.liveawayscore AS Subliveawayscore
				,b.creator
				,b.stake
				,b.currencyname				
				,b.status
				,bm.status AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,bm.transdesc AS SubTransdesc
				,bm.bettype AS Subbettype
				,1 AS IsMixParlay
				,b.modds
				,b.winlost - b.actual_stake AS WinLost
				,0
				,bm.liveindicator AS Subliveindicator
				,b.statusID AS mainstatusid
				,b.ExtraInfo
				,b.actual_stake AS ActualStake
				,bm.matchid
				,bm.SiteDBGroupID
				,0 AS IsCancelCashOut
				,b.statuswinlost
				,CASE WHEN f.GroupMatch IS NULL THEN 0 
						WHEN f.GroupMatch IS NOT NULL THEN 
														CASE WHEN f.GroupMatch = 0 AND f.BetType IN (5,15) THEN 1
																WHEN f.GroupMatch <> 0 THEN 2
																ELSE 2 END
						ELSE 0 END AS GroupPHaffected
				,CASE WHEN @IssueTypeId IN (25) AND g.GroupBettypeId IS NOT NULL THEN g.GroupBettypeId
						WHEN @IssueTypeId IN (25) AND g.GroupBettypeId IS NULL THEN bm.bettype
						ELSE NULL END AS GroupBettypeId
		FROM	@tmp_MissingTransId AS d
				INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON d.TransId = bm.TransId
				INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
				LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON bm.bettype = f.BetType AND f.IssueTypeId = @IssueTypeId
				LEFT JOIN f_TVS_GroupBettypeIdDisplayActualMarket() g ON g.typeid = bm.bettype
		WHERE	bm.matchid = @MatchId
				AND bm.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND bm.betfrom <> 'P'
				AND bm.SiteDBGroupID = @SiteDBGroupID
				AND b.matchid = 29
				AND b.bettype = 29
				
		--Write log
		DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			   ,@SubmittedDate DATETIME = GETDATE()
			   ,@spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
			   ,@TransIds VARCHAR(MAX) = NULL

		SELECT @TransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
									FROM @tmp_MissingTransId
									FOR XML PATH('')), 1,1,'')
									,'')

		SET @ID =  NEWID()
		BEGIN TRY
			IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
			BEGIN	
				SET @sqlCommand = 'Missing TransIds: ' + @TransIds

				INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
				VALUES (@ID, @spName, @sqlCommand, 0, NULL, GETDATE(),@SubmittedDate)
			END	
		END TRY
		BEGIN CATCH
		END CATCH 
	END

	--Update Main MatchID for child match cricket (Sporttype = 50)
	UPDATE d
	SET d.matchid = m.ParentID
	FROM #TVSTicketBets d
		INNER JOIN dbo.match m WITH(NOLOCK) ON d.matchid = m.matchid AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
	
	--Remove Invalid data
	DELETE t
	FROM #TVSTicketBets t
	WHERE @MatchId IS NOT NULL AND t.matchid <> @MatchId

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,eventstatus = ISNULL(m.eventstatus,'')
			,SubLeagueId = m.leagueid
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		FROM #TVSTicketBets d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
	
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
	BEGIN
		UPDATE d
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventstatus = ISNULL(odds.oddsstatus,'')
			,SubLeagueId = odds.leagueid
			,SettlementStatus = 0
		FROM #TVSTicketBets d
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)))
	BEGIN
		UPDATE d
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
				,eventstatus = ISNULL(o.eventstatus,'')
				,SubLeagueId = r.leagueid
				,SettlementStatus = 0
				,VendorMatchId = CASE WHEN d.bettype IN (2770,2771,15500,15501) THEN r.VendorMatchId ELSE NULL END
		FROM #TVSTicketBets d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)
	END

	-- UPDATE VS5, VS6
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype BETWEEN 11050 AND 11099 OR bettype BETWEEN 13000 AND 13011))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
		FROM #TVSTicketBets d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END

	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE d
		SET sporttype = sb.SportType
		FROM #TVSTicketBets d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- UPDATE IsMixParlay = 1 [MixParlay bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE d
		SET IsMixParlay = 1
		FROM #TVSTicketBets d
		WHERE d.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END

	--- Remove invalid sporttype
	DELETE 
	FROM #TVSTicketBets
	WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
		AND ( sporttype IS NULL OR bettype = 500) /*charge comm*/
			
	-- update username/creatorname column
	UPDATE al
		SET username = ci.username
			,creatorName = cr.username
	FROM	#TVSTicketBets al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK)
			ON al.creator = cr.custid
			
	-- update Isdeposit
	UPDATE al 
		SET IsDeposit = 1
	FROM	#TVSTicketBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
	
	BEGIN -- Instant Settlement declaration
			
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT)
		CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

		INSERT INTO #CTE_match (matchid, sporttype)
		SELECT DISTINCT t.matchid, m.sporttype
		FROM #TVSTicketBets t
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

	-- TICKET SECTION
	;WITH CTE_OriginResult AS (
		--1. For Credit	 
		SELECT 
			   s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.creatorName AS creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
			   ,s.IsMixParlay
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
			   ,s.GroupId
			   ,CASE WHEN s.betdaqid = -2 AND s.IsCancelCashOut <> 1 THEN 'Credit (CO)'
					 WHEN s.betdaqid = -2 AND s.IsCancelCashOut = 1 THEN 'Credit (Cancel CO)' 
					 ELSE 'Credit' 
					END AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsDeposit
			   ,s.eventstatus
			   ,s.SettlementStatus
			   ,s.SiteDBGroupID
			   ,s.IsCancelCashOut
			   ,s.statuswinlost
			   ,s.CheckTimeCashOut
			   ,s.GroupPHaffected
			   ,s.VendorMatchId
			   ,s.GroupBettypeId
		FROM	#TVSTicketBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #TVSTicketBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
			LEFT JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = s.recommend		
		WHERE	f.CustID IS NULL
				AND (s.username <> '12EU' AND ISNULL(sub.username,'') <> '12EU')
				AND s.IsDeposit = 0
				AND s.mrecommend NOT IN (105181, 118473, 105183) -- MHC
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND (s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 
					AND ISNULL(sub.custid,0) NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
				)  -- Betfair: BFOS, BF, ITibc102, BF3				
		UNION
		--2. For 8RM
		SELECT  
				s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.creatorName AS creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
			   ,s.IsMixParlay
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername			   
			   ,s.Transdesc
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
			   ,s.GroupId
			   ,'8RM/BARM' AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsDeposit
			   ,s.eventstatus
			   ,s.SettlementStatus
			   ,s.SiteDBGroupID
			   ,s.IsCancelCashOut
			   ,s.statuswinlost
			   ,s.CheckTimeCashOut
			   ,s.GroupPHaffected
			   ,s.VendorMatchId
			   ,s.GroupBettypeId
		FROM	#TVSTicketBets s 
		WHERE	s.recommend IN (52466, 5707545)
		UNION
		--3. For Deposit
		SELECT  
				s.transid
			   ,s.SubTransid
			   ,s.refno		
			   ,s.custid		
			   ,s.username	
			   ,s.transdate
			   ,s.creatorName AS creator
			   ,s.Stake
			   ,s.odds
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
			   ,s.IsMixParlay
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
			   ,s.GroupId
			   ,CASE WHEN s.betdaqid = -2 AND s.IsCancelCashOut <> 1 THEN 'Deposit (CO)' 
					 WHEN s.betdaqid = -2 AND s.IsCancelCashOut = 1 THEN 'Deposit (Cancel CO)' 
					 ELSE 'Deposit' END AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsDeposit
			   ,s.eventstatus
			   ,s.SettlementStatus
			   ,s.SiteDBGroupID
			   ,s.IsCancelCashOut
			   ,s.statuswinlost
			   ,s.CheckTimeCashOut
			   ,s.GroupPHaffected
			   ,s.VendorMatchId
			   ,s.GroupBettypeId
		FROM	#TVSTicketBets s 
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #TVSTicketBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
		WHERE	f.CustID IS NULL -- Betdaq
				AND (s.username <> '12EU' AND ISNULL(sub.username,'') <> '12EU')
				AND s.IsDeposit = 1
				AND s.mrecommend NOT IN (105181, 118473, 105183)
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND (s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 
				AND ISNULL(sub.custid,0) NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)) -- Betfair: BFOS, BF, ITibc102, BF3	
		UNION
		--4. For Betfair
		SELECT  
			s.transid
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.creatorName AS creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.SubLeagueId
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
		   ,s.IsMixParlay
		   ,s.ParlayType
		   ,NULL AS followedId
		   ,NULL AS followedUsername
		   ,s.Transdesc
		   ,s.sporttype
		   ,s.modds
		   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.IsCashOut
		   ,s.GroupId
		   ,'Betfair' AS OriginGroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.BonusID
		   ,s.RefCode
		   ,s.WinLost
		   ,s.IsMarked
		   ,s.recommend
		   ,s.LiveIndicator
		   ,s.mainstatusid
		   ,s.ActualStake
		   ,s.matchid
		   ,s.homeid    
		   ,s.awayid    
		   ,s.leagueid  
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.statusID
		   ,s.IsDeposit
		   ,s.eventstatus
		   ,s.SettlementStatus
		   ,s.SiteDBGroupID
		   ,s.IsCancelCashOut 
		   ,s.statuswinlost
		   ,s.CheckTimeCashOut
		   ,s.GroupPHaffected 
		   ,s.VendorMatchId
		   ,s.GroupBettypeId
		FROM	#TVSTicketBets s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
	)
	, CTE_InstantSettlementSubgrouping AS (
		/*
			Cases for dividing for instant settlement subgroup :
				1. Before match is kicked off : No ticketes in group 'Instant Settlement'.
				2. Before HT calculated : Ticketes that are settled ('WON', 'LOSE', 'DRAW')
										  and their bettype in list of HT instant settlement bettypes are in group 'Instant Settlement'
				3. After HT calculated : Ticketes that are settled  ('WON', 'LOSE', 'DRAW')
										 and bettype in list of FT instant settlement bettypes are in group 'Instant Settlement'
				4. After match is completed : No ticketes in group 'Instant Settlement'.
		*/
		SELECT  s.*
			   ,CASE WHEN s.eventstatus <> @eventstatus_completed AND s.mainstatusid IN (111, 112, 113) AND ISNULL(s.betdaqid,0) <> -2
						THEN CASE WHEN s.SportType = 1 AND
													EXISTS (SELECT TOP 1 1
															FROM #InstantSettlementBettypes
															WHERE bettype = s.bettype) THEN s.OriginGroupName + ' (Instant Settlement)'
								  WHEN s.SportType = 2 AND 
													EXISTS (SELECT TOP 1 1
															FROM #InstantSettlementBettypes
															WHERE bettype = s.bettype AND (betid = s.betid OR s.betid IS NULL)) THEN s.OriginGroupName + ' (Instant Settlement)'
								 ELSE s.OriginGroupName END
					ELSE s.OriginGroupName -- case 4
				END AS SubGroupName
		FROM CTE_OriginResult s

	)
	SELECT  s.transid 
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.STATUS
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.SubLeagueId
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
		   ,s.IsMixParlay
		   ,s.ParlayType AS SubBettype
		   ,s.followedId
		   ,s.followedUsername
		   ,s.Transdesc
		   ,s.sporttype
		   ,s.modds AS MasterOdds
		   ,s.IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.IsCashOut
		   ,s.SubGroupName AS GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.RefCode
		   ,s.SettlementStatus 
		   ,s.WinLost
		   ,s.IsMarked
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.ActualStake
		   ,s.matchid
		   ,s.homeid    
		   ,s.awayid    
		   ,s.leagueid  
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.statusID
		   ,s.IsDeposit
		   ,ISNULL(si.IsChinaView,0) AS IsChinaView
		   ,CASE WHEN s.SubGroupName LIKE '%(Instant Settlement)' THEN 1 ELSE 0 END AS IsInstantSettlement
		   ,s.SiteDBGroupID
		   ,ISNULL(s.IsCancelCashOut,0) AS IsCancelCashOut
		   ,s.statuswinlost
		   ,s.CheckTimeCashOut AS CheckTimeCancelCashOut
		   ,ISNULL(si.SpecialPlatfrom,0) AS SpecialPlatform --2: JollyView
		   ,s.GroupPHaffected -- Affect isuetype : HDP,OU,ODDS
		   ,s.VendorMatchId
	       ,s.GroupBettypeId
	FROM CTE_InstantSettlementSubgrouping s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.custid = c.custid
		LEFT JOIN custDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
	ORDER BY CASE
				WHEN s.OriginGroupName = 'Credit' THEN 1
				WHEN s.OriginGroupName = '8RM/BARM' THEN 2
				WHEN s.OriginGroupName = 'Deposit' THEN 3
				WHEN s.OriginGroupName = 'Betfair' THEN 4
				WHEN s.OriginGroupName = 'Credit (CO)' THEN 5
				WHEN s.OriginGroupName = 'Deposit (CO)' THEN 6
				WHEN s.OriginGroupName = 'Credit (Cancel CO)' THEN 7
				WHEN s.OriginGroupName = 'Deposit (Cancel CO)' THEN 8
			 END
			, CASE WHEN s.SubGroupName NOT LIKE '%(Instant Settlement)' THEN 1
				ELSE 2
			 END
		   , ISNULL(s.MainTransId, s.transid)
		   , CASE 
				WHEN s.BonusID IS NOT NULL
						THEN CASE 
								WHEN s.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE s.transid
			 END			
	
	DROP TABLE #TVSTicketBets
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #TmpTransid
END

GO

