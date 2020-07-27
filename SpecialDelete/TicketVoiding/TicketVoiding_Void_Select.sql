/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Select] 
(
	@MatchId		INT
    ,@KickOffDate	DATETIME = NULL
    ,@RequestId		INT = NULL
    ,@IssueTypeId	INT = NULL
	,@BetTypes    XML      = NULL
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
        LiveIndicator			BIT,
		FilterBettype      SMALLINT,
        FilterBetTeam      NVARCHAR(10),
        FilterSet          VARCHAR(50),
        FilterGame         VARCHAR(50),
        FilterValue        SMALLMONEY,
        FilterGoal         BIGINT,
        FilterBetOption    NVARCHAR(50),
        FilterTimeInterval SMALLMONEY,
    )
    CREATE TABLE #tmpRefCodeSummary
             (RefCode  BIGINT,
              custid   INT,
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

	DECLARE @SportType	SMALLINT
			,@LeagueId	INT
	
	SELECT	@SportType = Sporttype 
			,@LeagueId = leagueid
	FROM	dbo.match WITH(NOLOCK) 
	WHERE	matchid = @matchid
	

	DECLARE @SettlementStatus TINYINT = NULL
	SELECT @SettlementStatus = m.SettlementStatus FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId


	
	IF @IssueTypeId = 11 --11: AbnormalBet
	BEGIN
		DECLARE @TransIds VARCHAR(MAX)
		DECLARE @transIdTemp TABLE (transid BIGINT NULL);
		
		SET @TransIds = (
						SELECT trd.TransIds
						FROM TicketVoiding_Request tr WITH (NOLOCK)
						INNER JOIN TicketVoiding_RequestDetail trd WITH (NOLOCK)
							ON trd.RequestId = tr.RequestId
						WHERE tr.RequestId = @RequestId
						)
		IF @TransIds IS NOT NULL
		BEGIN
			INSERT INTO @transIdTemp (transid)
			SELECT DISTINCT val
			FROM dbo.f_SplitString(@TransIds, ',')
			OPTION (MAXRECURSION 0)
		END
	
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
		FROM	bettrans b WITH (NOLOCK)	
			INNER JOIN @transIdTemp t ON t.transid = b.transid
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
		WHERE  b.statusID NOT IN (101, 102, 103) -- reject, void, refund
			  	
					
	END
	ELSE IF @IssueTypeId = 1
	BEGIN
		IF @BetTypes IS NOT NULL
		BEGIN
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
					,FilterGoal
					,FilterBetOption
					,FilterTimeInterval
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
					,ISNULL(b.betid, 0) AS FilterGoal
					,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
					,b.hdp1 AS FilterTimeInterval
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
					AND b.liveindicator = 0
					AND b.bettype NOT IN (805, 806, 9, 29)			
					AND b.bettype NOT BETWEEN 901 AND 920
					AND b.betfrom <> 'P'	
		

			-- Metric Gaming Super Live
			IF EXISTS( SELECT TOP 1 1 FROM #tblBettype WHERE Id IN (805, 806))
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
						,WinLost
						,IsMarked
						,LiveIndicator
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
				FROM	Translog b WITH (NOLOCK)
					 LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId	
					 INNER JOIN #tblBettype tp 
						ON	tp.Id = b.gameID
					CROSS APPLY (
								SELECT TOP (1) transid
								FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
								WHERE transid = b.translogid
									AND RequestId = @RequestId
						) ts
				WHERE	b.EventID = @matchid
						AND b.statusID NOT IN (101, 102, 103) -- REJECT, VOID, refund
						AND b.liveindicator = 0
						AND b.GameID IN (805, 806) 
						AND b.betfrom <> 'P'
			END
		
			---get sub ticket of a mix parlay	
			IF EXISTS (
					SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
					WHERE bm.matchid = @matchid
						AND bm.statusID NOT IN (101, 102, 103)
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
						,FilterBettype
						,FilterBetTeam
						,FilterSet
						,FilterGame	
						,FilterValue
						,FilterGoal
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
						,ISNULL(sub.betcheck, 0) AS FilterGoal
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
						AND sub.liveindicator = 0
						AND sub.betfrom <> 'P'
						AND main.matchid = 29
						AND main.bettype = 29
						AND main.liveindicator = 0
						AND main.statusID NOT IN (101, 102, 103)
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
					WHERE tp.Id = b.FilterBettype AND (tp.TimeInterval = 9999 OR b.FilterTimeInterval = tp.TimeInterval ) OR b.bettype = 29) 
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
					AND b.liveindicator = 0
					AND b.bettype NOT IN (805, 806, 9, 29)			
					AND b.bettype NOT BETWEEN 901 AND 920
					AND b.betfrom <> 'P'	
					

			-- Metric Gaming Super Live
			IF EXISTS( SELECT TOP 1 1 FROM #tblBettype WHERE Id IN (805, 806))
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
						,WinLost
						,IsMarked
						,LiveIndicator
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
				FROM	Translog b WITH (NOLOCK)
					LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId	
					CROSS APPLY (
								SELECT TOP (1) transid
								FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
								WHERE transid = b.translogid
									AND RequestId = @RequestId
						) ts
				WHERE	b.EventID = @matchid
						AND b.statusID NOT IN (101, 102, 103) -- REJECT, VOID, refund
						AND b.liveindicator = 0
						AND b.GameID IN (805, 806) 
						AND b.betfrom <> 'P'
			END
		
			---get sub ticket of a mix parlay	
			IF EXISTS (
					SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
					WHERE bm.matchid = @matchid
						AND bm.statusID NOT IN (101, 102, 103)
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
						AND sub.liveindicator = 0
						AND sub.betfrom <> 'P'
						AND main.matchid = 29
						AND main.bettype = 29
						AND main.liveindicator = 0
						AND main.statusID NOT IN (101, 102, 103)
			END 
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
		FROM	bettrans b WITH (NOLOCK)	
		   LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId			
		WHERE	b.matchid = @matchid
				AND b.transdate >= @KickOffDate
				AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
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
			FROM	Translog b WITH (NOLOCK)
				 LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId		
			WHERE	b.EventID = @matchid
					AND b.transdate >= @KickOffDate
					AND b.statusID NOT IN (101, 102, 103) -- REJECT, VOID, refund
					AND b.liveindicator = 0
					AND b.GameID IN (805, 806) 
					AND b.betfrom <> 'P'
									
			---get sub ticket of a mix parlay	
			IF EXISTS (
					SELECT 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
					WHERE bm.matchid = @matchid
						AND bm.transdate >= @KickOffDate
						AND bm.statusID NOT IN (101, 102, 103)
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
				FROM	dbo.bettransm sub WITH (NOLOCK)				
						INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
							ON	main.refno = sub.refno				
								AND sub.matchid = @matchid
				WHERE	sub.transdate >= @KickOffDate
						AND sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
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
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = @MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE b.statusID NOT IN (101,102, 103 ) -- reject, void, refund	
		END  			    				    					    				    					    	
	END

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
	FROM dbo.bettrans sub911 WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets main 
				ON	sub911.refno = main.transid	
					AND sub911.custid = main.custid					
					AND main.betdaqid = 0
					AND charindex ('p25',main.extrainfo)> 0			
					AND sub911.bettype = 911
					AND sub911.matchid = @matchid
	WHERE sub911.statusID NOT IN (102, 101, 103) -- VOID, REJECT, refund					
		
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
	FROM #SpecialDeleteBets sub911
			CROSS APPLY (
							SELECT b.transid, b.refno, b.custid, b.oddsid, b.oddsspread, b.oddstype, b.transdate, b.bettype, b.betteam, b.betcheck, b.status
								,b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.creator, b.stake, b.CurrencyName, b.SecAcceptFlag, b.checktime, b.odds
								,b.srecommend, b.mrecommend, b.recommend, b.betid, b.transdesc, b.betdaqid, b.ExtraInfo, b.WalletType, b.RefCode, b.BonusID, b.winlost, b.actual_stake,liveindicator
							FROM dbo.bettrans b WITH (NOLOCK)
							WHERE b.refno = sub911.transid
							AND b.matchid = sub911.matchid					
							AND b.bettype = sub911.OriginalBetType
							AND b.statusID NOT IN (102, 101, 103) -- VOID, REJECT, refund
						) AS b
	WHERE sub911.bettype = 911
			 	
	-- update username/creatorname column
	UPDATE al
		SET username = ci.username
			,creatorName = cr.username
			,SubLeagueId = @LeagueId
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
			   ,CASE WHEN c.site = 'CN88' THEN 'CN88' ELSE 'Credit' END AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
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
			   ,'8RM/BARM' AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
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
			   ,'Deposit' AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
			   ,s.recommend
			   ,s.LiveIndicator
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
		   ,'Betfair' AS GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.BonusID
		   ,s.RefCode
		   ,s.WinLost
		   ,s.IsMarked
		   ,s.recommend
		   ,s.LiveIndicator
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
		   ,s.GroupName
		   ,s.WalletType		   
		   ,s.MainTransId
		   ,s.RefCode
		   ,@SettlementStatus AS SettlementStatus
		   ,s.WinLost
		   ,s.IsMarked
		   ,c.site as LicenseeName
		   ,s.LiveIndicator AS IsLiveIndicator
	FROM CTE_OriginResult s
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON s.recommend = c.custid
	ORDER BY CASE
				WHEN s.GroupName = 'CN88' THEN 1
				WHEN s.GroupName = 'Credit' THEN 2
				WHEN s.GroupName = '8RM/BARM' THEN 3
				WHEN s.GroupName = 'Deposit' THEN 4
				WHEN s.GroupName = 'Betfair' THEN 5 
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
	
END
GO

