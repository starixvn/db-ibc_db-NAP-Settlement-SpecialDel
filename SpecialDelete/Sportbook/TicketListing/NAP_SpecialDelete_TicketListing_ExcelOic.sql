/*<info serverAlias="DBBAH-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_ExcelOic]
	@MatchId					INT,
	@LicenseeName				VARCHAR(1000)	= 'ALL',
	@BetTypes					VARCHAR(1000)	= '',	
	@LiveType					SMALLINT		= 2,	
	@LiveHomeScore				SMALLINT		= NULL,
    @LiveAwayScore				SMALLINT		= NULL,
    @FromTransdate				Datetime		= NULL,
	@ToTransdate				Datetime		= NULL,
	@Type						SMALLINT		= 0,
    @SecondAcceptFlag			tinyint			= 0,
    @BallSequence				VARCHAR(200)	= '',
	@Quarter					VARCHAR(200)	= 'All',
	@BetTeams					XML				= NULL,
	@SingleOrSubParlay			VARCHAR(20)	    = 'All',
	@SelectionType				VARCHAR(200)	= '',
	@IsReSettled				BIT				= 0

AS
/*	Created by: Kent
	Date: 20171106
	Task: Show Tickets Listing Detail and Export to excel for NAP system
	DB: DBBAH/bodb02
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

	Param's Explanation:
	- @Type: sports type
		0: Sportsbook
		1: Number Game
		2: Virtual sports		
		4: MG
		5: Virtual sports betradar
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
     
   Example:    exec NAP_SpecialDelete_TicketListing_ExcelOic @MatchId=4626986,@LicenseeName='IBC',@BetTypes='1101,1102',@BetTypesLive='',@LiveType=0,@LiveHomeScore=default,@LiveAwayScore=default,@FromTransdate=default,@ToTransdate=default,@Type=2,@SecondAcceptFlag=0
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @p_bettypes VARCHAR(1000)
		   ,@ValueDefault SMALLMONEY = 9999.00

	SET @p_bettypes = @BetTypes

	DECLARE @tmpBettypes TABLE ( bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpQuarter TABLE (Id VARCHAR(10))

	INSERT INTO @tmpBettypes (bettype)
	SELECT	CONVERT(smallint, val)
	FROM	dbo.f_SplitString(@p_bettypes, ',')
	GROUP BY val
	OPTION (maxrecursion 0)

	IF (@Quarter <> 'All')
	BEGIN
		INSERT INTO @tmpQuarter (Id)
		SELECT val
		FROM dbo.f_SplitString(@Quarter, ',')
		OPTION (maxrecursion 0) 
	END

	CREATE TABLE  #tmpSelectionType (Selectiontype INT PRIMARY KEY)
	DECLARE @tmpTransid TABLE (Transid BIGINT)

	IF @SelectionType <> ''
	BEGIN
		INSERT INTO #tmpSelectionType (Selectiontype)
		SELECT val
		FROM dbo.f_SplitString(@SelectionType, ',')
		OPTION (maxrecursion 0) 
	
		INSERT INTO @tmpTransid (Transid)
		SELECT DISTINCT b.transid
		FROM dbo.bettrans b WITH(NOLOCK) 
			CROSS APPLY (
				SELECT SelectionType
				FROM dbo.SMP_MarketSelection ms WITH(NOLOCK) 
				WHERE b.betcheck = ms.MarketId and matchid = b.matchid
				)ms
			INNER JOIN  #tmpSelectionType s ON ms.SelectionType=s.Selectiontype
		WHERE b.matchid = @MatchId	
	END

	DECLARE @SportType SMALLINT = NULL
	SELECT @SportType = m.sporttype FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId

	CREATE TABLE #tmpAffectTickets (Transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblSettlementHistory (transid BIGINT, winlost MONEY, StatusId TINYINT, SettlementType TINYINT, CreatedDate DATETIME , BalanceChanged MONEY, Rownumber INT, RN_settle INT)
	CREATE CLUSTERED INDEX IDX_tblSettlementHistory_transid ON #tblSettlementHistory (transid)

	IF (@IsReSettled = 1)
	BEGIN 
		IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.settlementhistory WITH(NOLOCK) WHERE MatchId = @MatchId)
		BEGIN
			INSERT INTO #tblSettlementHistory (transid, winlost, StatusId, SettlementType, CreatedDate, BalanceChanged, Rownumber, RN_settle)
			SELECT transid, winlost, StatusId, SettlementType, CreatedDate, BalanceChanged
					, ROW_NUMBER() OVER (PARTITION BY transid ORDER BY CreatedDate DESC) Rownumber
					, CASE WHEN SettlementType <> 0 THEN ROW_NUMBER() OVER (PARTITION BY transid ORDER BY CASE WHEN SettlementType <> 0 THEN 1 ELSE 0 END DESC, CreatedDate DESC) ELSE 0 END AS RN_settle
			FROM bodb02.dbo.settlementhistory WITH(NOLOCK) 
			WHERE Matchid = @MatchId

			INSERT INTO #tmpAffectTickets(Transid)
			SELECT bt.transid
			FROM #tblSettlementHistory bt
			OUTER APPLY ( 
				SELECT  bt1.SettlementType, bt1.Rownumber --get settle before
				FROM #tblsettlementhistory bt1 
				WHERE  bt.transid = bt1.transid
						AND bt1.RN_settle = 2 
			)bt1 
			OUTER APPLY ( 
				SELECT  bt2.SettlementType, SUM(bt2.BalanceChanged) sumbalance 
				FROM #tblsettlementhistory bt2
				WHERE  bt.transid = bt2.transid
						AND 1 = CASE WHEN bt1.Rownumber IS NOT NULL AND  bt2.Rownumber > 1 and bt2.Rownumber < bt1.Rownumber THEN 1
									 WHEN bt1.Rownumber IS NULL AND bt2.Rownumber > 1 THEN 1
									 ELSE 0  
								END
				GROUP BY bt2.SettlementType
			)bt2
			WHERE bt.Rownumber = 1 
			AND 1 = CASE WHEN bt.SettlementType = 3 THEN 1 
						 WHEN bt.SettlementType = 2 AND bt.BalanceChanged + bt2.sumbalance <> 0 THEN 1
						 ELSE 0
					END
		END
	END
	---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
	IF @Type <> 0 SELECT @LiveType = 2

	CREATE TABLE #SpecialDeleteBets 
	(
		transid BIGINT,
		CustId INT,
		FilterBettype		SMALLINT,
		FilterBetTeam		NVARCHAR(10), 
		FilterSet			VARCHAR(50),
		FilterGame			VARCHAR(50),
		FilterValue			SMALLMONEY,	
		FilterGoal			BIGINT,
		FilterBetOption		NVARCHAR(50),
		FilterHdp1	        SMALLMONEY,
		FilterHdp2	        SMALLMONEY,
		FilterOddsSpread    MONEY,
	    FilterOddsId		INT,
		FilterTransdesc	    NVARCHAR(2000),
	)

	CREATE TABLE #TmpBallSequence (Seq TINYINT)

	INSERT INTO #TmpBallSequence(Seq)
	SELECT  val
	FROM	dbo.f_SplitString(@BallSequence, ',')
	OPTION (maxrecursion 0)

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
				, bt.val AS BetTeam 
				, se.val AS [Set]
				, ga.val AS Game
				, bop.val AS BetOption
				, CAST(CASE WHEN v.val = 'ALL' THEN @ValueDefault
						ELSE v.val END AS SMALLMONEY) AS [Value]
				, CAST(CASE WHEN vhdp1.val = 'ALL' THEN @ValueDefault
						ELSE vhdp1.val END AS SMALLMONEY) AS ValueHdp1
				, CAST(CASE WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2		
				, CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal END AS BIGINT) AS Goal
				, CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN @ValueDefault
						ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
				, CAST(CASE WHEN osid.val = 'ALL' THEN NULL
						ELSE osid.val END AS INT) AS OddsId
				, CAST(CASE WHEN td.val = 'ALL' THEN NULL
						ELSE td.val END AS NVARCHAR(2000)) AS Transdesc
		FROM #tblBetType cte
				CROSS APPLY dbo.f_SplitString(cte.betteam, ',') bt
				CROSS APPLY dbo.f_SplitString(cte.[Set], ',') se
				CROSS APPLY dbo.f_SplitString(cte.Game, ',') ga
				CROSS APPLY dbo.f_SplitString(cte.BetOption, ',') bop
				CROSS APPLY dbo.f_SplitString(cte.[Value], ',') v
				CROSS APPLY dbo.f_SplitString(cte.ValueHdp1, ',') vhdp1
				CROSS APPLY dbo.f_SplitString(cte.OddsId, ',') osid
				CROSS APPLY dbo.f_SplitString(cte.Transdesc, ',') td
	) cte
	OPTION(MAXRECURSION 0)

	BEGIN
		IF @Type = 1 -- Number Game
		BEGIN
			-- Select Happy 5
			IF @SportType = 164
			BEGIN
				INSERT INTO #SpecialDeleteBets (transid, CustId)
				SELECT	b.transid,
						b.custid
				FROM	dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				WHERE	b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
						AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
						AND b.matchid = @MatchId 
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				OPTION	(RECOMPILE)	
			END
			-- Select Number Game
			ELSE
			BEGIN
				INSERT INTO #SpecialDeleteBets (transid, CustId)
				SELECT	b.transid,
						b.custid
				FROM	dbo.bettrans b WITH (NOLOCK)
				     INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
					OUTER APPLY (SELECT BallSequence 
								FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore )
								WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
								) AS BS_tmp
				WHERE	b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
						AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
						AND b.matchid = @MatchId 
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
						AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WITH (NOLOCK) WHERE Seq = BS_tmp.BallSequence)
				OPTION	(RECOMPILE)	
			END
		END
		ELSE IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single'
		BEGIN
			INSERT INTO #SpecialDeleteBets (transid, CustId, FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc)
			SELECT	CASE WHEN b.Bettype IN (801,803,804,805,806) THEN b.refno ELSE b.transid END transid
					,b.custid
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
			FROM	dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
			WHERE	b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
				AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
				AND b.matchid = @MatchId 
				AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
				AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
				AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
							AND	   CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END
				AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (@Quarter = 'All' 
					OR (b.bettype NOT BETWEEN 609 AND 617 AND b.bettype NOT BETWEEN 627 AND 631 AND b.bettype NOT BETWEEN 707 AND 714 AND b.bettype NOT BETWEEN 381 AND 385) 
					OR ((b.bettype BETWEEN 609 AND 617 OR b.bettype BETWEEN 627 AND 631 OR b.bettype BETWEEN 707 AND 714 OR b.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE b.betid LIKE q.Id + '%')))

			UNION ALL
			SELECT	b.translogid transID,
					b.custid,
					NULL AS FilterBetType,
					NULL AS FilterBetTeam,
					NULL AS FilterSet,
					NULL AS FilterGame,
					NULL FilterValue,
					NULL AS FilterGoal,
					NULL AS FilterBetOption,
					NULL AS FilterHdp1,
					NULL AS FilterHdp2,
					NULL AS FilterOddsSpread,
					NULL AS FilterOddsId,
					NULL AS FilterTransdesc
			FROM	dbo.translog b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.gameID = t.bettype
				LEFT JOIN dbo.bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno AND b.gameid = bs.bettype		
			WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
				AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
				AND b.gameid IN (801,803,804,805,806) AND bs.refno IS NULL
				AND b.eventid = @MatchId 
				AND CASE WHEN @LiveType <> 2 THEN b.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END 
			OPTION (RECOMPILE)

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

			IF @SportType IN (43,50) -- E-Sports, Cricket
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
					WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

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
	END

	-- System parlay - Sportsbook 29
     IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'SubParlay'
	BEGIN
		INSERT INTO #SpecialDeleteBets (transid, CustId, FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, FilterHdp1, FilterHdp2, FilterOddsSpread, FilterOddsId, FilterTransdesc)
		SELECT	b.transid,
				b.custid,
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
		FROM dbo.bettransm bm WITH (NOLOCK)	
			INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
		WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
			AND b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
			AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND b.bettype = 29
			AND b.matchid = 29
			AND bm.matchid = @MatchId 
			AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
			AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
								AND	  CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
			AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
			AND (b.betid = 0 OR b.betid IS NULL)
			AND (@Quarter = 'All' 
				OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
				OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																									WHERE bm.betcheck LIKE q.Id + '%')))
		--========================================================================--
		IF (@BetTypes ='38' AND @Selectiontype <>'')
		BEGIN
			DELETE b
			FROM  #SpecialDeleteBets b
			WHERE NOT EXISTS ( SELECT TOP 1 1 FROM @tmpTransid t WHERE b.transid=t.Transid)
		END
		--========================================================================--
		IF @SportType IN (43,50) -- E-Sports, Cricket
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
				WHERE tp.Id = b.FilterBettype AND (tp.Goal = 100 OR b.FilterGoal = tp.Goal ))

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
    IF EXISTS(SELECT 1 FROM @tmpBettypes WHERE bettype =2799)
	BEGIN
		INSERT INTO #SpecialDeleteBets (transid, CustId)	
		SELECT	b.transid,
				b.custid
		FROM	dbo.bettransm bm WITH (NOLOCK)	
			INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
		WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
			AND b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
			AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
			AND b.bettype = 2799
			AND b.matchid = 2799
			AND bm.matchid = @MatchId 
			AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
			AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
			AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
			AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
								AND	  CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
			AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
			AND (b.betid = 0 OR b.betid IS NULL)
			AND (@Quarter = 'All' 
				OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
				OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																									WHERE bm.betcheck LIKE q.Id + '%')))
	END

	SELECT	tmp.transid,
			tmp.CustId
	FROM #SpecialDeleteBets tmp
	ORDER BY transid
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TmpBallSequence	
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #tmpSelectionType
	DROP TABLE #tblSettlementHistory
	DROP TABLE #tmpAffectTickets
END
