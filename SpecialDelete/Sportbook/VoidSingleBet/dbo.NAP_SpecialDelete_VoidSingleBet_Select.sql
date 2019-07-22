
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidSingleBet_Select] @MatchId          INT,
                                                               @FromTransId      BIGINT       = 0,
                                                               @ToTransId        BIGINT       = 0,
                                                               @Bet              VARCHAR(10)  = NULL,
                                                               @FromTransdate    DATETIME     = NULL,
                                                               @ToTransdate      DATETIME     = NULL,
                                                               @LiveIndicator    INT          = 0,
                                                               @LiveHomeScore    SMALLINT     = NULL,
                                                               @LiveAwayScore    SMALLINT     = NULL,
                                                               @BetTypes         XML          = NULL,
                                                               @SettledType      VARCHAR(100) = 'All',
                                                               @SecondAcceptFlag TINYINT      = 0
AS;
/*
    Created by: Kathy
	Date: 
	Original: [dbo].[Acc_BettransSelSpecialDel]
	Task: Select bets transaction need to delete
	DB: DBTXN/BODB02

	Revisions:
		- 20140102@Kathy: - Add username2 column [Redmine:#10270]
						  - Show settled ticket
		- 20140411@Kathy: - Separate tickets of Bet Fair, OneExchange 3rd parties [Redmine:#10128]
						  - Add 2 new bettypes 1H Total Goal and 1H First Goal/ Last Goal (126, 127) [Redmine:#14749]
		- 20140701@Kathy: Apply BetRadar - change @BetTypes to varchar(1000) [Redmine:#18219]						  
		- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
		- 20140806@Kathy: Support new 11 bettypes [Redmine:#19955]
		- 20140926@Kathy: - Offer new bettypes from Sportting Solutions and new IBC bettypes [Redmine:#23129]
						  - Add moneyline in filter
		- 20141104@Kathy: Change size of username2 to nvarchar(50)
		- 20141112@Kathy: Add 8RM group [Redmine:#22616]
		- 20141125@Kathy: Add betid column [Redmine:##26489]
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20151021@Patrick: Support Muay Thai [Redmine:#46015]
		- 20150611@Dominic: BetTrade Integration [Redmine:#36964]
		- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
		- 20151102@Kathy: Enhance performance [Redmine:#43233]
		- 20150712@Kathy: - Apply 28 Live Bettypes(PH) [Redmine: #48110]
						  - Database - Change datatype [Redmine: #48660]
		- 20150119@Kathy: Changes for phase 1.2 of PH All in One: bettype 4,30,413,414,405 [Redmine:#50932]	  
		- 20160112@Patrick: Support Cricket [Redmine: #50688]
		- 20160401@Bobby: #55354 - Update changes for new message structure
		- 20160426@Bobby: #56641 - Integrate Fast Market bettypes
		- 20160706@Kathy: Get Refno for Lucky Single Ticket [Redmine:#55272]
		- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
		- 20160816@Bobby: #62527 - Update BT's info for showing bet list
		- 20160909@Kent: Add logic for bettype 425, 426, 429 - PH AIO [Redmine:#62880]
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20161101@Elodie: #56641 - Integrate Fast Market new bettypes
		- 20170118@Kent: Support for Instant Settlement [Redmine:#70276]
		- 20170120@Kent: Tuning performance [Redmine:#70276]
		- 20170220@Kent: Add logic of new bettypes in BAIO [Redmine:#71536]
		- 20170303@Kent: Remove param @UserName [Redmine:#71536]
		- 20170308@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20170503@Kent: Integrate bonus [Redmine:#72790]		
		- 20180305@Kathy: Change the '8RM' group to '8RM/BARM' [Redmine:#83737]
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread - Fast Markets Phase 2 [Redmine:#90667]
		- 20180426@Alan: Allow void single and parlay tickets [Redmine:#93167]
		- 20180808@Alan: Allow to void Sub Parlay ticket while the status of main is 'Reject' [Redmine:#99528]
		- 20171029@Alan: Return Licensees Name [103474]
		- 20181003@Alan: Add new column SettlementStatus [102423]
		- 20180821@Alan: Incorporate ESports 2.0 [99448]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]
		
	Explanation's Param:
	    - @SecondAcceptFlag: 
	      + 0: All tickets
          + 1: Normal tickets only
	      + 2: SA tickets only
     
		- @LiveIndicator:
		 + 0: Dead
		 + 1: Live
		 + 2: All
		 
		- @SettledType:
		 + 'All': For user to search for 'Unsettled', 'Refunded', 'Instantly Settled', and 'Normal Settled' tickets.
		 + 'Unsettled': For user to search for 'Running' and 'Refunded' tickets.
		 + 'Instantly': For user to search for settled tickets which have been settled by Instant Settlement during live time.
		 + 'Settled': For user to search for settled tickets which have been settled manually by Keyscore team.
		
		- @BetTypes : 
		'<BetTypes>
			<BetType Id="1" 
					 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
					 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
					 Game="01"				-- Default : "All" ; Format : 0X 
					 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ; Additional handled field : TimeInterval
					 Goal="2"				-- Default : "All" ; Format : Single Number
			/>
		 <BetTypes/>'

		- @Bet:
		 + 'All': Search both single and parlay tickets.
		 + 'Single': Search only single tickets.
		 + 'Sub Parlay': Search only parlay tickets.

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
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
		TimeInterval	SMALLMONEY,	
		Goal			BIGINT
	)
		
	-- Parse xml @BetTypes
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], Goal)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			, t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
	FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))
			 
	INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], TimeInterval, Goal)
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
		 , CAST(CASE WHEN (cte.Id NOT BETWEEN 221 AND 227) AND (cte.Id NOT IN (479, 481)) THEN cte.[Value]
					ELSE 9999.00 END AS SMALLMONEY) AS [Value]
		 , CAST(CASE WHEN (cte.Id BETWEEN 221 AND 227) OR (cte.Id IN (479, 481)) THEN cte.[Value]
					ELSE 9999.00 END AS SMALLMONEY) AS TimeInterval
		 , cte.Goal
	FROM (
		SELECT cte.Id
			 , bt.val AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , bop.val AS BetOption
			 , CAST(CASE WHEN v.val = 'ALL' THEN 9999.00 
						ELSE v.val END AS SMALLMONEY) AS [Value]			 
			 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal END AS BIGINT) AS Goal
		FROM #tblBetType cte
			 CROSS APPLY dbo.strSplit(cte.betteam, ',') bt
			 CROSS APPLY dbo.strSplit(cte.BetOption, ',') bop
			 CROSS APPLY dbo.strSplit(cte.[Value], ',') v
	) cte	
	WHERE CASE WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
			WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
			ELSE 1 END = 1

	DECLARE @SettlementStatus TINYINT = NULL
	SELECT @SettlementStatus = m.SettlementStatus FROM dbo.match m WHERE m.matchid = @MatchId
	
	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(bettype	SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes(bettype)
	
		--> Get status of match
		SELECT @IsHTCal = ISNULL(IsHTCal, 0)		 
		FROM match_remark (NOLOCK)
		WHERE matchid = @MatchId
	
		SELECT @eventstatus = ISNULL(eventstatus, '')
		FROM match (NOLOCK)
		WHERE matchid = @MatchId		
	
		--> Build bettype list supported for instant settlement based on settlement status of match
		IF @eventstatus <> @eventstatus_completed
		BEGIN
			IF @IsHTCal = 0
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_Set_Instant_GetBettypes() T
				WHERE T.InstantType IN (1, 3) -- 01, 11
			ELSE
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_Set_Instant_GetBettypes() T
				WHERE T.InstantType IN (2, 3) -- 10, 11			
		END	 	
	END		 
	
	CREATE TABLE #SpecialDeleteBets
             (GroupID            BIGINT,
              transid            BIGINT,
              custid             INT,
              username           VARCHAR(30),
              oddsspread         MONEY,
              odds               MONEY,
              OddsType           INT,
              transdate          DATETIME,
              bettype            SMALLINT,
              OriginalBetType    SMALLINT,
              betteam            NVARCHAR(10),
              betcheck           NVARCHAR(50),
              hdp1               SMALLMONEY,
              hdp2               SMALLMONEY,
              IsLiveIndicator    BIT,
              livehomescore      SMALLINT,
              liveawayscore      SMALLINT,
              creator            INT,
              Stake              MONEY,
              CurrencyName       VARCHAR(10),
              IsDeposit          BIT DEFAULT(0),
              IsCricket          BIT DEFAULT(0),
              status             NVARCHAR(10),
              srecommend         INT,
              mrecommend         INT,
              recommend          INT,
              SecAcceptFlag      BIT,
              betid              BIGINT,
              betdaqid           BIGINT,
              SportType          SMALLINT,
              SoldId             BIGINT, -- stored transid of BTrade's subticket (bettype 901)
              TransDesc          NVARCHAR(1000),
              refno              BIGINT,
              mainstatusid       TINYINT, -- store statusid of normal ticket, or statusid of main ticket for bettrade 901		
              ExtraInfo          VARCHAR(1000),
              MainCashoutId      BIGINT,
              matchid            INT,
              WalletType         TINYINT,
              RefCode            BIGINT,
              BonusID            INT,
              MainTransId        BIGINT,
              WinLost            MONEY,
              IsMixParlay        BIT DEFAULT(0),
              SubTransId         BIGINT,
              SubStatus          NVARCHAR(10),
              SubBetCheck        NVARCHAR(50),
              SubBetTeam         NVARCHAR(10),
              SubBetType         SMALLINT DEFAULT(0),
              SubHdp1            SMALLMONEY,
              SubHdp2            SMALLMONEY,
              SubOdds            MONEY,
              FilterBettype      SMALLINT,
              FilterBetTeam      NVARCHAR(10),
              FilterSet          VARCHAR(50),
              FilterGame         VARCHAR(50),
              FilterValue        SMALLMONEY,
              FilterGoal         BIGINT,
              FilterBetOption    NVARCHAR(50),
              FilterTimeInterval SMALLMONEY,
              IsMarked           BIT
             );

	CREATE TABLE #SpecialDeleteBetsm
             (CustId        INT,
              OddsSpread    MONEY,
              TransDate     DATETIME,
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
              SubOdds       MONEY
             );
	
	CREATE TABLE #tmpRefCodeSummary
             (RefCode BIGINT,
              custid  INT,
              bettype SMALLINT,
              transid BIGINT,
		    IsMarked BIT
             );

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	DECLARE @SportType SMALLINT--, @MatchStatus NVARCHAR(50)
	
	SELECT	@SportType = Sporttype--, @MatchStatus = eventstatus
	FROM	dbo.match WITH(NOLOCK) 
	WHERE	matchid = @matchid
	
	IF @SportType <> 44
	BEGIN
		SET @SportType = NULL
	END		
			
	-- search tickets
	-- Search Single Tickets
	IF @FromTransId > 0
	BEGIN
		INSERT INTO #SpecialDeleteBets (
			GroupID
			,transid
			,custid	
			,odds
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
			,mainstatusid
			,ExtraInfo
			,MainCashoutId
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
			,FilterTimeInterval
			,IsMarked
		)
		SELECT
			b.transid,
			b.transid,
			b.custid,
			b.odds,   
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
			b.stake,
			b.CurrencyName, 
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
										   AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status END AS status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			ISNULL(SecAcceptFlag,0) SecAcceptFlag,
			b.betid,
			b.betdaqid,
			b.transdesc,
			b.refno,			
			b.statusID AS mainstatusid,
			b.ExtraInfo,
			CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
				ELSE NULL
			END	AS MainCashoutId,
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
			b.hdp1 AS FilterTimeInterval,
			CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = b.bettype
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId		
		WHERE
			b.matchid = @MatchId 
			AND b.transid BETWEEN @FromTransId AND @ToTransId
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveIndicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END			
			AND statusID NOT IN (101,102 ) -- reject, void		
			AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END	
			AND b.betfrom <> 'p'	
	END

	IF @Bet = 'All' OR @Bet = 'Single'
	BEGIN
		INSERT INTO #SpecialDeleteBets (
			GroupID
			,transid
			,custid	
			,odds
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
			,mainstatusid
			,ExtraInfo
			,MainCashoutId
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
			,FilterTimeInterval
			,IsMarked
		)
		SELECT
			b.transid,
			b.transid,
			b.custid,
			b.odds,   
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
			b.stake,
			b.CurrencyName, 
			CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
										   AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				 ELSE b.status END AS status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			ISNULL(SecAcceptFlag,0) SecAcceptFlag,
			b.betid,
			b.betdaqid,
			b.transdesc,
			b.refno,			
			b.statusID AS mainstatusid,
			b.ExtraInfo,
			CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
				ELSE NULL
			END	AS MainCashoutId,
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
			b.hdp1 AS FilterTimeInterval,
			CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = b.bettype
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId				
		WHERE
			b.matchid = @MatchId 
			AND b.transdate BETWEEN @FromTransdate AND @ToTransdate
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveIndicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END			
			AND statusID NOT IN (101,102 ) -- reject, void		
			AND ISNULL(b.SecAcceptFlag,0) = CASE @SecondAcceptFlag WHEN 0 THEN ISNULL(b.SecAcceptFlag,0) WHEN 1 THEN 0 WHEN 2 THEN 1 END	
			AND b.betfrom <> 'p'	
	END

	-- Search Parlay Tickets
	IF @Bet = 'All' OR @Bet = 'Sub Parlay'	
	BEGIN
		BEGIN
			INSERT INTO #SpecialDeleteBetsm (
				CustId
				,OddsSpread			
				,TransDate				
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
			)
			SELECT
				bm.custid, 
				bm.oddsspread,
				bm.transdate,
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
				bm.hdp2 AS SubHdp2,
				bm.odds As SubOdds
				
			FROM 
				dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = bm.bettype
			WHERE
				bm.matchid=@MatchId 
				AND bm.transdate BETWEEN @FromTransdate AND @ToTransdate
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE bm.liveIndicator END = @LiveIndicator
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END			
				AND bm.statusID NOT IN (101,102) -- reject, void
				AND bm.betfrom <> 'p'
		END

		BEGIN
			INSERT INTO #SpecialDeleteBets (
				GroupID
				,transid			
				,custid			
				,odds
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
				,mainstatusid
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
				,FilterGoal
			)
			SELECT
				b.transid,
				b.transid,
				bm.custid,
				b.odds,   
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
				b.stake,
				b.CurrencyName, 
				b.status,
				b.srecommend,
				b.mrecommend,
				b.recommend,
				b.betid,
				b.betdaqid,
				bm.transdesc,
				bm.refno,			
				b.statusID AS mainstatusid,
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
				ISNULL(bm.SubBetCheck, 0) AS FilterGoal
			FROM #SpecialDeleteBetsm bm WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS b with (NOLOCK) ON b.matchid	= 29 AND bm.refno = b.refno
		END
	END

	/*
		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY		
		filter for Game : Only handle for bettype 1324		 
		filter for BetOption : Only handle for bettypes 221 -> 227		 
		filter for [Value]		
		filter for TimeInterval		 
		filter for Goal
	*/	
	
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
			WHERE tp.Id = b.FilterBettype AND (tp.BetOption = 'All' OR b.FilterBetOption = tp.BetOption ) OR b.bettype = 29)

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND (tp.TimeInterval = 9999 OR b.FilterTimeInterval = tp.TimeInterval ) OR b.bettype = 29) 
	END	

	-- delete cash-out member bet tickets
	DELETE t
	FROM #SpecialDeleteBets t
	WHERE EXISTS (SELECT TOP 1 1
				  FROM bettrans sub911 (NOLOCK)
				  WHERE sub911.bettype = 911
				    AND sub911.transid = t.refno)
	
	-- update MainTransId	
	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
	BEGIN
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
				, MAX(transid) AS transid
		FROM	#SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, IsMarked
		HAVING COUNT(*) = 1	
	
		IF @@ROWCOUNT > 0
		BEGIN		
			INSERT INTO #SpecialDeleteBets(
					GroupID
					,transid			
					,custid						
					,odds
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
					,Stake			
					,CurrencyName				
					,status			
					,srecommend
					,mrecommend		
					,recommend		
					,SecAcceptFlag	
					,betid			
					,betdaqid
					,refno			
					,mainstatusid
					,ExtraInfo	
					,MainCashoutId
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,WinLost
					,IsMarked					
				)
			SELECT  b.transid,
					b.transid,
					b.custid,			
					b.odds, 
					b.oddsspread,					
					b.OddsType,  
					b.transdate,
					b.bettype,
					b.betteam,
					betcheck,
					b.hdp1,
					b.hdp2,
					b.liveindicator,
					b.livehomescore,
					b.liveawayscore,
					b.creator,
					b.stake,
					b.CurrencyName, 			
					CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						 ELSE b.status END AS status,
					b.srecommend,
					b.mrecommend,
					b.recommend,
					ISNULL(SecAcceptFlag,0) SecAcceptFlag,
					b.betid,
					b.betdaqid,
					b.refno,			
					b.statusID AS mainstatusid,	
					b.ExtraInfo,			
					CASE WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
						ELSE NULL
					END AS MainCashoutId,					
					b.WalletType,
					b.RefCode,
					b.BonusID,
					t.transid AS MainTransId,
					b.WinLost - b.actual_stake AS WinLost,
					t.IsMarked	
			FROM #tmpRefCodeSummary t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = @MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE b.statusID NOT IN (101,102 ) -- reject, void	  
		END 			    				    				    				    					    
	END

	-- update SoldId column: if main ticket is BT, update SoldId = transid of subticket(901)
	CREATE TABLE #tblSoldTicket (transid BIGINT PRIMARY KEY)
	
	UPDATE	main
		SET main.SoldId = sub.transid
	OUTPUT INSERTED.SoldId
	INTO #tblSoldTicket(transid)
	FROM #SpecialDeleteBets main 
		INNER JOIN dbo.bettrans sub WITH (NOLOCK)
			ON	main.transid = sub.refno
				AND main.betdaqid = 0 -- main ticket is BTrade
				AND main.extrainfo is null -- main ticket is BTrade
				AND sub.matchid = @MatchId
				AND sub.bettype = 901
				
	-- get sub ticket of BetTrade (901)
	INSERT INTO #SpecialDeleteBets (			 
			GroupID
			,transid			
			,custid				
			,odds
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype
			,OriginalBetType			
			,betteam			
			,betcheck		
			,hdp1			
			,hdp2			
			,IsLiveIndicator	
			,livehomescore 	
			,liveawayscore 	
			,creator			
			,Stake			
			,CurrencyName			
			,status			
			,srecommend
			,mrecommend		
			,recommend		
			,SecAcceptFlag	
			,betid			
			,betdaqid			
			,mainstatusid	
			,ExtraInfo					
			,refno
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,WinLost
			,IsMarked
		)
	SELECT  main.transid
			,sub.transid
			,sub.custid
			,main.odds
			,main.oddsspread
			,main.OddsType
			,sub.transdate
			,sub.bettype
			,main.bettype  AS OriginalBetType
			,main.betteam
			,main.betcheck
			,main.hdp1
			,main.hdp2
			,main.IsLiveIndicator
			,main.livehomescore
			,main.liveawayscore
			,sub.creator
			,main.Stake
			,main.CurrencyName
			,'SOLD'
			,main.srecommend
			,main.mrecommend
			,main.recommend
			,ISNULL(main.SecAcceptFlag,0) SecAcceptFlag
			,main.bettype AS betid
			,sub.betdaqid			
			,main.mainstatusid
			,sub.ExtraInfo			
			,sub.refno
			,sub.WalletType
			,sub.RefCode
			,sub.BonusID
			,main.transid AS MainTransId
			,sub.WinLost - sub.actual_stake AS WinLost
			,IsMarked
	FROM	#SpecialDeleteBets main
		INNER JOIN dbo.bettrans sub WITH (NOLOCK)
			ON	main.transid = sub.refno
				AND main.betdaqid = 0 -- main ticket is BTrade
				AND main.extrainfo is null -- main ticket is BTrade
				AND sub.matchid = @MatchId
				AND sub.bettype = 901
		INNER JOIN #tblSoldTicket sold ON sold.transid = sub.transid							
			
	-- get sub ticket of Cash-out (911)	
	INSERT INTO #SpecialDeleteBets (
			GroupID
			,transid			
			,custid				
			,odds	
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype
			,OriginalBetType			
			,betteam			
			,betcheck		
			,hdp1			
			,hdp2			
			,IsLiveIndicator	
			,livehomescore 	
			,liveawayscore 	
			,creator			
			,Stake			
			,CurrencyName			
			,status			
			,srecommend
			,mrecommend		
			,recommend		
			,SecAcceptFlag	
			,betid			
			,betdaqid			
			,mainstatusid	
			,ExtraInfo
			,MainCashoutId
			,refno
			,matchid
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,WinLost
			,IsMarked
		)
	SELECT  sub911.transid
			,sub911.transid
			,sub911.custid
			,main.odds
			,main.oddsspread
			,main.OddsType
			,sub911.transdate
			,sub911.bettype
			,main.bettype  AS OriginalBetType
			,main.betteam
			,main.betcheck
			,main.hdp1
			,main.hdp2
			,main.IsLiveIndicator
			,main.livehomescore
			,main.liveawayscore
			,sub911.creator
			,sub911.Stake
			,main.CurrencyName
			,'Cash out'
			,main.srecommend
			,main.mrecommend
			,main.recommend
			,ISNULL(main.SecAcceptFlag,0) SecAcceptFlag
			,main.bettype AS betid
			,sub911.betdaqid			
			,main.mainstatusid
			,sub911.ExtraInfo
			,main.transid AS MainCashoutId
			,sub911.refno
			,sub911.matchid
			,sub911.WalletType
			,sub911.RefCode
			,sub911.BonusID
			,main.transid AS MainTransId
			,sub911.WinLost - sub911.actual_stake AS WinLost
			,main.IsMarked
	FROM dbo.bettrans sub911 WITH (NOLOCK)
		 INNER JOIN #SpecialDeleteBets main
				ON	sub911.refno = main.transid	
					AND sub911.custid = main.custid
					AND main.betdaqid = 0
					AND charindex ('p25',main.extrainfo)> 0			
					AND sub911.bettype = 911
					AND sub911.matchid = @matchid
	WHERE sub911.statusID NOT IN (102, 101) -- VOID, REJECT																			
	
	-- get cash-out member bet tickets
	INSERT INTO #SpecialDeleteBets(
			GroupID
			,transid			
			,custid						
			,odds	
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype
			,OriginalBetType						
			,betteam			
			,betcheck		
			,hdp1			
			,hdp2			
			,IsLiveIndicator	
			,livehomescore 	
			,liveawayscore 	
			,creator			
			,Stake			
			,CurrencyName				
			,status			
			,srecommend
			,mrecommend		
			,recommend		
			,SecAcceptFlag	
			,betid			
			,betdaqid
			,refno			
			,mainstatusid	
			,ExtraInfo
			,MainCashoutId
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,WinLost
			,IsMarked
		)
	SELECT  sub911.transid,
			b.transid,
			b.custid,			
			b.odds,  
			b.oddsspread,
			b.OddsType,  
			b.transdate,
			b.bettype,
			sub911.OriginalBetType,			  
			b.betteam,
			b.betcheck,
			b.hdp1,
			b.hdp2,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.creator,
			b.stake,
			b.CurrencyName, 			
			b.status,
			b.srecommend,
			b.mrecommend,
			b.recommend,
			ISNULL(b.SecAcceptFlag,0) SecAcceptFlag,
			b.betid,
			b.betdaqid,
			b.refno,			
			b.statusID AS mainstatusid,
			b.ExtraInfo,
			sub911.MainCashoutId,
			b.WalletType,
			b.RefCode,
			b.BonusID,
			sub911.MainTransId,
			b.WinLost - b.actual_stake AS WinLost,
			sub911.IsMarked
	FROM #SpecialDeleteBets sub911
		 CROSS APPLY (	SELECT b.*
						FROM dbo.bettrans b WITH (NOLOCK)
						WHERE b.refno = sub911.transid
						AND b.matchid = sub911.matchid
						AND b.bettype = sub911.OriginalBetType
						AND b.statusID NOT IN (102, 101) -- VOID, REJECT
					) AS b	
	WHERE sub911.bettype = 911
	
	-- update username/creatorname column, Isdeposit
	UPDATE al
	SET username = CASE WHEN ci.IsExisted IS NOT NULL THEN ci.username
						ELSE al.username
				   END
	   ,SportType = CASE WHEN ci.IsExisted IS NOT NULL AND cr.IsExisted IS NOT NULL THEN @SportType
						ELSE al.SportType
					END
	   ,IsDeposit = CASE WHEN T.IsExisted IS NOT NULL THEN 1
						ELSE al.IsDeposit
					END
	FROM #SpecialDeleteBets al
		 OUTER APPLY (SELECT TOP 1 1 AS IsExisted , ci.username
					  FROM CustDB.dbo.custInfo ci WITH(NOLOCK)
					  WHERE al.custid = ci.custid) AS ci
		 OUTER APPLY (SELECT TOP 1 1 AS IsExisted , cr.username
					  FROM CustDB.dbo.custInfo cr WITH(NOLOCK)
					  WHERE al.creator = cr.custid) AS cr	
		OUTER APPLY (SELECT TOP 1 1 AS IsExisted
					 FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend) AS T					 					 					  				  		

	;WITH CTE_OriginResult AS (
		--1. For Normal bets
		SELECT  s.GroupID
			   ,s.transid		
			   ,s.custid		
			   ,s.username	
			   ,s.odds		
			   ,s.oddsspread
			   ,s.OddsType	
			   ,s.transdate	
			   ,s.bettype
			   ,s.OriginalBetType		
			   ,s.betteam		
			   ,s.betcheck
			   ,s.hdp1		
			   ,s.hdp2		
			   ,s.IsLiveIndicator
			   ,s.livehomescore
			   ,s.liveawayscore	
			   ,s.Stake		
			   ,s.CurrencyName
			   ,s.IsDeposit	
			   ,s.status		
			   ,s.mrecommend	
			   ,s.recommend	
			   ,s.SecAcceptFlag	
			   ,s.betid	
			   ,s.SportType	 
			   ,s.SoldID
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,'Credit' AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.WalletType
			   ,s.RefCode
			   ,s.BonusID
			   ,s.MainTransId
			   ,s.WinLost
			   ,s.IsMixParlay
			   ,s.SubTransid
			   ,s.SubStatus
			   ,s.SubBetcheck
			   ,s.SubBetteam
			   ,s.SubBettype
			   ,s.SubHdp1
			   ,s.SubHdp2
			   ,s.SubOdds
			   ,s.IsMarked
		FROM	#SpecialDeleteBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	f.CustID IS NULL
				AND (s.username <> '12EU' AND ISNULL(sub.username,'') <> '12EU')
				AND s.IsDeposit = 0
				AND s.mrecommend NOT IN (105181, 118473, 105183) -- MHC
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				AND (s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 
					AND ISNULL(sub.custid,0) NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
				)  -- Betfair: BFOS, BF, ITibc102, BF3	
		UNION ALL
		----2: For 8RM/BARM
		SELECT  s.GroupID
			   ,s.transid		
			   ,s.custid		
			   ,s.username	
			   ,s.odds		
			   ,s.oddsspread		
			   ,s.OddsType	
			   ,s.transdate	
			   ,s.bettype
			   ,s.OriginalBetType		
			   ,s.betteam		
			   ,s.betcheck
			   ,s.hdp1		
			   ,s.hdp2		
			   ,s.IsLiveIndicator
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.Stake		
			   ,s.CurrencyName
			   ,s.IsDeposit	
			   ,s.status		
			   ,s.mrecommend	
			   ,s.recommend	
			   ,s.SecAcceptFlag	
			   ,s.betid	
			   ,s.SportType	 
			   ,s.SoldID
			   ,b.transid AS followedId
			   ,b.Username AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,'8RM/BARM' AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.WalletType
			   ,s.RefCode
			   ,s.BonusID
			   ,s.MainTransId
			   ,s.WinLost
			   ,s.IsMixParlay
			   ,s.SubTransid
			   ,s.SubStatus
			   ,s.SubBetcheck
			   ,s.SubBetteam
			   ,s.SubBettype
			   ,s.SubHdp1
			   ,s.SubHdp2
			   ,s.SubOdds
			   ,s.IsMarked
		FROM	#SpecialDeleteBets s
			LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON s.betid = b.transid AND b.matchid = @matchid
		WHERE	s.recommend IN (52466, 5707545)
		UNION ALL
		----3. For Deposit bets
		SELECT  s.GroupID
			   ,s.transid		
			   ,s.custid		
			   ,s.username	
			   ,s.odds
			   ,s.oddsspread			   
			   ,s.OddsType	
			   ,s.transdate	
			   ,s.bettype
			   ,s.OriginalBetType		
			   ,s.betteam		
			   ,s.betcheck
			   ,s.hdp1		
			   ,s.hdp2		
			   ,s.IsLiveIndicator
			   ,s.livehomescore
			   ,s.liveawayscore	
			   ,s.Stake		
			   ,s.CurrencyName
			   ,s.IsDeposit	
			   ,s.status		
			   ,s.mrecommend	
			   ,s.recommend	
			   ,s.SecAcceptFlag	
			   ,s.betid		 
			   ,s.SportType
			   ,s.SoldID
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,'Deposit' AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.WalletType
			   ,s.RefCode
			   ,s.BonusID
			   ,s.MainTransId
			   ,s.WinLost
			   ,s.IsMixParlay
			   ,s.SubTransid
			   ,s.SubStatus
			   ,s.SubBetcheck
			   ,s.SubBetteam
			   ,s.SubBettype
			   ,s.SubHdp1
			   ,s.SubHdp2
			   ,s.SubOdds
			   ,s.IsMarked
		FROM #SpecialDeleteBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
		WHERE	f.CustID IS NULL -- Betdaq
				AND (s.username <> '12EU' AND ISNULL(sub.username,'') <> '12EU')
				AND s.IsDeposit = 1	
				AND s.mrecommend NOT IN (105181, 118473, 105183)
				AND s.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466, BARM : 5707545
				AND ( s.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 
					AND ISNULL(sub.custid,0) NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3	
				) 
		UNION ALL
		----8: For Betfair
		SELECT  s.GroupID
			   ,s.transid		
			   ,s.custid		
			   ,s.username	
			   ,s.odds
			   ,s.oddsspread			   
			   ,s.OddsType	
			   ,s.transdate	
			   ,s.bettype
			   ,s.OriginalBetType		
			   ,s.betteam		
			   ,s.betcheck
			   ,s.hdp1		
			   ,s.hdp2		
			   ,s.IsLiveIndicator
			   ,s.livehomescore
			   ,s.liveawayscore	
			   ,s.Stake		
			   ,s.CurrencyName
			   ,s.IsDeposit	
			   ,s.status		
			   ,s.mrecommend	
			   ,s.recommend	
			   ,s.SecAcceptFlag	
			   ,s.betid	
			   ,s.SportType	 
			   ,s.SoldID
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,'Betfair' AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.WalletType
			   ,s.RefCode
			   ,s.BonusID
			   ,s.MainTransId
			   ,s.WinLost
			   ,s.IsMixParlay
			   ,s.SubTransid
			   ,s.SubStatus
			   ,s.SubBetcheck
			   ,s.SubBetteam
			   ,s.SubBettype
			   ,s.SubHdp1
			   ,s.SubHdp2
			   ,s.SubOdds
			   ,s.IsMarked
		FROM #SpecialDeleteBets s
			LEFT JOIN #SpecialDeleteBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
	)
	, CTE_CalculateMainBettype AS (
		SELECT s.*
			 , CASE
					WHEN s.bettype IN (901, 911) THEN s.OriginalBetType -- sub bettrade 901 and sub cashout 911, then based on bettype of main
					ELSE s.bettype -- normal ticket, then based on its bettype
			   END AS MainBettype
		FROM CTE_OriginResult s
	)
	, CTE_InstantSettlementSubgrouping AS (
		/*
			Cases for dividing for instant settlement subgroup (subgroup of sub bettrade 901 will get from main bettrade) :
				1. Before match is kicked off : No ticketes in group 'Instant Settlement'.
				2. Before HT calculated : Ticketes that are settled ('WON', 'LOSE', 'DRAW')
										  and their bettype in list of HT instant settlement bettypes are in group 'Instant Settlement'
				3. After HT calculated : Ticketes that are settled  ('WON', 'LOSE', 'DRAW')
										 and bettype in list of FT instant settlement bettypes are in group 'Instant Settlement'
				4. After match is completed : No ticketes in group 'Instant Settlement'.
		*/
		SELECT  s.*
			   ,CASE 
					WHEN @eventstatus <> @eventstatus_completed -- cases 1, 2, 3 
							THEN CASE
									WHEN s.mainstatusid IN (111, 112, 113)
										 AND EXISTS (SELECT TOP 1 1
													 FROM #InstantSettlementBettypes
													 WHERE bettype = s.MainBettype)
											THEN s.OriginGroupName + ' (Instant Settlement)'
									ELSE s.OriginGroupName
								 END
					ELSE s.OriginGroupName -- case 4
				END AS SubGroupName
		FROM CTE_CalculateMainBettype s
	)
	, CTE_SettledTypeFiltering AS (
		SELECT s.*
		FROM CTE_InstantSettlementSubgrouping s
		WHERE CASE
					WHEN @SettledType = 'All' THEN 1
					WHEN @SettledType = 'Unsettled' 
							THEN CASE WHEN s.mainstatusid IN (0, 103) THEN 1
									ELSE 0
								 END
					WHEN @SettledType = 'Instantly' 
							THEN CASE WHEN s.SubGroupName LIKE '%(Instant Settlement)' THEN 1
									ELSE 0
								 END
					WHEN @SettledType = 'Settled' 
							THEN CASE WHEN s.mainstatusid IN (111, 112, 113)
										 AND s.SubGroupName NOT LIKE '%(Instant Settlement)' THEN 1
									ELSE 0
								 END
					ELSE 1
			  END = 1
	)	
	SELECT  s.transid		
			,s.custid		
			,s.username	
			,s.odds
			,s.oddsspread		   
			,s.OddsType	
			,s.transdate	
			,s.bettype
			,s.OriginalBetType		
			,s.betteam		
			,s.betcheck
			,s.hdp1		
			,s.hdp2		
			,s.IsLiveIndicator
			,s.livehomescore
			,s.liveawayscore
			,s.Stake		
			,s.CurrencyName
			,s.IsDeposit	
			,s.status		
			,s.mrecommend	
			,s.recommend	
			,s.SecAcceptFlag	
			,s.betid	
			,s.SportType	 
			,s.SoldID
			,s.followedId
			,s.followedUsername
			,s.TransDesc
			,s.IsCricket
			,s.refno		   
			,s.SubGroupName AS GroupName
			,s.betdaqid
			,s.ExtraInfo
			,s.MainCashoutId
			,s.WalletType		   
			,S.MainTransId
			,s.RefCode	
			,s.WinLost
			,s.IsMixParlay		
			,s.SubTransid
			,s.SubStatus
			,s.SubBetcheck
			,s.SubBetteam
			,s.SubBettype
			,s.SubHdp1
			,s.SubHdp2
			,s.SubOdds
			,c.site AS LicenseeName
			,@SettlementStatus AS SettlementStatus
			,s.IsMarked
	FROM CTE_SettledTypeFiltering s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
	ORDER BY CASE
				WHEN s.OriginGroupName = 'Credit' THEN 1
				WHEN s.OriginGroupName = '8RM/BARM' THEN 2
				WHEN s.OriginGroupName = 'Deposit' THEN 3
				WHEN s.OriginGroupName = 'Betfair' THEN 4
			 END
		   , CASE WHEN s.SubGroupName NOT LIKE '%(Instant Settlement)' THEN 1
				ELSE 2
			 END
		   , ISNULL(s.MainTransId, s.transid)
		   , CASE WHEN s.BonusID IS NOT NULL
				THEN CASE WHEN s.MainTransId IS NULL THEN 1
					ELSE 2 END
				ELSE s.transid
			 END
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #SpecialDeleteBetsm
	DROP TABLE #tblBettype
	DROP TABLE #tblBetType_Detail
	DROP TABLE #tblSoldTicket
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #tmpRefCodeSummary
	SET NOCOUNT OFF
END