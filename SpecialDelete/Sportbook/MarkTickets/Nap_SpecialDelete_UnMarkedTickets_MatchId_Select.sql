/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_UnMarkedTickets_MatchId_Select] 
(
	@MatchId       INT,
    @Duration      XML          = NULL,
    @LiveIndicator INT          = 0,
    @LiveHomeScore SMALLINT     = NULL,
    @LiveAwayScore SMALLINT     = NULL,
    @CurrencyIDs   VARCHAR(MAX) = NULL,
    @LicenseeNames VARCHAR(MAX) = NULL,
    @BetTypes      XML          = NULL,
	@Bet 		   VARCHAR(10)  = 'All'
)
AS;
/*
    Created by: 20190325@Alan
	Task: Mark Ticket for Settlement Exclusion
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190520@Raymond.Le: Mark Tickets - Not allow to mark Waiting [113518]
		- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]	
		- 20200115@Max: Mark & Unmark tickets for Othersports [Redmine: #127035]
		- 20200225@Charles: Mark & Unmark tickets for Esport, Badminton and Tennis [129139]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20200508@Charles: PHAIO 5.1 for Penalty [132985]
		- 20200727@Zane: Basketball AIO Phase 2 - Change filter advanced mode for new bettypes [137189]
		- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
		- 20201009@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210303@July: Enhance data type advance mode [Redmine: #150075]
		- 20210426@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20210823@Max: [TVS] Mark sub-parlay for from/to bet ID filter [Redmine: #160209]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230427@July: [TVS] Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20240129@July: Update the Advance Mode for bet types of Basketball [Redmine: #199605]
		- 20240123@July: Separate group to view data of 777 site [Redmine: #198089]
		- 20240312@July: Update the Advance Mode for bet types of Cricket [Redmine: #199238]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240527@July: [TVS] Scaleout DBCUST [Redmine: #205629]

	Explanation's Param:
		- @LiveIndicator:
		 + 0: Dead
		 + 1: Live
		 + 2: All

		- @BetTypes: 
		'<BetTypes>
			<BetType Id="1" 
					 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
					 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
					 Game="01"				-- Default : "All" ; Format : 0X 
					 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ;
					 ValueHdp1				-- Default : "All" ; Format : 1,2,3,4,... ;	
					 ValueHdp2				-- Default : "All" ; Format : Single Number
					 Goal="2"				-- Default : "All" ; Format : Single Number
					 OddsSpread="1.5"		-- Default : "All" ; Format : 1.5,0.5,1.0,...
					 OddsId="8518"			-- Default : "All" ; Format : 8518,8519,...
					 Transdesc = '100001'	-- Default : "All" ; Format : 100001,100002,... (PlayerId - [Team].[TeamID])
					 VirtualHead ="1"		-- Default : "All" ; Format : Single Number
			/>
		 <BetTypes/>'

		  - @Duration:
		  '<TransDates><TransDate From="2019-03-04 04:11:33.240" To="2019-03-26 04:11:33.240" /></TransDates>'
	    
*/
BEGIN
	SET NOCOUNT ON

    DECLARE @SportType		TINYINT= NULL
		   ,@ValueDefault	SMALLMONEY = 9999.00
		   ,@SiteDBGroupID  SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

    SELECT @SportType = SportType
    FROM dbo.match WITH (NOLOCK)
    WHERE MatchId = @MatchId;
    IF NOT EXISTS (
		SELECT TOP 1 1
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10) -- outright
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
			AND @SportType = pt.SportType
	)
    RETURN;

	DECLARE @tmpMatchId TABLE (MatchId INT)
	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN @SportType <> 50 AND matchid = @MatchId THEN 1
				    WHEN @SportType = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END

   CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(500),
		Game			VARCHAR(500),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		ValueHdp1		VARCHAR(500),
		ValueHdp2		VARCHAR(500),
		Goal			VARCHAR(10),
		OddsSpread		VARCHAR(500),
		OddsId			VARCHAR(1000),
		Transdesc		NVARCHAR(2000),
		VirtualHead		VARCHAR(500)
	)

	CREATE TABLE #tblBetType_Detail
	(
		Id				SMALLINT,
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,
		ValueHdp1		SMALLMONEY,
		ValueHdp2		SMALLMONEY,
		Goal			BIGINT,
		OddsSpread		MONEY,
		OddsId			INT,
		Transdesc		NVARCHAR(2000),
		VirtualHead		SMALLMONEY,
		Hdp1_tmp		SMALLMONEY
	)
		
	-- Parse xml @BetTypes
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc, VirtualHead)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(500)') AS [Set]				-- check columns : betid		 ; single-choice + multi-choice
			, t.c.value('@Game','VARCHAR(500)') AS Game				-- check columns : betid		 ; single-choice + multi-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]			-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1			 ; single-choice + multi-choice
			, t.c.value('@ValueHdp2','VARCHAR(500)') AS ValueHdp2	-- check columns : hdp2			 ; single-choice + multi-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice + multi-choice
			, t.c.value('@OddsSpread','VARCHAR(500)') AS OddsSpread	-- Check columns : OddsSpread	 ; single-choice + multi-choice
			, t.c.value('@OddsId','VARCHAR(1000)') AS OddsId		-- check columns : OddsId		 ; single-choice + multi-choice
			, t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice + multi-choice
			, t.c.value('@VirtualHead','NVARCHAR(500)') AS VirtualHead	-- check columns : hdp1 OR hdp2	 ; single-choice
	FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))
			 
	INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc, VirtualHead)
	SELECT cte.Id
		 , CASE
				WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
				WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
				ELSE cte.BetTeam
		   END AS BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.BetOption
		 , cte.[Value]
		 , cte.ValueHdp1
		 , cte.ValueHdp2
		 , cte.Goal
		 , cte.OddsSpread
		 , cte.OddsId
		 , cte.Transdesc
		 , cte.VirtualHead
	FROM (
		SELECT cte.Id
			 , bt.value AS BetTeam 
			 , se.value AS [Set]
			 , ga.value AS Game
			 , bop.value AS BetOption
			 , CAST(CASE WHEN v.value = 'ALL' THEN @ValueDefault 
						ELSE v.value END AS SMALLMONEY) AS [Value]
			 , CAST(CASE WHEN vhdp1.value = 'ALL' THEN @ValueDefault
						ELSE vhdp1.value END AS SMALLMONEY) AS ValueHdp1
			 , CAST(CASE WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault 
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2					 
			 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal END AS BIGINT) AS Goal
			 , CAST(CASE WHEN os.value = 'ALL' THEN @ValueDefault
						ELSE os.value END AS MONEY) AS OddsSpread
			 , CAST(CASE WHEN osid.value = 'ALL' THEN NULL
						ELSE osid.value END AS INT) AS OddsId
			 , CAST(CASE WHEN td.value = 'ALL' THEN NULL
						ELSE td.value END AS NVARCHAR(2000)) AS Transdesc
			 , CAST(CASE WHEN cte.VirtualHead = 'ALL' THEN @ValueDefault 
						ELSE cte.VirtualHead END AS SMALLMONEY) AS VirtualHead	
		FROM #tblBetType cte
			 CROSS APPLY STRING_SPLIT(cte.betteam, ',') bt
			 CROSS APPLY STRING_SPLIT(cte.[Set], ',') se
			 CROSS APPLY STRING_SPLIT(cte.Game, ',') ga
			 CROSS APPLY STRING_SPLIT(cte.BetOption, ',') bop
			 CROSS APPLY STRING_SPLIT(cte.[Value], ',') v
			 CROSS APPLY STRING_SPLIT(cte.ValueHdp1, ',') vhdp1
			 CROSS APPLY STRING_SPLIT(cte.OddsSpread, ',') os
			 CROSS APPLY STRING_SPLIT(cte.OddsId, ',') osid
			 CROSS APPLY STRING_SPLIT(cte.Transdesc, ',') td
	) cte	
	WHERE CASE WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
			WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
			ELSE 1 END = 1

	CREATE TABLE #Durations (FromTransDate DATETIME, ToTransDate DATETIME)
	
    -- Only parse xml @Durations if @Duration is not null and is not empty
    IF ISNULL(DATALENGTH(@Duration), 5) <> 5
    BEGIN 
        INSERT INTO #Durations
               (FromTransDate,
                ToTransDate
               )
               SELECT x.value('@From', 'DATETIME') AS FromTransDate,
                      x.value('@To', 'DATETIME') AS ToTransDate
               FROM @Duration.nodes('TransDates/TransDate') XmlData(x) OPTION(OPTIMIZE FOR(@Duration = NULL));
    END;

	CREATE TABLE #t_LicenseeNames(LicenseeName VARCHAR(100), GroupName VARCHAR(100))
	CREATE CLUSTERED INDEX t_IDX_LicenseeNames_LicenseeName ON #t_LicenseeNames(LicenseeName)
	
	CREATE TABLE #t_UIRepresentativeLicenseeGroupNames(GroupName VARCHAR(100))

	CREATE TABLE #t_exchanges(exchangeid INT, currency NVARCHAR(50))

	--> Parse @LicenseeNames
	INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
	SELECT ss.value AS LicenseeName, ss.value AS GroupName
	FROM STRING_SPLIT(@LicenseeNames, ',') ss		

	DECLARE @MBCGroup_Name VARCHAR(50) = 'MBC Group'
		  , @789y_Name	   VARCHAR(50) = '789y'
		  , @cn88_Name	   VARCHAR(50) = 'CN88'
		  , @777_Name	   VARCHAR(50) = '777'

	-- Replace all UI representative groups (MBCGroup and 789y) by their real credit licensees
	DELETE FROM #t_LicenseeNames 
	OUTPUT DELETED.GroupName 
			INTO #t_UIRepresentativeLicenseeGroupNames(GroupName)
	WHERE LicenseeName IN (@MBCGroup_Name, @789y_Name, @cn88_Name, @777_Name)

	IF @@ROWCOUNT > 0
	BEGIN
		;WITH CTE_CreditSite AS
		(
			SELECT [site], ISNULL(SiteLabel,'') AS SiteLabel
			FROM CustDB.dbo.Site WITH(NOLOCK) 
			WHERE isLicensee = 0 AND isActive = 1
		)
		INSERT INTO #t_LicenseeNames(LicenseeName, GroupName)
		SELECT cte.[site] AS LicenseeName, t.GroupName
		FROM #t_UIRepresentativeLicenseeGroupNames AS t
			 CROSS APPLY (
							SELECT cte.[site]
							FROM CTE_CreditSite cte
							WHERE 1 = CASE
										  WHEN t.GroupName = @MBCGroup_Name AND cte.[site] NOT IN (@cn88_Name) AND cte.SiteLabel NOT IN (@789y_Name, @777_Name) THEN 1
										  WHEN t.GroupName = @789y_Name AND cte.SiteLabel = @789y_Name THEN 1
										  WHEN t.GroupName = @cn88_Name AND cte.[site] IN (@cn88_Name) THEN 1 
										  WHEN t.GroupName = @777_Name AND cte.SiteLabel = @777_Name THEN 1
										  ELSE 0 
									  END
						 ) AS cte
	END
	
	--> Parse @CurrencyIDs
	INSERT INTO #t_exchanges(exchangeid, currency)
	SELECT e.exchangeid, e.currency
	FROM STRING_SPLIT(@CurrencyIDs, ',') ss
		 INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK) ON CAST(ss.value AS INT) = e.exchangeid	

	CREATE TABLE #Tickets(
              transid               BIGINT,
              custid                INT,
              UserName              VARCHAR(50),
              oddsspread            MONEY,
              odds                  MONEY,
              modds					SMALLMONEY,
			  OddsType              INT,
              transdate             DATETIME,
              bettype               SMALLINT,
              betteam               NVARCHAR(10),
              betcheck              NVARCHAR(50),
              hdp1                  SMALLMONEY,
              hdp2                  SMALLMONEY,
              IsLiveIndicator       BIT,
              livehomescore         SMALLINT,
              liveawayscore         SMALLINT,
              creator               INT,
              Stake                 MONEY,
              CurrencyName          VARCHAR(10),
              IsDeposit             BIT DEFAULT(0),
              IsCricket             BIT DEFAULT(0),
              status                NVARCHAR(10),
              srecommend            INT,
              mrecommend            INT,
              recommend             INT,
              SecAcceptFlag         BIT,
              betid                 BIGINT,
              betdaqid              BIGINT,
              TransDesc             NVARCHAR(1000),
              refno                 BIGINT,
              ExtraInfo             VARCHAR(1000),
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
              WinLost               MONEY,
			  IsMixParlay			BIT DEFAULT(0),
              SubTransId			BIGINT,
              SubStatus				NVARCHAR(10),
              SubBetCheck			NVARCHAR(50),
              SubBetTeam			NVARCHAR(10),
              SubBetType			SMALLINT DEFAULT(0),
              SubHdp1				SMALLMONEY,
              SubHdp2				SMALLMONEY,
              SubOdds				MONEY,	
              FilterBettype         SMALLINT,
              FilterBetTeam         NVARCHAR(10),
              FilterSet             VARCHAR(50),
              FilterGame            VARCHAR(50),
              FilterValue           SMALLMONEY,
              FilterGoal            BIGINT,
              FilterBetOption       NVARCHAR(50),
              FilterHdp1		 	SMALLMONEY,
        	  FilterHdp2		 	SMALLMONEY,
			  FilterOddsSpread	 	MONEY,
			  FilterOddsId		    INT,
			  FilterTransdesc	    NVARCHAR(2000),
			  ActualStake			MONEY,
			  MatchId				INT
             );

	CREATE TABLE #ParlayTickets
             (CustId        INT,
              OddsSpread    MONEY,
              TransDate     DATETIME,
			  checktime		DATETIME,
              LiveIndicator BIT,
              LiveHomeScore SMALLINT,
              LiveAwayScore SMALLINT,
              Creator       INT,
              TransDesc     NVARCHAR(1000),
              Refno         BIGINT,
              SubTransId    BIGINT,
              SubStatus     NVARCHAR(10),
              SubBetCheck   NVARCHAR(50),
              SubBetTeam    NVARCHAR(10),
              SubBetType    SMALLINT DEFAULT(0),
              SubHdp1       SMALLMONEY,
              SubHdp2       SMALLMONEY,
              SubOdds       MONEY,
			  SubOddsSpread	 MONEY,
			  MatchId		INT,
			  SubOddsId		INT,
			  SubTransDesc  NVARCHAR(2000)
             );

	IF @Bet = 'All' OR @Bet = 'Single'
	BEGIN
		INSERT INTO #Tickets (
			transid
			,custid	
			,odds
			,modds
			,oddsspread	
			,OddsType
			,transdate
			,bettype
			,betteam
			,betcheck
			,hdp1
			,hdp2
			,IsLiveIndicator
			,livehomescore 
			,liveawayscore 
			,creator
			,UserName
			,Stake
			,CurrencyName
			,status
			,srecommend
			,mrecommend
			,recommend
			,SecAcceptFlag
			,betid
			,betdaqid
			,TransDesc
			,refno
			,ExtraInfo
			,WalletType
			,RefCode
			,BonusID
			,WinLost
			,FilterBettype
			,FilterBetTeam
			,FilterSet
			,FilterGame	
			,FilterValue
			,FilterGoal
			,FilterBetOption
			,FilterHdp1
			,FilterHdp2
			,FilterOddsSpread
			,FilterOddsId
			,FilterTransdesc
			,ActualStake
			,MatchId
		)
		SELECT 
			b.transid,
			b.custid,
			b.odds,   
			b.modds,
			b.oddsspread,
			b.OddsType,  
			b.transdate,
			b.bettype,
			b.betteam,
			b.betcheck,
			b.hdp1,
			b.hdp2,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.creator,
			b.Username,
			b.stake,
			b.CurrencyName,
			b.status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			ISNULL(SecAcceptFlag,0) SecAcceptFlag,
			b.betid,
			b.betdaqid,
			b.transdesc,
			b.refno,
			b.ExtraInfo,
			b.WalletType,
			b.RefCode,
			b.BonusID,
			b.WinLost - b.actual_stake AS WinLost,
			b.bettype AS FilterBetType,
			b.betteam AS FilterBetTeam,
			b.betid AS FilterSet,
			RIGHT(b.betid, 2) AS FilterGame,
			b.hdp1 + b.hdp2 AS FilterValue,
			ISNULL(b.betid, 0) AS FilterGoal,
			CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
			b.hdp1 AS FilterHdp1,
			CASE WHEN bt.Id = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS FilterHdp2, --646: Match Handicap & Total
			CASE WHEN bt.Id = 229 THEN ABS(b.oddsspread) ELSE b.oddsspread END AS FilterOddsSpread, --229:SABA HDP Time Machine
			b.oddsid AS FilterOddsId,
			b.transdesc AS FilterTransdesc,
			b.actual_stake AS ActualStake,
			b.matchid
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblBetType bt WITH (NOLOCK) ON bt.id = b.bettype
			INNER JOIN #t_exchanges te WITH (NOLOCK) ON b.currency = te.exchangeid
			INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		WHERE b.matchid IN (SELECT MatchId FROM @tmpMatchId)
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveIndicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
			AND (b.statusID = 0 -- running
				AND NOT ( b.SecAcceptFlag = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)) -- not in waiting SecAccept
			AND b.betfrom <> 'p'	
			AND EXISTS (SELECT TOP 1 1 FROM #Durations d WHERE b.transdate BETWEEN d.FromTransDate AND d.ToTransDate) 
	END

	IF @Bet = 'All' OR @Bet = 'Parlay'
	BEGIN
		INSERT INTO #ParlayTickets (
			CustId
			,OddsSpread			
			,TransDate
			,checktime
			,LiveIndicator	
			,LiveHomeScore 	
			,LiveAwayScore 	
			,Creator
			,TransDesc	
			,Refno
			,SubTransId
			,SubStatus
			,SubBetCheck
			,SubBetTeam
			,SubBetType
			,SubHdp1
			,SubHdp2
			,SubOdds
			,SubOddsSpread
			,MatchId
			,SubOddsId
			,SubTransDesc
		)
		SELECT
			bm.custid, 
			bm.oddsspread,
			bm.transdate,
			bm.checktime,
			bm.liveindicator,
			bm.livehomescore,
			bm.liveawayscore,
			bm.creator,
			bm.transdesc,
			bm.refno,
			bm.transid AS SubTransId,
			bm.status AS SubStatus,
			bm.betcheck AS SubBetCheck,
			bm.betteam AS SubBetTeam,
			bm.bettype AS SubBetType,
			bm.hdp1 AS SubHdp1,
			CASE WHEN bt.Id = 646 THEN ABS(bm.hdp2) ELSE bm.hdp2 END AS SubHdp2, --646: Match Handicap & Total
			bm.odds As SubOdds,
			CASE WHEN bt.Id = 229 THEN ABS(bm.oddsspread) ELSE bm.oddsspread END AS SubOddsSpread, --229:SABA HDP Time Machine
			bm.matchid,
			bm.oddsid,
			bm.transdesc
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = bm.bettype
		WHERE bm.matchid IN (SELECT MatchId FROM @tmpMatchId)
			AND bm.SiteDBGroupID = @SiteDBGroupID
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE bm.liveIndicator END = @LiveIndicator
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END			
			AND bm.statusID = 0
			AND bm.betfrom <> 'p'
			AND EXISTS (SELECT TOP 1 1 FROM #Durations d WHERE bm.transdate BETWEEN d.FromTransDate AND d.ToTransDate)

		INSERT INTO #Tickets (
			 transid
			,custid	
			,odds
			,modds
			,oddsspread	
			,OddsType
			,transdate
			,bettype
			,betteam
			,betcheck
			,hdp1
			,hdp2
			,IsLiveIndicator
			,livehomescore 
			,liveawayscore 
			,creator
			,UserName
			,Stake
			,CurrencyName
			,status
			,srecommend
			,mrecommend
			,recommend
			,betid
			,betdaqid
			,TransDesc
			,refno
			,WinLost
			,IsMixParlay
			,SubTransId
			,SubStatus
			,SubBetCheck
			,SubBetTeam
			,SubBetType
			,SubHdp1
			,SubHdp2
			,SubOdds
			,FilterBettype
			,FilterBetTeam
			,FilterSet
			,FilterGame	
			,FilterValue
			,FilterHdp1
			,FilterHdp2
			,FilterGoal
			,FilterOddsSpread
			,FilterOddsId
			,FilterTransdesc
			,ExtraInfo
			,ActualStake
			,MatchId
		)
		SELECT 
			b.transid,
			bm.custid,
			b.odds,   
			b.modds,
			bm.oddsspread,
			b.OddsType,  
			bm.transdate,
			b.bettype,
			b.betteam,
			b.betcheck,
			b.hdp1,
			b.hdp2,
			bm.liveindicator,
			bm.livehomescore,
			bm.liveawayscore,
			bm.creator,
			b.username,
			b.stake,
			b.CurrencyName, 
			b.status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			b.betid,
			b.betdaqid,
			bm.transdesc,
			bm.Refno,
			b.WinLost - b.actual_stake AS WinLost,
			1 AS IsMixParlay,
			bm.SubTransId,
			bm.SubStatus,
			bm.SubBetCheck,
			bm.SubBetTeam,
			bm.SubBetType,
			bm.SubHdp1,
			bm.SubHdp2,
			bm.SubOdds,
			bm.SubBetType AS FilterBetType,
			bm.SubBetTeam AS FilterBetTeam,
			bm.SubBetCheck AS FilterSet,
			RIGHT(bm.SubBetCheck, 2) AS FilterGame,
			bm.SubHdp1 + bm.SubHdp2 AS FilterValue,
			bm.SubHdp1 AS FilterHdp1,
			CASE WHEN b.bettype = 646 THEN ABS(bm.SubHdp2) ELSE bm.SubHdp2 END AS FilterHdp2, --646: Match Handicap & Total
			ISNULL(bm.SubBetCheck, 0) AS FilterGoal,
			CASE WHEN b.bettype = 229 THEN ABS(bm.SubOddsSpread) ELSE bm.OddsSpread END AS FilterOddsSpread, --229:SABA HDP Time Machine
			bm.SubOddsId AS FilterOddsId,
			bm.SubTransDesc AS FilterTransdesc,
			b.ExtraInfo,
			b.actual_stake AS ActualStake,
			bm.MatchId
		FROM #ParlayTickets AS bm
		INNER JOIN dbo.bettrans AS b with (NOLOCK) ON b.matchid	= 29 AND bm.refno = b.refno AND b.SiteDBGroupID = @SiteDBGroupID
		INNER JOIN #t_exchanges te WITH (NOLOCK) ON b.currency = te.exchangeid
	END

	-- Filter Advanced Mode
	BEGIN
		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND 
				CASE
					WHEN tp.Id <> 376 THEN CASE WHEN tp.BetTeam = 'All' OR b.FilterBetTeam = tp.BetTeam THEN 1 ELSE 0 END
					ELSE 
						CASE tp.BetTeam
							 WHEN 'All-All' THEN 1
							 WHEN 'All-S' THEN CASE WHEN b.FilterBetTeam LIKE '%S%' THEN 1 ELSE 0 END
							 WHEN 'All-M' THEN CASE WHEN b.FilterBetTeam LIKE '%M%' THEN 1 ELSE 0 END
							 WHEN 'H-All' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) <> '-----' THEN 1 ELSE 0 END
							 WHEN 'A-All' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) <> '-----' THEN 1 ELSE 0 END
							 WHEN 'H-S' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) LIKE '%S%' THEN 1 ELSE 0 END
							 WHEN 'H-M' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 1, 5) LIKE '%M%' THEN 1 ELSE 0 END
							 WHEN 'A-S' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) LIKE '%S%' THEN 1 ELSE 0 END
							 WHEN 'A-M' THEN CASE WHEN SUBSTRING(b.FilterBetTeam, 6, 5) LIKE '%M%' THEN 1 ELSE 0 END
							 ELSE 0
						END
				END = 1
		)

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

		IF @SportType NOT IN (50) --NOT Cricket
		BEGIN
			DELETE b
			FROM  #Tickets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

			DELETE b
			FROM  #Tickets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

			DELETE b
			FROM  #Tickets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

		END
		ELSE --Cricket
		BEGIN
			--Note: Value of Cricket => hdp1 value
			UPDATE #tblBetType_Detail 
			SET Hdp1_tmp = CASE WHEN [Value] <> @ValueDefault THEN [Value] 
							    WHEN ValueHdp1 <> @ValueDefault THEN ValueHdp1 
								ELSE @ValueDefault END
			
			DELETE b
			FROM  #Tickets b
			WHERE b.FilterBetTeam NOT IN ('y')
			  AND NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
							  WHERE tp.Id = b.FilterBettype 
								AND 1 = CASE WHEN tp.Hdp1_tmp = @ValueDefault AND tp.VirtualHead = @ValueDefault THEN 1
											 WHEN tp.Hdp1_tmp <> @ValueDefault AND tp.VirtualHead = @ValueDefault AND b.FilterHdp1 = tp.Hdp1_tmp THEN 1
											 WHEN tp.Hdp1_tmp <> @ValueDefault AND tp.VirtualHead <> @ValueDefault AND (b.FilterHdp1 = tp.Hdp1_tmp OR b.FilterHdp1 >= tp.VirtualHead) THEN 1
											 WHEN tp.Hdp1_tmp = @ValueDefault AND tp.VirtualHead <> @ValueDefault AND b.FilterHdp1 >= tp.VirtualHead THEN 1
											 ELSE 0 END)
			
			--Group bettypes: xxx Fancy (Yes/No value case 'y')
			DELETE b
			FROM  #Tickets b
			WHERE b.FilterBetTeam IN ('y')
			  AND NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
							  WHERE tp.Id = b.FilterBettype
							  AND 1 = CASE WHEN tp.ValueHdp2 = @ValueDefault AND tp.VirtualHead = @ValueDefault THEN 1
										   WHEN tp.ValueHdp2 <> @ValueDefault AND tp.VirtualHead = @ValueDefault AND b.FilterHdp2 = tp.ValueHdp2 THEN 1
										   WHEN tp.ValueHdp2 <> @ValueDefault AND tp.VirtualHead <> @ValueDefault AND (b.FilterHdp2 = tp.ValueHdp2 OR b.FilterHdp2 >= tp.VirtualHead) THEN 1
										   WHEN tp.ValueHdp2 = @ValueDefault AND tp.VirtualHead <> @ValueDefault AND b.FilterHdp2 >= tp.VirtualHead THEN 1
										   ELSE 0 END)
		END

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ) OR b.bettype = 29)

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread))
		
		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId))

		DELETE b
		FROM  #Tickets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))

	END

	-- delete marked tickets
	DELETE t 
	FROM #Tickets t
		INNER JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON m.TransId = t.transid AND t.MatchId = m.MatchId

	UPDATE s
	SET IsDeposit = 1
	FROM #Tickets s
		INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) ON s.srecommend = d.custid

	------------------------------------------------------------------------------
	--1. Table invald/moved transid
	SELECT '' AS InvalidTransIds
	      ,'' AS MovedTransIds
		  ,'' AS MarkedTransIds

	--2. Table get tickets
	SELECT 
		b.Stake,
		b.BetCheck,
		b.BetId,
		b.BetTeam,
		b.BetType,
		b.CurrencyName,		
		b.Hdp1,
		b.Hdp2,
		b.IsLiveIndicator,
		b.LiveAwayScore,
		b.LiveHomeScore,
		b.Odds,
		b.oddsspread,
		CASE WHEN b.bettype = 501 AND b.IsDeposit = 0 THEN 1 ELSE 0 END AS IsCricket,
		b.OddsType,
		b.RefNo,
		b.Status,
		b.TransDate,
		b.TransDesc,
		b.TransId,
		b.UserName,
		b.WinLost,
		CASE 
		  WHEN b.recommend IN (52466, 5707545) THEN '8RM/BARM' 
		  WHEN b.custid IN(1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
		  ELSE tl.GroupName
		END GroupName,
		b.betdaqid,
		b.ExtraInfo,
		b.WalletType,
		b.MainTransId,
		b.RefCode,
		b.MatchId,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.IsNeutral,
		m.sporttype,
		m.SettlementStatus,
		c.site AS LicenseeName,
		b.IsDeposit,
		b.IsMixParlay,
		b.SubTransid,
		b.SubStatus,
		b.SubBetcheck,
		b.SubBetteam,
		b.SubBettype,
		b.SubHdp1,
		b.SubHdp2,
		b.SubOdds,
		b.ActualStake,
		b.modds AS MasterOdds, 
		@SiteDBGroupID AS SiteDBGroupID
	FROM #Tickets b
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON b.recommend = c.custid
		INNER JOIN #t_LicenseeNames tl WITH (NOLOCK) ON tl.LicenseeName = c.site 
		LEFT JOIN match m WITH (NOLOCK) ON m.matchid = b.MatchId
	ORDER BY CASE
				WHEN b.recommend IN (52466, 5707545) THEN 1
				WHEN b.custid IN(1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 2
				WHEN tl.GroupName = @cn88_Name THEN 3
				WHEN tl.GroupName = @789y_Name THEN 4
				WHEN tl.GroupName = @MBCGroup_Name THEN 5
				WHEN tl.GroupName = @777_Name THEN 6
				ELSE 7
		     END ASC
		   , tl.GroupName ASC
		   , ISNULL(b.MainTransId, b.transid) ASC
		   , CASE WHEN b.BonusID IS NOT NULL
				THEN CASE WHEN b.MainTransId IS NULL THEN 1
				ELSE 2 END ELSE b.transid END

	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #Durations
	DROP TABLE #Tickets
	DROP TABLE #t_exchanges
	DROP TABLE #t_LicenseeNames
	DROP TABLE #t_UIRepresentativeLicenseeGroupNames
	DROP TABLE #ParlayTickets

	SET NOCOUNT OFF
END