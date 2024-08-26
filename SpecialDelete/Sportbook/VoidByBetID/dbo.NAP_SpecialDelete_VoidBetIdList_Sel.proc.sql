/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetIdList_Sel] 
(
	@CustID            VARCHAR(MAX) = NULL,
    @TransIds          VARCHAR(MAX) = NULL,
    @FromDate          DATETIME     = NULL,
    @ToDate            DATETIME     = NULL,
    @IncludeMainParlay BIT          = 0,
	@Products		   VARCHAR(50)  = NULL,
	@StatusIds		   VARCHAR(50)  = NULL,
	@AbnormalBetType   TINYINT		= NULL --NULL: Uncheck AbnormalBet UI, 0: single, 1: main parlay

)
AS;
/*  
	Created by: Bobby  
	Date: 20160225
	Task: Get tickets by Bet ID/CustID : 
		  Normal SB, Outright, Mix Parlay (Allow to delete Running & Refunded), NG, and Live Casino 
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02 
	Original:NAP_BettransSpecialDelBetID_Sel     

	Revisions:  
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150611@Dominic: BetTrade Integration [Redmine:#36964]
		- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]
		- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
		- 20151102@Kathy: Enhance performance [Redmine:#43233]
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160113@Patrick: Support Cricket [Redmine: #50688]
		- 20160301@Bobby: #53123 - Enhance SP void bet by Id list (allow transId up to 1000 rows)
		- 20160314@Bobby: #53935 - Update changes for multiple bet trade transaction
		- 20160413@Bobby: #55893 - Update change request for grouping tickets
		- 20160714@Kathy: change the order of result: groupname, groupid, transid
		- 20160816@Bobby: #62527 - Update BT's info for showing bet list	
		- 20160914@Kent: Add logic for suporting void system parlay [Redmine:#63202]	
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20161124@Kent: Include phone betting tickets and add new GroupName "Phone Betting" [Redmine:#67751]
		- 20170302@Kent: Fix show time for virtual sport [Redmine:#72475]
		- 20170314@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]	
		- 20170725@Paul: Return CurrencyName [Redmine:#77175]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]	
		- 20170503@Kent: Integrate bonus [Redmine:#72790]	
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread - Fast Markets Phase 2 [Redmine:#90667]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20171029@Alan: Return Licensees Name [103474]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20190220@Alan: Separate a function from Void By Bet ID to void main parlay ticket [108969]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190227@Alan: Implement Bet Builder - [106898]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20191106@Charles: Implement NPM Promotion [122187]
		- 20200618@Max: Hotfix Change Primary key on MarkedTransaction [Redmine: #136064]
		- 20200810@Charles: Offer Saba Loyalty for Saba Promotion [139255]
		- 20201005@Max: TVS - Enhance void by Bet ID to support void by customer [Redmine: #142010]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210201@Max: Hotfix - TVS - Abnormal Accounts [Redmine: #149697]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210622@Helen: [TVS] SP Tuning [Redmine: #157354]
		- 20210526@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220214@July: Intergrate new Saba Basketball PinGoal [Redmine: #168079]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220818@July: Change of Void By Bet ID regarding to Scale out DBTrans [Redmine: #176811]
		- 20221212@July: [TVS] Changes of TVS to integrate E-Sports Pingoal [Redmine: #181087]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230717@July: [SD] Integrate Virtual Sports 3 (Leap Gaming) [Redmine: #189556]
		- 20231031@July: [SD] Void By BetID - Void abnormal tickets of many matches at once [Redmine: #196028]
		- 20240223@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20240229@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240826@July: [TVS] Void By Bet ID - Support void abnormal bet for main parlay ticket [Redmine: #209348]

	Param's Explanation:
		+ @CustID NOT NULL: Search by CustID
		+ @TransIds NOT NULL: Search by TransID
		+ @Products : 1 - Sportbook
					2 - Parlay
					3 - Bet Builder
					4 - Outright
					5 - Saba
					6 - NonSport

	*/
