/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_Summary] 
	 @MatchId						INT
	,@LicenseeId					INT
	,@BetTypes						VARCHAR(1000)	= ''	
	,@LiveType						SMALLINT 		= 2
	,@LiveHomeScore					SMALLINT 		= NULL
	,@LiveAwayScore					SMALLINT 		= NULL
	,@FromTransdate					DATETIME 		= NULL
	,@ToTransdate					DATETIME 		= NULL
	,@Type							SMALLINT 		= 0
	,@SecondAcceptFlag				TINYINT			= 0
	,@BallSequence					VARCHAR(200)	= ''
	,@Quarter						VARCHAR(200)	= 'All'
	,@BetTeams						XML				= NULL
	,@SingleOrSubParlay				VARCHAR(20)	    = 'All'
	,@SelectionType					VARCHAR(200)    = ''
	,@IsReSettled					BIT				= 0
	,@AffectTickets					XML				= NULL
	,@SelectionSubParlays			VARCHAR(200)    = ''

AS
/*	Created by: 20130606@Elodie
	Task: Show Tickets Listing for NAP system
	DB: DBACC/bodb02
	Original: Acc_Rpt_TicketListing
	
	Revisions:	
		- 20130910@Kathy: Rename parameter @SAFilter to @SecondAcceptFlag
		- 20131129@Kathy: Add HR Fixed Odds (154) [Redmine:#6505]
		- 20131203@Kathy: Add @showtime column.
						Using Dep_CustSuper table instead of f_DepSuper_1() function.
		- 20141021@Kathy: Consolidate Sportting Solution and IBC bettypes [Redmine:#23129]
		- 20150401@Dominic: Add new parent-child bettypes [Redmine:#27214]
		- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:#38200]
		- 20150401@Kathy: Add new parent-child bettypes for PH [Redmine:#48110]
		- 20150119@Kathy: Changes parent-child for phase 1.2 of PH All in One:  [Redmine:#50932]	  
		- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
		- 20170414@Kent: Fix IBC to MBC [Redmine:#75009]
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170718@Paul: Integrate Lucky 3 [Redmine:#77175]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180305@Helen: Betradar VS2 - [Redmine:90153]
		- 20180814@Alan: Rename SP - Filter basketball tickets by quarter [99786]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20181218@Alan: Filter Esports Tickets [106455]
		- 20190408@Jacob: Separate Filter Parlay Ticket by 1H & 2H [107682]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190601@Jacob: Ticket listing cannot show detail Parlay for CN88 [114437]
		- 20190613@Raymond.Le: Allow User to Filter Ticket by Selecting Multiple Maps and Rounds [115074]
		- 20191002@Charles: Replace 'MBC' Licensee by 'Credit' [120586]
		- 20191029@Raymond.Le: Fix Ticket listing search wrong quarter [122834]
		- 20191129@Max: Count Parlay_Wrong Score_Score Info Unmark [Redmine: #124516]
		- 20191202@Raymond.Le: Separate function Group Bettype from Report team [124675]
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

	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports
		3: Live casino
		4: Metric Gaming Super Live (Not used)
		5: Virtual sports betradar
		6: Lucky 3 (Not used)
		7: Bull fighting (Not used)
		8: Bet Builder
		9: Bitcoin

	- @LicenseeID:
	  + =0: No Site filter
	  + >0: Filter by specific Licensee's ID
	  + -1: Filter by IBC sites (Non-Licensee sites)
	- @BetTypes: String of bettype for Sportsbook, Virtual sports and for Dead Ball - Number game, Live casino	 
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

	DECLARE @SportType		SMALLINT = NULL
		   ,@ValueDefault	SMALLMONEY = 9999.00
		   ,@n				INT 
	
	SET @n = 2147483647

	DECLARE @tmpMatchId TABLE (MatchId INT PRIMARY KEY, sporttype SMALLINT)
	INSERT INTO @tmpMatchId (MatchId, sporttype)
	SELECT MatchId, sporttype
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype <> 50 AND matchid = @MatchId THEN 1
					WHEN sporttype = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END
	UNION --Bitcoin
	SELECT match3rdId, sporttype
	FROM dbo.match3rd WITH (NOLOCK)
	WHERE match3rdId = @MatchID

	SELECT @SportType = sporttype FROM @tmpMatchId

	---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
	IF @Type <> 0 SELECT @LiveType = 2

	DECLARE @TmpTotal TABLE (
		OrderNo			INT
		,TotalTrans		BIGINT
		,bettype		SMALLINT
		,LiveIndicator	BIT
		,LicenseeName	VARCHAR(50)
		,IsChinaView	BIT
		)
	DECLARE @tmpBettypes TABLE ( bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpQuarter TABLE (Id VARCHAR(10))
	DECLARE @tmpSelectionSubParlay TABLE (Id VARCHAR(10))

	CREATE TABLE #tmpAffectTickets (Transid BIGINT PRIMARY KEY)

	IF (@IsReSettled = 1 AND @AffectTickets IS NOT NULL)
	BEGIN 
		INSERT INTO #tmpAffectTickets(Transid)
		SELECT t.c.value('@tid','BIGINT') AS Transid
		FROM @AffectTickets.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@AffectTickets = NULL ))
	END

	DECLARE @tmpBettransList TABLE (
		transid				BIGINT --PRIMARY KEY
		,srecommend			INT
		,bettype			SMALLINT
		,liveindicator		BIT
		,statusID			TINYINT
		,matchid			INT	
		,custid				INT
		,RefCode			BIGINT	
		,FilterBettype		SMALLINT
		,FilterBetTeam		NVARCHAR(10)
		,FilterSet			VARCHAR(50)
		,FilterGame			VARCHAR(50)
		,FilterValue		SMALLMONEY	
		,FilterGoal			BIGINT
		,FilterBetOption	NVARCHAR(50)
		,FilterHdp1			SMALLMONEY
        ,FilterHdp2			SMALLMONEY
		,FilterOddsSpread	 MONEY
		,FilterOddsId		INT
		,FilterTransdesc	NVARCHAR(2000)
	)

	CREATE TABLE #TmpBettrans (
		srecommend		INT
		,bettype		SMALLINT
		,liveindicator	BIT
		,statusID		TINYINT
		,matchid		INT
		,cnt			INT
		)
		
	CREATE TABLE #TmpBallSequence (Seq TINYINT)

	DECLARE @tmpConsolidatedBettypes TABLE (parentid INT, typeid INT)
		
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
	
	INSERT INTO @tmpBettypes (bettype)
	SELECT	CONVERT(smallint, value)
	FROM STRING_SPLIT(@BetTypes, ',')

	IF (@Quarter <> 'All')
	BEGIN
		INSERT INTO @tmpQuarter (Id)
		SELECT value
		FROM STRING_SPLIT(@Quarter, ',')
	END	
	
	-- filter bettype detail
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

	CREATE TABLE #CTE_ParlayTickets (
		ParentTransId		BIGINT
		,ParentBettype		SMALLINT
		,mLiveIndicator		BIT
		,Refno				BIGINT
		,FilterBettype		SMALLINT
		,FilterBetTeam		NVARCHAR(10)
		,FilterSet			VARCHAR(50)
		,FilterGame			VARCHAR(50)
		,FilterValue		SMALLMONEY	
		,FilterGoal			NVARCHAR(50)
		,FilterBetOption	NVARCHAR(50)
		,FilterHdp1			SMALLMONEY
		,FilterHdp2			SMALLMONEY
		,FilterOddsSpread	MONEY
		,FilterOddsId		INT
		,FilterTransdesc	NVARCHAR(2000)
		,srecommend			INT
		,ParentHdp2			SMALLMONEY --selection parlay
	) 

	CREATE TABLE #CTE_ParlayVSTickets (
		TransId				BIGINT
		,Bettype			SMALLINT
		,srecommend			INT
		,mLiveIndicator		BIT
		,Refno				BIGINT
	) 

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
			, cte.BetTeam
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
				, CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN @ValueDefault
						ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
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
				CROSS APPLY STRING_SPLIT(cte.OddsId, ',') osid
				CROSS APPLY STRING_SPLIT(cte.Transdesc, ',') td
	) cte

	INSERT INTO @tmpConsolidatedBettypes
	SELECT f.GroupTypeId AS parentid
		 , f.Bettype AS typeid
    FROM [dbo].[f_SD_GroupDisplayBettype] () f

	IF @Type = 1 -- FOR Happy 5, Number Game Only
	BEGIN
		INSERT INTO #TmpBallSequence(Seq)
		SELECT  value
		FROM STRING_SPLIT(@BallSequence, ',')
	
		INSERT INTO #TmpBettrans (srecommend,bettype,liveindicator,statusID,matchid,cnt)
		SELECT b.srecommend
			,b.bettype
			,b.liveindicator
			,b.statusID
			,b.matchid
			,COUNT(b.transid) cnt
		FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				OUTER APPLY (SELECT BallSequence 
						FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
						WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
						) AS BS_tmp		
		WHERE b.matchid IN (SELECT MatchId FROM @tmpMatchId)
			AND statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')					
			AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
																  WHEN 1 THEN 0
																  WHEN 2 THEN 1 END
			AND 1 = CASE WHEN  @SportType = 164 THEN 1 --Happy 5
						 WHEN  @SportType <> 164 AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WHERE Seq = BS_tmp.BallSequence) THEN 1 --Number Game
						 ELSE 0 END
		GROUP BY b.srecommend
			,b.matchid
			,b.bettype
			,b.liveindicator
			,b.statusid		
		OPTION (RECOMPILE)	
	END
	ELSE -- For Others
	BEGIN
		INSERT INTO @TmpBettransList (transid, srecommend, bettype, liveindicator, statusID, matchid, custid, RefCode,
			FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc)
		SELECT transid 
			,srecommend
			,b.bettype
			,liveindicator
			,statusID
			,matchid
			,custid
			,RefCode
			,b.bettype AS FilterBetType
			,b.betteam AS FilterBetTeam
			,b.betid AS FilterSet
			,RIGHT(b.betid, 2) AS FilterGame
			,b.hdp1 + b.hdp2 AS FilterValue
			,ISNULL(b.betid, 0) AS FilterGoal
			,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
			,b.hdp1 AS FilterHdp1
			,b.hdp2 AS FilterHdp2
			,b.oddsspread AS FilterOddsSpread
			,b.oddsid AS FilterOddsId
			,b.transdesc AS FilterTransdesc
		FROM bettrans b WITH (NOLOCK)
		WHERE matchid IN (SELECT MatchId FROM @tmpMatchId)
			AND statusID NOT IN (101, 102, 121) --('Void', 'Reject', 'Dummy')
			AND EXISTS (SELECT TOP 1 1 FROM @tmpBettypes t WHERE t.bettype = b.bettype)
			AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE livehomescore END
			AND liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE liveawayscore END
			AND transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE transdate END
							AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE transdate END					
			AND ISNULL(SecAcceptFlag, 0) = CASE @SecondAcceptFlag
				WHEN 0 THEN ISNULL(SecAcceptFlag, 0)
				WHEN 1 THEN 0
				WHEN 2 THEN 1 END
				AND (@Quarter = 'All' 
					OR (b.bettype NOT BETWEEN 609 AND 617 AND b.bettype NOT BETWEEN 627 AND 631 AND b.bettype NOT BETWEEN 707 AND 714 AND b.bettype NOT BETWEEN 381 AND 385) 
					OR ((b.bettype BETWEEN 609 AND 617 OR b.bettype BETWEEN 627 AND 631 OR b.bettype BETWEEN 707 AND 714 OR b.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q WHERE b.betid LIKE q.Id + '%')))

		IF (@IsReSettled = 1 AND @SportType = 1)
		BEGIN
			DELETE b
			FROM @TmpBettransList b
			WHERE NOT EXISTS ( SELECT TOP 1 1 FROM #tmpAffectTickets t WHERE b.transid=t.Transid)
		END

		IF (@BetTypes = '38' AND @SelectionType <>'')
		BEGIN
			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS ( SELECT TOP 1 1 FROM @tmpTransid t WHERE b.transid=t.Transid)
		END
		
		IF @SportType IN (43,50,5,6) -- E-Sports, Cricket, Tennis, Volleyball
		BEGIN
			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.BetTeam = 'All' OR b.FilterBetTeam = tp.BetTeam ))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%'  ))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.Game = 'All' OR (tp.Game LIKE '>%' AND b.FilterGame > RIGHT(tp.Game, 2)) OR (b.FilterGame = tp.Game)))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ))
			
			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				 WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))
		
			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId )) 
	
			DELETE b
			FROM  @TmpBettransList b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
				WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))
		
		END

		INSERT INTO #TmpBettrans
		SELECT srecommend
			,bettype
			,liveindicator
			,statusID
			,matchid
			,COUNT(transid) cnt
		FROM @TmpBettransList tmp	
		GROUP BY srecommend
			,matchid
			,bettype
			,liveindicator
			,statusid	
	END

	-- System parlay - Sportsbook 29
	IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'SubParlay'
	BEGIN
		INSERT INTO #CTE_ParlayTickets (
				ParentTransId
				,ParentBettype
				,mLiveIndicator
				,Refno
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
				,srecommend
				,ParentHdp2
			)
		SELECT   b.transid
				,b.bettype
				,bm.liveIndicator
				,b.refno
				,bm.bettype AS FilterBetType
				,bm.betteam AS FilterBetTeam
				,bm.betcheck AS FilterSet
				,RIGHT(bm.betcheck, 2) AS FilterGame
				,bm.hdp1 + bm.hdp2 AS FilterValue
				,ISNULL(bm.betcheck, 0) AS FilterGoal
				,CAST(CAST(bm.hdp2 AS INT) AS VARCHAR(50)) + '-' + bm.betteam AS FilterBetOption
				,bm.hdp1 AS FilterHdp1
				,bm.hdp2 AS FilterHdp2
				,bm.oddsspread AS FilterOddsSpread
				,bm.oddsid AS FilterOddsId
				,bm.transdesc AS FilterTransdesc
				,b.srecommend
				,b.hdp2 AS ParentHdp2
		FROM (SELECT TOP (@n) matchid from @tmpMatchId) tmp
			INNER JOIN bettransm bm WITH (NOLOCK) ON tmp.MatchId = bm.matchid
			INNER HASH JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
			INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
		WHERE b.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND b.bettype = 29
			AND b.matchid = 29
			AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
			AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END
							AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
			AND ISNULL(b.SecAcceptFlag, 0) = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag, 0)
																	WHEN 1 THEN 0
																	WHEN 2 THEN 1 END
			AND (b.betid = 0 OR b.betid IS NULL )
			AND (@Quarter = 'All' 
				OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
				OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q WHERE bm.betcheck LIKE q.Id + '%')))			
		OPTION(OPTIMIZE FOR (@n = 1))

		IF @SelectionSubParlays <> ''
		BEGIN
			INSERT INTO @tmpSelectionSubParlay (Id)
			SELECT value AS  Id
			FROM STRING_SPLIT(@SelectionSubParlays, ',')
		
			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tmpSelectionSubParlay sp 
					WHERE 1 = CASE WHEN sp.Id = '10 UP' AND t.ParentHdp2 >= 10 THEN 1
								   WHEN sp.Id <> '10 UP' AND t.ParentHdp2 = CAST (sp.Id AS SMALLMONEY) THEN 1
								   ELSE 0 END)
		END
		
		IF @SportType IN (43,50,5,6) -- E-Sports, Cricket, Tennis, Volleyball
		BEGIN
			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd 
					WHERE bd.Id = t.FilterBettype AND (bd.BetTeam = 'All' OR t.FilterBetTeam = bd.BetTeam ))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.[Set] = 'All' OR t.FilterSet LIKE bd.[Set] + '%'  ))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.Game = 'All' OR (bd.Game LIKE '>%' AND t.FilterGame > RIGHT(bd.Game, 2)) OR (t.FilterGame = bd.Game)))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.[Value] = 9999 OR t.FilterValue = bd.[Value] ))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (CONVERT(NVARCHAR(50), bd.Goal) = 100 OR t.FilterGoal = CONVERT(NVARCHAR(50), bd.Goal) ))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.BetOption = 'All' OR t.FilterBetOption = bd.BetOption )) -- filter Map X Round Y
			
			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.ValueHdp1 = 9999 OR t.FilterHdp1 = bd.ValueHdp1 ))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.ValueHdp2 = 9999 OR t.FilterHdp2 = bd.ValueHdp2 ))

			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.OddsSpread = 9999 OR t.FilterOddsSpread = bd.OddsSpread ))
		
			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.OddsId IS NULL OR t.FilterOddsId = bd.OddsId ))
	
			DELETE t
			FROM  #CTE_ParlayTickets t
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail bd
					WHERE bd.Id = t.FilterBettype AND (bd.Transdesc IS NULL OR t.FilterTransdesc = bd.Transdesc ))
		END
	END
	
	-- System parlay - Virtual Sports 2799 -- NOTE: 2799 don't have filter Advance Mode 
	IF CHARINDEX('2799', @BetTypes, 1) <> 0
	BEGIN
		INSERT INTO #CTE_ParlayVSTickets(
				TransId
				,Bettype
				,srecommend
				,mLiveIndicator		
				,Refno				
			)
		SELECT b.TransId
			 , b.bettype
			 , b.srecommend
			 , bm.liveindicator AS mLiveIndicator
			 , b.refno
		FROM (SELECT TOP (@n) matchid from @tmpMatchId) tmp
			INNER JOIN bettransm bm WITH (NOLOCK) ON tmp.MatchId = bm.matchid
			INNER HASH JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
		WHERE b.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND b.bettype = 2799
			AND b.matchid = 2799
			AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
			AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END
							AND CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
			AND ISNULL(b.SecAcceptFlag, 0) = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag, 0)
																	WHEN 1 THEN 0
																	WHEN 2 THEN 1 END
			AND (b.betid = 0 OR b.betid IS NULL )
			AND (@Quarter = 'All' 
				OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
				OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q WHERE bm.betcheck LIKE q.Id + '%')))
		OPTION(OPTIMIZE FOR (@n = 1))
	END
	
	----## Direct Licensee
	IF @LicenseeID > 0
	BEGIN
		DECLARE @LicenseeName VARCHAR(100) = '', @IsChinaView BIT

		SELECT @LicenseeName = site, @IsChinaView = ISNULL(IsChinaView,0)
		FROM site WITH (NOLOCK)
		WHERE isLicensee = 1
			AND isActive = 1
			AND siteID NOT IN (29, 35)
			AND siteID = @LicenseeID

		IF (@SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single') 
		BEGIN
		  INSERT INTO @TmpTotal (
			 OrderNo
			 ,TotalTrans
			 ,bettype
			 ,LiveIndicator
			 ,LicenseeName
			 ,IsChinaView
			 )
		    SELECT 1 AS OrderNo
				,SUM(cnt) AS TotalTrans
				,bettype
				,CASE WHEN @type = 1 THEN liveindicator ELSE 0 END --- because liveindicator only use for indicate live or dead ball of number game. So the sportsbook don't care.
				,@LicenseeName AS LicenseeName
				,@IsChinaView AS IsChinaView
		    FROM #TmpBettrans WITH (NOLOCK)
		    WHERE srecommend IN ( SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) WHERE site = @LicenseeName )
		    GROUP BY bettype, LiveIndicator
		END

		-- System parlay - Sportsbook 29
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_ParlayTickets)
		BEGIN
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				,IsChinaView
				)
			SELECT 1 AS OrderNo
				,COUNT(t.ParentTransId) AS TotalTrans
				,t.ParentBettype
				,0
				,@LicenseeName AS LicenseeName
				,@IsChinaView AS IsChinaView
			FROM #CTE_ParlayTickets AS t
			WHERE t.srecommend IN ( SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) WHERE site = @LicenseeName )
			GROUP BY t.ParentBettype
				,t.mLiveIndicator
			HAVING COUNT(t.Refno) > 0
		  END

		-- System parlay - Virtual Sports 2799 -- NOTE: 2799 don't have filter Advance Mode 
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_ParlayVSTickets)
		BEGIN
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				,IsChinaView
				)
			SELECT 1 AS OrderNo
				,COUNT(b.transid) AS TotalTrans
				,b.bettype
				,0
				,@LicenseeName AS LicenseeName
				,@IsChinaView AS IsChinaView
			FROM #CTE_ParlayVSTickets b
			WHERE b.srecommend IN ( SELECT custid FROM dbo.Dep_CustSuper WITH (NOLOCK) WHERE site = @LicenseeName)
			GROUP BY b.bettype
				,b.mLiveIndicator
			HAVING COUNT(b.Refno) > 0
		  END
	END

	----## Credit Group
	IF @LicenseeID = - 1
	BEGIN
		  IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single' 
		  BEGIN		
			 INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				,IsChinaView
				)
			 SELECT 0 AS OrderNo
				,SUM(cnt) AS TotalTrans
				,bettype
				,CASE WHEN @type = 1 THEN b.liveindicator ELSE 0 END
				,'Credit' AS LicenseeName
				,0 
			FROM #TmpBettrans b 
			LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON b.srecommend = ds.custid
			LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.custid
			WHERE ds.custid IS NULL AND cs.CustId IS NULL
			 GROUP BY b.bettype
				,b.liveindicator
		  END
		
		  -- System parlay - Sportsbook 29
		  IF EXISTS (SELECT TOP 1 1 FROM #CTE_ParlayTickets)
		  BEGIN
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				,IsChinaView
				)
			SELECT 0 AS OrderNo
				,COUNT(DISTINCT t.ParentTransId) AS TotalTrans
				,t.ParentBettype
				,0
				,'Credit' AS LicenseeName
				,0
			FROM #CTE_ParlayTickets AS t
			LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON t.srecommend = ds.custid
			LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON t.srecommend = cs.custid
			WHERE ds.custid IS NULL AND cs.CustId IS NULL
			GROUP BY t.ParentBettype
				,t.mLiveIndicator
			HAVING COUNT(t.Refno) > 0
		  END

		  -- System parlay - Virtual Sports 2799 -- NOTE: 2799 don't have filter Advance Mode 
	      IF EXISTS (SELECT TOP 1 1 FROM #CTE_ParlayVSTickets)
		  BEGIN
			INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				,IsChinaView
				)
			SELECT 0 AS OrderNo
				,COUNT(DISTINCT b.transid) AS TotalTrans
				,b.bettype
				,0
				,'Credit' AS LicenseeName
				,0
			FROM #CTE_ParlayVSTickets b
				LEFT JOIN dbo.Dep_CustSuper ds WITH (NOLOCK) ON b.srecommend = ds.custid
				LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.custid
			WHERE ds.custid IS NULL AND cs.CustId IS NULL
			GROUP BY b.bettype
				,b.mLiveIndicator
			HAVING COUNT(B.Refno) > 0
		  END
	END

	-----## All 
	IF @LicenseeID = 0
	BEGIN
	   IF (@SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single') AND @BetTypes <> '2799'
	   BEGIN
		  INSERT INTO @TmpTotal (
				OrderNo
				,TotalTrans
				,bettype
				,LiveIndicator
				,LicenseeName
				,IsChinaView
				)
		  SELECT CASE WHEN s.site IS NULL AND cs.CustId IS NULL THEN 0
					  WHEN s.site IS NOT NULL AND ISNULL(s.IsChinaView,0) = 1 THEN 2
					  ELSE 1 END
				,SUM(cnt) AS TotalTrans
				,bettype
				,CASE WHEN @type = 1 THEN b.liveindicator ELSE 0 END
			 ,CASE WHEN s.site IS NULL AND cs.CustId IS NULL THEN 'Credit' ELSE s.site END AS LicenseeName
			 ,ISNULL(s.IsChinaView,0) AS IsChinaView
		  FROM #TmpBettrans b WITH (NOLOCK)
			 LEFT JOIN Customer c WITH (NOLOCK) ON b.srecommend = c.custid
			 LEFT JOIN site s WITH (NOLOCK) ON s.site = c.Site AND s.isLicensee = 1 AND s.isActive = 1 AND s.siteID NOT IN (29, 35)
			 LEFT JOIN CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.CustId
		  GROUP BY b.bettype
			 ,b.liveindicator
			 ,s.site, s.IsChinaView
			 ,cs.CustId
	   END
	   
	   -- System parlay - Sportsbook 29
	   IF EXISTS (SELECT TOP 1 1 FROM #CTE_ParlayTickets)
	   BEGIN
			INSERT INTO @TmpTotal (
				 OrderNo
				 ,TotalTrans
				 ,bettype
				 ,LiveIndicator
				 ,LicenseeName
				 ,IsChinaView
				 )
			SELECT  CASE WHEN s.site IS NULL AND cs.CustId IS NULL THEN 0
						WHEN s.site IS NOT NULL AND IsChinaView = 1 THEN 2
						ELSE 1 END
			,COUNT(DISTINCT t.ParentTransId) AS TotalTrans
			,t.ParentBettype
			,0
			,CASE WHEN s.site IS NULL AND cs.CustId IS NULL THEN 'Credit' ELSE s.site END AS LicenseeName
			,ISNULL(s.IsChinaView,0)
			FROM #CTE_ParlayTickets AS t
				LEFT JOIN Customer c WITH (NOLOCK) ON t.srecommend = c.custid
				LEFT JOIN site s WITH (NOLOCK) ON s.site = c.Site AND s.isLicensee = 1 AND s.isActive = 1 AND s.siteID NOT IN (29, 35)
				LEFT JOIN CS_CustSuper cs WITH (NOLOCK) ON t.srecommend = cs.CustId
			GROUP BY s.Site, s.IsChinaView
				,t.mLiveIndicator
				,t.ParentBettype
				,cs.CustId
	   END

	   -- System parlay - Virtual Sports 2799 -- NOTE: 2799 don't have filter Advance Mode 
	   IF EXISTS (SELECT TOP 1 1 FROM #CTE_ParlayVSTickets)
	   BEGIN
		  INSERT INTO @TmpTotal (
			 OrderNo
			 ,TotalTrans
			 ,bettype
			 ,LiveIndicator
			 ,LicenseeName
			 ,IsChinaView
			 )
		  SELECT CASE WHEN s.site IS NULL AND cs.CustId IS NULL THEN 0
					  WHEN s.site IS NOT NULL AND ISNULL(s.IsChinaView,0) = 1 THEN 2
					  ELSE 1 END
			 ,COUNT(DISTINCT b.transid) AS TotalTrans
			 ,b.bettype
			 ,0
			 ,CASE WHEN s.site IS NULL AND cs.CustId IS NULL THEN 'Credit' ELSE s.site END AS LicenseeName
			 ,ISNULL(s.IsChinaView,0)
		  FROM #CTE_ParlayVSTickets b
			 LEFT JOIN Customer c WITH (NOLOCK) ON b.srecommend = c.custid
			 LEFT JOIN site s WITH (NOLOCK) ON s.site = c.Site AND s.isLicensee = 1 AND s.isActive = 1 AND s.siteID NOT IN (29, 35)
			 LEFT JOIN CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.CustId
		  GROUP BY s.site, s.IsChinaView
			 ,b.mLiveIndicator
			 ,b.bettype
			 ,cs.CustId
	   END
	END

	UPDATE t
	SET t.bettype = c.parentid
	FROM @TmpTotal t
		LEFT JOIN @tmpConsolidatedBettypes c ON c.typeid = t.bettype
	WHERE c.parentid IS NOT NULL

	SELECT SUM(TotalTrans) TotalTrans
		,OrderNo
		,bettype AS 'bettypeId'
		,LiveIndicator
		,LicenseeName
		,IsChinaView
	FROM @TmpTotal
	GROUP BY OrderNo
		,LicenseeName
		,bettype
		,LiveIndicator
		,IsChinaView
	ORDER BY OrderNo
		,LicenseeName
		,bettype
		,LiveIndicator
		,IsChinaView

	DROP TABLE #TmpBettrans
	DROP TABLE #TmpBallSequence
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #tmpSelectionType
	DROP TABLE #tmpAffectTickets
	DROP TABLE #CTE_ParlayTickets
	DROP TABLE #CTE_ParlayVSTickets
END
