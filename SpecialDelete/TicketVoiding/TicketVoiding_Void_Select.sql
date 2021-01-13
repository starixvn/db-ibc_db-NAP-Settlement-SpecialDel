/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Select] 
(
	@MatchId			INT = 0
    ,@KickOffDate		DATETIME = NULL
    ,@RequestId			INT = NULL
    ,@IssueTypeId		INT = NULL
	,@BetTypes			XML = NULL
	,@ActionId			TINYINT = 0
	,@LiveHomeScore		SMALLINT = NULL
	,@LiveAwayScore		SMALLINT = NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200405@Max: Enhance EKO Issue Type - [Redmine: #126418]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200819@Max: HotFix - [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
	    - 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785] 
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201127@Charles: God of fortune [Redmine: #146053]
		- 20201216@July: [TVS] - Abnormal Account [Redmine: #143666]
		 
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON	

	CREATE TABLE #SpecialDeleteBets (
		GroupID               BIGINT,
        transid               BIGINT,
        SubTransid            BIGINT,
        refno                 BIGINT,
        custid                INT,
        username              VARCHAR(30),
        odds                  MONEY,
        SubOdds               MONEY,
        oddsspread            MONEY,
        OddsType              INT,
        transdate             DATETIME,
        bettype               SMALLINT,
        OriginalBetType       SMALLINT,
        betteam               NVARCHAR(10),
        SubBetTeam            NVARCHAR(10),
        betcheck              NVARCHAR(50),
        SubBetcheck           NVARCHAR(50),
        Subhdp1               SMALLMONEY,
        Subhdp2               SMALLMONEY,
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
        SubStatus             NVARCHAR(10),
        srecommend            INT,
        mrecommend            INT,
        recommend             INT,
        SubLeagueId           INT,
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
        WinLost               MONEY,
        IsMarked              BIT,
        LiveIndicator		  BIT,
		FilterBettype		  SMALLINT,
        FilterBetTeam		  NVARCHAR(10),
        FilterSet			  VARCHAR(50),
        FilterGame			  VARCHAR(50),
        FilterValue			  SMALLMONEY,
		FilterHdp1		      SMALLMONEY,
		FilterHdp2		      SMALLMONEY,
        FilterGoal			  BIGINT,
        FilterBetOption		  NVARCHAR(50),
        FilterTimeInterval	  SMALLMONEY,
		mainstatusid		  TINYINT, -- store statusid of normal ticket, or statusid of main ticket for bettrade 901,
		FilterOddsSpread	  MONEY,
		ActualStake			  MONEY,
		oddsid                INT,
		homeid                INT,
        awayid                INT,
		leagueid              INT,
		isNeutral             BIT,
		matchcode             NVARCHAR(50),
		showtime              NVARCHAR(50),
		winlostdate			  DATETIME,
		statusID			  TINYINT,
		IsCashOutTicket		  BIT DEFAULT 0, --include 911,member ticket CO
    )
    CREATE TABLE #tmpRefCodeSummary
             (RefCode  BIGINT,
              custid   INT,
			  matchid  INT,
              bettype  SMALLINT,
              transid  BIGINT,
              IsMarked BIT
             )
	CREATE TABLE #tblSoldTicket (transid BIGINT PRIMARY KEY)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	

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
		OddsSpread		VARCHAR(20)
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
		TimeInterval	SMALLMONEY,	
		Goal			BIGINT,
		OddsSpread		MONEY
	)
	DECLARE @tmpMatchIDBatch TABLE (MatchID INT, bettype  SMALLINT)
	DECLARE @Status_tmp TABLE (StatusId TINYINT)

	DECLARE @SettledType VARCHAR(100) = 'All'
		   ,@StatusIds	 VARCHAR(50) =''

	IF @IssueTypeId = 13
	BEGIN
		SET @StatusIds = (SELECT TOP 1 TicketStatusIds FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) WHERE RequestId = @RequestId)
		
		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@StatusIds, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)
	END

	CREATE TABLE #TmpMatch 
	( 
		MatchId		INT, 
		Sporttype	SMALLINT, 
		Leagueid	INT, 
		SettlementStatus TINYINT
	)

	IF @RequestId = 0 -- case: search for EKO,WKO
	BEGIN
		INSERT INTO #TmpMatch ( MatchId, Sporttype, Leagueid, SettlementStatus)
		SELECT DISTINCT @MatchId
					,ISNULL(m.sporttype, 0)
					,ISNULL(m.leagueid, 0)
					,ISNULL(m.SettlementStatus, 0)
		FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId
	END
	ELSE 
	BEGIN 
		INSERT INTO #TmpMatch ( MatchId, Sporttype, Leagueid, SettlementStatus)
		SELECT DISTINCT rd.matchid
						,ISNULL(m.sporttype, 0)
						,ISNULL(m.leagueid, 0)
						,ISNULL(m.SettlementStatus, 0)
		FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			LEFT JOIN dbo.match m WITH(NOLOCK) ON rd.MatchId = m.matchid
		WHERE rd.RequestId = @RequestId AND  (rd.MatchId = @MatchId OR @MatchId = 0)
	END

	IF @IssueTypeId = 11 --11: AbnormalBet
	BEGIN
		DECLARE @transIdTemp TABLE (transid BIGINT NULL);
				
		INSERT INTO @transIdTemp (transid)
		SELECT DISTINCT TransId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
		WHERE RequestId = @RequestId
	
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
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
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
				,ActualStake
				,matchid
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
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
					END AS SubStatus
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
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
				,b.actual_stake AS ActualStake
				,b.matchid
		FROM	bettrans b WITH (NOLOCK)	
			INNER JOIN @transIdTemp t ON t.transid = b.transid
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE  b.statusID NOT IN (101, 102, 103) -- reject, void, refund
			  	
					
	END
	ELSE IF @IssueTypeId IN (1, 10) -- Danger Accept, Red Card
	BEGIN
		IF @BetTypes IS NOT NULL
		BEGIN
			-- Parse xml @BetTypes
			INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread)
			SELECT t.c.value('@Id','SMALLINT') AS Id
					, t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
					, t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
					, t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
					, t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
					, t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
					, t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1		-- check columns : hdp1	 ; single-choice + multi-choice
					, t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2		-- check columns : hdp2	 ; single-choice
					, t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
					, t.c.value('@OddsSpread', 'VARCHAR(20)') AS OddsSpread	-- Check columns : OddsSpread ; single value
			FROM @BetTypes.nodes('BetTypes/BetType') t(c)
			OPTION (OPTIMIZE FOR (@BetTypes = NULL))
			 
			INSERT INTO #tblBetType_Detail(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, TimeInterval, Goal, OddsSpread)
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
				 , CAST(CASE WHEN (cte.Id NOT BETWEEN 221 AND 228) AND (cte.Id NOT IN (479, 481)) THEN cte.[Value]
							ELSE 9999.00 END AS SMALLMONEY) AS [Value]
				 , cte.ValueHdp1
		 		 , cte.ValueHdp2
				 , CAST(CASE WHEN (cte.Id BETWEEN 221 AND 228) OR (cte.Id IN (479, 481)) THEN cte.[Value]
							ELSE 9999.00 END AS SMALLMONEY) AS TimeInterval
				 , cte.Goal
				 , cte.OddsSpread
			FROM (
				SELECT cte.Id
					 , bt.val AS BetTeam 
					 , cte.[Set]
					 , cte.Game
					 , bop.val AS BetOption
					 , CAST(CASE WHEN v.val = 'ALL' THEN 9999.00 
								ELSE v.val END AS SMALLMONEY) AS [Value]
					 , CAST(CASE WHEN vhdp1.val = 'ALL' THEN 9999.00 
							ELSE vhdp1.val END AS SMALLMONEY) AS ValueHdp1
					 , CAST(CASE WHEN cte.ValueHdp2 = 'ALL' THEN 9999.00 
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2
					 , CAST(CASE WHEN cte.Goal = 'ALL' THEN 100 
								ELSE cte.Goal END AS BIGINT) AS Goal
					 , CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN 9999.00 
								ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
				FROM #tblBetType cte
					 CROSS APPLY dbo.f_SplitString(cte.betteam, ',') bt
					 CROSS APPLY dbo.f_SplitString(cte.BetOption, ',') bop
					 CROSS APPLY dbo.f_SplitString(cte.[Value], ',') v
					 CROSS APPLY dbo.f_SplitString(cte.ValueHdp1, ',') vhdp1
			) cte	
			WHERE CASE WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
					WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
					ELSE 1 END = 1
			OPTION (MAXRECURSION 0)

			-- search tickets : not metric gaming tickets, mix parlay tickets
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid			
					,odds			
					,SubOdds	
					,oddsspread			
					,OddsType		
					,transdate		
					,bettype 		
					,betteam 		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,hdp1 			
					,hdp2 			
					,livehomescore 	
					,liveawayscore 	
					,creator		
					,Stake			
					,currencyname		
					,STATUS			
					,SubStatus	
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
					,WinLost
					,IsMarked
					,LiveIndicator
					,FilterBettype
					,FilterBetTeam
					,FilterSet
					,FilterGame	
					,FilterValue
					,FilterHdp1
					,FilterHdp2
					,FilterGoal
					,FilterBetOption
					,FilterTimeInterval
					,mainstatusid
					,FilterOddsSpread
					,ActualStake
					,matchid
				)
			SELECT 
					b.transid AS GroupID
					,b.transid
					,b.transid AS SubTransID
					,b.refno
					,b.custid
					,b.odds
					,b.odds AS SubOdds
					,b.oddsspread			
					,b.OddsType
					,b.transdate
					,b.bettype
					,b.betteam
					,b.betteam AS SubBetteam
					,b.betcheck
					,b.betcheck AS SubBetcheck
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
						END AS SubStatus
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
					,b.WinLost - b.actual_stake AS WinLost
					,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
					,b.liveindicator
					,b.bettype AS FilterBetType
					,b.betteam AS FilterBetTeam
					,b.betid AS FilterSet
					,RIGHT(b.betid, 2) AS FilterGame
					,b.hdp1 + b.hdp2 AS FilterValue
					,b.hdp1 AS FilterHdp1
					,b.hdp2 AS FilterHdp2
					,ISNULL(b.betid, 0) AS FilterGoal
					,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
					,b.hdp1 AS FilterTimeInterval
					,b.statusID AS mainstatusid
					,b.oddsspread AS FilterOddsSpread
					,b.actual_stake AS ActualStake
					,b.matchid
			FROM	bettrans b WITH (NOLOCK)	
				LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
				CROSS APPLY (
							SELECT TOP (1) transid
							FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE transid = b.transid
								AND RequestId = @RequestId
					) ts
				INNER JOIN #tblBetType bt with (NOLOCK) ON bt.id = b.bettype
			WHERE	b.matchid = @matchid
					AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
					AND b.bettype NOT IN (805, 806, 9, 29)			
					AND b.bettype NOT BETWEEN 901 AND 920
					AND b.betfrom <> 'P'
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE b.liveawayscore END
		
			---get sub ticket of a mix parlay	
			IF EXISTS (
					SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
					WHERE bm.matchid = @matchid
						AND bm.statusID NOT IN (101, 102, 103)
						AND bm.betfrom <> 'P'
					)
			BEGIN		
				INSERT INTO #SpecialDeleteBets(
						GroupID			
						,transid		
						,SubTransid		
						,refno			
						,custid					
						,odds			
						,SubOdds	
						,oddsspread
						,OddsType		
						,transdate		
						,bettype		
						,betteam		
						,SubBetTeam
						,betcheck	
						,SubBetcheck	
						,Subhdp1
						,Subhdp2
						,hdp1 			
						,hdp2 			
						,livehomescore	
						,liveawayscore	
						,creator		
						,Stake			
						,currencyname						
						,STATUS			
						,SubStatus	
						,srecommend		
						,mrecommend		
						,recommend						
						,Transdesc		
						,ParlayType		
						,IsMixParlay
						,modds
						,WinLost
						,IsMarked
						,LiveIndicator
						,FilterBettype
						,FilterBetTeam
						,FilterSet
						,FilterGame	
						,FilterValue
						,FilterHdp1
						,FilterHdp2
						,FilterGoal
						,mainstatusid
						,FilterOddsSpread
						,ExtraInfo
						,ActualStake
						,matchid
						
					)
				SELECT 
						main.transid AS GroupID
						,main.transid AS TransId
						,sub.transid AS SubTransID
						,sub.refno
						,sub.custid				
						,main.odds
						,sub.odds AS SubOdds
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
						,sub.STATUS AS SubStatus
						,main.srecommend
						,main.mrecommend
						,main.recommend
						,sub.Transdesc
						,sub.bettype AS parlaytype
						,1 AS IsMixParlay
						,main.modds
						,main.winlost -main.actual_stake AS WinLost
						,0
						,sub.liveindicator
						,sub.bettype AS FilterBetType
						,sub.betteam AS FilterBetTeam
						,sub.betcheck AS FilterSet
						,RIGHT(sub.betcheck, 2) AS FilterGame
						,sub.hdp1 + sub.hdp2 AS FilterValue
						,sub.hdp1 AS FilterHdp1
						,sub.hdp2 AS FilterHdp2
						,ISNULL(sub.betcheck, 0) AS FilterGoal
						,main.statusID AS mainstatusid
						,sub.oddsspread AS FilterOddsSpread
						,main.ExtraInfo
						,main.actual_stake AS ActualStake
						,sub.matchid
				FROM	dbo.bettransm sub WITH (NOLOCK)				
						INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
						INNER JOIN #tblBettype tp
							ON	sub.bettype = tp.Id
						CROSS APPLY (
									SELECT TOP (1) transid
									FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
									WHERE transid = sub.transid
										AND RequestId = @RequestId
							) ts
				WHERE	sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
						AND sub.betfrom <> 'P'
						AND main.matchid = 29
						AND main.bettype = 29
						AND sub.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE sub.livehomescore END
						AND sub.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE sub.liveawayscore END
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
				filter for TimeInterval		 
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
					WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp1 = 9999 OR b.FilterHdp1 = tp.ValueHdp1 ))

				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.ValueHdp2 = 9999 OR b.FilterHdp2 = tp.ValueHdp2 ))

				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.TimeInterval = 9999 OR b.FilterTimeInterval = tp.TimeInterval ) OR b.bettype = 29) 

				DELETE b
				FROM  #SpecialDeleteBets b
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType_Detail tp
					WHERE tp.Id = b.FilterBettype AND (tp.OddsSpread = 9999 OR b.FilterOddsSpread = tp.OddsSpread ))
			END
		END
		ELSE
		BEGIN
			-- search tickets : not metric gaming tickets, mix parlay tickets
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid			
					,odds			
					,SubOdds	
					,oddsspread			
					,OddsType		
					,transdate		
					,bettype 		
					,betteam 		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,hdp1 			
					,hdp2 			
					,livehomescore 	
					,liveawayscore 	
					,creator		
					,Stake			
					,currencyname		
					,STATUS			
					,SubStatus	
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
					,WinLost
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ActualStake
					,matchid
				)
			SELECT 
					b.transid AS GroupID
					,b.transid
					,b.transid AS SubTransID
					,b.refno
					,b.custid
					,b.odds
					,b.odds AS SubOdds
					,b.oddsspread			
					,b.OddsType
					,b.transdate
					,b.bettype
					,b.betteam
					,b.betteam AS SubBetteam
					,b.betcheck
					,b.betcheck AS SubBetcheck
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
						END AS SubStatus
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
					,b.WinLost - b.actual_stake AS WinLost
					,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
					,b.liveindicator
					,b.statusID AS mainstatusid
					,b.actual_stake AS ActualStake
					,b.matchid
			FROM	bettrans b WITH (NOLOCK)	
			   LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
			   CROSS APPLY (
							SELECT TOP (1) transid
							FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE transid = b.transid
								AND RequestId = @RequestId
					) ts
			WHERE	b.matchid = @matchid
					AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
					AND b.bettype NOT IN (805, 806, 9, 29)			
					AND b.bettype NOT BETWEEN 901 AND 920
					AND b.betfrom <> 'P'
					AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE b.livehomescore END
					AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE b.liveawayscore END
					
		
			---get sub ticket of a mix parlay	
			IF EXISTS (
					SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
					WHERE bm.matchid = @matchid
						AND bm.statusID NOT IN (101, 102, 103)
						AND bm.betfrom <> 'P'
					)
			BEGIN		
				INSERT INTO #SpecialDeleteBets(
						GroupID			
						,transid		
						,SubTransid		
						,refno			
						,custid					
						,odds			
						,SubOdds	
						,oddsspread
						,OddsType		
						,transdate		
						,bettype		
						,betteam		
						,SubBetTeam
						,betcheck	
						,SubBetcheck	
						,Subhdp1
						,Subhdp2
						,hdp1 			
						,hdp2 			
						,livehomescore	
						,liveawayscore	
						,creator		
						,Stake			
						,currencyname						
						,STATUS			
						,SubStatus	
						,srecommend		
						,mrecommend		
						,recommend						
						,Transdesc		
						,ParlayType		
						,IsMixParlay
						,modds
						,WinLost
						,IsMarked
						,LiveIndicator
						,mainstatusid
						,ExtraInfo
						,ActualStake
						,matchid
					)
				SELECT 
						main.transid AS GroupID
						,main.transid AS TransId
						,sub.transid AS SubTransID
						,sub.refno
						,sub.custid				
						,main.odds
						,sub.odds AS SubOdds
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
						,sub.STATUS AS SubStatus
						,main.srecommend
						,main.mrecommend
						,main.recommend
						,sub.Transdesc
						,sub.bettype AS parlaytype
						,1 AS IsMixParlay
						,main.modds
						,main.winlost -main.actual_stake AS WinLost
						,0
						,sub.liveindicator
						,main.statusID AS mainstatusid
						,main.ExtraInfo
						,main.actual_stake AS ActualStake
						,sub.matchid
				FROM	dbo.bettransm sub WITH (NOLOCK)				
						INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
						CROSS APPLY (
									SELECT TOP (1) transid
									FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
									WHERE transid = sub.transid
										AND RequestId = @RequestId
							) ts
				WHERE	sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
						AND sub.betfrom <> 'P'
						AND main.matchid = 29
						AND main.bettype = 29
						AND sub.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL THEN @LiveHomeScore ELSE sub.livehomescore END
						AND sub.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL THEN @LiveAwayScore ELSE sub.liveawayscore END
			END 
		END
	END
	ELSE IF @IssueTypeId = 13 -- Abnormal account
	BEGIN

		INSERT INTO #SpecialDeleteBets(
				GroupID
				,bettype
				,transid
				,SubTransid
				,betid
				,refno	
				,hdp1
				,hdp2
				,odds
				,oddsspread
				,OddsType
				,STATUS
				,stake
				,transdate
				,betteam
				,betcheck
				,liveindicator	
				,modds
				,custid
				,livehomescore	
				,liveawayscore
				,matchid
				,winlost
				,TransDesc
				,betdaqid
				,username
				,recommend
				,CurrencyName
				,IsMarked
				,srecommend
				,mrecommend	
				,winlostdate
				,statusID
			)
		SELECT	
			b.translogID AS GroupID
			,b.GameID
			,b.translogID as transid
			,b.translogID as SubTransid
			,0 AS BetID
			,b.translogID refno	
			,0 hdp1
			,0 hdp2
			,b.odds
			,0 AS oddsspread
			,b.custom1 OddsType
			,b.STATUS
			,b.stake
			,b.transdate
			,NULL betteam
			,NULL betcheck
			,b.liveindicator liveindicator
			,NULL modds
			,b.custid
			,NULL livehomescore
			,NULL liveawayscore
			,b.EventID
			,- b.actual_stake as winlost
			,b.transdesc
			,-1 -- normal ticket
			,username
			,recommend
			,b.CurrencyName
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.srecommend
			,b.mrecommend
			,b.winlostdate
			,b.statusID
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				ON  s.transid = b.translogid AND b.eventID = s.MatchId AND s.RequestId = @RequestId
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.translogid = TransId
					)m
		WHERE b.GameID BETWEEN 801 AND 806
			AND b.statusID = 0
				
		-- bettrans tickets	
		INSERT INTO #SpecialDeleteBets (
			GroupID			
			,bettype		
			,transid
			,SubTransid		
			,betid			
			,refno		
			,hdp1			
			,hdp2			
			,odds
			,oddsspread				
			,OddsType		
			,STATUS					
			,stake							
			,transdate		
			,betteam		
			,betcheck		
			,liveindicator	
			,modds			
			,custid						
			,livehomescore	
			,liveawayscore						
			,matchid					
			,winlost		
			,TransDesc		
			,betdaqid
			,username
			,recommend
			,ExtraInfo
			,MainCashoutId
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,IsMarked
			,oddsid
			,srecommend
			,mrecommend	
			,winlostdate
			,statusID
		)
		SELECT	
			b.refno AS GroupId
			,b.bettype
			,b.transid
			,b.transid AS SubTransid	
			,isnull(b.BetID, 0) AS BetID
			,b.refno			
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,b.OddsType
			,CASE 
				WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,b.stake
			,b.transdate
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.modds
			,b.custid
			,b.livehomescore
			,b.liveawayscore
			,b.matchid				
			,(b.winlost - b.actual_stake) winlost
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.recommend			
			,b.ExtraInfo
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
				ELSE NULL END AS MainCashoutId
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.oddsid
			,b.srecommend
			,b.mrecommend
			,b.winlostdate
			,b.statusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON b.custid 		= tl.custid
				AND b.refno 	= tl.translogid
				AND b.matchid 	= tl.eventid
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				ON  tl.translogid 	= s.transid	 AND s.RequestId = @RequestId
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.transid = TransId
					)m
		WHERE			
				b.bettype BETWEEN 801 AND 806 
			AND b.statusID NOT IN (0, 101, 102, 103)
			
		UNION ALL
		SELECT	
			b.transid AS GroupId
			,b.bettype
			,b.transid
			,b.transid AS SubTransid	
			,isnull(b.BetID, 0) AS BetID
			,b.refno			
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,b.OddsType
			,CASE 
				WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,b.stake				
			,b.transdate
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.modds
			,b.custid
			,b.livehomescore
			,b.liveawayscore				
			,b.matchid				
			,(b.winlost - b.actual_stake) winlost
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.recommend			
			,b.ExtraInfo
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid
				ELSE NULL
				END AS MainCashoutId
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.oddsid
			,b.srecommend
			,b.mrecommend
			,b.winlostdate
			,b.statusID
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				ON  s.transid = b.transid AND s.RequestId = @RequestId
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.transid = TransId
					)m
					
		WHERE	 b.bettype NOT BETWEEN 801 AND 806-- MG
			AND  b.statusID NOT IN (101, 102, 103)
				
	END
	ELSE --EKO, WKO
	BEGIN
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
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
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
			,ActualStake
				,matchid
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
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
					END AS SubStatus
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
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
			,b.actual_stake AS ActualStake
				,b.matchid
		FROM	bettrans b WITH (NOLOCK)	
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			OUTER APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
								INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
							WHERE rs.TransId = b.transid
								AND rs.MatchId = @MatchId
								AND r.ActionId NOT IN (2)
								AND 1= CASE WHEN @RequestId <> 0 AND rs.RequestId = @RequestId THEN 0
											ELSE 1 END
					)tmp
		WHERE	b.matchid = @matchid
				AND b.transdate >= @KickOffDate
				AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.liveindicator = 0
				AND b.bettype NOT IN (805, 806, 9, 29)			
				AND b.bettype NOT BETWEEN 901 AND 920
				AND b.betfrom <> 'P'	
		
	-- Metric Gaming Super Live
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread							
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
				,matchid
			)	
		SELECT 
				b.TranslogID AS GroupID
				,b.TranslogID AS TransId
				,b.TranslogID AS SubTransID
				,b.TranslogID refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,0 AS oddsspread			
				,b.custom1 OddsType
				,b.transdate
				,b.GameID
				,NULL betteam
				,NULL Subbetteam
				,NULL betcheck
				,NULL Subbetcheck
				,0 hdp1
				,0 hdp2
				,NULL livehomescore
				,NULL liveawayscore
				,b.creator
				,b.stake			
				,b.currencyname			
				,b.STATUS
				,b.Status AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend		
				,NULL betid
				,b.Transdesc
				,-1 AS betdaqid -- normal ticket
				,- b.actual_stake as winlost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
				,b.eventID 
		FROM	Translog b WITH (NOLOCK)
				LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId		
		WHERE	b.EventID = @matchid
				AND b.transdate >= @KickOffDate
				AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.liveindicator = 0
				AND b.GameID IN (805, 806) 
				AND b.betfrom <> 'P'
									
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
					AND bm.transdate >= @KickOffDate
					AND 1= CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND bm.liveindicator = 0
					AND bm.betfrom <> 'P'
				)
		BEGIN		
			INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid					
					,odds			
					,SubOdds	
					,oddsspread
					,OddsType		
					,transdate		
					,bettype		
					,betteam		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,Subhdp1
					,Subhdp2
					,hdp1 			
					,hdp2 			
					,livehomescore	
					,liveawayscore	
					,creator		
					,Stake			
					,currencyname						
					,STATUS			
					,SubStatus	
					,srecommend		
					,mrecommend		
					,recommend						
					,Transdesc		
					,ParlayType		
					,IsMixParlay
					,modds
					,WinLost
					,IsMarked
					,LiveIndicator
					,mainstatusid
					,ExtraInfo
					,ActualStake
					,matchid
				)
			SELECT 
					main.transid AS GroupID
					,main.transid AS TransId
					,sub.transid AS SubTransID
					,sub.refno
					,sub.custid				
					,main.odds
					,sub.odds AS SubOdds
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
					,sub.STATUS AS SubStatus
					,main.srecommend
					,main.mrecommend
					,main.recommend
					,sub.Transdesc
					,sub.bettype AS parlaytype
					,1 AS IsMixParlay
					,main.modds
					,main.winlost -main.actual_stake AS WinLost
					,0
					,sub.liveindicator
					,main.statusID AS mainstatusid
					,main.ExtraInfo
					,main.actual_stake AS ActualStake
					,sub.matchid
			FROM	dbo.bettransm sub WITH (NOLOCK)				
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
					OUTER APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rs WITH (NOLOCK)
								INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId
							WHERE rs.TransId = sub.transid
								AND rs.MatchId = @MatchId
								AND r.ActionId NOT IN (2)
								AND 1= CASE WHEN @RequestId <> 0 AND rs.RequestId = @RequestId THEN 0
										ELSE 1 END
						)tmp
			WHERE	sub.transdate >= @KickOffDate
					AND 1= CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
								WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND sub.liveindicator = 0
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND main.liveindicator = 0
					AND main.transdate >= @KickOffDate
					AND main.statusID NOT IN (101, 102, 103)
		END 
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
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, matchid, bettype, IsMarked, transid)
		SELECT RefCode, custid, matchid, bettype, IsMarked
				, MAX(transid) AS transid
		FROM #SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, matchid, bettype, IsMarked
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
						,SubOdds		
						,oddsspread
						,OddsType		
						,transdate		
						,bettype 		
						,betteam 		
						,SubBetTeam
						,betcheck	
						,SubBetcheck	
						,hdp1 			
						,hdp2 			
						,livehomescore 	
						,liveawayscore 	
						,creator		
						,Stake			
						,currencyname		
						,STATUS			
						,SubStatus	
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
						,WinLost
						,IsMarked
						,LiveIndicator
						,mainstatusid
						,ActualStake
						,matchid
						,winlostdate
					)
				SELECT 
						b.transid AS GroupID
						,b.transid
						,b.transid AS SubTransID
						,b.refno
						,b.custid
						,b.odds
						,b.odds AS SubOdds
						,b.oddsspread
						,b.OddsType
						,b.transdate
						,b.bettype
						,b.betteam
						,b.betteam AS SubBetteam
						,b.betcheck
						,b.betcheck AS SubBetcheck
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
							END AS SubStatus
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
						,b.winlost - b.actual_stake AS WinLost
						,t.IsMarked
						,b.liveindicator
						,b.statusID AS mainstatusid
						,b.actual_stake AS ActualStake
						,t.matchid
						,b.winlostdate
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = t.matchid
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1 -- reject, void, refund	
						  WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						  ELSE 0 END 
		END  			    				    					    				    					    	
	END

	IF @IssueTypeId <> 13 --AB,DA,EKO,WKO,RC
	BEGIN
		UPDATE	main
			SET main.SoldId = sub.transid
		OUTPUT INSERTED.SoldId
		INTO #tblSoldTicket(transid)
		FROM #SpecialDeleteBets main 
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND main.betdaqid = 0 -- main ticket is BTrade
					AND main.extrainfo is null
					AND sub.matchid = main.matchid
					AND sub.bettype = 901
			
		-- get sub ticket of BetTrade (901)
		INSERT INTO #SpecialDeleteBets (
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype
				,OriginalBetType 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
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
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
			,ActualStake
				,matchid
			)
		SELECT  main.transid AS GroupTransId
				,sub.transid AS transId
				,sub.transid AS SubTransId
				,sub.refno
				,sub.custid
				,main.odds
				,main.odds AS SubOdds
				,main.oddsspread
				,main.OddsType
				,sub.transdate
				,sub.bettype
				,main.bettype  AS OriginalBetType
				,main.betteam
				,main.SubBetTeam
				,main.betcheck
				,main.SubBetcheck
				,main.hdp1
				,main.hdp2			
				,main.livehomescore
				,main.liveawayscore
				,sub.creator
				,main.Stake
				,main.CurrencyName
				,'SOLD'
				,'SOLD' AS SubStatus
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
				,sub.winlost - sub.actual_stake AS WinLost
				,main.IsMarked
				,main.LiveIndicator
				,main.mainstatusid
			,main.ActualStake
				,main.matchid
		FROM	#SpecialDeleteBets main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND sub.matchid = main.matchid
					AND sub.bettype = 901
			INNER JOIN #tblSoldTicket sold 
				ON sold.transid = sub.transid
	END	
	ELSE  -- Abnormal account
	BEGIN
		-- UPDATE eventtype = 1
		IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype NOT IN (9, 29, 2799)))
		BEGIN
			UPDATE d
			SET matchcode 	= m.matchcode
				,homeid 	= m.homeid
				,awayid 	= m.awayid
				,leagueid 	= m.leagueid
				,sporttype 	= m.sporttype
				,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
				,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			FROM #SpecialDeleteBets d
				INNER JOIN dbo.match m WITH (NOLOCK) 
				ON	d.matchid = m.matchid
			WHERE d.bettype NOT IN (9, 29, 2799)
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

		-- UPDATE IsMixParlay = 1 [MixParlay bettype]
		IF(EXISTS(SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE bettype IN (9, 29, 2799)))
		BEGIN
			UPDATE d
			SET IsMixParlay = 1
			FROM #SpecialDeleteBets d
			WHERE d.bettype IN (9, 29, 2799)
		END

		--- Remove invalid sporttype
		DELETE 
		FROM #SpecialDeleteBets
		WHERE bettype NOT IN (9, 29, 2799)
			AND (
				sporttype IS NULL
				OR bettype = 500 /*charge comm*/
			)	

		-- Delete main bettrade
		IF(EXISTS (SELECT TOP 1 1 
				   FROM #SpecialDeleteBets 
				   WHERE betdaqid = 0 AND extrainfo IS NULL))
		BEGIN
			DELETE FROM #SpecialDeleteBets WHERE betdaqid = 0 AND extrainfo IS NULL
		END
	END
			
	-- get sub ticket of Cash-out (911)
	INSERT INTO #SpecialDeleteBets (
			GroupID			
			,transid		
			,SubTransid		
			,refno			
			,custid			
			,odds					
			,SubOdds
			,oddsspread				
			,OddsType		
			,transdate		
			,bettype
			,OriginalBetType 		
			,betteam 		
			,SubBetTeam
			,betcheck	
			,SubBetcheck	
			,hdp1 			
			,hdp2 			
			,livehomescore 	
			,liveawayscore 	
			,creator		
			,Stake			
			,currencyname		
			,STATUS			
			,SubStatus	
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
			,WinLost
			,IsMarked
			,LiveIndicator
			,mainstatusid
			,ActualStake
			,homeid    
			,awayid    
			,leagueid  
			,isNeutral 
			,matchcode 
			,showtime
			,sporttype
			,winlostdate
			,statusID
			,IsCashOutTicket
		)
	SELECT  sub911.transid AS GroupTransId
			,sub911.transid AS transId
			,sub911.transid AS SubTransId
			,sub911.refno
			,sub911.custid
			,main.odds
			,main.odds AS SubOdds
			,main.oddsspread
			,main.OddsType
			,sub911.transdate
			,sub911.bettype
			,main.bettype AS OriginalBetType
			,main.betteam
			,main.SubBetTeam
			,main.betcheck
			,main.SubBetcheck
			,main.hdp1
			,main.hdp2			
			,main.livehomescore
			,main.liveawayscore
			,sub911.creator
			,sub911.Stake
			,main.CurrencyName
			,'Cash out'
			,'Cash out' AS SubStatus
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
			,sub911.winlost - sub911.actual_stake AS WinLost
			,main.IsMarked
			,main.LiveIndicator
			,main.mainstatusid
			,main.ActualStake
			,main.homeid
			,main.awayid
			,main.leagueid
			,main.IsNeutral
			,main.matchcode
			,main.showtime
			,main.sporttype
			,main.winlostdate
			,main.statusID
			,1 AS IsCashOutTicket
	FROM dbo.bettrans sub911 WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets main 
				ON	sub911.refno = main.transid	
					AND sub911.custid = main.custid					
					AND main.betdaqid = 0
					AND charindex ('p25',main.extrainfo)> 0			
					AND sub911.bettype = 911
					AND sub911.matchid = main.matchid
	WHERE  1= CASE WHEN @ActionId <>2 AND sub911.statusID NOT IN (101, 102, 103) THEN 1 -- reject, void, refund	
						  WHEN @ActionId = 2 AND sub911.statusID NOT IN (101, 103) THEN 1
						  ELSE 0 END 					
		
	-- get cash-out member bet tickets	
	INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread				
				,OddsType		
				,transdate		
				,bettype 
				,OriginalBetType		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
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
				,WinLost
				,IsMarked
				,LiveIndicator
				,mainstatusid
				,ActualStake
				,matchid
				,homeid    
				,awayid    
				,leagueid  
				,isNeutral 
				,matchcode 
				,showtime
				,sporttype
				,winlostdate
				,statusID
				,IsCashOutTicket
			)
		SELECT  sub911.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread
				,b.OddsType
				,b.transdate
				,b.bettype
				,sub911.OriginalBetType
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
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
					END AS SubStatus
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
				,b.winlost - b.actual_stake AS WinLost
				,sub911.IsMarked
				,b.liveindicator
				,b.statusID AS mainstatusid
				,b.actual_stake AS ActualStake
				,b.matchid
				,sub911.homeid
				,sub911.awayid
				,sub911.leagueid
				,sub911.IsNeutral
				,sub911.matchcode
				,sub911.showtime
				,sub911.sporttype
				,sub911.winlostdate
				,sub911.statusID
				,1 AS IsCashOutTicket
	FROM #SpecialDeleteBets sub911
			CROSS APPLY (
							SELECT b.transid, b.refno, b.custid, b.oddsid, b.oddsspread, b.oddstype, b.transdate, b.bettype, b.betteam, b.betcheck, b.status
								,b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.creator, b.stake, b.CurrencyName, b.SecAcceptFlag, b.checktime, b.odds
								,b.srecommend, b.mrecommend, b.recommend, b.betid, b.transdesc, b.betdaqid, b.ExtraInfo, b.WalletType, b.RefCode, b.BonusID, b.winlost, b.actual_stake,liveindicator,statusID,b.matchid
							FROM dbo.bettrans b WITH (NOLOCK)
							WHERE b.refno = sub911.transid
							AND b.matchid = sub911.matchid					
							AND b.bettype = sub911.OriginalBetType
							AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
										WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
										ELSE 0 END
						) AS b
	WHERE sub911.bettype = 911
			 	
	-- update username/creatorname column
	UPDATE al
		SET username = ci.username
			,creatorName = cr.username
			,SubLeagueId = m.Leagueid
			,sporttype = m.Sporttype
	FROM	#SpecialDeleteBets al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK)
			ON al.creator = cr.custid
		INNER JOIN #TmpMatch m ON al.matchid = m.matchid
			
			
	-- update Isdeposit
	UPDATE al 
		SET IsDeposit = 1
	FROM	#SpecialDeleteBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)
	
	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(bettype	SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype ON #InstantSettlementBettypes(bettype)
		
		DECLARE @TempMatchID TABLE( MatchID INT, Bettype SMALLINT, IsFinish BIT)
		INSERT INTO @TempMatchID (MatchID,Bettype)
		SELECT m.MatchId, s.bettype
		FROM #TmpMatch m
		CROSS APPLY ( SELECT DISTINCT s.bettype
						FROM #SpecialDeleteBets s where m.matchid = s.matchid
					)s

		IF @MatchId <> 0
		BEGIN
			--> Get status of match
			SELECT @IsHTCal = ISNULL(IsHTCal, 0)		 
			FROM match_remark (NOLOCK)
			WHERE matchid = @MatchID	
	
			SELECT @eventstatus = ISNULL(eventstatus, '')
			FROM match (NOLOCK)
			WHERE matchid = @MatchID		
	
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
		ELSE
		BEGIN
			DECLARE @OldMatchID INT = 0

			WHILE (1=1)
			  -- multiple match = 0
			BEGIN
				DELETE @tmpMatchIDBatch
				UPDATE TOP (1) m
					SET IsFinish = 1
					   ,@MatchId = m.MatchID
				OUTPUT DELETED.matchid
					  ,DELETED.bettype
				INTO @tmpMatchIDBatch (MatchID, bettype)
				FROM @TempMatchID m
					WHERE IsFinish IS NULL
				
				IF @@ROWCOUNT = 0 BREAK

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
					IF @IsHTCal = 0 AND @MatchId <> @OldMatchID
						INSERT INTO #InstantSettlementBettypes(bettype)
						SELECT T.bettype
						FROM dbo.f_Set_Instant_GetBettypes() T
						WHERE T.InstantType IN (1, 3) -- 01, 11

					IF @IsHTCal = 1 AND @MatchId <> @OldMatchID
						INSERT INTO #InstantSettlementBettypes(bettype)
						SELECT T.bettype
						FROM dbo.f_Set_Instant_GetBettypes() T
						WHERE T.InstantType IN (2, 3) -- 10, 11				
				END	

				SET @OldMatchID = @MatchId

			END
		END	
	END	

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
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.OriginalBetType
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
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
			   ,CASE WHEN c.site = 'CN88' THEN 'CN88' ELSE 'Credit' END AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsCashOutTicket
		FROM	#SpecialDeleteBets s
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				ON s.custid = f.CustID
			LEFT JOIN #SpecialDeleteBets sub
				ON	s.GroupID = sub.GroupID
					AND s.transid <> sub.transid
			LEFT JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = s.recommend		
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
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.OriginalBetType
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
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
			   ,'8RM/BARM' AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsCashOutTicket
		FROM	#SpecialDeleteBets s 
			LEFT JOIN dbo.bettrans b WITH(NOLOCK)
				ON	s.betid = b.transid
					AND b.matchid = s.matchid --@matchid	
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
			   ,s.SubOdds
			   ,s.oddsspread
			   ,s.OddsType
			   ,s.bettype
			   ,s.OriginalBetType
			   ,s.STATUS
			   ,s.SubStatus
			   ,s.currencyname
			   ,s.betteam
			   ,s.SubBetTeam
			   ,s.SubLeagueId
			   ,s.Subhdp1
			   ,s.Subhdp2
			   ,s.hdp1
			   ,s.hdp2
			   ,s.livehomescore
			   ,s.liveawayscore
			   ,s.betid
			   ,s.betcheck
			   ,s.SubBetcheck
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
			   ,'Deposit' AS OriginGroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
			   ,s.mainstatusid
			   ,s.ActualStake
			   ,s.matchid
			   ,s.homeid    
			   ,s.awayid    
			   ,s.leagueid  
			   ,s.isNeutral 
			   ,s.matchcode
			   ,s.winlostdate
			   ,s.statusID
			   ,s.IsCashOutTicket
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
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.OriginalBetType
		   ,s.STATUS
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.SubLeagueId
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
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
		   ,'Betfair' AS OriginGroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.BonusID
		   ,s.RefCode
		   ,s.WinLost
		   ,s.IsMarked
		   ,s.recommend
		   ,s.LiveIndicator
		   ,s.mainstatusid
		   ,s.ActualStake
		   ,s.matchid
		   ,s.homeid    
		   ,s.awayid    
		   ,s.leagueid  
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.statusID
		   ,s.IsCashOutTicket
		FROM	#SpecialDeleteBets s WITH (NOLOCK)
			LEFT JOIN #SpecialDeleteBets sub
				ON s.GroupID = sub.GroupID AND s.GroupID <> sub.transid
		WHERE	s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
				OR sub.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
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
													 WHERE bettype = s.MainBettype
													 )
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
	SELECT CASE WHEN s.bettype BETWEEN 801 AND 806 THEN s.refno ELSE s.transid END transid
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,s.username	
		   ,s.transdate
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.OriginalBetType
		   ,s.STATUS
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.SubLeagueId
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
		   ,s.IsMixParlay
		   ,s.ParlayType AS SubBettype
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
		   ,s.SubGroupName AS GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.RefCode
		   ,m.SettlementStatus AS SettlementStatus
		   ,s.WinLost
		   ,s.IsMarked
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.ActualStake
		   ,s.matchid
		   ,s.homeid    
		   ,s.awayid    
		   ,s.leagueid  
		   ,s.isNeutral 
		   ,s.matchcode
		   ,s.winlostdate
		   ,s.statusID
		   ,s.IsCashOutTicket
	FROM CTE_SettledTypeFiltering s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
		INNER JOIN #TmpMatch m ON s.matchid = m.matchid
	WHERE 1 = CASE WHEN @IssueTypeId <> 13 THEN 1
				   WHEN @IssueTypeId = 13 AND  s.statusId IN (SELECT statusID FROM @Status_tmp)	 THEN 1 
				   ELSE 0 END
	ORDER BY CASE
				WHEN s.OriginGroupName = 'CN88' THEN 1
				WHEN s.OriginGroupName = 'Credit' THEN 2
				WHEN s.OriginGroupName = '8RM/BARM' THEN 3
				WHEN s.OriginGroupName = 'Deposit' THEN 4
				WHEN s.OriginGroupName = 'Betfair' THEN 5 
			 END
			, CASE WHEN s.SubGroupName NOT LIKE '%(Instant Settlement)' THEN 1
				ELSE 2
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
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tblBetType
	DROP TABLE #tblBetType_Detail
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #TmpMatch
END

GO