BEGIN
	SET NOCOUNT ON
	
	IF(@CustID IS NULL AND @TransIds IS NULL) RETURN
	
	DECLARE @movebetdate	DATETIME,
			@maxdate 		DATETIME = '9999-01-01',
			@IsSB			BIT = 0,
			@IsParlay		BIT = 0,
			@IsBB			BIT = 0,
			@IsOutright		BIT = 0,
			@IsSaba			BIT = 0,
			@IsNonSport		BIT = 0,
			@SiteDBGroupID	SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE  @InvalidTransIds   VARCHAR(MAX) = ''
			,@MovedTransIds     VARCHAR(MAX) = '' 

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)	
	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)

	--Get Movebetdate
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @movebetdate OUTPUT
	
	SELECT @FromDate	= ISNULL(@FromDate, @movebetdate)
		, @FromDate 	= CASE WHEN @FromDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromDate END

	IF @ToDate IS NULL
	BEGIN
		SET @ToDate = @maxdate
	END
	
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)	
	CREATE TABLE #CustId (CustId INT)

	CREATE TABLE #SpecialDeleteBets
             (GroupID               BIGINT,
              bettype               INT,
              transid               BIGINT,
              betid                 BIGINT,
              refno                 BIGINT,
              matchcode             NVARCHAR(50),
              homeid                INT,
              awayid                INT,
              hdp1                  SMALLMONEY,
              hdp2                  SMALLMONEY,
              odds                  SMALLMONEY,
              oddsspread            MONEY DEFAULT 0,
              finalodds             MONEY,
              finalodds2            MONEY,
              OddsType              TINYINT,
              STATUS                NVARCHAR(50),
              comstatus             NVARCHAR(50),
              stake                 MONEY,
              transdate             DATETIME,
              betteam               NVARCHAR(10),
              betcheck              NVARCHAR(50),
              liveindicator         BIT,
              modds                 SMALLMONEY,
              custid                INT,
              username              VARCHAR(30),
              livehomescore         SMALLINT,
              liveawayscore         SMALLINT,
              leagueid              INT,
              sporttype             SMALLINT,
              betfrom               NVARCHAR(4),
              matchid               INT,
              isNeutral             BIT,
              winlost               MONEY,
              commission            MONEY,
              showtime              NVARCHAR(50),
              winlostdate           SMALLDATETIME,
              TransDesc             NVARCHAR(1000),
              betdaqid              BIGINT,
              recommend             INT,
              IsHideComm            BIT DEFAULT(0),
              oddsid                INT,
              ExtraInfo             VARCHAR(1000),
              IsCashOut				BIT DEFAULT(0),
              CurrencyName          NVARCHAR(50),
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
			  IsMarked			 	BIT,
			  ActualStake			MONEY,
			  eventdate				DATETIME,
			  EndTime				DATETIME, --support Bitcoin
             );
   
	IF @CustID IS NULL
	BEGIN
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE 1 = CASE WHEN @AbnormalBetType IS NULL THEN 1
					   WHEN @AbnormalBetType = 0 AND pt.ProductID = 1 
							AND pt.bettype < 19001
							AND pt.bettype NOT IN (9, 29) -- Parlay Tickets
							AND pt.bettype NOT IN (10) -- outright tickets
							AND pt.bettype NOT IN (1231, 1232, 1233, 1237, 1238) -- virtual sport
							AND pt.bettype NOT IN (38) -- Bet Builder
					   THEN 1 --Only Sportsbook
					   WHEN @AbnormalBetType = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
					   ELSE 0 END
			AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss', 'MG-SuperLive') -- Bet trade (BT-), MG
			AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
			AND pt.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno
	END
	ELSE
	BEGIN
		SELECT @IsSB = CASE WHEN CHARINDEX('1',@Products) > 0 THEN 1 ELSE 0 END
				, @IsParlay = CASE WHEN CHARINDEX('2',@Products) > 0 THEN 1 ELSE 0 END
				, @IsBB = CASE WHEN CHARINDEX('3',@Products) > 0 THEN 1 ELSE 0 END
				, @IsOutright = CASE WHEN CHARINDEX('4',@Products) > 0 THEN 1 ELSE 0 END
				, @IsSaba = CASE WHEN CHARINDEX('5',@Products) > 0 THEN 1 ELSE 0 END
				, @IsNonSport = CASE WHEN CHARINDEX('6',@Products) > 0 THEN 1 ELSE 0 END
	
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE 1 = CASE
						WHEN (@IsSB = 1 OR @IsSaba = 1) 
							AND pt.ProductID = 1 
							AND pt.BetType NOT IN (9,29,10)
							AND pt.SubProduct NOT IN ('Bet Builder') THEN 1 -- Sportsbook
						WHEN @IsOutright = 1 AND pt.bettype IN (10) THEN 1 --Outright
						WHEN @IsParlay = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
						WHEN @IsBB = 1 AND pt.SubProduct IN ('Bet Builder') THEN 1 --Bet Builder
						WHEN @IsNonSport = 1 AND ProductID IN (3,5,27,77) THEN 1
					ELSE 0 END
			AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss', 'MG-SuperLive') -- Bet trade (BT-), MG
			AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
			AND pt.bettype NOT BETWEEN 1501 AND 1599	-- NOT IN Keno
	END

	IF(LEN(@TransIds) > 0)
	BEGIN
		INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''
	END
	
	IF(@CustID <> '')
	BEGIN
		INSERT INTO #CustId (CustId)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@CustID, ',')
		WHERE value <> ''

		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@StatusIds, ',')
		
		INSERT INTO #transIdTemp (transid)
		SELECT b.transid 
		FROM dbo.bettrans AS b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
			)ml
			INNER JOIN #CustId c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND  ml.LeagueGroupID IS NULL THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)
			AND b.SiteDBGroupID = @SiteDBGroupID
	END
	
	--Search by TransIds
	IF (EXISTS(SELECT TOP 1 1 FROM #transIdTemp))
	BEGIN
		-- bettrans tickets	
		INSERT INTO #SpecialDeleteBets (
			GroupID			
			,bettype		
			,transid		
			,betid			
			,refno		
			,hdp1			
			,hdp2			
			,odds
			,oddsspread			
			,finalodds		
			,finalodds2		
			,OddsType		
			,STATUS			
			,comstatus		
			,stake							
			,transdate		
			,betteam		
			,betcheck		
			,liveindicator	
			,modds			
			,custid						
			,livehomescore	
			,liveawayscore					
			,betfrom		
			,matchid					
			,winlost		
			,commission					
			,winlostdate	
			,TransDesc		
			,betdaqid
			,username
			,recommend
			,IsHideComm
			,oddsid
			,ExtraInfo
			,IsCashOut
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,IsMarked
			,ActualStake
		)
		SELECT	
			b.transid AS GroupId
			,b.bettype
			,b.transid
			,ISNULL(b.BetID, 0) AS BetID
			,b.refno			
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,0 finalodds
			,0 finalodds2
			,b.OddsType
			,CASE 
				WHEN b.STATUS = 'running'
					AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus
			,b.stake				
			,b.transdate
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.modds
			,b.custid
			,b.livehomescore
			,b.liveawayscore				
			,b.betfrom
			,b.matchid				
			,(b.winlost - b.actual_stake) winlost
			,b.playercomm AS commission				
			,b.winlostdate
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.recommend			
			,CASE WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 ELSE 0 END AS IsHideComm
			,b.oddsid
			,b.ExtraInfo
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.actual_stake AS ActualStake
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #transIdTemp temp
				ON b.transid = temp.transid
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.transid = TransId
					)m
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype				
		WHERE	b.winlostdate >= @FromDate				
			AND b.statusID NOT IN (101, 102, 103)	
			AND b.SiteDBGroupID = @SiteDBGroupID
	END			

	-- delete main parlay tickets
	IF(@IncludeMainParlay = 0 AND @Products IS NULL AND @AbnormalBetType IS NULL)
	BEGIN
			DELETE b FROM #SpecialDeleteBets b 
			WHERE  b.bettype IN (9, 29, 2799, 10449, 38)
	END
	
	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype NOT IN (9, 29, 2799, 10449)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,eventdate  = m.eventdate
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799, 10449)
	END
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (10)))
	BEGIN
		UPDATE d
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventdate  = odds.eventdate
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE d
		SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
			,homeid 	= o.RacerID
			,awayid 	= 0
			,leagueid 	= r.leagueid
			,sporttype 	= r.sporttype
			,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
			,eventdate  = o.eventdate
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE d
		SET sporttype = sb.SportType
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END
	-- UPDATE Sportype, Endtime for Bitcoin 
	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype BETWEEN 7901 AND 7999))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
			,eventdate  = m.EventDate
			,EndTime    = m.EndTime
		FROM #SpecialDeleteBets d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END

	IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (9,29,2799,10449)))
	BEGIN
		UPDATE #SpecialDeleteBets
		SET eventdate = winlostdate
		WHERE bettype IN (9,29,2799,10449)
	END
	--- Remove invalid sporttype
	DELETE 
	FROM #SpecialDeleteBets
	WHERE bettype NOT IN (9, 29, 2799,10449)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		)	

	/*Modify the way to get move bet date*/
	IF @TransIds IS NOT NULL AND EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE eventdate <= @movebetdate)
	BEGIN
		DELETE 
		FROM #SpecialDeleteBets
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE eventdate <= @movebetdate
	END
	
	DECLARE @cnt INT, @MatchId INT
	DECLARE @tmpMatchId TABLE (MatchId INT)

	--Return matchid show infor 1 match (case check abnormal) || remove saba (for case uncheck abnormal) 
	BEGIN
		INSERT INTO  @tmpMatchId (MatchId)
		SELECT DISTINCT 
			   CASE WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN m.ParentID ELSE s.matchid END AS MatchId
		FROM #SpecialDeleteBets s
			INNER JOIN dbo.match m WITH (NOLOCK) ON s.matchid = m.matchid 

		SET @cnt = @@ROWCOUNT
		IF @cnt = 0 
			SET @MatchId = NULL
		ELSE IF @cnt = 1
			SELECT @MatchId = MatchId FROM @tmpMatchId
		ELSE IF @cnt NOT IN (0,1)
			SET @MatchId = 0 --Multiple matches
	END

	------------------------------------------------------------------------------
	--1. Table invalid/moved transid	
	CREATE TABLE #InvalidTransIds (transid BIGINT, IsMoved BIT)
	INSERT INTO #InvalidTransIds(transid, IsMoved)
	SELECT t.transid
		  , CASE WHEN b.transid IS NOT NULL THEN 1
				 WHEN m.TransId IS NOT NULL THEN 1
				 ELSE 0 END AS IsMoved
	FROM #transIdTemp t
		LEFT JOIN dbo.bettrans14 b WITH(NOLOCK) ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
		LEFT JOIN @tmpTransIdMoveBet m ON t.transid = m.TransId
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets r WHERE r.transid = t.transid)

	SELECT @InvalidTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
									 FROM #InvalidTransIds
									 WHERE IsMoved = 0
									 FOR XML PATH('')), 1, 1, '');									

	SELECT @MovedTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
								   FROM #InvalidTransIds
								   WHERE IsMoved = 1
								   FOR XML PATH('')), 1, 1, '');	

	SELECT @InvalidTransIds AS InvalidTransIds
	      ,@MovedTransIds AS MovedTransIds
		  ,@MatchId AS MatchId

	-- UPDATE SiteName
	;WITH CustSiteName AS (
		SELECT DISTINCT ag.custid, ci.site, ci.srecommend, ci.mrecommend
		FROM CUSTDB.dbo.Customer ci WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets ag
			ON ci.custid = ag.recommend
	)
	--format group
	, CTE_GroupInfo AS (
		SELECT DISTINCT d.custid
			,cs.mrecommend
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
			,CASE 
				WHEN (
					d.recommend NOT IN (52466, 5707545)
					AND d.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
					AND s.custid IS NULL					
				) THEN '0-Credit'
				WHEN d.recommend IN (52466, 5707545) THEN '1-8RM/BARM'
				WHEN (
					d.recommend NOT IN (52466, 5707545)
					AND d.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
					AND s.custid IS NOT NULL					
				) THEN '2-Deposit'
				WHEN d.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 					 
				  THEN '3-BetFair'				
			END AS GroupName
		FROM #SpecialDeleteBets d
			INNER JOIN CustSiteName cs 
			ON d.custid = cs.custid
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) 
			ON cs.srecommend = s.custid
	)

	--2. Table get tickets
	SELECT d.transid
		,d.bettype
		,d.betid
		,d.refno
		,d.matchcode
		,d.homeid
		,d.awayid
		,d.hdp1
		,d.hdp2
		,d.odds
		,d.oddsspread
		,d.finalodds
		,d.finalodds2
		,d.OddsType
		,d.STATUS
		,d.comstatus
		,d.stake
		,d.transdate
		,d.betteam
		,d.betcheck
		,d.liveindicator
		,d.modds AS MasterOdds
		,d.custid
		,d.username
		,d.livehomescore
		,d.liveawayscore
		,d.leagueid
		,d.sporttype
		,d.betfrom
		,d.matchid
		,d.isNeutral
		,d.winlost
		,d.commission
		,d.showtime
		,d.winlostdate
		,d.TransDesc
		,d.IsHideComm
		,g.IsDeposit
		,SUBSTRING(T.GroupName, 3, 30) AS GroupName
		,d.betdaqid
		,d.ExtraInfo
		,d.IsCashOut
		,d.CurrencyName
		,d.WalletType	    
	    ,d.MainTransId
	    ,FollowInfo.transid AS followedId
		,FollowInfo.Username AS followedUsername
		,d.RefCode
		,c.site AS LicenseeName
		,m.SettlementStatus
		,d.IsMarked
		,m.GlobalShowTime
		,c.custid
		,d.ActualStake
		,d.EndTime 
		,@SiteDBGroupID AS SiteDBGroupID
	FROM #SpecialDeleteBets d
		INNER JOIN CTE_GroupInfo g ON d.custid = g.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON d.recommend = c.custid
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = d.matchid
		OUTER APPLY (SELECT CASE 
								WHEN d.betfrom = 'p' THEN '4-Phone Betting'
								ELSE g.GroupName
							END AS GroupName) AS T
		OUTER APPLY (SELECT TOP 1 transid, username
					 FROM bettrans (NOLOCK)
					 WHERE transid = d.betid AND SitedbgroupId = @SiteDBGroupID				   
					   AND T.GroupName = '1-8RM/BARM'
			) AS FollowInfo							
	WHERE NOT EXISTS (
			SELECT TOP 1 1 
			FROM  dbo.[f_GetBetDaqCustomer] (1) 
			WHERE custid = d.custid
		) --betdaq
		AND d.username 		<> '12EU'
		AND g.mrecommend 	NOT IN (105181, 118473, 105183) --MHC
		AND d.recommend 	NOT IN (11196380) --Foobet
		AND d.recommend 	NOT IN (13423967) --OneExchange
	ORDER BY T.GroupName
		   , ISNULL(d.MainTransId, d.transid)
		   , CASE 
				WHEN d.BonusID IS NOT NULL
						THEN CASE 
								WHEN d.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE d.transid
			 END

	DROP TABLE #CustId
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #transIdTemp
	DROP TABLE #InvalidTransIds
	RETURN;
END
GO