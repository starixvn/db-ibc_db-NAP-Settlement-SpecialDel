/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_Detail] @MatchId          INT,
                                                               @LicenseeName     VARCHAR(1000) = 'ALL',
                                                               @BetTypes         VARCHAR(1000) = '',
                                                               @LiveType         SMALLINT      = 2,
                                                               @LiveHomeScore    SMALLINT      = NULL,
                                                               @LiveAwayScore    SMALLINT      = NULL,
                                                               @FromTransdate    DATETIME      = NULL,
                                                               @ToTransdate      DATETIME      = NULL,
                                                               @Type             SMALLINT      = 0,
                                                               @SecondAcceptFlag TINYINT       = 0,
                                                               @BallSequence     VARCHAR(200)  = '',
                                                               @Quarter          VARCHAR(200)  = 'All',
															   @BetTeams			XML		   = NULL,
															   @SingleOrSubParlay VARCHAR(20)  = 'All'
WITH RECOMPILE
AS;
/*	Created by: Elodie
	Date: 20130606
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
			/>
		<BetTypes/>'
    - @SingleOrSubParlay: 
	 + 'All'
	 + 'Single'
	 + 'SubParlay' 	
     
   Example:    exec NAP_Rpt_TicketsListingDetail @MatchId=4626986,@LicenseeName='IBC',@BetTypes='1101,1102',@BetTypesLive='',@LiveType=0,@LiveHomeScore=default,@LiveAwayScore=default,@FromTransdate=default,@ToTransdate=default,@Type=2,@SecondAcceptFlag=0
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @p_bettypes VARCHAR(1000)
	SET @p_bettypes = @BetTypes

	DECLARE @SportType SMALLINT = NULL
	SELECT @SportType = m.sporttype FROM dbo.match m WHERE m.matchid = @MatchId

	---- If not sportbook then don't care @livetype , so set @LiveType to 2 (All)
	IF @Type <> 0 SELECT @LiveType = 2
	
	DECLARE @tmpBettypes TABLE ( bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpQuarter TABLE (Id VARCHAR(10))

	SELECT 'match' AS [matchtype]
	  , matchid
	  , sporttype
	  , homeid
	  , awayid
	  , isNeutral
	INTO #T_Match
	FROM match (NOLOCK)
	WHERE matchid = @MatchId
	UNION ALL
	SELECT 'match3rd' AS [matchtype]
		  , match3rdid AS matchid
		  , sporttype
		  , homeid
		  , awayid
		  , NULL AS isNeutral
	FROM match3rd (NOLOCK)
	WHERE match3rdid = @MatchId

	DECLARE @SettlementStatus TINYINT = NULL
	SELECT @SettlementStatus = m.SettlementStatus FROM dbo.match m WHERE m.matchid = @MatchId

	CREATE TABLE #TmpBallSequence (Seq TINYINT)

	CREATE TABLE #SpecialDeleteBets
             (username         VARCHAR(30),
              bettype          SMALLINT,
              OriginalBetType  SMALLINT,
              ExtraInfo        VARCHAR(1000),
              BetdaqId         BIGINT,
              ActualStake      MONEY,
              transid          BIGINT,
              homeid           INT,
              awayid           INT,
              hdp1             SMALLMONEY,
              hdp2             SMALLMONEY,
              odds             MONEY,
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
              SubTransID       BIGINT,
              SubBetType       INT,
              SubHomeID        INT,
              SubAwayID        INT,
              SubHdp1          SMALLMONEY,
              SubHdp2          SMALLMONEY,
              SubOdds          MONEY,
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
              FilterGoal       BIGINT,
              FilterBetOption  NVARCHAR(50),
              IsMarked         BIT
             );

    CREATE TABLE #tmpRefCodeSummary
             (RefCode  BIGINT,
              custid   INT,
              bettype  SMALLINT,
              transid  BIGINT,
              IsMarked BIT
             );

	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

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

	-- 
	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(500),
		Game			VARCHAR(500),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		Goal			VARCHAR(10)
	)
	CREATE TABLE #tblBetType_Detail
	(
		Id				SMALLINT,
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,	
		Goal			BIGINT
	)

	-- Parse xml @BetTeams
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], Goal)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(500)') AS [Set]				-- check columns : betid		 ; single-choice
			, t.c.value('@Game','VARCHAR(500)') AS Game				-- check columns : betid		 ; single-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]			-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
	FROM @BetTeams.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTeams = NULL))
			 
	INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], Goal)
	SELECT cte.Id
			, cte.BetTeam
			, cte.[Set]
			, cte.Game
			, cte.BetOption
			, cte.[Value] 
			, cte.Goal
	FROM (
		SELECT cte.Id
				, bt.val AS BetTeam 
				, se.val AS [Set]
				, ga.val AS Game
				, bop.val AS BetOption
				, CAST(CASE WHEN v.val = 'ALL' THEN 9999.00 
						ELSE v.val END AS SMALLMONEY) AS [Value]
				, CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal END AS BIGINT) AS Goal
		FROM #tblBetType cte
				CROSS APPLY dbo.f_SplitString(cte.betteam, ',') bt
				CROSS APPLY dbo.f_SplitString(cte.[Set], ',') se
				CROSS APPLY dbo.f_SplitString(cte.Game, ',') ga
				CROSS APPLY dbo.f_SplitString(cte.BetOption, ',') bop
				CROSS APPLY dbo.f_SplitString(cte.[Value], ',') v
	) cte

	INSERT INTO #TmpBallSequence(Seq)
	SELECT  val
	FROM	dbo.f_SplitString(@BallSequence, ',')
	OPTION (maxrecursion 0)

	IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'Single'
	BEGIN	
		----Direct Licensee
		IF @LicenseeName <> 'Credit' AND @LicenseeName <> 'CN88' AND @LicenseeName <> 'ALL' 
		BEGIN
			IF @Type = 1 -- Number Game
			BEGIN
				-- Select Happy 5
				IF(EXISTS(SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchID AND m.sporttype = 164))
				BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,				
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,						
							CASE WHEN b.Bettype IN (801,803,804,805,806) THEN b.refno ELSE b.transid END transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END  as status,
							b.stake,
							b.transdate,		
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.sporttype,
							b.MOdds,
							NULL AS BallSequence
					FROM	bettrans b WITH (NOLOCK) 
						INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid
					WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper WITH(NOLOCK) where site = @LicenseeName)
						AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
						AND b.matchid = @MatchId 
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					OPTION	(RECOMPILE)
				END

				-- Select Number Game
				ELSE
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,				
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,						
							CASE WHEN b.Bettype IN (801,803,804,805,806) THEN b.refno ELSE b.transid END transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status END  as status,
							b.stake,
							b.transdate,
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.sporttype,
							b.MOdds,
							BS_tmp.BallSequence AS BallSequence
					FROM		bettrans b WITH (NOLOCK) 
						INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 	
							
						OUTER APPLY (SELECT BallSequence 
									FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore)
									WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
									) AS BS_tmp
					WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper WITH(NOLOCK) where site = @LicenseeName)
						AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
						AND b.matchid = @MatchId 
						AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
						AND EXISTS (SELECT TOP 1 1 FROM #TmpBallSequence WITH (NOLOCK) WHERE Seq = BS_tmp.BallSequence)
					OPTION	(RECOMPILE)
				END
			END
			ELSE 
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,SportType,MOdds,WalletType,RefCode,BonusID,MainTransId, custid
											,FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption,IsMarked)
				SELECT	b.username,
						b.bettype,				
						b.bettype AS OriginalBetType,
						b.ExtraInfo,
						b.BetdaqId,
						b.actual_stake AS ActualStake,
						CASE WHEN b.Bettype IN (801,803,804,805,806,1004) THEN b.refno ELSE b.transid END transid,
						m.homeID,
						m.awayID,
						convert(float, b.hdp1) as hdp1, 
						convert(float, b.hdp2) as hdp2, 
						b.odds,
						b.oddsspread,
						CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END  as status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						m.sporttype,
						b.MOdds,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						NULL AS MainTransId,				
						b.custid,
						b.bettype AS FilterBetType,
						b.betteam AS FilterBetTeam,
						b.betid AS FilterSet,
						RIGHT(b.betid, 2) AS FilterGame,
						b.hdp1 + b.hdp2 AS FilterValue,
						ISNULL(b.betid, 0) AS FilterGoal,
						CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
						CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				FROM	Bettrans b WITH (NOLOCK) 
				     INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
					INNER JOIN  #T_Match m WITH (NOLOCK) ON CASE 
													WHEN b.bettype = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype 	
				     LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON b.transid = mt.TransId											   	
				WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)			
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
				SELECT	b.username,
						b.gameID AS bettype,				
						b.gameID AS OriginalBetType,
						NULL AS ExtraInfo,
						NULL AS BetdaqId,
						b.actual_stake AS ActualStake,						
						b.translogid transID,
						m.homeID,
						m.awayID,
						0 AS hdp1, 
						0 as hdp2, 
						b.odds,
						0 AS oddsspread,
						b.status,
						b.stake,
						b.transdate,		
						b.custom3 AS betteam,
						NULL betcheck,
						NULL livehomescore,
						NULL liveawayscore,
						b.liveindicator liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.custom1 AS OddsType,
						b.CurrencyName,
						- b.actual_stake as winlost,
						NULL AS betid,
						0 IsParlay,
						NULL SecAcceptFlag,
						b.translogid refno,
						b.TransDesc,
						m.SportType,
						NULL AS MOdds,
						NULL AS WalletType,
						NULL AS RefCode,
						NULL AS BonusID,
						NULL AS MainTransId,				
						b.custid,
						NULL AS FilterBetType,
						NULL AS FilterBetTeam,
						NULL AS FilterSet,
						NULL AS FilterGame,
						NULL FilterValue,
						NULL AS FilterGoal,
						NULL AS FilterBetOption,
						0 AS IsMarked
				FROM	translog b WITH (NOLOCK) 
				INNER JOIN @tmpBettypes t ON b.gameID = t.bettype
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.gameID = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype 	
				LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno AND b.gameid = bs.bettype		
				WHERE		b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(nolock) where site = @LicenseeName)
							AND b.statusID NOT IN (101,102, 121) ---('Void', 'Reject', 'Dummy')
							AND b.gameid IN (801,803,804,805,806,1004) AND bs.refno IS NULL
							AND b.eventid = @MatchId 
							AND CASE WHEN @LiveType <> 2 THEN b.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				ORDER BY transID
			END	
		END

		---IBC 
		IF @LicenseeName = 'Credit'  
		BEGIN
			IF @Type = 1 -- Number Game
			BEGIN
				-- Select Happy 5
				IF(EXISTS(SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchID AND m.sporttype = 164))
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,
							b.transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END as status,
							b.stake,
							b.transdate,
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.SportType,
							b.MOdds,
							NULL AS BallSequence
					FROM	bettrans b WITH (NOLOCK) 
					     INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid
					WHERE	b.srecommend NOT IN (SELECT custid
							   FROM dbo.Dep_CustSuper WITH (NOLOCK)
							   UNION
							   SELECT custid
							   FROM dbo.CS_CustSuper WITH (NOLOCK))
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					OPTION	(RECOMPILE)
				END
				-- Select Number Game
				ELSE
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,
							b.transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END as status,
							b.stake,
							b.transdate,		
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.SportType,
							b.MOdds,
							BS_tmp.BallSequence AS BallSequence
					FROM	bettrans b WITH (NOLOCK) 
					     INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 	
						OUTER APPLY (SELECT BallSequence 
									FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore )
									WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
									) AS BS_tmp								
					WHERE	b.srecommend NOT IN ( SELECT custid
							   FROM dbo.Dep_CustSuper WITH (NOLOCK)
							   UNION
							   SELECT custid
							   FROM dbo.CS_CustSuper WITH (NOLOCK))
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
							AND EXISTS (SELECT TOP 1 1
										FROM #TmpBallSequence WITH (NOLOCK)
										WHERE Seq = BS_tmp.BallSequence)										
					OPTION	(RECOMPILE)
				END
			END
			ELSE 
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,SportType,MOdds,WalletType,RefCode,BonusID,MainTransId, custid
											,FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, IsMarked)
				SELECT	b.username,
						b.bettype,				
						b.bettype AS OriginalBetType,
						b.ExtraInfo,
						b.BetdaqId,
						b.actual_stake AS ActualStake,						
						b.transid,
						m.homeID,
						m.awayID,
						convert(float, b.hdp1) as hdp1, 
						convert(float, b.hdp2) as hdp2, 
						b.odds,
						b.oddsspread,
						CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END as status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						m.SportType,
						b.MOdds,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						NULL AS MainTransId,				
						b.custid,
						b.bettype AS FilterBetType,
						b.betteam AS FilterBetTeam,
						b.betid AS FilterSet,
						RIGHT(b.betid, 2) AS FilterGame,
						b.hdp1 + b.hdp2 AS FilterValue,
						ISNULL(b.betid, 0) AS FilterGoal,
						CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
						CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				FROM	Bettrans b WITH (NOLOCK) 
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.bettype = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype
				LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON b.transid = mt.TransId
				WHERE b.srecommend NOT IN ( SELECT custid
					   FROM dbo.Dep_CustSuper WITH (NOLOCK)
					   UNION
					   SELECT custid
					   FROM dbo.CS_CustSuper WITH (NOLOCK))
					AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
					AND b.matchid = @MatchId 
					AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
					AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					AND (@Quarter = 'All' 
						OR (b.bettype NOT BETWEEN 609 AND 617 AND b.bettype NOT BETWEEN 627 AND 631 AND b.bettype NOT BETWEEN 707 AND 714 AND b.bettype NOT BETWEEN 381 AND 385) 
						OR ((b.bettype BETWEEN 609 AND 617 OR b.bettype BETWEEN 627 AND 631 OR b.bettype BETWEEN 707 AND 714 OR b.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																											WHERE b.betid LIKE q.Id + '%')))
				UNION ALL
				SELECT	b.username,
						b.GameID AS bettype,					
						b.gameID AS OriginalBetType,
						NULL AS ExtraInfo,
						NULL AS BetdaqId,
						b.actual_stake AS ActualStake,					
						b.TranslogID transid,
						m.homeID,
						m.awayID,
						0 as hdp1, 
						0 as hdp2, 
						b.odds,
						0 AS oddsspread,
						b.status,
						b.stake,
						b.transdate,		
						b.custom3 AS betteam,
						NULL betcheck,
						NULL livehomescore,
						NULL liveawayscore,
						b.liveindicator liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.custom1 AS OddsType,
						b.CurrencyName,
						- b.actual_stake as winlost,
						NULL AS betid,
						0 as IsParlay,
						NULL SecAcceptFlag,
						b.translogid refno,
						b.TransDesc,
						m.SportType,
						NULL AS MOdds,
						NULL AS WalletType,
						NULL AS RefCode,
						NULL AS BonusID,
						NULL AS MainTransId,				
						b.custid,
						NULL AS FilterBetType,
						NULL AS FilterBetTeam,
						NULL AS FilterSet,
						NULL AS FilterGame,
						NULL FilterValue,
						NULL AS FilterGoal,
						NULL AS FilterBetOption,
						0 AS IsMarked
				FROM		Translog b WITH (NOLOCK) 
				INNER JOIN @tmpBettypes t ON b.gameID = t.bettype
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.gameID = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype 
				LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno AND b.gameid = bs.bettype			
				WHERE		b.srecommend NOT IN ( SELECT custid
							   FROM dbo.Dep_CustSuper WITH (NOLOCK)
							   UNION
							   SELECT custid
							   FROM dbo.CS_CustSuper WITH (NOLOCK))
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.gameid IN (801,803,804,805,806,1004) AND bs.refno IS NULL
							AND b.EventID = @MatchId 
							AND EXISTS (SELECT TOP 1 1 FROM @tmpBettypes t WHERE t.bettype = b.gameID)
				ORDER BY transID								
				OPTION	(RECOMPILE)
			END	
		END
		---CN88 
		IF @LicenseeName = 'CN88'  
		BEGIN
			IF @Type = 1 -- Number Game
			BEGIN
				-- Select Happy 5
				IF(EXISTS(SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchID AND m.sporttype = 164))
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,
							b.transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END as status,
							b.stake,
							b.transdate,
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.SportType,
							b.MOdds,
							NULL AS BallSequence
					FROM	bettrans b WITH (NOLOCK) 
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid
					WHERE	b.srecommend IN (SELECT custid FROM dbo.CS_CustSuper WITH (NOLOCK))
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
							AND b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					OPTION	(RECOMPILE)
				END
				-- Select Number Game
				ELSE
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,
							b.transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END as status,
							b.stake,
							b.transdate,		
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.SportType,
							b.MOdds,
							BS_tmp.BallSequence AS BallSequence
					FROM	bettrans b WITH (NOLOCK) 
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 	
						OUTER APPLY (SELECT BallSequence 
									FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore )
									WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
									) AS BS_tmp								
					WHERE	b.srecommend IN (SELECT custid FROM dbo.CS_CustSuper WITH (NOLOCK))
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.matchid = @MatchId 
							AND b.bettype IN (SELECT CONVERT(INT,val) FROM dbo.strSplit(@p_bettypes,','))
							AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
							AND EXISTS (SELECT TOP 1 1
										FROM #TmpBallSequence WITH (NOLOCK)
										WHERE Seq = BS_tmp.BallSequence)										
					OPTION	(RECOMPILE)
				END
			END
			ELSE
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,SportType,MOdds,WalletType,RefCode,BonusID,MainTransId, custid
											,FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, IsMarked)
				SELECT	b.username,
						b.bettype,				
						b.bettype AS OriginalBetType,
						b.ExtraInfo,
						b.BetdaqId,
						b.actual_stake AS ActualStake,						
						b.transid,
						m.homeID,
						m.awayID,
						convert(float, b.hdp1) as hdp1, 
						convert(float, b.hdp2) as hdp2, 
						b.odds,
						b.oddsspread,
						CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END as status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						m.SportType,
						b.MOdds,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						NULL AS MainTransId,				
						b.custid,
						b.bettype AS FilterBetType,
						b.betteam AS FilterBetTeam,
						b.betid AS FilterSet,
						RIGHT(b.betid, 2) AS FilterGame,
						b.hdp1 + b.hdp2 AS FilterValue,
						ISNULL(b.betid, 0) AS FilterGoal,
						CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
						CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				FROM	Bettrans b WITH (NOLOCK) 
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.bettype = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype
				LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON b.transid = mt.TransId
				WHERE b.srecommend IN (SELECT custid FROM dbo.CS_CustSuper WITH (NOLOCK))
					AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
					AND b.matchid = @MatchId 
					AND EXISTS (SELECT TOP 1 1 FROM @tmpBettypes t WHERE t.bettype = b.bettype)
					AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
					AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					AND (@Quarter = 'All' 
						OR (b.bettype NOT BETWEEN 609 AND 617 AND b.bettype NOT BETWEEN 627 AND 631 AND b.bettype NOT BETWEEN 707 AND 714 AND b.bettype NOT BETWEEN 381 AND 385) 
						OR ((b.bettype BETWEEN 609 AND 617 OR b.bettype BETWEEN 627 AND 631 OR b.bettype BETWEEN 707 AND 714 OR b.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																											WHERE b.betid LIKE q.Id + '%'))) 
				UNION ALL
				SELECT	b.username,
						b.GameID AS bettype,					
						b.gameID AS OriginalBetType,
						NULL AS ExtraInfo,
						NULL AS BetdaqId,
						b.actual_stake AS ActualStake,					
						b.TranslogID transid,
						m.homeID,
						m.awayID,
						0 as hdp1, 
						0 as hdp2, 
						b.odds,
						0 AS oddsspread,
						b.status,
						b.stake,
						b.transdate,		
						b.custom3 AS betteam,
						NULL betcheck,
						NULL livehomescore,
						NULL liveawayscore,
						b.liveindicator liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.custom1 AS OddsType,
						b.CurrencyName,
						- b.actual_stake as winlost,
						NULL AS betid,
						0 as IsParlay,
						NULL SecAcceptFlag,
						b.translogid refno,
						b.TransDesc,
						m.SportType,
						NULL AS MOdds,
						NULL AS WalletType,
						NULL AS RefCode,
						NULL AS BonusID,
						NULL AS MainTransId,				
						b.custid,
						NULL AS FilterBetType,
						NULL AS FilterBetTeam,
						NULL AS FilterSet,
						NULL AS FilterGame,
						NULL FilterValue,
						NULL AS FilterGoal,
						NULL AS FilterBetOption,
						0 AS IsMarked
				FROM		Translog b WITH (NOLOCK) 
				INNER JOIN @tmpBettypes t ON b.gameID = t.bettype
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.gameID = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype 
				LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno AND b.gameid = bs.bettype			
				WHERE		b.srecommend IN (SELECT custid FROM dbo.CS_CustSuper WITH (NOLOCK))
							AND b.statusID NOT IN (101,102, 121) --- ('Void', 'Reject', 'Dummy')
							AND b.gameid IN (801,803,804,805,806,1004) AND bs.refno IS NULL
							AND b.EventID = @MatchId 
				ORDER BY transID								
				OPTION	(RECOMPILE)
			END	
		END

		---ALL
		IF @LicenseeName= 'ALL' 
		BEGIN 
			IF @Type = 1 -- Number Game
			BEGIN
				-- Select Happy 5
				IF(EXISTS(SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchID AND m.sporttype = 164))
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,					
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,					
							b.transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END  as status,
							b.stake,
							b.transdate,		
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.SportType,
							b.MOdds,
							NULL AS BallSequence
					FROM	bettrans b WITH (NOLOCK)
					     INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid
					WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
								AND b.matchid = @MatchId 
								AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
										
					OPTION	(RECOMPILE)
				END
				-- Select Number Game
				ELSE
				BEGIN
					INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
												,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
												,SecAcceptFlag,refno,TransDesc,SportType,MOdds,BallSequence)
					SELECT	b.username,
							b.bettype,					
							b.bettype AS OriginalBetType,
							b.ExtraInfo,
							b.BetdaqId,
							b.actual_stake AS ActualStake,					
							b.transid,
							m.homeID,
							m.awayID,
							convert(float, b.hdp1) as hdp1, 
							convert(float, b.hdp2) as hdp2, 
							b.odds,
							b.oddsspread,
							CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								 ELSE b.status 
								 END  as status,
							b.stake,
							b.transdate,		
							b.betteam,
							b.betcheck,
							b.livehomescore,
							b.liveawayscore,
							b.liveindicator, 
							isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
							b.OddsType,
							b.CurrencyName,
							(winlost-actual_stake )as winlost,
							b.betid,
							0 as IsParlay,
							ISNULL(SecAcceptFlag,0) SecAcceptFlag,
							b.refno,
							b.TransDesc,
							m.SportType,
							b.MOdds,
							BS_tmp.BallSequence AS BallSequence
					FROM	bettrans b WITH (NOLOCK)
					     INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
						INNER JOIN  match m WITH (NOLOCK) on b.matchid = m.matchid 		
						OUTER APPLY (SELECT BallSequence 
									FROM dbo.f_NG_GetBallSequence (b.bettype, b.betteam , b.betid , b.liveindicator	, b.livehomescore, b.liveawayscore )
									WHERE b.bettype IN (85, 86, 87, 88, 89, 90, 91)
									) AS BS_tmp
					WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
								AND b.matchid = @MatchId 
								AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
								AND EXISTS (SELECT TOP 1 1
											FROM #TmpBallSequence WITH (NOLOCK)
											WHERE Seq = BS_tmp.BallSequence)
										
					OPTION	(RECOMPILE)
				END
			END
			ELSE
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,oddsspread,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,SportType,MOdds,WalletType,RefCode,BonusID,MainTransId, custid
											,FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption, IsMarked)
				SELECT	b.username,
						b.bettype,					
						b.bettype AS OriginalBetType,
						b.ExtraInfo,
						b.BetdaqId,
						b.actual_stake AS ActualStake,					
						b.transid,
						m.homeID,
						m.awayID,
						convert(float, b.hdp1) as hdp1, 
						convert(float, b.hdp2) as hdp2, 
						b.odds,
						b.oddsspread,
						CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END  as status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						m.SportType,
						b.MOdds,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						NULL AS MainTransId,				
						b.custid,
						b.bettype AS FilterBetType,
						b.betteam AS FilterBetTeam,
						b.betid AS FilterSet,
						RIGHT(b.betid, 2) AS FilterGame,
						b.hdp1 + b.hdp2 AS FilterValue,
						ISNULL(b.betid, 0) AS FilterGoal,
						CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption,
						CASE WHEN mt.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				FROM	Bettrans b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.bettype = t.bettype
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.bettype = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype 
				LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK) ON b.transid = mt.TransId				
				WHERE b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
					AND b.matchid = @MatchId 
					AND CASE WHEN @LiveType <> 2 THEN liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE b.liveawayscore END
					AND b.transdate	BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE b.transdate END 
									AND	    CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE b.transdate END 
					AND ISNULL(SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
					AND (@Quarter = 'All' 
						OR (b.bettype NOT BETWEEN 609 AND 617 AND b.bettype NOT BETWEEN 627 AND 631 AND b.bettype NOT BETWEEN 707 AND 714 AND b.bettype NOT BETWEEN 381 AND 385) 
						OR ((b.bettype BETWEEN 609 AND 617 OR b.bettype BETWEEN 627 AND 631 OR b.bettype BETWEEN 707 AND 714 OR b.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																											WHERE b.betid LIKE q.Id + '%')))  
				UNION ALL
				SELECT	b.username,
						b.GameID AS bettype,				
						b.gameID AS OriginalBetType,
						NULL AS ExtraInfo,
						NULL AS BetdaqId,
						b.actual_stake AS ActualStake,						
						b.translogid AS transid,
						m.homeID,
						m.awayID,
						0 as hdp1, 
						0as hdp2, 
						b.odds,
						0 AS oddsspread,
						b.status,
						b.stake,
						b.transdate,		
						b.custom3 AS betteam,
						NULL betcheck,
						NULL livehomescore,
						NULL liveawayscore,
						b.liveindicator liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.custom1 AS OddsType,
						b.CurrencyName,
						- b.actual_stake as winlost,
						NULL AS betid,
						0 as IsParlay,
						NULL SecAcceptFlag,
						b.translogid refno,
						b.TransDesc,
						m.SportType,
						NULL AS MOdds,
						NULL AS WalletType,
						NULL AS RefCode,
						NULL AS BonusID,
						NULL AS MainTransId,				
						b.custid,
						NULL AS FilterBetType,
						NULL AS FilterBetTeam,
						NULL AS FilterSet,
						NULL AS FilterGame,
						NULL FilterValue,
						NULL AS FilterGoal,
						NULL AS FilterBetOption,
						0 AS IsMarked
				FROM	Translog b WITH (NOLOCK)
				INNER JOIN @tmpBettypes t ON b.gameID = t.bettype
				INNER JOIN  #T_Match m WITH (NOLOCK) on CASE 
													WHEN b.gameID = 1004 THEN 'match3rd'
													ELSE 'match' 
											    END = m.matchtype 	
				LEFT JOIN bettrans bs WITH(NOLOCK) ON b.translogid = bs.refno	AND b.gameid = bs.bettype	
				WHERE		b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy') 
							AND b.gameid IN (801,803,804,805,806,1004) AND bs.refno IS NULL
							AND b.EventID = @MatchId 
				ORDER BY transID
				
				OPTION	(RECOMPILE)
			END	
		END		
		
		IF @SportType = 43 -- E-Sports
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
		END

		-- Insert data for Bonus tickets
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)					
		BEGIN		
			CREATE CLUSTERED INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
			-- update MainTransId
			UPDATE sub
			SET MainTransId = main.transid
			FROM #SpecialDeleteBets main
				 INNER JOIN #SpecialDeleteBets sub
						 ON main.RefCode = sub.RefCode
							AND main.transid <> sub.transid
							AND main.custid = sub.custid
							AND main.bettype = sub.bettype	
			WHERE main.WalletType = 1
		  
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets		
			INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, IsMarked, transid)
			SELECT	RefCode, custid, bettype, IsMarked
					,MAX(transid) AS transid					
			FROM	 #SpecialDeleteBets
			WHERE	RefCode IS NOT NULL
			GROUP BY RefCode, custid, bettype, IsMarked
			HAVING COUNT(*) = 1
			
			IF @@ROWCOUNT <> 0
			BEGIN
				INSERT INTO #SpecialDeleteBets (username,bettype,OriginalBetType,ExtraInfo,BetdaqId,ActualStake,transid,homeid,awayid,hdp1,hdp2,odds,status,stake,transdate
											,betteam,betcheck,livehomescore,liveawayscore,IsLiveIndicator,ISNeutral,OddsType,CurrencyName,winlost,betid,IsParlay
											,SecAcceptFlag,refno,TransDesc,SportType,MOdds,WalletType,RefCode,BonusID,MainTransId, custid, IsMarked)
				SELECT	b.username,
						b.bettype,
						b.bettype AS OriginalBetType,
						b.ExtraInfo,
						b.BetdaqId,
						b.actual_stake AS ActualStake,		
						b.transid,
						m.homeID,
						m.awayID,
						convert(float, b.hdp1) as hdp1, 
						convert(float, b.hdp2) as hdp2, 
						b.odds,
						CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							 ELSE b.status 
							 END  as status,
						b.stake,
						b.transdate,		
						b.betteam,
						b.betcheck,
						b.livehomescore,
						b.liveawayscore,
						b.liveindicator, 
						isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
						b.OddsType,
						b.CurrencyName,
						(winlost-actual_stake )as winlost,
						b.betid,
						0 as IsParlay,
						ISNULL(SecAcceptFlag,0) SecAcceptFlag,
						b.refno,
						b.TransDesc,
						m.SportType,
						b.MOdds,
						b.WalletType,
						b.RefCode,
						b.BonusID,
						t.transid AS MainTransId,				
						b.custid,
						t.IsMarked
				FROM #tmpRefCodeSummary t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = t.RefCode
								AND b.transid <> t.transid
								AND b.matchid = @MatchId
								AND b.custid = t.custid
								AND b.bettype = t.bettype
								AND (@Quarter = 'All' 
									OR (b.bettype NOT BETWEEN 609 AND 617 AND b.bettype NOT BETWEEN 627 AND 631 AND b.bettype NOT BETWEEN 707 AND 714 AND b.bettype NOT BETWEEN 381 AND 385) 
									OR ((b.bettype BETWEEN 609 AND 617 OR b.bettype BETWEEN 627 AND 631 OR b.bettype BETWEEN 707 AND 714 OR b.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																														WHERE b.betid LIKE q.Id + '%')))  
					 INNER JOIN match m WITH (NOLOCK) 
							 ON b.matchid = m.matchid 						
				WHERE b.statusID NOT IN (101,102, 121)--('Void', 'Reject', 'Dummy')	
				
			END	  						  
		END			
	END

	-- System parlay - Sportsbook 29
     IF @SingleOrSubParlay = 'All' OR @SingleOrSubParlay = 'SubParlay'
	BEGIN 
		---Licensee
		IF @LicenseeName <> 'Credit' AND @LicenseeName <> 'CN88' AND @LicenseeName <> 'ALL' 
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc,
					FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption)	
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,		
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,			
					
					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck as SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId ,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc,
					bm.bettype AS FilterBetType,
					bm.betteam AS FilterBetTeam,
					bm.betcheck AS FilterSet,
					RIGHT(bm.betcheck, 2) AS FilterGame,
					bm.hdp1 + bm.hdp2 AS FilterValue,
					ISNULL(bm.betcheck, 0) AS FilterGoal,
					CAST(CAST(bm.hdp2 AS INT) AS VARCHAR(50)) + '-' + bm.betteam AS FilterBetOption
			FROM	bettransm bm WITH (NOLOCK)	
			INNER HASH JOIN  Bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.MatchID	
			WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
				AND b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 29 AND b.matchID = 29
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
		
		---IBC
		IF @LicenseeName= 'Credit'  
		BEGIN	
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc,
					FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption)
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	

					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc,
					bm.bettype AS FilterBetType,
					bm.betteam AS FilterBetTeam,
					bm.betcheck AS FilterSet,
					RIGHT(bm.betcheck, 2) AS FilterGame,
					bm.hdp1 + bm.hdp2 AS FilterValue,
					ISNULL(bm.betcheck, 0) AS FilterGoal,
					CAST(CAST(bm.hdp2 AS INT) AS VARCHAR(50)) + '-' + bm.betteam AS FilterBetOption
			FROM	Bettrans b WITH (NOLOCK) 
			INNER HASH JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
			WHERE b.srecommend NOT IN ( SELECT custid
							   FROM dbo.Dep_CustSuper WITH (NOLOCK)
							   UNION
							   SELECT custid
							   FROM dbo.CS_CustSuper WITH (NOLOCK))
				AND b.statusID NOT IN (101,102) --('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 29 AND b.matchID = 29
				AND bm.matchid = @MatchId 	 
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
				AND (@Quarter = 'All' 
					OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
					OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE bm.betcheck LIKE q.Id + '%')))  
			OPTION	(RECOMPILE)			
		END 

		---CN88
		IF @LicenseeName= 'CN88'  
		BEGIN	
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc,
					FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption)
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	

					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc,
					bm.bettype AS FilterBetType,
					bm.betteam AS FilterBetTeam,
					bm.betcheck AS FilterSet,
					RIGHT(bm.betcheck, 2) AS FilterGame,
					bm.hdp1 + bm.hdp2 AS FilterValue,
					ISNULL(bm.betcheck, 0) AS FilterGoal,
					CAST(CAST(bm.hdp2 AS INT) AS VARCHAR(50)) + '-' + bm.betteam AS FilterBetOption
			FROM	Bettrans b WITH (NOLOCK) 
			INNER HASH JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
			WHERE b.srecommend IN (SELECT custid FROM dbo.CS_CustSuper WITH (NOLOCK))
				AND b.statusID NOT IN (101,102) --('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 29 AND b.matchID = 29
				AND bm.matchid = @MatchId 	 
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
				AND (@Quarter = 'All' 
					OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
					OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE bm.betcheck LIKE q.Id + '%'))) 
			OPTION	(RECOMPILE)			
		END 

		---ALL
		IF @LicenseeName= 'ALL'  
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc,
					FilterBettype, FilterBetTeam, FilterSet, FilterGame, FilterValue, FilterGoal, FilterBetOption)
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	

					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId ,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc,
					bm.bettype AS FilterBetType,
					bm.betteam AS FilterBetTeam,
					bm.betcheck AS FilterSet,
					RIGHT(bm.betcheck, 2) AS FilterGame,
					bm.hdp1 + bm.hdp2 AS FilterValue,
					ISNULL(bm.betcheck, 0) AS FilterGoal,
					CAST(CAST(bm.hdp2 AS INT) AS VARCHAR(50)) + '-' + bm.betteam AS FilterBetOption
			FROM	Bettrans b WITH (NOLOCK)	
			INNER HASH JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN @tmpBettypes t ON bm.bettype = t.bettype
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
			WHERE b.statusID NOT IN (101,102)--('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 29 AND b.matchID = 29
				AND bm.matchID = @MatchId
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
				AND (@Quarter = 'All' 
					OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
					OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE bm.betcheck LIKE q.Id + '%'))) 
		END 	
		
		IF @SportType = 43 -- E-Sports
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
		END	
	END 

	-- System parlay Virtual Sports 2799
     IF EXISTS(SELECT 1 FROM @tmpBettypes WHERE bettype =2799)
	BEGIN 
		---Licensee
		IF @LicenseeName <> 'Credit' AND @LicenseeName <> 'CN88' AND @LicenseeName <> 'ALL' 
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc)	
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,		
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,			
					
					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck as SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId ,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc
			FROM	bettransm bm WITH (NOLOCK)	
			INNER HASH JOIN  Bettrans b WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.MatchID	
			WHERE b.srecommend IN ( SELECT custid FROM Dep_CustSuper with(NOLOCK) where site = @LicenseeName) 
				AND b.statusID NOT IN (101,102) --- ('Void', 'Reject' )
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 2799 AND b.matchID = 2799
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
		ELSE 
		
		---IBC
		IF @LicenseeName= 'Credit'  
		BEGIN	
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc)
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	

					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc
			FROM	Bettrans b WITH (NOLOCK) 
			INNER HASH JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
			WHERE b.srecommend NOT IN ( SELECT custid
							   FROM dbo.Dep_CustSuper WITH (NOLOCK)
							   UNION
							   SELECT custid
							   FROM dbo.CS_CustSuper WITH (NOLOCK))
				AND b.statusID NOT IN (101,102) --('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 2799 AND b.matchID = 2799
				AND bm.matchid = @MatchId 	 
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
				AND (@Quarter = 'All' 
					OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
					OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE bm.betcheck LIKE q.Id + '%')))
			OPTION	(RECOMPILE)			
		END 
		---CN88
		IF @LicenseeName= 'CN88'  
		BEGIN	
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc)
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	

					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc
			FROM	Bettrans b WITH (NOLOCK) 
			INNER HASH JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
			WHERE b.srecommend IN (SELECT custid FROM dbo.CS_CustSuper WITH (NOLOCK))
				AND b.statusID NOT IN (101,102) --('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 2799 AND b.matchID = 2799
				AND bm.matchid = @MatchId 	 
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
				AND (@Quarter = 'All' 
					OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
					OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE bm.betcheck LIKE q.Id + '%')))
			OPTION	(RECOMPILE)			
		END 
		---ALL
		IF @LicenseeName= 'ALL'  
		BEGIN
			INSERT INTO #SpecialDeleteBets (username, bettype, OriginalBetType, ExtraInfo, BetdaqId, ActualStake, transid, homeid,
					awayid, hdp1, hdp2, odds, oddsspread, status, stake, transdate,  betteam, betcheck, livehomescore, 
					liveawayscore, IsLiveIndicator, ISNeutral, OddsType, CurrencyName, winlost, betid, IsParlay, SecAcceptFlag,
					refno, TransDesc, SportType, MOdds, BallSequence, WalletType, RefCode, BonusID, MainTransId, custid,
					SubTransID, SubBetType, SubHomeID, SubAwayID, SubHdp1, SubHdp2, SubOdds, SubStake, SubBetTeam, SubBetCheck, SubLiveHomeScore,
					SubLiveAwayScore, SubLiveIndicator, SubLeagueId, SubSportType, SubTransDesc)
			SELECT	b.username,
					b.bettype,				
					b.bettype AS OriginalBetType,
					b.ExtraInfo,
					b.BetdaqId,
					b.actual_stake AS ActualStake,					
					b.transid,	
					m.homeID,
					m.awayID,
					b.hdp1,
					b.hdp2,
					b.odds,
					b.oddsspread,
					CASE WHEN b.status = 'running' AND IsNull(b.SecAcceptFlag, 0) = 1 and IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status 
						 END  as status,
					b.stake,
					b.transdate,
					b.betteam,
					b.betcheck,
					b.livehomescore,
					b.liveawayscore,
					b.liveindicator as IsLiveIndicator,
					isnull(m.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					0 as OddsType,
					b.CurrencyName,
					(b.winlost-b.actual_stake )as winlost,
					b.betid,
					1 as IsParlay,
					0 SecAcceptFlag,
					b.refno,
					b.TransDesc,
					m.SportType,
					b.MOdds,
					NULL AS BallSequence,				
					b.WalletType,
					b.RefCode,
					b.BonusID,
					NULL AS MainTransId,				
					b.custid,	

					bm.transid SubTransID,
					bm.bettype SubBetType,
					m.homeid SubHomeID,
					m.awayid SubAwayID,
					convert(float, bm.hdp1) as SubHdp1, 
					convert(float, bm.hdp2) as SubHdp2, 				  
					bm.odds as SubOdds, 				
					bm.stake SubStake,						
					bm.betteam SubBetTeam,
					bm.betcheck SubBetCheck,
					bm.livehomescore SubLiveHomeScore,
					bm.liveawayscore SubLiveAwayScore,
					bm.liveindicator SubLiveIndicator,
					m.leagueid  as SubLeagueId ,
					m.sporttype as SubSportType,				
					bm.transdesc SubTransDesc
			FROM	Bettrans b WITH (NOLOCK)	
			INNER HASH JOIN  bettransm bm WITH (NOLOCK) ON b.refno = bm.refno 
			INNER JOIN  match m WITH (NOLOCK) ON m.matchid = bm.matchID
			WHERE b.statusID NOT IN (101,102)--('Void', 'Reject')
				AND bm.statusID NOT IN (101, 102) --('Void', 'Reject')
				AND b.bettype = 2799 AND b.matchID = 2799
				AND bm.matchID = @MatchId
				AND CASE WHEN @LiveType <> 2 THEN bm.liveindicator ELSE 0 END = CASE WHEN @LiveType <> 2 THEN @LiveType ELSE 0 END
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveType = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveType = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END
				AND bm.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL AND @LiveType = 1 THEN @FromTransdate ELSE bm.transdate END 
									AND	 CASE WHEN @ToTransdate IS NOT NULL AND @LiveType = 1 THEN @ToTransdate ELSE bm.transdate END
				AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 then ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END
				AND (b.betid = 0 OR b.betid IS NULL)
				AND (@Quarter = 'All' 
					OR (bm.bettype NOT BETWEEN 609 AND 617 AND bm.bettype NOT BETWEEN 627 AND 631 AND bm.bettype NOT BETWEEN 707 AND 714 AND bm.bettype NOT BETWEEN 381 AND 385) 
					OR ((bm.bettype BETWEEN 609 AND 617 OR bm.bettype BETWEEN 627 AND 631 OR bm.bettype BETWEEN 707 AND 714 OR bm.bettype BETWEEN 381 AND 385) AND EXISTS (SELECT TOP 1 1 FROM @tmpQuarter AS q 
																										WHERE bm.betcheck LIKE q.Id + '%')))  
		END 		
	END 

	SELECT  username,
			bettype,		
			OriginalBetType,
			ExtraInfo,
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
	DROP TABLE #tmpRefCodeSummary	
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
END	 