/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_Select]
(	
	@MatchId              INT
	,@RequestId			  INT = 0
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime	  DATETIME = NULL
	,@FilterFromBetId	  BIGINT = NULL
	,@FilterToBetId		  BIGINT = NULL
	,@FilterBy			  TINYINT = 1
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@SubIssueTypeId	  INT = NULL
	,@IsCheckedHomeTeam   BIT = 0
	,@IsCheckedAwayTeam   BIT = 0
	,@KickOffTime		  DATETIME = NULL
	,@WrongScoreInfo			VARCHAR(MAX) = ''
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20201002@Max: [TVS] - Modify bet type list on Home/Away Team filter of Danger Accept [Redmine: #142883]
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201015@Max: [TVS] - HotFix - Danger accept add by accept time can add ticket super live [Redmine: #143308]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201102@Max: TVS - Enhance for Danger Accept - Phase 4 - Show LogInfo when voided [Redmine: #143091]
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210322@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210510@Max: [TVS] Danger Accept/Red Card Enhancement - Search and save not same log info [Redmine: #154772]
		- 20210511@Max: TVS - Wrong Score [Redmine: #140953]
	
	Param's explanation:
		+ SubIssueTypeId in (1,2) will show IsCheckedHomeTeam, IsCheckedAwayTeam
		+ @WrongScoreInfo:
		<root>
			<r LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" />
		</root>
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @IsInvalidTransId     BIT = 0
			,@IsInValidTotalTickets   BIT = 0
			,@IsInvalidLiveScore	  BIT = 0
			,@IsExistedInOtherRequest BIT = 0
			,@totalRecord			  INT = 0
			,@SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@IsExistSingle			  BIT = 0
			,@IsExistParlay			  BIT = 0
			,@IsExistFM				  BIT = 0
			,@IsExistFM2			  BIT = 0
			,@MatchProcessXML		  XML = NULL
			,@InstantlySettleCount	  INT = 0
			,@WrongScoreInfoXML		XML = NULL
			,@LiveHomeScore			SMALLINT
			,@LiveAwayScore			SMALLINT
			,@FilterFromTime		DATETIME
			,@FilterToTime			DATETIME
	
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
			StatusId			  TINYINT,
			checktime			  DATETIME
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode  BIGINT,
			custid   INT,
			bettype  SMALLINT,
			transid  BIGINT,
			IsMarked BIT
	)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	CREATE TABLE #logInfo (
		MatchId INT
		,LiveScores NVARCHAR(300)
		,VoidFromTime DATETIME
		,VoidToTime DATETIME
		,SingleCount INT
		,CashOutCount INT
		,InstantlySettleCount INT
		,MainParlayCount INT
		,MinSingleTransId BIGINT
		,MaxSingleTransId BIGINT
		,MinMainParlayTransId BIGINT
		,MaxMainParlayTransId BIGINT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, livehomescore SMALLINT,liveawayscore SMALLINT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY, transdate DATETIME)
	CREATE TABLE #CashOuts (RequestId INT, MatchId INT, transid BIGINT, bettype SMALLINT, OriginalBetType SMALLINT, IsCOTicket BIT)
	CREATE TABLE #WrongScores (MatchId INT, LiveHomeScore SMALLINT, LiveAwayScore SMALLINT, FilterFromTime DATETIME, FilterToTime DATETIME)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

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

	IF @IssueTypeId IN (1,10)
	BEGIN
		/*Generate LogInfo*/
		/*Check valid transid*/
		IF @FilterBy = 0
		BEGIN
			INSERT INTO #transIdTemp (transid, transdate)
			SELECT b.transid, b.transdate
			FROM dbo.bettrans b WITH (NOLOCK)        
			WHERE transid IN (@FilterFromBetId,@FilterToBetId)
				AND matchid = @MatchID 

			SELECT @totalRecord = COUNT(1)
			FROM #transIdTemp
    
			IF (@FilterFromBetId = @FilterToBetId AND @totalRecord <> 1) OR (@FilterFromBetId <> @FilterToBetId AND @totalRecord <> 2)
			BEGIN
				SELECT @IsInvalidTransId = 1
			
				--Error Table
				SELECT @IsInvalidTransId AS IsInvalidTransId
					,@IsInvalidLiveScore AS IsInvalidLiveScore
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,@IsExistedInOtherRequest AS IsExistedInOtherRequest
					,@IsExistSingle AS IsExistSingle
					,@IsExistParlay AS IsExistParlay
					,@IsExistFM AS IsExistFM
					,@IsExistFM2 AS IsExistFM2
					,@MatchProcessXML AS MatchProcessXML

				--TransId in request table
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
					,r.RequestId
					,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
				FROM #TransidInRequest r
			
				--Loginfo Table
				SELECT @MatchId AS MatchId 
					,l.LiveScores
					,l.VoidFromTime
					,l.VoidToTime
					,l.SingleCount
					,l.CashOutCount
					,l.InstantlySettleCount
					,l.MainParlayCount
					,l.MinSingleTransId
					,l.MaxSingleTransId
					,l.MinMainParlayTransId
					,l.MaxMainParlayTransId
				FROM #logInfo l

				RETURN;
			END
		
			SELECT @FilterFromTransTime = MIN(t.transdate)
				,@FilterToTransTime = MAX(t.transdate)
			FROM #transIdTemp t
		END

		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

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
				,matchid
				,StatusId
				,checktime
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
				,@MatchId
				,b.statusID
				,b.checktime
		FROM	bettrans b WITH (NOLOCK)	
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE	b.matchid = @matchid
				AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
				AND b.betfrom <> 'P'
				AND 1 = CASE WHEN @FilterBy = 1 AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
							WHEN @FilterBy = 2 AND b.checktime IS NOT NULL AND b.checktime BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
							WHEN @FilterBy = 2 AND b.checktime IS NULL AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
							WHEN @FilterBy = 0 AND b.transid BETWEEN @FilterFromBetId AND @FilterToBetId THEN 1
							ELSE 0 END
				AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
							ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
									  WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
									  WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
									  ELSE 0 END
							END)
		
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
					AND 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
								 WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								 ELSE 0 END
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
					,matchid
					,StatusId
					,checktime
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
					,@MatchId
					,main.statusID
					,sub.checktime
			FROM	dbo.bettransm sub WITH (NOLOCK)				
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
			WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						   ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND CASE WHEN @FilterBy = 0 THEN sub.transdate
							WHEN @FilterBy = 1 THEN sub.transdate
							WHEN @FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							WHEN @FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
						END BETWEEN @FilterFromTransTime AND @FilterToTransTime
				        AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
							ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
										   WHEN @IsCheckedAwayTeam = 1 AND sub.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
										   WHEN @IsCheckedHomeTeam = 1 AND sub.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
										   ELSE 0 END
							END)
		END 

	END
	IF @IssueTypeId IN (8,9)
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
				,matchid
				,StatusId
				,checktime
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
				,@MatchId
				,b.statusID
				,b.checktime
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
				AND b.transdate >= @KickOffTime
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
				,matchid
				,StatusId
				,checktime
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
				,@MatchId
				,b.statusID
				,NULL
		FROM	Translog b WITH (NOLOCK)
				LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId		
		WHERE	b.EventID = @matchid
				AND b.transdate >= @KickOffTime
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
					AND bm.transdate >= @KickOffTime
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
					,matchid
					,StatusId
					,checktime
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
					,@MatchId
					,main.statusID
					,sub.checktime
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
			WHERE	sub.transdate >= @KickOffTime
					AND 1= CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
								WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND sub.liveindicator = 0
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND main.liveindicator = 0
					AND main.transdate >= @KickOffTime
					AND main.statusID NOT IN (101, 102, 103)
		END 
	END
	IF @IssueTypeId = 3 AND @WrongScoreInfo <> '' --Wrong Score
	BEGIN
		SET @WrongScoreInfoXML = CONVERT(XML, @WrongScoreInfo)
		
		INSERT INTO #WrongScores(MatchId, LiveHomeScore, LiveAwayScore, FilterFromTime, FilterToTime)
		SELECT	@MatchId
				,T.C.value('./@LiveHomeScore', 'smallint')
				,T.C.value('./@LiveAwayScore', 'smallint')
				,T.C.value('./@FilterFromTransTime', 'datetime')
				,T.C.value('./@FilterToTransTime', 'datetime')
		FROM	@WrongScoreInfoXML.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL ))
		
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
				,@MatchId
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
				AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.bettype NOT IN (805, 806, 9, 29)			
				AND b.bettype NOT BETWEEN 901 AND 920
				AND b.betfrom <> 'P'
				AND EXISTS (SELECT TOP 1 1 
								FROM #WrongScores
								WHERE matchid = @MatchId
									AND b.livehomescore = LiveHomeScore
									AND b.liveawayscore = LiveAwayScore
									AND b.transdate BETWEEN FilterFromTime AND FilterToTime)
				
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
				WHERE bm.matchid = @matchid
					AND 1= CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND bm.betfrom <> 'P'
					AND EXISTS (SELECT TOP 1 1 
								FROM #WrongScores
								WHERE matchid = @MatchId
									AND bm.livehomescore = LiveHomeScore
									AND bm.liveawayscore = LiveAwayScore
									AND bm.transdate BETWEEN FilterFromTime AND FilterToTime)
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
					,@MatchId
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
			WHERE 1= CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) AND tmp.TransId IS NULL THEN 1
								WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND main.liveindicator = 0
					AND main.statusID NOT IN (101, 102, 103)
					AND EXISTS (SELECT TOP 1 1 
								FROM #WrongScores
								WHERE matchid = @MatchId
									AND sub.livehomescore = LiveHomeScore
									AND sub.liveawayscore = LiveAwayScore
									AND sub.transdate BETWEEN FilterFromTime AND FilterToTime)
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
						,matchid
						,StatusId
						,checktime
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
						,@MatchId
						,b.statusID
						,b.checktime
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = @MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND 1 = CASE WHEN @IssueTypeId IN (1,10)   
									AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
											 ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
													   WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
													   WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
													   ELSE 0 END
									END) THEN 1 
								 WHEN @IssueTypeId IN (8,9) THEN 1 ELSE 0 END
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
			,StatusId
			,checktime
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
			,main.StatusId
			,sub911.checktime
	FROM dbo.bettrans sub911 WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets main 
				ON	sub911.refno = main.transid	
					AND sub911.custid = main.custid					
					AND main.betdaqid = 0
					AND charindex ('p25',main.extrainfo)> 0			
					AND sub911.bettype = 911
					AND sub911.matchid = @matchid
	WHERE 1 = CASE WHEN @ActionId <>2 AND sub911.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId =2 AND sub911.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END							
			AND 1 = CASE WHEN @IssueTypeId IN (1,10)
							AND (1 = CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
									ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
										WHEN @IsCheckedAwayTeam = 1 AND main.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
										WHEN @IsCheckedHomeTeam = 1 AND main.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
										ELSE 0 END
								END) THEN 1 
						WHEN @IssueTypeId IN (8,9) THEN 1 
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
				,matchid
				,StatusId
				,checktime
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
				,@MatchId
				,b.statusID
				,sub911.checktime
	FROM #SpecialDeleteBets sub911
			CROSS APPLY (
							SELECT b.transid, b.refno, b.custid, b.oddsid, b.oddsspread, b.oddstype, b.transdate, b.bettype, b.betteam, b.betcheck, b.status
								,b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.creator, b.stake, b.CurrencyName, b.SecAcceptFlag, b.checktime, b.odds
								,b.srecommend, b.mrecommend, b.recommend, b.betid, b.transdesc, b.betdaqid, b.ExtraInfo, b.WalletType, b.RefCode, b.BonusID, b.winlost, b.actual_stake,liveindicator,statusID
							FROM dbo.bettrans b WITH (NOLOCK)
							WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid					
								AND b.bettype = sub911.OriginalBetType
								AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
												WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
												ELSE 0 END
								AND 1 = CASE WHEN @IssueTypeId IN (1,10) AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
															 ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
																	   WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
																	   WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
																	   ELSE 0 END
															END) THEN 1 
											WHEN @IssueTypeId IN (8,9) THEN 1 ELSE 0 END
						) AS b
	WHERE sub911.bettype = 911
	
	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		IF @IssueTypeId IN (8,9)
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId)
			SELECT tmp.transid, rd.RequestId, tmp.MainTransId
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.RequestId = r.RequestId
								AND rs.MatchId = @MatchId
							UNION ALL
							SELECT rp.TransId, b.transid AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
								INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
								INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
							WHERE rp.RequestId = r.RequestId
								AND rp.MatchId = @MatchId
					)tmp
			WHERE rd.MatchId = @MatchId
				AND r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2)
		END
		ELSE
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, livehomescore, liveawayscore)
			SELECT tmp.transid, rd.RequestId, tmp.MainTransId, t.livehomescore, t.liveawayscore
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId 
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.RequestId = r.RequestId
								AND rs.MatchId = @MatchId
							UNION ALL
							SELECT rp.TransId, b.transid AS MainTransId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
								INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
								INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno
							WHERE rp.RequestId = r.RequestId
								AND rp.MatchId = @MatchId
					)tmp
				INNER JOIN #SpecialDeleteBets t ON t.SubTransid = tmp.transid
			WHERE rd.MatchId = @MatchId
				AND r.RequestId <> @RequestId
				AND r.ActionId NOT IN (2)
		END

		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId)
	SELECT @MatchId AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + ' - ' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(CASE WHEN ISNULL(b.betdaqid,-1) NOT IN (1) AND @FilterBy = 1 THEN b.transdate
				  WHEN ISNULL(b.betdaqid,-1) NOT IN (1) AND @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
				  WHEN ISNULL(b.betdaqid,-1) NOT IN (1) AND @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
				  END
			) AS VoidFromTime
		,MAX(CASE WHEN ISNULL(b.betdaqid,-1) NOT IN (1) AND @FilterBy = 1 THEN b.transdate
				  WHEN ISNULL(b.betdaqid,-1) NOT IN (1) AND @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
				  WHEN ISNULL(b.betdaqid,-1) NOT IN (1) AND @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
				  END
			) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) NOT IN (1) THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) = 1 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,MIN(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) NOT IN (1) THEN b.transid ELSE NULL END) AS MinSingleTransId
		,MAX(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) NOT IN (1) THEN b.transid ELSE NULL END) AS MaxSingleTransId
		,COUNT(CASE WHEN b.transid <> b.SubTransid AND (ISNULL(b.betdaqid,-1) NOT IN (1) OR b.IsMixParlay = 1) THEN b.transid ELSE NULL END) AS MainParlayCount
		,MIN(CASE WHEN b.transid <> b.SubTransid AND (ISNULL(b.betdaqid,-1) NOT IN (1) OR b.IsMixParlay = 1) THEN b.transid ELSE NULL END) AS MinSingleTransId
		,MAX(CASE WHEN b.transid <> b.SubTransid AND (ISNULL(b.betdaqid,-1) NOT IN (1) OR b.IsMixParlay = 1) THEN b.transid ELSE NULL END) AS MaxSingleTransId
	FROM #SpecialDeleteBets b WITH (NOLOCK)
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest t WHERE t.TransId = b.SubTransid)
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + ' - ' + CAST(b.liveawayscore AS VARCHAR(2))
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + ' - ' + CAST(b.liveawayscore AS VARCHAR(2))

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		--Error Table
		SELECT @IsInvalidTransId AS IsInvalidTransId
			,@IsInvalidLiveScore AS IsInvalidLiveScore
			,@IsInValidTotalTickets AS IsInValidTotalTickets
			,@IsExistedInOtherRequest AS IsExistedInOtherRequest
			,@IsExistSingle AS IsExistSingle
			,@IsExistParlay AS IsExistParlay
			,@IsExistFM AS IsExistFM
			,@IsExistFM2 AS IsExistFM2
			,@MatchProcessXML AS MatchProcessXML

		--TransId in request table
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId
			,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
		FROM #TransidInRequest r

		/*Get log info for Void Page*/
		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, IsCOTicket)
		SELECT @RequestId, @MatchId, s.TransId, b.bettype, 0
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid
		WHERE s.RequestId = @RequestId
			AND s.MatchId = @MatchId
			AND b.betdaqid = 0
			AND charindex ('p25',b.extrainfo)> 0	

		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, OriginalBetType, IsCOTicket)
		SELECT @RequestId, @MatchId 
			,sub911.transid
			,sub911.bettype
			,main.bettype
			,1
		FROM dbo.bettrans sub911 WITH(NOLOCK)
				INNER JOIN #CashOuts main 
					ON	sub911.refno = main.transid	
		WHERE sub911.matchid = @MatchId

		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, OriginalBetType, IsCOTicket)
		SELECT @RequestId, @MatchId 
			,b.transid
			,b.bettype
			,sub911.OriginalBetType
			,1
		FROM #CashOuts sub911
				CROSS APPLY (
								SELECT b.transid, b.bettype
								FROM dbo.bettrans b WITH (NOLOCK)
								WHERE b.refno = sub911.transid
									AND b.matchid = @MatchId					
									AND b.bettype = sub911.OriginalBetType
							) AS b
		WHERE sub911.bettype = 911

		/*Get Instant settlement*/
		SELECT @InstantlySettleCount = COUNT(s.TransId)
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid
		WHERE s.RequestId = @RequestId
			AND s.MatchId = @MatchId
			AND b.statusID IN (111,112,113)
			 AND EXISTS (SELECT TOP 1 1
						 FROM #InstantSettlementBettypes
						 WHERE bettype = b.bettype)

		SELECT rd.MatchId
			,rd.IssueDetail AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,c.CashOutCount AS CashOutCount
			,@InstantlySettleCount AS InstantlySettleCount
			,rd.MainParlayCount
			,rd.MinSingleTransId
			,rd.MaxSingleTransId
			,rd.MinMainParlayTransId
			,rd.MaxMainParlayTransId
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		  OUTER APPLY (
					SELECT COUNT(CASE WHEN IsCOTicket = 1 THEN transid ELSE NULL END) AS CashOutCount
					FROM #CashOuts
					WHERE RequestId = rd.RequestId	
						AND MatchId = rd.MatchId
			) c
		WHERE rd.RequestId = @RequestId

		RETURN;
	END

	IF @IssueTypeId IN (1, 10)
	BEGIN
		SELECT @SingleCount = SUM(SingleCount)
			,@MainParlayCount = SUM(MainParlayCount)
		FROM #logInfo
		GROUP BY MatchId

		IF @SingleCount = 0 AND @MainParlayCount = 0
		BEGIN
			SELECT @IsInValidTotalTickets = 1

			--Error Table
			SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest
				,@IsExistSingle AS IsExistSingle
				,@IsExistParlay AS IsExistParlay
				,@IsExistFM AS IsExistFM
				,@IsExistFM2 AS IsExistFM2
				,@MatchProcessXML AS MatchProcessXML

			--TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN			
				SELECT RequestId,
					STUFF((
					SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
					FROM #TransidInRequest
					WHERE (RequestId = r.RequestId) 
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
					,1,2,'') AS TransIds
					,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
				FROM #TransidInRequest r
				GROUP BY r.RequestId
					,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2))
			END
			ELSE
			BEGIN
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
					,r.RequestId
					,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
				FROM #TransidInRequest r
			END
			
			--Loginfo Table
			IF @IssueTypeId <> 3
			BEGIN
				SELECT MatchId
					,STUFF((SELECT '|' + LiveScores
							FROM #logInfo WITH (NOLOCK)
							FOR XML PATH ('')
							),1,1,'') AS LiveScores
					,MIN(VoidFromTime) AS VoidFromTime
					,MAX(VoidToTime) AS VoidToTime
					,SUM(SingleCount) AS SingleCount
					,SUM(CashOutCount) AS CashOutCount
				,SUM(InstantlySettleCount) AS InstantlySettleCount
					,SUM(MainParlayCount) AS MainParlayCount
					,MIN(MinSingleTransId) AS MinSingleTransId
					,MAX(MaxSingleTransId) AS MaxSingleTransId
					,MIN(MinMainParlayTransId) AS MinMainParlayTransId
					,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
				FROM #logInfo
				GROUP BY MatchId
			END
			ELSE
			BEGIN
				SELECT MatchId
					,LiveScores
					,MIN(VoidFromTime) AS VoidFromTime
					,MAX(VoidToTime) AS VoidToTime
					,SUM(SingleCount) AS SingleCount
					,SUM(CashOutCount) AS CashOutCount
					,SUM(MainParlayCount) AS MainParlayCount
					,MIN(MinSingleTransId) AS MinSingleTransId
					,MAX(MaxSingleTransId) AS MaxSingleTransId
					,MIN(MinMainParlayTransId) AS MinMainParlayTransId
					,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
				FROM #logInfo
				GROUP BY MatchId, LiveScores
			END
			RETURN;
		END
	END

	---Prepare for lock match---
	SELECT @IsExistSingle = MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@IsExistParlay = MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END)
			,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM #SpecialDeleteBets AS t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)

	SET @MatchProcessXML = (
		SELECT DISTINCT t.matchid "@MatchId"
			,CASE 
				WHEN f.GroupId IS NULL THEN 1 --SB
				WHEN f.GroupId = 1 THEN 6 -- Fast Market
				WHEN f.GroupId = 2 THEN 7 -- Fast market 228
				ELSE 0
				END AS "@KeyID"
		FROM #SpecialDeleteBets t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)

	--Error Table
	SELECT @IsInvalidTransId AS IsInvalidTransId
			,@IsInvalidLiveScore AS IsInvalidLiveScore
			,@IsInValidTotalTickets AS IsInValidTotalTickets
			,@IsExistedInOtherRequest AS IsExistedInOtherRequest
			,@IsExistSingle AS IsExistSingle
			,@IsExistParlay AS IsExistParlay
			,@IsExistFM AS IsExistFM
			,@IsExistFM2 AS IsExistFM2
			,@MatchProcessXML AS MatchProcessXML

	--TransId in request table
	--For EKO check transid exists in request
		
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN			
		SELECT RequestId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId) 
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
		FROM #TransidInRequest r
		GROUP BY r.RequestId
			,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2))
	END
	ELSE
	BEGIN
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId
			,CAST(livehomescore AS VARCHAR(2)) + ' - ' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
		FROM #TransidInRequest r
	END

	--Loginfo table
	IF @IssueTypeId <> 3
	BEGIN
		SELECT MatchId
			,STUFF((SELECT '|' + LiveScores
					FROM #logInfo WITH (NOLOCK)
					FOR XML PATH ('')
					),1,1,'') AS LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
		,SUM(InstantlySettleCount) AS InstantlySettleCount
			,SUM(MainParlayCount) AS MainParlayCount
			,MIN(MinSingleTransId) AS MinSingleTransId
			,MAX(MaxSingleTransId) AS MaxSingleTransId
			,MIN(MinMainParlayTransId) AS MinMainParlayTransId
			,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
		FROM #logInfo
		GROUP BY MatchId
	END
	ELSE
	BEGIN
		SELECT MatchId
			,LiveScores
			,MIN(VoidFromTime) AS VoidFromTime
			,MAX(VoidToTime) AS VoidToTime
			,SUM(SingleCount) AS SingleCount
			,SUM(CashOutCount) AS CashOutCount
			,SUM(MainParlayCount) AS MainParlayCount
			,MIN(MinSingleTransId) AS MinSingleTransId
			,MAX(MaxSingleTransId) AS MaxSingleTransId
			,MIN(MinMainParlayTransId) AS MinMainParlayTransId
			,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
		FROM #logInfo
		GROUP BY MatchId, LiveScores
	END


	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #transIdTemp
	DROP TABLE #CashOuts
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #WrongScores

END
GO