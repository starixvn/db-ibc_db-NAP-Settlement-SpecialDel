/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransSelSpecialDel_EarlyKO] @MatchID     INT,
                                                          @KickOffDate DATETIME,
                                                          @BetTypes    XML      = NULL
AS;
/*  
 Created by: Kathy
 Date: 20131125
 Original: ACC_BettransSelSpecialDel_EarlyKO
 Task: Get ticket information needed to be voided for early kickoff
 DB: DBAGE/BODB02  
  
 Revisions:  
	- 20140102@Kathy: - Add username2 column [Redmine:#10270]
					  - Show settled ticket
	- 20140411@Kathy: - Separate tickets of Bet Fair, OneExchange 3rd parties [Redmine:#10128]
					  - Add 2 new bettypes 1H Total Goal and 1H First Goal/ Last Goal (126, 127) [Redmine:#14749]
	- 20140701@Kathy: Apply BetRadar - change @BetTypes to varchar(1000) [Redmine:#18219]
	- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]	
	- 20140806@Kathy: Support new 11 bettypes [Redmine:#19955]
	- 20140929@Kathy: - Offer new bettypes from Sportting Solutions and new IBC bettypes [Redmine:#23129]
					  - Add moneyline in filter
	- 20141104@Kathy: Change size of username2 to nvarchar(50)
	- 20141112@Kathy: Add 8RM group [Redmine:#22616]
	- 20141125@Kathy: Add betid column [Redmine:##26489]
	- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
	- 20150611@Dominic: BetTrade Integration [Redmine:#36964]
	- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]
	- 20151021@Patrick: Support Muay Thai [Redmine:#46015]
	- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
	- 20151102@Kathy: Enhance performance [Redmine:#43233]
	- 20151302@Kathy: add modds column 
	- 20150712@Kathy: - Apply 28 Live Bettypes(PH) [Redmine: #48110]
					  - Database - Change datatype [Redmine: #48660]
	- 20150119@Kathy: Changes for phase 1.2 of PH All in One: bettype 4,30,413,414,405 [Redmine:#50932]	  					  
	- 20160112@Patrick: Support Cricket [Redmine: #50688]
	- 20160401@Bobby: #55354 - Update changes for new message structure
	- 20160426@Bobby: #56641 - Integrate Fast Market bettypes
	- 20160421@Kathy: Add bettrans.betcheck, hdp1, hdp2 columns to support Combo Parlay [Redmine:#55272]
	- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
	- 20160816@Bobby: #62527 - Update BT's info for showing bet list
	- 20160909@Kent: Add logic for bettype 425, 426, 429 - PH AIO [Redmine:#62880]
	- 20161101@Elodie: #56641 - Integrate Fast Market new bettypes
	- 20170220@Kent: Add logic of new bettypes in BAIO [Redmine:#71536]
	- 20170313@Kent: Integrate cash-out [Redmine:#72059]
	- 20170417@Kent: Tune performance [Redmine:#72059]
	- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
	- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
	- 20170503@Kent: Integrate bonus [Redmine:#72790]
	- 20180306@Kathy: get Refcode value [Redmine:#91461]
	- 20180301@Benjamin: Add oddsspread and Bettype 226, 227 - Fast Markets Phase 2 [Redmine:#90667]
	- 20181004@Alan: Add new column SettlementStatus [102423]
	- 20180821@Alan: Incorporate ESports 2.0 [99448]
	- 20190426@Jacob: Mark Tickets - Enhancement [112480]
	- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]		  
	- 20190301@Alan: Implement Bet Builder - [106898]
	- 20190812@Charles: Add new column IsMarked [118437]
	- 20200723@Zane: Basketball AIO Phase 2 - [137189]
	- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
	- 20201009@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
	- 20201126@Charles: God of fortune [Redmine: #146053]

 Param's Explanation:
	- @BetTeam430: bettype =4: Correct Score ; bettype =30: 1st Correct Score
	- @BetTeam6: bettype=6: Total Goal; bettype = 126: 1st Total Goal
	- @BetTeam14: bettype=14: First Goal/Last Goal; bettype = 127: 1st First Goal/ Last Goal
	- @BetTeam16: bettype=16: Half Time/Full Time
	- @BetOptionXXX: formation.('[[hdp2-value]-[betteam-value]]^...n') & Example.('1-1^2-2^4-4')
  
*/
BEGIN
	SET NOCOUNT ON	

	CREATE TABLE #SpecialDeleteBets
             (GroupID               BIGINT,
              transid               BIGINT,
              SubTransid            BIGINT,
              refno                 BIGINT,
              custid                INT,
              username              VARCHAR(30),
              odds                  MONEY,
              choiceOdds            MONEY,
              oddsspread            MONEY,
              OddsType              INT,
              transdate             DATETIME,
              bettype               SMALLINT,
              OriginalBetType       SMALLINT,
              betteam               NVARCHAR(10),
              ChoiceBetTeam         NVARCHAR(10),
              betcheck              NVARCHAR(50),
              choiceBetcheck        NVARCHAR(50),
              choicehdp1            SMALLMONEY,
              choicehdp2            SMALLMONEY,
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
              ChoiceStatus          NVARCHAR(10),
              srecommend            INT,
              mrecommend            INT,
              recommend             INT,
              ChoiceLeagueId        INT,
              betid                 BIGINT DEFAULT(0),
              Transdesc             NVARCHAR(1000),
              betdaqid              BIGINT,
              ParlayType            SMALLINT DEFAULT(0)
              , -- sub bettype of parlay 
              IsMixParlay           BIT DEFAULT(0),
              SoldId                BIGINT,
              sporttype             SMALLINT,
              modds                 MONEY,
              ExtraInfo             VARCHAR(1000),
              IsCashOutMemberTicket BIT DEFAULT 0,
              MainCashoutId         BIGINT,
              matchid               INT,
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
			  IsMarked			 	BIT,
			  ActualStake			MONEY
             );
    CREATE TABLE #tmpRefCodeSummary
             (RefCode  BIGINT,
              custid   INT,
              bettype  SMALLINT,
              transid  BIGINT,
              IsMarked BIT
             );

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	

	DECLARE @SportType	SMALLINT
			,@LeagueId	INT
			,@SettlementStatus TINYINT = NULL
			,@GlobalShowTime SMALLDATETIME
	
	SELECT	@SportType = m.Sporttype 
			,@LeagueId = m.leagueid
			,@SettlementStatus = m.SettlementStatus
			,@GlobalShowTime = m.GlobalShowTime
	FROM	dbo.match m WITH(NOLOCK) 
	WHERE	matchid = @matchid
	--IF @SportType <> 44
	--BEGIN
	--	SET @SportType = NULL
	--END
	
	CREATE TABLE #tblBetType
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
		OddsSpread		MONEY
	)
	
	-- Parse xml @BetTypes
	;WITH CTE_ParsedBettypes_1 AS
	(	
		SELECT t.c.value('@Id','SMALLINT') AS Id
			 , t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			 , t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			 , t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			 , t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			 , t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1			 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2			 ; single-choice
			 , t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
			 , t.c.value('@OddsSpread', 'VARCHAR(20)') AS OddsSpread	-- Check columns : OddsSpread ; single value
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.val AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , bop.val AS BetOption
			 , CAST(CASE
						WHEN v.val = 'ALL' THEN 9999.00 
						ELSE v.val
					END AS SMALLMONEY) AS [Value]	
			 , CAST(CASE
						WHEN vhdp1.val = 'ALL' THEN 9999.00 
						ELSE vhdp1.val END AS SMALLMONEY) AS ValueHdp1
			 , CAST(CASE 
			 			WHEN cte.ValueHdp2 = 'ALL' THEN 9999.00 
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2			 
			 , CAST(CASE 
						WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal
					END AS BIGINT) AS Goal
			, CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN 9999.00 
						ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY dbo.strSplit(cte.betteam, ',') bt
			 CROSS APPLY dbo.strSplit(cte.BetOption, ',') bop
			 CROSS APPLY dbo.strSplit(cte.[Value], ',') v
			 CROSS APPLY dbo.strSplit(cte.ValueHdp1, ',') vhdp1
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread)
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
	FROM CTE_ParsedBettypes cte	
	WHERE CASE
				WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
				ELSE 1
		  END = 1
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))

	
	
	-- search tickets : not metric gaming tickets, mix parlay tickets
	INSERT INTO #SpecialDeleteBets(
			GroupID			
			,transid		
			,SubTransid		
			,refno			
			,custid			
			,odds			
			,choiceOdds	
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype 		
			,betteam 		
			,ChoiceBetTeam
			,betcheck	
			,choiceBetcheck	
			,hdp1 			
			,hdp2 			
			,livehomescore 	
			,liveawayscore 	
			,creator		
			,Stake			
			,currencyname		
			,STATUS			
			,ChoiceStatus	
			,srecommend
			,mrecommend		
			,recommend		
			,betid			
			,Transdesc		
			,betdaqid	
			,ExtraInfo
			,MainCashoutId
			,WalletType
			,RefCode
			,BonusID
			,IsMarked
			,ActualStake
		)
	SELECT 
			b.transid AS GroupID
			,b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.odds
			,b.odds AS choiceOdds
			,b.oddsspread			
			,b.OddsType
			,b.transdate
			,b.bettype
			,b.betteam
			,b.betteam AS choiceBetteam
			,b.betcheck
			,b.betcheck AS choiceBetcheck
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.creator
			,b.stake
			,b.CurrencyName
			,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS
				END AS STATUS
			,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS
				END AS ChoiceStatus
			,b.srecommend
			,b.mrecommend
			,b.recommend
			,b.betid
			,b.Transdesc
			,b.betdaqid
			,b.ExtraInfo
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid
				ELSE NULL
			 END AS MainCashoutId
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.actual_stake AS ActualStake
	FROM	bettrans b WITH (NOLOCK)	
		  LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId			
	WHERE	b.matchid = @matchid
			AND b.transdate >= @KickOffDate
			AND b.statusID NOT IN (101, 102) -- reject, void
			AND b.liveindicator = 0
			AND b.bettype NOT IN (805, 806, 9, 29)			
			AND b.betfrom <> 'P'
			-- filter for BetTeam
			AND EXISTS (SELECT TOP 1 1
						FROM #tblBetType tp
						WHERE tp.Id = b.bettype
						  AND CASE
									WHEN tp.BetTeam = 'ALL' THEN 1									
									ELSE CASE 
											WHEN b.betteam = tp.BetTeam THEN 1
											ELSE 0
										 END 
							  END = 1)
							  
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
	DELETE s
	FROM #SpecialDeleteBets s	 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Set] = 'ALL' THEN 1							
								ELSE CASE 						  
										WHEN s.betid LIKE tp.[Set] + '%' THEN 1
										ELSE 0
									 END
							END = 1) 
				
	DELETE s
	FROM #SpecialDeleteBets s	 	
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.Game = 'ALL' THEN 1
								WHEN (tp.Game LIKE '>%' AND RIGHT(s.betid, 2) > RIGHT(tp.Game, 2)) 
									 OR (RIGHT(s.betid, 2) = tp.Game)
										THEN 1											
								ELSE 0
							END = 1)
				
	DELETE s
	FROM #SpecialDeleteBets s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.BetOption = 'ALL' THEN 1				
								ELSE CASE
										WHEN CAST(CAST(s.hdp2 AS INT) AS VARCHAR(50)) + '-' + s.betteam = tp.BetOption THEN 1
										ELSE 0
									 END
							END = 1)				
					 
	DELETE s
	FROM #SpecialDeleteBets s		 		
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Value] = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp1 + s.hdp2 = tp.[Value] THEN 1
										ELSE 0
									 END
							END = 1)
		  
	DELETE s
	FROM #SpecialDeleteBets s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.ValueHdp1 = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp1 = tp.ValueHdp1 THEN 1
										ELSE 0
									 END
							END = 1)

	DELETE s
	FROM #SpecialDeleteBets s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.ValueHdp2 = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp2 = tp.ValueHdp2 THEN 1
										ELSE 0
									 END
							END = 1)		  
				
	DELETE s
	FROM #SpecialDeleteBets s		 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.Goal = 100 THEN 1
								WHEN ISNULL(s.betID, 0) = tp.Goal THEN 1			
								ELSE 0
							END = 1)

	DELETE s
	FROM #SpecialDeleteBets s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.OddsSpread = 9999 THEN 1				
								ELSE CASE
										WHEN s.oddsspread = tp.OddsSpread THEN 1
										ELSE 0
									 END
							END = 1)
	END					
		
	-- Metric Gaming Super Live
	IF EXISTS( SELECT TOP 1 1 FROM #tblBettype WHERE Id IN (805, 806))	
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,choiceOdds	
				,oddsspread							
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,ChoiceBetTeam
				,betcheck	
				,choiceBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,ChoiceStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid
				,IsMarked					
			)	
		SELECT 
				b.TranslogID AS GroupID
				,b.TranslogID AS TransId
				,b.TranslogID AS SubTransID
				,b.TranslogID refno
				,b.custid
				,b.odds
				,b.odds AS choiceOdds
				,0 AS oddsspread			
				,b.custom1 OddsType
				,b.transdate
				,b.GameID
				,NULL betteam
				,NULL choicebetteam
				,NULL betcheck
				,NULL choicebetcheck
				,0 hdp1
				,0 hdp2
				,NULL livehomescore
				,NULL liveawayscore
				,b.creator
				,b.stake			
				,b.currencyname			
				,b.STATUS
				,b.Status AS ChoiceStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend		
				,NULL betid
				,b.Transdesc
				,-1 AS betdaqid -- normal ticket
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked								
		FROM	Translog b WITH (NOLOCK)
			INNER JOIN #tblBettype tp 
				ON	tp.Id = b.gameID
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.TranslogID = m.TransId
		WHERE	b.EventID = @matchid
				AND b.transdate >= @KickOffDate
				AND b.statusID NOT IN (101, 102) -- REJECT, VOID
				AND b.liveindicator = 0
				AND b.GameID IN (805, 806) 
				AND b.betfrom <> 'P'				
	
	---get sub ticket of a mix parlay	
	CREATE TABLE #MainParlay (
		transid			BIGINT
		,Refno			BIGINT
		,CurrencyID		TINYINT
		,currencyname	VARCHAR(20)
		,oddstype		TINYINT
		,bettype		SMALLINT
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,odds			MONEY
		,stake			MONEY
		,STATUS			VARCHAR(20)
		,srecommend		INT
		,mrecommend		INT
		,recommend		INT
		,modds			MONEY
		,creator		INT
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,ExtraInfo		VARCHAR(1000)
		,ActualStake	MONEY
		)

	IF EXISTS (
			SELECT TOP 1 1 FROM #tblBettype WHERE Id IN (9,29)
			)
		AND EXISTS (
			SELECT 1
			FROM dbo.bettransm AS bm WITH (NOLOCK)
			WHERE bm.matchid = @matchid
				AND bm.transdate >= @KickOffDate
				AND bm.statusID NOT IN (101, 102)
				AND bm.liveindicator = 0
				AND bm.betfrom <> 'P'
			)
	BEGIN
		INSERT INTO #MainParlay(
				transid			
				,Refno			
				,CurrencyID		
				,currencyname	
				,oddstype		
				,bettype		
				,betteam		
				,betcheck		
				,odds			
				,stake			
				,STATUS			
				,srecommend		
				,mrecommend		
				,recommend	
				,modds	
				,creator		
				,hdp1
				,hdp2
				,ExtraInfo
				,ActualStake	
		)
		SELECT	main.transid
				,main.Refno
				,main.Currency
				,main.CurrencyName
				,main.oddstype
				,main.bettype
				,main.betteam
				,main.betcheck
				,main.odds
				,main.stake
				,main.STATUS
				,main.srecommend
				,main.mrecommend
				,main.recommend
				,main.modds
				,main.creator
				,main.hdp1
				,main.hdp2
				,main.ExtraInfo
				,main.actual_stake	AS ActualStake
		FROM	dbo.bettrans AS main WITH (NOLOCK)
			INNER JOIN #tblBettype tp
				ON	main.bettype = tp.Id
		WHERE	main.matchid IN (9, 29)
				AND main.bettype IN (9, 29)
				AND (main.betid IS NULL OR main.betid = 0)
				AND main.liveindicator = 0
				AND main.transdate >= @KickOffDate
				AND main.statusID NOT IN (101, 102)
		
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid					
				,odds			
				,choiceOdds	
				,oddsspread
				,OddsType		
				,transdate		
				,bettype		
				,betteam		
				,ChoiceBetTeam
				,betcheck	
				,choiceBetcheck	
				,choicehdp1
				,choicehdp2
				,hdp1 			
				,hdp2 			
				,livehomescore	
				,liveawayscore	
				,creator		
				,Stake			
				,currencyname						
				,STATUS			
				,ChoiceStatus	
				,srecommend		
				,mrecommend		
				,recommend						
				,Transdesc		
				,ParlayType		
				,IsMixParlay
				,modds							
				,ExtraInfo
				,ActualStake
			)
		SELECT 
				main.transid AS GroupID
				,main.transid AS TransId
				,sub.transid AS SubTransID
				,sub.refno
				,sub.custid				
				,main.odds
				,sub.odds AS choiceOdds
				,sub.oddsspread
				,main.OddsType
				,sub.transdate
				,main.bettype
				,main.betteam
				,sub.betteam
				,main.betcheck				
				,sub.betcheck
				,sub.hdp1
				,sub.hdp2
				,main.hdp1
				,main.hdp2
				,sub.livehomescore
				,sub.liveawayscore
				,main.creator
				,main.stake
				,main.currencyname				
				,main.STATUS
				,sub.STATUS AS ChoiceStatus
				,main.srecommend
				,main.mrecommend
				,main.recommend
				,sub.Transdesc
				,sub.bettype AS parlaytype
				,1 AS IsMixParlay
				,main.modds
				,main.ExtraInfo
				,main.ActualStake			
		FROM	dbo.bettransm sub WITH (NOLOCK)				
				INNER JOIN #MainParlay AS main WITH (NOLOCK) 
					ON	main.refno = sub.refno				
						AND sub.matchid = @matchid
		WHERE	sub.transdate >= @KickOffDate
				AND sub.statusID NOT IN (101, 102) -- reject, void
				AND sub.liveindicator = 0
				AND sub.betfrom <> 'P'
	END --exists bettype=9		
	
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
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, IsMarked, transid)
		SELECT RefCode, custid, bettype, IsMarked
			 , MAX(transid) AS transid
		FROM #SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, IsMarked
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #SpecialDeleteBets(
						GroupID			
						,transid		
						,SubTransid		
						,refno			
						,custid			
						,odds			
						,choiceOdds		
						,oddsspread
						,OddsType		
						,transdate		
						,bettype 		
						,betteam 		
						,ChoiceBetTeam
						,betcheck	
						,choiceBetcheck	
						,hdp1 			
						,hdp2 			
						,livehomescore 	
						,liveawayscore 	
						,creator		
						,Stake			
						,currencyname		
						,STATUS			
						,ChoiceStatus	
						,srecommend
						,mrecommend		
						,recommend		
						,betid			
						,Transdesc		
						,betdaqid
						,ExtraInfo	
						,MainCashoutId
						,WalletType
						,RefCode
						,BonusID
						,MainTransId
						,IsMarked
						,ActualStake		
					)
				SELECT 
						b.transid AS GroupID
						,b.transid
						,b.transid AS SubTransID
						,b.refno
						,b.custid
						,b.odds
						,b.odds AS choiceOdds
						,b.oddsspread
						,b.OddsType
						,b.transdate
						,b.bettype
						,b.betteam
						,b.betteam AS choiceBetteam
						,b.betcheck
						,b.betcheck AS choiceBetcheck
						,b.hdp1
						,b.hdp2
						,b.livehomescore
						,b.liveawayscore
						,b.creator
						,b.stake
						,b.CurrencyName
						,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							  ELSE b.STATUS
						 END AS STATUS
						,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							  ELSE b.STATUS
						 END AS ChoiceStatus
						,b.srecommend
						,b.mrecommend
						,b.recommend
						,b.betid
						,b.Transdesc
						,b.betdaqid
						,b.ExtraInfo
						,CASE
							WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
									THEN b.transid
							ELSE NULL
						 END AS MainCashoutId
						,b.WalletType
						,b.RefCode
						,b.BonusID
						,t.transid AS MainTransId
						,IsMarked
						,b.actual_stake AS ActualStake
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
		INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			ON	main.transid = sub.refno
				AND main.betdaqid = 0 -- main ticket is BTrade
				AND main.extrainfo is null
				AND sub.matchid = @MatchId
				AND sub.bettype = 901
		
	-- get sub ticket of BetTrade (901)
	INSERT INTO #SpecialDeleteBets (
			GroupID			
			,transid		
			,SubTransid		
			,refno			
			,custid			
			,odds			
			,choiceOdds	
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype
			,OriginalBetType 		
			,betteam 		
			,ChoiceBetTeam
			,betcheck	
			,choiceBetcheck	
			,hdp1 			
			,hdp2 			
			,livehomescore 	
			,liveawayscore 	
			,creator		
			,Stake			
			,currencyname		
			,STATUS			
			,ChoiceStatus	
			,srecommend
			,mrecommend		
			,recommend		
			,betid			
			,Transdesc		
			,betdaqid
			,ExtraInfo
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,IsMarked
			,ActualStake						
		)
	SELECT  main.transid AS GroupTransId
			,sub.transid AS transId
			,sub.transid AS SubTransId
			,sub.refno
			,sub.custid
			,main.odds
			,main.odds AS choiceOdds
			,main.oddsspread
			,main.OddsType
			,sub.transdate
			,sub.bettype
			,main.bettype  AS OriginalBetType
			,main.betteam
			,main.ChoiceBetTeam
			,main.betcheck
			,main.choiceBetcheck
			,main.hdp1
			,main.hdp2			
			,main.livehomescore
			,main.liveawayscore
			,sub.creator
			,main.Stake
			,main.CurrencyName
			,'SOLD'
			,'SOLD' AS ChoiceStatus
			,main.srecommend
			,main.mrecommend
			,main.recommend			
			,main.bettype AS betid
			,sub.transdesc
			,sub.betdaqid
			,sub.ExtraInfo
			,sub.WalletType
			,sub.RefCode
			,sub.BonusID
			,main.transid AS MainTransId
			,main.IsMarked
			,main.ActualStake			
	FROM	#SpecialDeleteBets main
		INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			ON	main.transid = sub.refno
				AND sub.matchid = @MatchId
				AND sub.bettype = 901
		INNER JOIN #tblSoldTicket sold 
			ON sold.transid = sub.transid
			
	-- get sub ticket of Cash-out (911)
	INSERT INTO #SpecialDeleteBets (
			GroupID			
			,transid		
			,SubTransid		
			,refno			
			,custid			
			,odds					
			,choiceOdds
			,oddsspread				
			,OddsType		
			,transdate		
			,bettype
			,OriginalBetType 		
			,betteam 		
			,ChoiceBetTeam
			,betcheck	
			,choiceBetcheck	
			,hdp1 			
			,hdp2 			
			,livehomescore 	
			,liveawayscore 	
			,creator		
			,Stake			
			,currencyname		
			,STATUS			
			,ChoiceStatus	
			,srecommend
			,mrecommend		
			,recommend		
			,betid			
			,Transdesc		
			,betdaqid
			,ExtraInfo	
			,MainCashoutId
			,matchid
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,IsMarked
			,ActualStake		
		)
	SELECT  sub911.transid AS GroupTransId
			,sub911.transid AS transId
			,sub911.transid AS SubTransId
			,sub911.refno
			,sub911.custid
			,main.odds
			,main.odds AS choiceOdds
			,main.oddsspread
			,main.OddsType
			,sub911.transdate
			,sub911.bettype
			,main.bettype AS OriginalBetType
			,main.betteam
			,main.ChoiceBetTeam
			,main.betcheck
			,main.choiceBetcheck
			,main.hdp1
			,main.hdp2			
			,main.livehomescore
			,main.liveawayscore
			,sub911.creator
			,sub911.Stake
			,main.CurrencyName
			,'Cash out'
			,'Cash out' AS ChoiceStatus
			,main.srecommend
			,main.mrecommend
			,main.recommend			
			,main.bettype AS betid
			,sub911.transdesc
			,sub911.betdaqid
			,sub911.ExtraInfo
			,main.transid AS MainCashoutId
			,sub911.matchid	
			,sub911.WalletType
			,sub911.RefCode
			,sub911.BonusID
			,main.transid AS MainTransId
			,main.IsMarked
			,main.ActualStake
	FROM dbo.bettrans sub911 WITH(NOLOCK)
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
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,choiceOdds	
				,oddsspread				
				,OddsType		
				,transdate		
				,bettype 
				,OriginalBetType		
				,betteam 		
				,ChoiceBetTeam
				,betcheck	
				,choiceBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,ChoiceStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid
				,ExtraInfo
				,IsCashOutMemberTicket
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,IsMarked
				,ActualStake		
			)
		SELECT  sub911.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS choiceOdds
				,b.oddsspread
				,b.OddsType
				,b.transdate
				,b.bettype
				,sub911.OriginalBetType
				,b.betteam
				,b.betteam AS choiceBetteam
				,b.betcheck
				,b.betcheck AS choiceBetcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.creator
				,b.stake
				,b.CurrencyName
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					  ELSE b.STATUS
				 END AS STATUS
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					  ELSE b.STATUS
				 END AS ChoiceStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.Transdesc
				,b.betdaqid
				,b.ExtraInfo
				,CAST(1 AS BIT)  AS IsCashOutMemberTicket
				,sub911.MainCashoutId AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,sub911.MainTransId
				,sub911.IsMarked
				,b.actual_stake AS ActualStake
	FROM #SpecialDeleteBets sub911
		 CROSS APPLY (
						  SELECT b.transid
						  		,b.refno
								,b.custid
								,b.odds
								,b.oddsspread
								,b.OddsType
								,b.transdate
								,b.bettype
								,b.betteam
								,b.betcheck
								,b.hdp1
								,b.hdp2
								,b.livehomescore
								,b.liveawayscore
								,b.creator
								,b.stake
								,b.CurrencyName
								,b.STATUS
								,b.SecAcceptFlag
								,b.checktime
								,b.srecommend
								,b.mrecommend
								,b.recommend
								,b.betid
								,b.Transdesc
								,b.betdaqid
								,b.ExtraInfo
								,b.WalletType
								,b.RefCode
								,b.BonusID	
						  FROM dbo.bettrans b WITH (NOLOCK)
						  WHERE b.refno = sub911.transid
							AND b.matchid = sub911.matchid					
							AND b.bettype = sub911.OriginalBetType
							AND b.statusID NOT IN (102, 101) -- VOID, REJECT
					 ) AS b
	WHERE sub911.bettype = 911
				
	-- update username/creatorname column
	UPDATE al
		SET username = ci.username
			,creatorName = cr.username
			,ChoiceLeagueId = @LeagueId
			,sporttype = @SportType
	FROM	#SpecialDeleteBets al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK)
			ON al.creator = cr.custid
			
			
	-- update Isdeposit
	UPDATE al 
		SET IsDeposit = 1
	FROM	#SpecialDeleteBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
		
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
			   ,s.choiceOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.OriginalBetType
			   ,s.STATUS
			   ,s.ChoiceStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.ChoiceBetTeam
			   ,s.ChoiceLeagueId
			   ,s.choicehdp1
			   ,s.choicehdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.choiceBetcheck
			   ,s.IsMixParlay
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,s.SoldId
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.GroupId
			   ,'Credit' AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.IsMarked
			   ,s.ActualStake
		FROM	#SpecialDeleteBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
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
			   ,s.choiceOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.OriginalBetType
			   ,s.STATUS
			   ,s.ChoiceStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.ChoiceBetTeam
			   ,s.ChoiceLeagueId
			   ,s.choicehdp1
			   ,s.choicehdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.choiceBetcheck
			   ,s.IsMixParlay
			   ,s.ParlayType
			   ,b.transid AS followedId
			   ,b.Username AS followedUsername			   
			   ,s.Transdesc
			   ,s.SoldId
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.GroupId
			   ,'8RM/BARM' AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.IsMarked
			   ,s.ActualStake
		FROM	#SpecialDeleteBets s 
			LEFT JOIN dbo.bettrans b WITH(NOLOCK)
				ON	s.betid = b.transid
					AND b.matchid = @matchid	
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
			   ,s.choiceOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.OriginalBetType
			   ,s.STATUS
			   ,s.ChoiceStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.ChoiceBetTeam
			   ,s.ChoiceLeagueId
			   ,s.choicehdp1
			   ,s.choicehdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.choiceBetcheck
			   ,s.IsMixParlay
			   ,s.ParlayType
			   ,NULL AS followedId
			   ,NULL AS followedUsername
			   ,s.Transdesc
			   ,s.SoldId
			   ,s.sporttype
			   ,s.modds
			   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
			   ,s.betdaqid
			   ,s.ExtraInfo
			   ,s.MainCashoutId
			   ,s.GroupId
			   ,'Deposit' AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.IsMarked
			   ,s.ActualStake
		FROM	#SpecialDeleteBets s 
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub
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
		   ,s.choiceOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.OriginalBetType
		   ,s.STATUS
		   ,s.ChoiceStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.ChoiceBetTeam
		   ,s.ChoiceLeagueId
		   ,s.choicehdp1
		   ,s.choicehdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.choiceBetcheck
		   ,s.IsMixParlay
		   ,s.ParlayType
		   ,NULL AS followedId
		   ,NULL AS followedUsername
		   ,s.Transdesc
		   ,s.SoldId
		   ,s.sporttype
		   ,s.modds
		   ,CASE WHEN s.bettype = 501 AND s.IsDeposit = 0 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.MainCashoutId
		   ,s.GroupId
		   ,'Betfair' AS GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.BonusID
		   ,s.RefCode
		   ,s.IsMarked
		   ,s.ActualStake
		FROM	#SpecialDeleteBets s WITH (NOLOCK)
			LEFT JOIN #SpecialDeleteBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
	)
	SELECT s.transid
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.choiceOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.OriginalBetType
		   ,s.STATUS
		   ,s.ChoiceStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.ChoiceBetTeam
		   ,s.ChoiceLeagueId
		   ,s.choicehdp1
		   ,s.choicehdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.choiceBetcheck
		   ,s.IsMixParlay
		   ,s.ParlayType
		   ,s.followedId
		   ,s.followedUsername
		   ,s.Transdesc
		   ,s.SoldId
		   ,s.sporttype
		   ,s.modds
		   ,s.IsCricket
		   ,s.betdaqid
		   ,s.ExtraInfo
		   ,s.MainCashoutId
		   ,s.GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.RefCode
		   ,@SettlementStatus AS SettlementStatus
		   ,s.IsMarked
		   ,@GlobalShowTime AS GlobalShowTime
		   ,s.ActualStake
	FROM CTE_OriginResult s
	ORDER BY CASE
				WHEN s.GroupName = 'Credit' THEN 1
				WHEN s.GroupName = '8RM/BARM' THEN 2
				WHEN s.GroupName = 'Deposit' THEN 3
				WHEN s.GroupName = 'Betfair' THEN 4
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
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tblBetType
	DROP TABLE #MainParlay
	DROP TABLE #tblSoldTicket
END