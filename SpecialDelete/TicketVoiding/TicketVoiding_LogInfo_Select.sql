/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_Select]
(	
	@MatchId INT
	,@RequestId	INT = 0
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime DATETIME = NULL
	,@FilterFromBetId BIGINT = NULL
	,@FilterToBetId BIGINT = NULL
	,@FilterBy TINYINT = 1
	,@IssueTypeId INT = 1
	,@ActionId INT = 5
	,@IsShowLogOnly BIT = 0
	,@SubIssueTypeId INT = NULL
	,@IsCheckedHomeTeam  BIT = 0
	,@IsCheckedAwayTeam  BIT = 0
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
	
	Param's explanation:
		+ SubIssueTypeId in (1,2) will show IsCheckedHomeTeam, IsCheckedAwayTeam
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @IsInvalidTransId BIT = 0
		,@IsInValidTotalTickets BIT = 0
		,@IsInvalidLiveScore BIT = 0
		,@IsExistedInOtherRequest BIT = 0
		,@totalLiveHomeScore INT = 0
		,@totalAwayLiveScore INT = 0
		,@totalRecord INT = 0
		,@SingleCount INT = 0
		,@MainParlayCount INT = 0

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
			LiveIndicator			BIT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode  BIGINT,
			custid   INT,
			bettype  SMALLINT,
			transid  BIGINT,
			IsMarked BIT
	)

	CREATE TABLE #tblSoldTicket (transid BIGINT PRIMARY KEY)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	CREATE TABLE #logInfo (
		MatchId INT
		,LiveScores NVARCHAR(300)
		,VoidFromTime DATETIME
		,VoidToTime DATETIME
		,SingleCount INT
		,CashOutCount INT
		,MainParlayCount INT
		,MinSingleTransId BIGINT
		,MaxSingleTransId BIGINT
		,MinMainParlayTransId BIGINT
		,MaxMainParlayTransId BIGINT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY, transdate DATETIME)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	IF @IssueTypeId NOT IN (8,9)
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

				--TransId in request table
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
					,r.RequestId
				FROM #TransidInRequest r
			
				--Loginfo Table
				SELECT @MatchId AS MatchId 
					,l.LiveScores
					,l.VoidFromTime
					,l.VoidToTime
					,l.SingleCount
					,l.CashOutCount
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
				WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							   ELSE 0 END
					AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
								 ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
										   WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
										   WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
										   ELSE 0 END
								END)
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
		WHERE 1 = CASE WHEN @ActionId <>2 AND sub911.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId =2 AND sub911.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END							
			AND (1 = CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
						  ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
									WHEN @IsCheckedAwayTeam = 1 AND main.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
									WHEN @IsCheckedHomeTeam = 1 AND main.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
									ELSE 0 END
						 END) 		
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
									AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
												 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
												 ELSE 0 END
									AND (1= CASE WHEN @SubIssueTypeId NOT IN (1,2) THEN 1
												 ELSE CASE WHEN (@IsCheckedHomeTeam = 0 AND @IsCheckedAwayTeam = 0) OR (@IsCheckedHomeTeam = 1 AND @IsCheckedAwayTeam = 1) THEN 1
														   WHEN @IsCheckedAwayTeam = 1 AND b.bettype NOT IN (401,403,407,482,484,461,463) THEN 1 
														   WHEN @IsCheckedHomeTeam = 1 AND b.bettype NOT IN (402,404,409,483,485,462,464) THEN 1
														   ELSE 0 END
												END)
							) AS b
		WHERE sub911.bettype = 911
	END

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
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId)
	SELECT @MatchId AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + ' - ' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,CASE WHEN @FilterBy <> 0 THEN @FilterFromTransTime ELSE MIN(b.transdate) END AS VoidFromTime
		,CASE WHEN @FilterBy <> 0 THEN @FilterToTransTime ELSE MAX(b.transdate) END AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) NOT IN (1) THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) = 1 THEN b.transid ELSE NULL END) AS CashOutCount
		,MIN(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) NOT IN (1) THEN b.transid ELSE NULL END) AS MinSingleTransId
		,MAX(CASE WHEN b.transid = b.SubTransid AND ISNULL(b.betdaqid,-1) NOT IN (1) THEN b.transid ELSE NULL END) AS MaxSingleTransId
		,COUNT(CASE WHEN b.transid <> b.SubTransid AND (ISNULL(b.betdaqid,-1) NOT IN (1) OR b.IsMixParlay = 1) THEN b.transid ELSE NULL END) AS MainParlayCount
		,MIN(CASE WHEN b.transid <> b.SubTransid AND (ISNULL(b.betdaqid,-1) NOT IN (1) OR b.IsMixParlay = 1) THEN b.transid ELSE NULL END) AS MinSingleTransId
		,MAX(CASE WHEN b.transid <> b.SubTransid AND (ISNULL(b.betdaqid,-1) NOT IN (1) OR b.IsMixParlay = 1) THEN b.transid ELSE NULL END) AS MaxSingleTransId
	FROM #SpecialDeleteBets b WITH (NOLOCK)
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

		--TransId in request table
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId
		FROM #TransidInRequest r

		/*Get log info for Void Page*/
		SELECT rd.MatchId
			,rd.IssueDetail AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,l.CashOutCount
			,rd.MainParlayCount
			,rd.MinSingleTransId
			,rd.MaxSingleTransId
			,rd.MinMainParlayTransId
			,rd.MaxMainParlayTransId
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		  INNER JOIN #logInfo l ON rd.MatchId = l.matchid
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
				FROM #TransidInRequest r
				GROUP BY r.RequestId
			END
			ELSE
			BEGIN
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
					,r.RequestId
				FROM #TransidInRequest r
			END
			
			--Loginfo Table
			SELECT MatchId
				,STUFF((SELECT '|' + LiveScores
						FROM #logInfo WITH (NOLOCK)
						FOR XML PATH ('')
						),1,1,'') AS LiveScores
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
			GROUP BY MatchId

			RETURN;
		END
	END

	--Error Table
	SELECT @IsInvalidTransId AS IsInvalidTransId
		,@IsInvalidLiveScore AS IsInvalidLiveScore
		,@IsInValidTotalTickets AS IsInValidTotalTickets
		,@IsExistedInOtherRequest AS IsExistedInOtherRequest

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
		FROM #TransidInRequest r
		GROUP BY r.RequestId
	END
	ELSE
	BEGIN
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId
		FROM #TransidInRequest r
	END

	--Loginfo table
	SELECT MatchId
		,STUFF((SELECT '|' + LiveScores
				FROM #logInfo WITH (NOLOCK)
				FOR XML PATH ('')
				),1,1,'') AS LiveScores
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
	GROUP BY MatchId


	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #transIdTemp

END
GO