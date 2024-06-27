/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_ExcelOic]
	@MatchId					INT,
	@LicenseeName				VARCHAR(MAX)	= 'ALL',
	@BetTypes					VARCHAR(1000)	= '',	
	@LiveType					SMALLINT		= 2,	
	@LiveHomeScore				SMALLINT		= NULL,
    @LiveAwayScore				SMALLINT		= NULL,
    @FromTransdate				Datetime		= NULL,
	@ToTransdate				Datetime		= NULL,
	@Type						SMALLINT		= 0,
    @SecondAcceptFlag			tinyint			= 0,
    @BallSequence				VARCHAR(200)	= '',
	@BetTeams					XML				= NULL,
	@SingleOrSubParlay			VARCHAR(20)	    = 'All',
	@SelectionType				VARCHAR(200)	= '',
	@IsReSettled				BIT				= 0,
	@AffectTickets				XML				= NULL,
	@SelectionSubParlays		VARCHAR(200)    = ''

AS
/*	Created by: 20171106@Kent
	Task: Show Tickets Listing Detail and Export to excel for NAP system
	DB: DBACC/bodb02
	Original: 

	Revisions:			
		- 20171106@Kent: Implement Notifications Center [Redmine:#84330] 
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20180201@Helen: Change way to get Ball Sequence [Redmine:#90434 ]
		- 20180409@Alan: Add new column Username2 - Remove Licensee = 'All', 'MBC' [Redmine:#93167]
		- 20180814@Alan: Filter basketball tickets by quarter - Remove #CustIDs [99786]
		- 20181122@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20181218@Alan: Filter Esports Tickets [106455]
		- 20190408@Jacob: Separate Filter Parlay Ticket by 1H & 2H [107682]
		- 20190613@Raymond.Le: Allow User to Filter Ticket by Selecting Multiple Maps and Rounds [115074]
		- 20191029@Raymond.Le: Fix Ticket listing search wrong quarter [122834]
		- 20191216@Max: Count Parlay_Wrong Score_Score Info Unmark [Redmine: #124516]
		- 20191226@Max: Phase 5 on Special Delete Site [Redmine: #126084]
		- 20200727@Zane: Basketball AIO Phase 2 - Change filter advanced mode for new bettypes [137189]
		- 20200812@Charles: Implement Next R/B bet type for NG Color Ball - [128215]
		- 20200817@July: Ticket Listing - Bet Builder Enhancement [Redmine: #138555]
		- 20200911@Max: Tuning SP [Redmine: 141476]
		- 20200923@July: TVS - Resettled Affected Tickets [Redmine: #138552]
		- 20201202@Max: Tuning SP [Redmine: #146485]
		- 20210423@July: TVS - Enhance Ticket Listing for Cricket [Redmine: #153930]
		- 20210517@July: Enhance performance of Ticket Listing function [Redmine: #154732]
		- 20211122@July: SD - Send data to OIC instead of file [Redmine: #159115]
		- 20220303@July: Integrate Cricket AIO Phase 2 [Redmine:#168080]
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
		- 20240129@July: Update the Advance Mode for bet types of Basketball [Redmine: #199605]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240312@July: Update the Advance Mode for bet types of Cricket [Redmine: #199238]
		- 20240614@Max: [TVS] Ticket Listing - Insert data to DB053 [Redmine: #206452]
		- 20240626@Max: [TVS] Ticket Listing - Adjust code Send Data to OIC [Redmine: #207035]

	Param's Explanation:
	- @Type: sports type
		0: Sportsbook

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
					VirtualHead ="1"		-- Default : "All" ; Format : Single Number
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

	DECLARE @p_bettypes				VARCHAR(1000)
		   ,@ValueDefault			SMALLMONEY = 9999.00
		   ,@SportType				SMALLINT = NULL
		   ,@TransInfoSendOICJson	VARBINARY(MAX)
		   ,@n						INT

	SET @p_bettypes = @BetTypes
	SET @n = 2147483647

	DECLARE @tmpBettypes TABLE ( bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpMatchId TABLE (MatchId INT PRIMARY KEY, sporttype SMALLINT)
	DECLARE @tmpSelectionSubParlay TABLE (Id VARCHAR(10))
	DECLARE @tmpLicenseeName TABLE (LicenseeName NVARCHAR(50), SessionId NVARCHAR(100))
	
	INSERT INTO @tmpMatchId (MatchId, sporttype)
	SELECT MatchId, sporttype
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype <> 50 AND matchid = @MatchId THEN 1
					WHEN sporttype = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END

	SELECT @SportType = sporttype FROM @tmpMatchId

	INSERT INTO @tmpBettypes (bettype)
	SELECT	CONVERT(smallint, value)
	FROM STRING_SPLIT(@p_bettypes, ',')

	IF @LicenseeName <> 'All'
	BEGIN
		INSERT INTO @tmpLicenseeName (LicenseeName, SessionId)
		SELECT DISTINCT value, NEWID()
		FROM STRING_SPLIT(@LicenseeName, ',')
	END

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

	CREATE TABLE #tmpAffectTickets (Transid BIGINT PRIMARY KEY)

	IF (@IsReSettled = 1 AND @AffectTickets IS NOT NULL)
	BEGIN 
		INSERT INTO #tmpAffectTickets(Transid)
		SELECT t.c.value('@tid','BIGINT') AS Transid
		FROM @AffectTickets.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@AffectTickets = NULL ))
	END
	---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
	IF @Type <> 0 SELECT @LiveType = 2

	CREATE TABLE #SpecialDeleteBets 
	(
		transid				BIGINT,
		CustId				INT,
		ParentHdp2	        SMALLMONEY,
		Recommend			INT,
		LicenseeName		NVARCHAR(50),
		FilterBettype		SMALLINT,
		FilterBetTeam		NVARCHAR(10), 
		FilterSet			VARCHAR(50),
		FilterGame			VARCHAR(50),
		FilterValue			SMALLMONEY,	
		FilterGoal			NVARCHAR(50),
		FilterBetOption		NVARCHAR(50),
		FilterHdp1	        SMALLMONEY,
		FilterHdp2	        SMALLMONEY,
		FilterOddsSpread    MONEY,
	    FilterOddsId		INT,
		FilterTransdesc	    NVARCHAR(2000)
	)

	CREATE TABLE #TmpBallSequence (Seq TINYINT)

	INSERT INTO #TmpBallSequence(Seq)
	SELECT  value
	FROM STRING_SPLIT(@BallSequence, ',')

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

	-- Parse xml @BetTeams
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc, VirtualHead)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam			-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(500)') AS [Set]					-- check columns : betid		 ; single-choice + multi-choice
			, t.c.value('@Game','VARCHAR(500)') AS Game					-- check columns : betid		 ; single-choice + multi-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption		-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]				-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1		-- check columns : hdp1			 ; single-choice + multi-choice
			, t.c.value('@ValueHdp2','VARCHAR(500)') AS ValueHdp2		-- check columns : hdp2			 ; single-choice + multi-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal					-- check columns : betID		 ; single-choice + multi-choice
			, t.c.value('@OddsSpread', 'VARCHAR(500)') AS OddsSpread	-- Check columns : OddsSpread	 ; single-choice + multi-choice
			, t.c.value('@OddsId','VARCHAR(1000)') AS OddsId			-- check columns : OddsId		 ; single-choice + multi-choice
			, t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc		-- check columns : Transdesc	 ; single-choice + multi-choice
			, t.c.value('@VirtualHead','NVARCHAR(500)') AS VirtualHead	-- check columns : hdp1 OR hdp2	 ; single-choice
	FROM @BetTeams.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTeams = NULL))
	 
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

	BEGIN
		IF @Type = 1 -- FOR Happy 5, Number Game Only
		BEGIN
			INSERT INTO #SpecialDeleteBets (transid, CustId, Recommend, LicenseeName)
			SELECT	b.transid,
					b.custid,
					b.recommend,
					s.LicenseeName
			FROM	dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				INNER JOIN dbo.Dep_CustSuper dc WITH (NOLOCK) ON b.srecommend = dc.custid
				INNER JOIN @tmpLicenseeName s ON dc.site = s.LicenseeName
				OUTER APPLY (SELECT BallSequence 
							FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore )
							WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
							) AS BS_tmp
			WHERE	b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
					AND b.matchid IN (SELECT MatchId FROM @tmpMatchId)
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					AND 1 = CASE WHEN  @SportType = 164 THEN 1 --Happy 5
								 WHEN  @SportType <> 164 AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WHERE Seq = BS_tmp.BallSequence) THEN 1 --Number Game
								 ELSE 0 END
				OPTION	(RECOMPILE)	
		END
		ELSE IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single'
		BEGIN
			INSERT INTO #SpecialDeleteBets (transid, CustId, Recommend, LicenseeName
											, FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc)
			SELECT	 b.transid
					,b.custid
					,b.recommend
					,s.LicenseeName
					,b.bettype AS FilterBetType
					,b.betteam AS FilterBetTeam
					,b.betid AS FilterSet
					,RIGHT(b.betid, 2) AS FilterGame
					,b.hdp1 + b.hdp2 AS FilterValue
					,ISNULL(CONVERT(NVARCHAR(50),b.betid), 0) AS FilterGoal
					,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
					,b.hdp1 AS FilterHdp1
					,b.hdp2 AS FilterHdp2
					,b.oddsspread AS FilterOddsSpread
					,b.oddsid AS FilterOddsId
					,b.transdesc AS FilterTransdesc
			FROM	dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				INNER JOIN dbo.Dep_CustSuper dc WITH (NOLOCK) ON b.srecommend = dc.custid
				INNER JOIN @tmpLicenseeName s ON dc.site = s.LicenseeName
			WHERE	b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
				AND b.matchid IN (SELECT MatchId FROM @tmpMatchId)
				AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
				AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
				AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
							AND	   CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END
				AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				
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

				IF @SportType NOT IN (50) --NOT Cricket
				BEGIN
					DELETE b
					FROM  #SpecialDeleteBets b
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
						WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

					DELETE b
					FROM  #SpecialDeleteBets b
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
						WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

					DELETE b
					FROM  #SpecialDeleteBets b
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
					FROM  #SpecialDeleteBets b
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
					FROM  #SpecialDeleteBets b
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
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ))

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
	END

	-- System parlay - Sportsbook 29
    IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'SubParlay'
	BEGIN
		INSERT INTO #SpecialDeleteBets (transid, CustId, ParentHdp2, Recommend, LicenseeName
										, FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc
										)
		SELECT	b.transid,
				b.custid,
				b.hdp2 AS ParentHdp2,
				b.recommend,
				s.LicenseeName,
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
			INNER JOIN dbo.Dep_CustSuper dc WITH (NOLOCK) ON b.srecommend = dc.custid
			INNER JOIN @tmpLicenseeName s ON dc.site = s.LicenseeName
		WHERE b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
			AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND b.bettype = 29
			AND b.matchid = 29
			AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
			AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
								AND	  CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
			AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
			AND (b.betid = 0 OR b.betid IS NULL)
		OPTION(OPTIMIZE FOR (@n = 1))

		IF @SelectionSubParlays <> ''
		BEGIN
			INSERT INTO @tmpSelectionSubParlay (Id)
			SELECT value AS  Id
			FROM STRING_SPLIT(@SelectionSubParlays, ',')
		
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tmpSelectionSubParlay sp 
					WHERE 1 = CASE WHEN sp.Id = '10 UP' AND b.ParentHdp2 >= 10 THEN 1
								   WHEN sp.Id <> '10 UP' AND b.ParentHdp2 = CAST (sp.Id AS SMALLMONEY) THEN 1
								   ELSE 0 END)
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

			IF @SportType NOT IN (50) --NOT Cricket
			BEGIN
				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.[Value] = 9999 OR b.FilterValue = tp.[Value] ))

				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

				DELETE b
				FROM  #SpecialDeleteBets b
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
				FROM  #SpecialDeleteBets b
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
				FROM  #SpecialDeleteBets b
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

    -- System parlay Virtual Sports
    IF EXISTS(SELECT 1 FROM @tmpBettypes WHERE bettype IN (2799, 10449))
	BEGIN
		INSERT INTO #SpecialDeleteBets (transid, CustId, Recommend, LicenseeName)	
		SELECT	b.transid,
				b.custid,
				s.LicenseeName,
				b.recommend
		FROM (SELECT TOP (@n) matchid from @tmpMatchId) tmp
			INNER JOIN bettransm bm WITH (NOLOCK) ON tmp.MatchId = bm.matchid
			INNER HASH JOIN Bettrans b WITH (NOLOCK) ON bm.refno = b.refno
			INNER JOIN dbo.Dep_CustSuper dc WITH (NOLOCK) ON b.srecommend = dc.custid
			INNER JOIN @tmpLicenseeName s ON dc.site = s.LicenseeName
		WHERE b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
			AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND b.bettype IN (2799, 10449)
			AND b.matchid IN (2799, 10449)
			AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
			AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
								AND	  CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
			AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
			AND (b.betid = 0 OR b.betid IS NULL)
		OPTION(OPTIMIZE FOR (@n = 1))
	END

	--RETURN DATA
	SET @TransInfoSendOICJson = COMPRESS((SELECT TransId AS 't'
		,CustId 'c'
		,Recommend AS 're'
		,s.LicenseeName AS 'ln'
		,l.SessionId AS 'ssid'
	FROM #SpecialDeleteBets s
		INNER JOIN @tmpLicenseeName l ON l.LicenseeName = s.LicenseeName
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoSendOICJson, 1) AS TransInfoSendOICJson

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TmpBallSequence	
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #tmpSelectionType
	DROP TABLE #tmpAffectTickets
END
