/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidSingleBet_Select] 
(
	@MatchId          INT,
    @Bet              VARCHAR(10)  = NULL,
	@TimeType		  SMALLINT	  = 0,	
    @FromTransdate    DATETIME     = NULL,
    @ToTransdate      DATETIME     = NULL,
    @LiveIndicator    INT          = 0,
    @LiveHomeScore    SMALLINT     = NULL,
    @LiveAwayScore    SMALLINT     = NULL,
    @BetTypes         XML          = NULL,
	@OddsFilter		  XML		   = NULL,
    @SettledType      VARCHAR(100) = 'All',
    @SecondAcceptFlag TINYINT      = 0
)
AS
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
		- 20191011@Charles: Support filter ticket by Checktime in Void Single Bet [121868]
		- 20200508@Charles: PHAIO 5.1 for Penalty [132985]
		- 20200723@Zane: Basketball AIO Phase 2 [137189]
		- 20200911@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
		- 20201009@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210303@July: Enhance data type advance mode [Redmine: #150075]
		- 20210426@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20210622@Helen: [TVS] SP Tuning [Redmine: #157354]
		- 20210630@July: Saba Time Machine - Support multiple HDP/OU value search [Redmine: #157642]
		- 20210722@Max: [TVS HF] Exclude Cash-Out tickets from Void Time Calculation [Redmine: #158294]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220216@July: Fix check ISNULL betdaqid [Redmine: #167055]
		- 20220221@July: Remove SABA of league name for China View sites [Redmine: #168651]
		- 20220301@Max: [TVS] Integrate new bet types of Cricket [Redmine: #168080]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220615@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220705@Max: [TVS] Support multiple selection on Player filter of Cricket AIO [Redmine: #174652] 
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		
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
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ;
					 ValueHdp1="1,2,3"		-- Default : "All" ; Format : 1,2,3,4,...
					 ValueHdp2="2"			-- Default : "All" ; Format : Single Number
					 Goal="2"				-- Default : "All" ; Format : Single Number
					 OddsSpread="1.5"		-- Default : "All" ; Format : 1.5,0.5,1.0,...
					 OddsId="8518"			-- Default : "All" ; Format : 8518,8519,...
					 Transdesc = '100001'	-- Default : "All" ; Format : 100001,100002,... (PlayerId - [Team].[TeamID])
			/>
		 <BetTypes/>'

		- @Bet:
		 + 'All': Search both single and parlay tickets.
		 + 'Single': Search only single tickets.
		 + 'Sub Parlay': Search only parlay tickets.

		 - @TimeType:
		 + 0: TransTime.
		 + 1: CheckTime.

		- @OddsFilter: <root><r o="0.75&1.25" ost="DEC"/></root>

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ValueDefault SMALLMONEY = 9999.00

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT PRIMARY KEY,
		BetTeam			NVARCHAR(MAX), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(250),
		[Value]			VARCHAR(500),
		ValueHdp1		VARCHAR(500),
		ValueHdp2		VARCHAR(20),
		Goal			VARCHAR(10),
		OddsSpread		VARCHAR(500),
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
		
	-- Parse xml @BetTypes
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc)
	SELECT t.c.value('@Id','SMALLINT') AS Id
			, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			, t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			, t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			, t.c.value('@Value','VARCHAR(500)') AS [Value]			-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1			 ; single-choice + multi-choice
			, t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2			 ; single-choice
			, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
			, t.c.value('@OddsSpread','VARCHAR(500)') AS OddsSpread	-- Check columns : OddsSpread	 ; single value + multi-choice
			, t.c.value('@OddsId','VARCHAR(1000)') AS OddsId		-- check columns : OddsId		 ; single-choice + multi-choice
			, t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice + multi-choice
	FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))
			 
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
			 , cte.[Set]
			 , cte.Game
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
				FROM dbo.f_TVS_GetInstantBettypes() T
				WHERE T.InstantType IN (1, 3) -- 01, 11
			ELSE
				INSERT INTO #InstantSettlementBettypes(bettype)
				SELECT T.bettype
				FROM dbo.f_TVS_GetInstantBettypes() T
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
			  checktime          DATETIME,
              bettype            SMALLINT,
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
              TransDesc          NVARCHAR(1000),
              refno              BIGINT,
              mainstatusid       TINYINT, -- store statusid of normal ticket	
              ExtraInfo          VARCHAR(1000),
              IsCashOut			 BIT DEFAULT(0),
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
              FilterHdp1		 SMALLMONEY,
              FilterHdp2		 SMALLMONEY,
			  FilterOddsSpread	 MONEY,
			  FilterOddsId		 INT,
			  FilterTransdesc	 NVARCHAR(2000),
              IsMarked           BIT,
			  ActualStake		 MONEY,
			  OddsId			INT,
			  SiteDBGroupId		SMALLINT
             );

	CREATE TABLE #SpecialDeleteBetsm
             (CustId        INT,
              OddsSpread    MONEY,
              TransDate     DATETIME,
			  checktime		DATETIME,
              LiveIndicator BIT,
              LiveHomeScore SMALLINT,
              LiveAwayScore SMALLINT,
              Creator       INT,
              TransDesc     NVARCHAR(2000),
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
			  SubOddsId		INT,
			  SubTransDesc  NVARCHAR(2000),
			  SiteDBGroupId		SMALLINT
             );

	DECLARE @SportType SMALLINT--, @MatchStatus NVARCHAR(50)

	SELECT	@SportType = Sporttype--, @MatchStatus = eventstatus
	FROM	dbo.match WITH(NOLOCK) 
	WHERE	matchid = @matchid
	
	IF @SportType <> 44
	BEGIN
		SET @SportType = NULL
	END	
	
	DECLARE @Odds_str NVARCHAR(100)
		, @OddsType_Input VARCHAR(29)
	DECLARE @tmp_Odds AS TABLE (Odds SMALLMONEY, OddsType TINYINT)

	SELECT @Odds_str = REPLACE(t.c.value('@o','NVARCHAR(MAX)'), '&', ',')
			, @OddsType_Input = t.c.value('@ost','VARCHAR(20)')
	FROM @OddsFilter.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@OddsFilter = NULL))

	INSERT INTO @tmp_Odds (Odds, OddsType)
	SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Caculate(@Odds_str, @OddsType_Input) f
			
	-- search tickets
	-- Search Single Tickets
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
			,checktime
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
			,IsCashOut
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
			,IsMarked
			,ActualStake
			,OddsId
			,SiteDBGroupId
		)
		SELECT
			b.transid,
			b.transid,
			b.custid,
			b.odds,   
			b.oddsspread,
			b.OddsType,  
			b.transdate,
			b.checktime,
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
			CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END	AS IsCashOut,
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
			CASE WHEN bt.id = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS FilterHdp2, --646: Match Handicap & Total
			CASE WHEN bt.id = 229 THEN ABS(b.oddsspread) ELSE b.oddsspread END AS FilterOddsSpread,-- 229:SABA HDP Time Machine
			b.oddsid AS FilterOddsId,
			b.transdesc AS FilterTransdesc,
			CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked,
			b.actual_stake AS ActualStake,
			b.oddsid
			,b.SiteDBGroupID
		FROM 
			dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = b.bettype
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId				
		WHERE
			b.matchid = @MatchId
			AND CASE
					WHEN @TimeType = 0 THEN b.transdate
					WHEN @TimeType = 1 AND b.checktime IS NOT NULL THEN b.checktime
					WHEN @TimeType = 1 AND b.checktime IS NULL THEN b.transdate
				END BETWEEN @FromTransdate AND @ToTransdate
			AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE b.liveIndicator END = @LiveIndicator
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE b.livehomescore END
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE b.liveawayscore END			
			AND statusID NOT IN (101,102, 103) -- reject, void, refund		
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
				,SubOddsId
				,SubTransDesc
				,SiteDBGroupId
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
				CASE WHEN bt.id = 646 THEN ABS(bm.hdp2) ELSE bm.hdp2 END AS SubHdp2, --646: Match Handicap & Total
				bm.odds As SubOdds,
				CASE WHEN bt.id = 229 THEN ABS(bm.oddsspread) ELSE bm.oddsspread END AS SubOddsSpread,-- 229:SABA HDP Time Machine
				bm.oddsid,
				bm.transdesc
				,bm.SiteDBGroupID
			FROM 
				dbo.bettransm bm WITH (NOLOCK)
				INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = bm.bettype
			WHERE
				bm.matchid=@MatchId
				AND	CASE
						WHEN @TimeType = 0 THEN bm.transdate
						WHEN @TimeType = 1 AND bm.checktime IS NOT NULL THEN bm.checktime
						WHEN @TimeType = 1 AND bm.checktime IS NULL THEN bm.transdate
					END BETWEEN @FromTransdate AND @ToTransdate
				AND CASE WHEN @LiveIndicator = 2 THEN @LiveIndicator ELSE bm.liveIndicator END = @LiveIndicator
				AND bm.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveHomeScore ELSE bm.livehomescore END
				AND bm.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @LiveIndicator = 1 THEN @LiveAwayScore ELSE bm.liveawayscore END			
				AND bm.statusID NOT IN (101,102, 103) -- reject, void, refund
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
				,checktime
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
				,FilterHdp1
				,FilterHdp2
				,FilterGoal
				,FilterOddsSpread
				,FilterOddsId
				,FilterTransdesc
				,ExtraInfo
				,ActualStake
				,OddsId
				,SiteDBGroupId
			)
			SELECT
				b.transid,
				b.transid,
				bm.custid,
				b.odds,   
				bm.oddsspread,
				b.OddsType,  
				bm.transdate,
				bm.checktime,
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
				bm.SubHdp1 AS FilterHdp1,
				CASE WHEN b.bettype = 646 THEN ABS(bm.SubHdp2) ELSE bm.SubHdp2 END AS FilterHdp2, --646: Match Handicap & Total
				ISNULL(bm.SubBetCheck, 0) AS FilterGoal,
				CASE WHEN b.bettype = 229 THEN ABS (bm.SubOddsSpread) ELSE bm.SubOddsSpread END AS FilterOddsSpread, -- 229:SABA HDP Time Machine
				bm.SubOddsId AS FilterOddsId,
				bm.SubTransDesc AS FilterTransdesc,
				b.ExtraInfo,
				b.actual_stake AS ActualStake,
				bm.SubOddsId
				,bm.SiteDBGroupId
			FROM #SpecialDeleteBetsm bm WITH (NOLOCK)
				INNER HASH JOIN dbo.bettrans AS b with (NOLOCK) ON b.matchid	= 29 AND bm.refno = b.refno
		END
	END

	/*
		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY		
		filter for Game : Only handle for bettype 1324		 
		filter for BetOption : Only handle for bettypes 221 -> 227		 
		filter for [Value]		
		filter for ValueHdp1	
		filter for ValueHdp2	  
		filter for Goal
	*/	
	
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
			WHERE tp.Id = b.FilterBettype 
			AND (	tp.[Set] = 'All' OR b.FilterSet LIKE tp.[Set] + '%' ))

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
			WHERE tp.Id = b.FilterBettype AND (tp.OddsId IS NULL OR b.FilterOddsId = tp.OddsId))

		DELETE b
		FROM  #SpecialDeleteBets b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
			WHERE tp.Id = b.FilterBettype AND  (tp.Transdesc IS NULL OR b.FilterTransdesc = tp.Transdesc))
	END	
	
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
			   ,s.checktime
			   ,s.bettype
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
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,CASE WHEN ISNULL(s.betdaqid,0) <> -2 THEN 'Credit' ELSE 'Credit (CO)' END AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
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
			   ,s.ActualStake
			   ,s.SiteDBGroupId
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
			   ,s.checktime	
			   ,s.bettype
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
			   ,b.transid AS followedId
			   ,b.Username AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,'8RM/BARM' AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
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
			   ,s.ActualStake
			   ,s.SiteDBGroupId
		FROM	#SpecialDeleteBets s
			LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON s.betid = b.transid AND b.matchid = @matchid
		WHERE	s.recommend IN (52466, 5707545)
			AND ISNULL(s.betdaqid,0) <> -2 --NOT Cashout
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
			   ,s.checktime	
			   ,s.bettype
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
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,CASE WHEN ISNULL(s.betdaqid,0) <> -2 THEN 'Deposit' ELSE 'Deposit (CO)' END AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
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
			   ,s.ActualStake
			   ,s.SiteDBGroupId
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
		----4: For Betfair
		SELECT  s.GroupID
			   ,s.transid		
			   ,s.custid		
			   ,s.username	
			   ,s.odds
			   ,s.oddsspread			   
			   ,s.OddsType	
			   ,s.transdate
			   ,s.checktime	
			   ,s.bettype
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
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.TransDesc
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.refno
			   ,s.mainstatusid
			   ,'Betfair' AS OriginGroupName
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.IsCashOut
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
			   ,s.ActualStake
			   ,s.SiteDBGroupId
		FROM #SpecialDeleteBets s
			LEFT JOIN #SpecialDeleteBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
			AND ISNULL(s.betdaqid,0) <> -2 --NOT Cashout
	)
	, CTE_CalculateMainBettype AS (
		SELECT s.*
			 , s.bettype AS MainBettype -- normal ticket, then based on its bettype
		FROM CTE_OriginResult s
	)
	, CTE_InstantSettlementSubgrouping AS (
		/*
			Cases for dividing for instant settlement subgroup:
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
									WHEN s.mainstatusid IN (111, 112, 113) AND ISNULL(s.betdaqid,0) <> -2
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
			,s.checktime	
			,s.bettype
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
			,s.followedId
			,s.followedUsername
			,s.TransDesc
			,s.IsCricket
			,s.refno		   
			,s.SubGroupName AS GroupName
			,s.betdaqid
			,s.ExtraInfo
			,s.IsCashOut
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
			,s.ActualStake
			,ISNULL(si.IsChinaView,0) AS IsChinaView
			,CASE WHEN s.SubGroupName LIKE '%(Instant Settlement)' THEN 1 ELSE 0 END AS IsInstantSettlement
			,s.SiteDBGroupId
	FROM CTE_SettledTypeFiltering s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
		LEFT JOIN custDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
	ORDER BY CASE
				WHEN s.OriginGroupName = 'Credit' THEN 1
				WHEN s.OriginGroupName = '8RM/BARM' THEN 2
				WHEN s.OriginGroupName = 'Deposit' THEN 3
				WHEN s.OriginGroupName = 'Betfair' THEN 4
				WHEN s.OriginGroupName = 'Credit (CO)' THEN 5
				WHEN s.OriginGroupName = 'Deposit (CO)' THEN 6
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
	DROP TABLE #InstantSettlementBettypes

	SET NOCOUNT OFF
END