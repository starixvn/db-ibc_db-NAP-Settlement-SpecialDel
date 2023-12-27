/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_Detail] 
	@MatchId					INT,
    @LicenseeName				VARCHAR(MAX)  = 'ALL',
    @BetTypes					VARCHAR(1000) = '',
    @LiveType					SMALLINT      = 2,
    @LiveHomeScore				SMALLINT      = NULL,
    @LiveAwayScore				SMALLINT      = NULL,
    @FromTransdate				DATETIME      = NULL,
    @ToTransdate				DATETIME      = NULL,
    @Type						SMALLINT      = 0,
    @SecondAcceptFlag			TINYINT       = 0,
    @BallSequence				VARCHAR(200)  = '',
	@BetTeams					XML			  = NULL,
	@SingleOrSubParlay			VARCHAR(20)   = 'All',
	@SelectionType				VARCHAR(200)  = '',
	@IsReSettled				BIT			  = 0,
	@AffectTickets				XML				= NULL,
	@SelectionSubParlays		VARCHAR(200)    = ''

AS;
/*	Created by: 20130606@Elodie
	Task: Show Tickets Listing Detail and Export to excel for NAP system
	DB: DBACC/bodb02
	Original: Acc_Rpt_TicketsListingDetail

	Revisions:	
		- 20130911@Kathy: Rename parameter @SAFilter to @SecondAcceptFlag
		- 20131203@Kathy: Rename column: liveindicator to IsLiveIndicator.
						Using Dep_CustSuper table instead of f_DepSuper_1() function.		
		- 20140211@Kathy: Get more column for MixParlay	
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]	  
		- 20151023@Patrick: Add more field sporttype to support Muay Thai
		- 20151302@Kathy: add modds column 
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20150119@Kathy: Changes for phase 1.2 of PH All in One: add new column transdesc [Redmine:#50932]
		- 20170104@Kent: Add Column SportType to output tables [Redmine:#69816]	
		- 20170410@Kent: Add columns OriginalBetType, BetdaqId, ExtraInfo [Redmine:#72887]
		- 20170414@Kent: Fix IBC to MBC [Redmine:#75009]  
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170818@Kent: Re-Add columns OriginalBetType, ExtraInfo, BetdaqId And Add new column ActualStake [Redmine:#81868] 
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread - Fast Markets Phase 2 [Redmine:#90667]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20180814@Alan: Rename SP - Filter basketball tickets by quarter [99786]
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20181218@Alan: Filter Esports Tickets [106455]
		- 20190408@Jacob: Separate Filter Parlay Ticket by 1H & 2H [107682]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190601@Jacob: Ticket listing cannot show detail Parlay for CN88 [114437]
		- 20190613@Raymond.Le: Allow User to Filter Ticket by Selecting Multiple Maps and Rounds [115074]
		- 20191002@Charles: Replace 'MBC' Licensee by 'Credit' [120586]
		- 20191029@Raymond.Le: Fix Ticket listing search wrong quarter [122834]
		- 20191129@Max: Count Parlay_Wrong Score_Score Info Unmark [Redmine: #124516]
		- 20191226@Max: Phase 5 on Special Delete Site [Redmine: #126084]
		- 20200727@Zane: Basketball AIO Phase 2 - Change filter advanced mode for new bettypes [137189]
		- 20200812@Charles: Implement Next R/B bet type for NG Color Ball - [128215]
		- 20200817@July: Ticket Listing - Bet Builder Enhancement [Redmine: #138555]
		- 20200911@Max: Tuning SP [Redmine: 141476]
		- 20200923@July: TVS - Resettled Affected Tickets [Redmine: #138552]
		- 20201013@July: [TVS] - HotFix - TicketListing bettype > 100 items [Redmine: #143308]
		- 20201202@Max: Tuning SP [Redmine: #146485]
		- 20210423@July: TVS - Enhance Ticket Listing for Cricket [Redmine: #153930]
		- 20210517@July: Enhance performance of Ticket Listing function [Redmine: #154732]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20211221@July: Remove column old CO [Redmine:#165097]
		- 20220303@July: Integrate Cricket AIO Phase 2 [Redmine:#168080]
		- 20220425@July: Separate Send Data to China View & Remove support CN88 [Redmine:#171395]
		- 20220705@Max: [TVS] Support multiple selection on Player filter of Cricket AIO [Redmine: #174652]
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220828@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221006@July: Ticket Listing - Support Advance Mode for Tennis(5) & Volleyball(6) [Redmine: #176611]
		- 20221110@Max: Scale out DBTrans - Enhancement to prevent high latency on Balance Record [Redmine: #180225]
		- 20230524@July: Support sport Cricket for all functions [Redmine: #188374]
		- 20230613@July: Ticket Listing - Add new filter to search tickets by combo parlay [Redmine: #187405]
		- 20230622@Max: Ticket listing - Select ticket listing has ERROR converting data type nvarchar to bigint [Redmine: #190166]
		- 20230623@July: Ticket listing - Enhance performance when sending data to many Licensees at a time [Redmine: #190071]
		- 20230831@Max: [TVS] Integrate 4 new bet types of Basketball [Redmine: #192608]
		- 20231213@July: Ticket Listing - Support more Advanced Mode controls for some sports [Redmine: #193777]

	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports
		5: Virtual sports betradar
		8: Bet Builder
		9: Bitcoin

	- @LicenseeName:
		ALL, IBC, 12bet, ...	
	- @BetTypes: String of bettype for Sportsbook, virtual sports and for Dead Ball - Number game, Live casino	 
	- @LiveType: Combo Type, used only for Sportsbook
		0: Dead ball
		1: Live ball
		2: All	
	- Because the interface is separated with sportbook and number game
		==>	SportsBook: Use @BetTypes and @LiveType to indicate Live ball or Dead ball
			Number game: Use @BetTypes and @BetTypesLive to indicate Live ball or Dead ball
			Virtual sports: Use @BetTypes to indicate Dead ball
    - @SecondAcceptFlag: 
      + 0: All tickets
      + 1: Normal tickets only
      + 2: SA tickets only
	  - @BetTypes : 
		'<BetTypes>
			<BetType Id="1" 
						BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
						Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
						Game="01"				-- Default : "All" ; Format : 0X 
						BetOption="4-4,5-5"		-- Default : "All" ; Format : hdp2-betteam,...					 
						Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ;
						ValueHdp1				-- Default : "All" ; Format : 1,2,3,4,... ;	
					 	ValueHdp2				-- Default : "All" ; Format : Single Number
						Goal="2"				-- Default : "All" ; Format : Single Number
						OddsSpread="1.5"		-- Default : "All" ; Format : 1.5,0.5,1.0,...
						OddsId="8518"			-- Default : "All" ; Format : 8518,8519,...
						Transdesc = '100001'	-- Default : "All" ; Format : 100001,100002,... (PlayerId - [Team].[TeamID])
			/>
		<BetTypes/>'
    - @SingleOrSubParlay: 
	 + 'All'
	 + 'Single'
	 + 'SubParlay' 
	 
	- @AffectTickets: <root><r tid="1010509175087955968" /><r tid="1010509175087955968" />...</root>
    - @SelectionSubParlays: 
	 + IF @SingleOrSubParlay: 'All' OR 'Single' => default : ''
	 + IF @SingleOrSubParlay: 'SubParlay' => value : '2,3,4,5,6,7,8,9,10 UP'

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @p_bettypes			VARCHAR(1000)
		   ,@ValueDefault		SMALLMONEY = 9999.00
		   ,@SportType			SMALLINT = NULL
		   ,@SettlementStatus	TINYINT = NULL
		   ,@n					INT

	SET @p_bettypes = @BetTypes
	SET @n = 2147483647

	---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
	IF @Type <> 0 SELECT @LiveType = 2
	
	DECLARE @tmpBettypes TABLE ( bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpMatchId TABLE (MatchId INT PRIMARY KEY)
	DECLARE @tmpSelectionSubParlay TABLE (Id VARCHAR(10))
	
	INSERT INTO @tmpMatchId (MatchId)
	SELECT matchid
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype <> 50 AND matchid = @MatchId THEN 1
					WHEN sporttype = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END
	UNION 
	SELECT match3rdId
	FROM dbo.match3rd WITH (NOLOCK)
	WHERE match3rdId = @MatchID

	CREATE TABLE #tmpAffectTickets (Transid BIGINT PRIMARY KEY)
	CREATE TABLE #T_Match (matchtype VARCHAR(10), matchid INT, sporttype SMALLINT, homeid INT, awayid INT, isNeutral BIT, SettlementStatus TINYINT, Leagueid INT)

	IF (@IsReSettled = 1 AND @AffectTickets IS NOT NULL)
	BEGIN 
		INSERT INTO #tmpAffectTickets(Transid)
		SELECT t.c.value('@tid','BIGINT') AS Transid
		FROM @AffectTickets.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@AffectTickets = NULL ))
	END

	INSERT INTO #T_Match (matchtype, matchid, sporttype, homeid, awayid, isNeutral, SettlementStatus, Leagueid)
	SELECT 'match' AS [matchtype]
	  , matchid
	  , sporttype
	  , homeid
	  , awayid
	  , ISNULL(isNeutral,0)
	  , SettlementStatus
	  , leagueid
	FROM match (NOLOCK)
	WHERE matchid = @MatchId
	UNION ALL
	SELECT 'match3rd' AS [matchtype]
		  , match3rdid AS matchid
		  , sporttype
		  , homeid
		  , awayid
		  , NULL AS isNeutral
		  , NULL AS SettlementStatus
		  , League3rdId
	FROM match3rd (NOLOCK)
	WHERE match3rdid = @MatchId

	SELECT @Sporttype = sporttype 
		  ,@SettlementStatus = SettlementStatus
	FROM #T_Match

	CREATE TABLE #TmpBallSequence (Seq TINYINT)

	CREATE TABLE #SpecialDeleteBets
             (username         VARCHAR(30),
              bettype          SMALLINT,
              BetdaqId         BIGINT,
              ActualStake      MONEY,
              transid          BIGINT,
			  homeid           INT,
              awayid           INT,
              hdp1             SMALLMONEY,
              hdp2             SMALLMONEY,
              odds             SMALLMONEY,
              oddsspread       MONEY,
              status           NVARCHAR(10),
              stake            MONEY,
              transdate        DATETIME,
              betteam          NVARCHAR(10),
              betcheck         NVARCHAR(50),
              livehomescore    SMALLINT,
              liveawayscore    SMALLINT,
              IsLiveIndicator  BIT,
              ISNeutral        BIT,
              OddsType         INT,
              CurrencyName     NVARCHAR(100),
              winlost          MONEY,
              betid            BIGINT,
              IsParlay         BIT,
              SecAcceptFlag    BIT,
              refno            BIGINT,
              TransDesc        NVARCHAR(1000),
              SportType        SMALLINT,
              MOdds            SMALLMONEY,
              BallSequence     TINYINT,
              WalletType       TINYINT,
              RefCode          BIGINT,
              BonusID          INT,
              MainTransId      BIGINT,
              custid           INT,
              srecommend	   INT,
			  SubTransID       BIGINT,
              SubBetType       INT,
              SubHomeID        INT,
              SubAwayID        INT,
              SubHdp1          SMALLMONEY,
              SubHdp2          SMALLMONEY,
              SubOdds          SMALLMONEY,
              SubStake         MONEY,
              SubBetTeam       NVARCHAR(20),
              SubBetCheck      NVARCHAR(50),
              SubLiveHomeScore SMALLINT,
              SubLiveAwayScore SMALLINT,
              SubLiveIndicator BIT,
              SubLeagueId      INT,
              SubSportType     SMALLINT,
              SubTransDesc     NVARCHAR(1000),
              FilterBettype    SMALLINT,
              FilterBetTeam    NVARCHAR(10),
              FilterSet        VARCHAR(50),
              FilterGame       VARCHAR(50),
              FilterValue      SMALLMONEY,
              FilterGoal       NVARCHAR(50),
              FilterBetOption  NVARCHAR(50),
              IsMarked         BIT,
			  FilterHdp1	   SMALLMONEY,
			  FilterHdp2	   SMALLMONEY,
			  FilterOddsSpread MONEY,
			  FilterOddsId	   INT,
			  FilterTransdesc  NVARCHAR(1000)
             );

	INSERT INTO @tmpBettypes (bettype)
	SELECT	CONVERT(smallint, value)
	FROM STRING_SPLIT(@p_bettypes, ',')

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(500),
		Game			VARCHAR(500),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		ValueHdp1		VARCHAR(500),
		ValueHdp2		VARCHAR(20),
		Goal			VARCHAR(10),
		OddsSpread		VARCHAR(20),
		OddsId			VARCHAR(1000),
		Transdesc		NVARCHAR(2000)
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
		Transdesc		NVARCHAR(2000)
	)
	
	CREATE TABLE  #tmpSelectionType (Selectiontype INT PRIMARY KEY)
	DECLARE @tmpTransid TABLE (Transid BIGINT)

	IF @SelectionType <> ''
	BEGIN
		INSERT INTO #tmpSelectionType (Selectiontype)
		SELECT value
		FROM STRING_SPLIT(@SelectionType, ',')
	
		INSERT INTO @tmpTransid (Transid)
		SELECT DISTINCT b.transid
		FROM dbo.bettrans b WITH(NOLOCK) 
			CROSS APPLY (
				SELECT SelectionType
				FROM dbo.SMP_MarketSelection ms WITH(NOLOCK) 
				WHERE b.betcheck = ms.MarketId and matchid = b.matchid
				)ms
			INNER JOIN  #tmpSelectionType s ON ms.SelectionType=s.Selectiontype
		WHERE b.matchid IN (SELECT MatchId FROM @tmpMatchId)
	END
	
	-- Parse xml @BetTeams
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(500)') AS [Set]				-- check columns : betid		 ; single-choice
			, t.c.value('@Game','VARCHAR(500)') AS Game				-- check columns : betid		 ; single-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]			-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1	 ; single-choice + multi-choice
			, t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2	 ; single-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
			, t.c.value('@OddsSpread', 'VARCHAR(20)') AS OddsSpread	-- Check columns : OddsSpread ; single value
			, t.c.value('@OddsId','VARCHAR(1000)') AS OddsId			-- check columns : OddsId		 ; single-choice + multi-choice
			, t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice + multi-choice
	FROM @BetTeams.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTeams = NULL))
			 
	INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc)
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

	INSERT INTO #TmpBallSequence(Seq)
	SELECT  value
	FROM STRING_SPLIT(@BallSequence, ',')

	IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single'
	BEGIN	
		---ALL
		--IF @LicenseeName= 'ALL' 
		BEGIN 
			IF @Type = 1 -- FOR Happy 5, Number Game Only
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,BetdaqId,ActualStake,transid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,MOdds,BallSequence, srecommend)
				SELECT	b.username,
						b.bettype,					
						b.BetdaqId,
						b.actual_stake AS ActualStake,					
						b.transid,
						CONVERT(float, b.hdp1) as hdp1, 
						CONVERT(float, b.hdp2) as hdp2, 
						b.odds,
						b.oddsspread,
						CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 and ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								ELSE b.status END AS status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						b.MOdds,
						CASE WHEN @SportType = 164 THEN NULL ELSE BS_tmp.BallSequence END AS BallSequence,
						b.srecommend
				FROM	bettrans b WITH (NOLOCK)
					INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
					OUTER APPLY (SELECT BallSequence 
								FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore )
								WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
								) AS BS_tmp
					LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON b.srecommend = ds.custid
					LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.custid
				WHERE b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
					AND b.matchid IN (SELECT MatchId FROM @tmpMatchId)
					AND 1 = CASE WHEN @LicenseeName <> 'Credit' AND @LicenseeName <> 'ALL'  
									AND ds.custid IS NOT NULL AND ds.site = @LicenseeName THEN 1
								 WHEN @LicenseeName = 'Credit'  
									AND ds.custid IS  NULL AND cs.CustId IS  NULL THEN 1
								 WHEN @LicenseeName = 'ALL' THEN 1 
								 ELSE 0 END
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					AND 1 = CASE WHEN  @SportType = 164 THEN 1 --Happy 5
									WHEN  @SportType <> 164 AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WITH (NOLOCK) WHERE Seq = BS_tmp.BallSequence) THEN 1 --Number Game
									ELSE 0 END	
				OPTION	(RECOMPILE)
			END
			ELSE
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,BetdaqId,ActualStake,transid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,MOdds,WalletType,RefCode,BonusID,MainTransId, custid, srecommend
											,FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, IsMarked, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc)
				SELECT	b.username,
						b.bettype,					
						b.BetdaqId,
						b.actual_stake AS ActualStake,					
						b.transid,
						CONVERT(float, b.hdp1) as hdp1, 
						CONVERT(float, b.hdp2) as hdp2, 
						b.odds,
						b.oddsspread,
						CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 and ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END  as status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						b.MOdds,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						NULL AS MainTransId,				
						b.custid,
						b.srecommend,
						b.bettype AS FilterBetType,
						b.betteam AS FilterBetTeam,
						b.betid AS FilterSet,
						RIGHT(b.betid, 2) AS FilterGame,
						b.hdp1 + b.hdp2 AS FilterValue,
						ISNULL(CONVERT(NVARCHAR(50),b.betid), 0) AS FilterGoal,
						CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
						CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked,
						b.hdp1 AS FilterHdp1,
						b.hdp2 AS FilterHdp2,
						b.oddsspread AS FilterOddsSpread,
						b.oddsid AS FilterOddsId,
						b.transdesc AS FilterTransdesc
				FROM	Bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON b.transid = mt.TransId				
				LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON b.srecommend = ds.custid
				LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.custid
				WHERE b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
					AND b.matchid IN (SELECT MatchId FROM @tmpMatchId)
					AND 1 = CASE WHEN @LicenseeName <> 'Credit' AND @LicenseeName <> 'ALL'  
									AND ds.custid IS NOT NULL AND ds.site = @LicenseeName THEN 1
								 WHEN @LicenseeName = 'Credit'  
									AND ds.custid IS  NULL AND cs.CustId IS  NULL THEN 1
							     WHEN @LicenseeName = 'ALL' THEN 1 
								 ELSE 0 END
					AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
					AND b.transdate	BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
									AND	    CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END 
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				OPTION	(RECOMPILE)
			END	
		END		
		
		IF (@IsReSettled = 1 AND @SportType = 1)
		BEGIN
			DELETE b
			FROM #SpecialDeleteBets b
			WHERE NOT EXISTS ( SELECT TOP 1 1 FROM #tmpAffectTickets t WHERE b.transid=t.Transid)
		END

		IF (@BetTypes ='38' AND @Selectiontype <>'')
		BEGIN
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS ( SELECT TOP 1 1 FROM @tmpTransid t WHERE b.transid=t.Transid)
		END
		
		IF @BetTeams IS NOT NULL
		BEGIN
			DELETE b
			FROM  #SpecialDeleteBets b
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
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (CONVERT(NVARCHAR(50),tp.Goal) = 100 OR b.FilterGoal = CONVERT(NVARCHAR(50),tp.Goal) ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId )) 
	
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))
		END

	END

	-- System parlay - Sportsbook 29
    IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'SubParlay'
	BEGIN 
		---ALL
		--IF @LicenseeName= 'ALL'  
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, bettype, BetdaqId, ActualStake, transid,
					hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid, srecommend,
					SubTransID, SubBetType, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubTransDesc,
					FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc)	
			SELECT	b.username,
					b.bettype,				
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 and ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	
					b.srecommend,
					bm.transid SubTransID,
					bm.bettype SubBetType,
					CONVERT(float, bm.hdp1) as SubHdp1, 
					CONVERT(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					bm.transdesc SubTransDesc,
					bm.bettype AS FilterBetType,
					bm.betteam AS FilterBetTeam,
					bm.betcheck AS FilterSet,
					RIGHT(bm.betcheck, 2) AS FilterGame,
					bm.hdp1 + bm.hdp2 AS FilterValue,
					ISNULL(bm.betcheck, 0) AS FilterGoal,
					CAST(CAST(bm.hdp2 AS INT) AS VARCHAR(50)) + '-' + bm.betteam AS FilterBetOption,
					bm.hdp1 AS FilterHdp1,
					bm.hdp2 AS FilterHdp2,
					bm.oddsspread AS FilterOddsSpread,
					bm.oddsid AS FilterOddsId,
					bm.transdesc AS FilterTransdesc
			FROM (SELECT TOP (@n) matchid from @tmpMatchId) tmp
				INNER JOIN bettransm bm WITH (NOLOCK) ON tmp.MatchId = bm.matchid
				INNER HASH JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
				INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
			WHERE b.statusID NOT IN (101,102)--('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 29 AND b.matchID = 29
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
			OPTION(OPTIMIZE FOR (@n = 1))
		END 	
		
		---Licensee
		IF @LicenseeName <> 'Credit' AND @LicenseeName <> 'ALL' 
		BEGIN
			DELETE b
			FROM #SpecialDeleteBets b
			WHERE b.srecommend NOT IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
		END
		---IBC
		IF @LicenseeName= 'Credit'  
		BEGIN	
			DELETE b
			FROM #SpecialDeleteBets b
				LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON b.srecommend = ds.custid
				LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.custid
			WHERE ds.custid IS NOT NULL OR cs.CustId IS NOT NULL
		END 

		IF @SelectionSubParlays <> ''
		BEGIN
			INSERT INTO @tmpSelectionSubParlay (Id)
			SELECT value AS  Id
			FROM STRING_SPLIT(@SelectionSubParlays, ',')
		
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tmpSelectionSubParlay sp 
					WHERE 1 = CASE WHEN sp.Id = '10 UP' AND b.Hdp2 >= 10 THEN 1
								   WHEN sp.Id <> '10 UP' AND b.Hdp2 = CAST (sp.Id AS SMALLMONEY) THEN 1
								   ELSE 0 END)
		END

		IF @BetTeams IS NOT NULL
		BEGIN
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.BetTeam = 'All' OR b.FilterBetTeam = tp.BetTeam ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (CONVERT(NVARCHAR(50),tp.Goal) = 100 OR b.FilterGoal = CONVERT(NVARCHAR(50),tp.Goal) ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))

			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId )) 
	
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))
		END	
	END 

	-- System parlay Virtual Sports 2799
    IF EXISTS(SELECT 1 FROM @tmpBettypes WHERE bettype = 2799)
	BEGIN 
		---ALL
		--IF @LicenseeName= 'ALL'  
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, bettype, BetdaqId, ActualStake, transid,
					hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid, srecommend,
					SubTransID, SubBetType, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubTransDesc)
			SELECT	b.username,
					b.bettype,				
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 and ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	
					b.srecommend,
					bm.transid SubTransID,
					bm.bettype SubBetType,
					CONVERT(float, bm.hdp1) as SubHdp1, 
					CONVERT(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					bm.transdesc SubTransDesc
			FROM (SELECT TOP (@n) matchid from @tmpMatchId) tmp
				INNER JOIN bettransm bm WITH (NOLOCK) ON tmp.MatchId = bm.matchid
				INNER HASH JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
			WHERE b.statusID NOT IN (101,102)--('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 2799 AND b.matchID = 2799
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
			OPTION(OPTIMIZE FOR (@n = 1))
		END 		
		
		---Licensee
		IF @LicenseeName <> 'Credit' AND @LicenseeName <> 'ALL' 
		BEGIN
			DELETE b
			FROM #SpecialDeleteBets b
			WHERE srecommend NOT IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
		END
		---IBC
		IF @LicenseeName= 'Credit'  
		BEGIN	
			DELETE b
			FROM #SpecialDeleteBets b
				LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON b.srecommend = ds.custid
				LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.custid
			WHERE ds.custid IS NOT NULL OR cs.CustId IS NOT NULL
				
		END 
	END 

	UPDATE b
		SET homeid 	= m.homeid
			,awayid 	= m.awayid
			,sporttype 	= m.sporttype
			,ISNeutral = m.isNeutral
			,SubHomeID  = m.homeid
			,SubAwayID 	= m.awayid
			,SubSportType = m.sporttype
			,SubLeagueId = m.leagueid
	FROM #SpecialDeleteBets b
		INNER JOIN #T_Match m WITH (NOLOCK) 
			ON CASE WHEN b.bettype IN (7901) THEN 'match3rd' -- 7901: Bitcoin Over/Under
											ELSE 'match' 
								END = m.matchtype 

	SELECT  username,
			bettype,		
			BetdaqId,
			ActualStake,		
			transid,
			homeid,
			awayid,
			hdp1, 
			hdp2,
			odds,
			oddsspread,
			status,
			stake,
			transdate, 
			betteam,
			betcheck,
			livehomescore, 
			liveawayscore,
			IsLiveIndicator,
			ISNeutral,
			OddsType, 
			CurrencyName,
			winlost,
			betid,
			IsParlay,
			SecAcceptFlag,		
			refno,
			TransDesc,
			SportType,
			MOdds,
			BallSequence,
			WalletType,			
			RefCode,
			SubTransID,
			SubBetType,
			SubHomeID,
			SubAwayID,
			SubHdp1, 
			SubHdp2,
			SubOdds,
			SubStake,
			SubBetTeam, 
			SubBetCheck, 
			SubLiveHomeScore,
			SubLiveAwayScore,
			SubLiveIndicator,
			SubLeagueId,
			SubSportType,          
			SubTransDesc,
			@SettlementStatus AS SettlementStatus,
			IsMarked
	FROM #SpecialDeleteBets
	ORDER BY IsParlay
		   , ISNULL(MainTransId, transid)
		   , CASE WHEN BonusID IS NOT NULL
				THEN CASE WHEN MainTransId IS NULL THEN 1
					ELSE 2 END
				ELSE transid END
	
	
	DROP TABLE #SpecialDeleteBets  
	DROP TABLE #TmpBallSequence  
	DROP TABLE #T_Match
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #tmpSelectionType
	DROP TABLE #tmpAffectTickets
END	 
