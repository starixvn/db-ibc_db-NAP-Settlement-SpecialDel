/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_Select]
(	
	@MatchId INT
	,@RequestId	INT = 0
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime DATETIME = NULL
	,@FilterFromBetId BIGINT = NULL
	,@FilterToBetId BIGINT = NULL
	,@IsFilterByTransTime BIT = 1
	,@IssueTypeId INT = 1
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @IsInvalidTransId BIT = 0
		,@IsInValidTotalTickets BIT = 0
		,@IsInvalidLiveScore BIT = 0
		,@IsExistedInOtherRequest BIT = 0
		,@totalLiveHomeScore INT
		,@totalAwayLiveScore INT
		,@totalRecord INT
		,@SingleCount INT
		,@MainParlayCount INT

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
		LiveHomeScore INT
		,LiveAwayScore INT
		,VoidFromTime DATETIME
		,VoidToTime DATETIME
		,SingleCount INT
		,MainParlayCount INT
		,MinSingleTransId BIGINT
		,MaxSingleTransId BIGINT
		,MinMainParlayTransId BIGINT
		,MaxMainParlayTransId BIGINT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY, transdate DATETIME)

	/*Get log info for Void Page*/
	IF @RequestId <> 0
	BEGIN
		SELECT rd.SingleCount
			,rd.MainParlayCount
			,rd.MinSingleTransId
			,rd.MaxSingleTransId
			,rd.MinMainParlayTransId
			,rd.MaxMainParlayTransId
			,rd.VoidFromTime
			,rd.VoidToTime
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE rd.RequestId = @RequestId
	END
	
	IF @IssueTypeId <> 8
	BEGIN
	/*Generate LogInfo*/
	/*Check valid transid*/
	IF @IsFilterByTransTime = 0
	BEGIN
		INSERT INTO #transIdTemp (transid, transdate)
		SELECT b.transid, b.transdate
		FROM dbo.bettrans b WITH (NOLOCK)        
		WHERE transid IN (@FilterFromBetId,@FilterToBetId)
			AND matchid = @MatchID 

		SELECT @totalRecord = COUNT(1)
		FROM #transIdTemp
    
		IF (@FilterFromBetId = @FilterToBetId AND @totalRecord <> 1) OR @totalRecord <> 2
		BEGIN
			SELECT @IsInvalidTransId = 1
			
			--Error Table
			SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest

			--TransId in request table
			SELECT r.TransId AS TransIds
				,r.RequestId
			FROM #TransidInRequest r
			
			--Loginfo Table
			SELECT @MatchId AS MatchId 
				,l.LiveHomeScore
				,l.LiveAwayScore
				,l.VoidFromTime
				,l.VoidToTime
				,l.SingleCount
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
			AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND b.liveindicator = 0
			AND b.bettype NOT IN (805, 806, 9, 29)			
			AND b.bettype NOT BETWEEN 901 AND 920
			AND b.betfrom <> 'P'
			AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime

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
			AND b.statusID NOT IN (101, 102, 103) -- REJECT, VOID, refund
			AND b.liveindicator = 0
			AND b.GameID IN (805, 806) 
			AND b.betfrom <> 'P'
			AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
		
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
		WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND sub.liveindicator = 0
				AND sub.betfrom <> 'P'
				AND main.matchid = 29
				AND main.bettype = 29
				AND main.liveindicator = 0
				AND main.statusID NOT IN (101, 102, 103)
				AND sub.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
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
	
		/*Check Live Score*/
		SELECT @totalLiveHomeScore = COUNT(DISTINCT b.livehomescore),
			@totalAwayLiveScore = COUNT(DISTINCT b.liveawayscore)
		FROM #SpecialDeleteBets b WITH (NOLOCK)

		IF @totalLiveHomeScore <> 1 OR @totalAwayLiveScore <> 1
		BEGIN
			SELECT @IsInvalidLiveScore = 1

			--Error table
			SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest

			--TransId in request table
			SELECT r.TransId AS TransIds
				,r.RequestId
			FROM #TransidInRequest r
			
			--Loginfo Table
			SELECT @MatchId AS MatchId 
				,l.LiveHomeScore
				,l.LiveAwayScore
				,l.VoidFromTime
				,l.VoidToTime
				,l.SingleCount
				,l.MainParlayCount
				,l.MinSingleTransId
				,l.MaxSingleTransId
				,l.MinMainParlayTransId
				,l.MaxMainParlayTransId
			FROM #logInfo l

			RETURN;
		END

		INSERT INTO #logInfo (LiveHomeScore, LiveAwayScore, VoidFromTime, VoidToTime, SingleCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId)
		SELECT b.livehomescore
			,b.liveawayscore
			,MIN(b.transdate) AS VoidFromTime
			,MAX(b.transdate) AS VoidToTime
			,COUNT(CASE WHEN b.MainTransId IS NULL THEN b.transid ELSE NULL END) AS SingleCount
			,MIN(CASE WHEN b.MainTransId IS NULL THEN b.transid ELSE NULL END) AS MinSingleTransId
			,MAX(CASE WHEN b.MainTransId IS NULL THEN b.transid ELSE NULL END) AS MaxSingleTransId
			,COUNT(CASE WHEN b.MainTransId IS NOT NULL THEN b.transid ELSE NULL END) AS SingleCount
			,MIN(CASE WHEN b.MainTransId IS NOT NULL THEN b.transid ELSE NULL END) AS MinSingleTransId
			,MAX(CASE WHEN b.MainTransId IS NOT NULL THEN b.transid ELSE NULL END) AS MaxSingleTransId
		FROM #SpecialDeleteBets b WITH (NOLOCK)
		WHERE b.MainTransId IS NULL
		GROUP BY b.livehomescore
			,b.liveawayscore

		SELECT @SingleCount = SingleCount
			,@MainParlayCount = MainParlayCount
		FROM #logInfo

		IF @SingleCount = 0 AND @MainParlayCount = 0
		BEGIN
			SELECT @IsInValidTotalTickets = 1

			--Error Table
			SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest

			--TransId in request table
			SELECT r.TransId AS TransIds
				,r.RequestId
			FROM #TransidInRequest r
			
			--Loginfo Table
			SELECT @MatchId AS MatchId 
				,l.LiveHomeScore
				,l.LiveAwayScore
				,l.VoidFromTime
				,l.VoidToTime
				,l.SingleCount
				,l.MainParlayCount
				,l.MinSingleTransId
				,l.MaxSingleTransId
				,l.MinMainParlayTransId
				,l.MaxMainParlayTransId
			FROM #logInfo l

			RETURN;
		END
	END
	
	/*Get Transid in Request of range Transid*/
	IF @IssueTypeId = 8
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId)
		SELECT tmp.transid, rd.RequestId
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId 
			CROSS APPLY (
						SELECT rs.TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.RequestId = r.RequestId
							AND rs.MatchId = @MatchId
						UNION ALL
						SELECT rp.TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.RequestId = r.RequestId
							AND rp.MatchId = @MatchId
				)tmp
		WHERE rd.MatchId = @MatchId
		OPTION (maxrecursion 0)
	END
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId)
		SELECT tmp.transid, rd.RequestId
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId 
			CROSS APPLY (
						SELECT rs.TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.RequestId = r.RequestId
							AND rs.MatchId = @MatchId
						UNION ALL
						SELECT rp.TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.RequestId = r.RequestId
							AND rp.MatchId = @MatchId
				)tmp
			INNER JOIN #SpecialDeleteBets t ON t.transid = tmp.transid
		WHERE rd.MatchId = @MatchId
		OPTION (maxrecursion 0)
	END

	--For EKO check transid exists in request
	IF @IssueTypeId = 8
	BEGIN
		SELECT RequestId,
			STUFF((
			SELECT ', ' + CAST(TransId AS VARCHAR(50)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId) 
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
		FROM #TransidInRequest r
		GROUP BY r.RequestId

		RETURN;
	END

	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT @IsExistedInOtherRequest = 1

		SELECT @IsInvalidTransId AS IsInvalidTransId
			,@IsInvalidLiveScore AS IsInvalidLiveScore
			,@IsInValidTotalTickets AS IsInValidTotalTickets
			,@IsExistedInOtherRequest AS IsExistedInOtherRequest

		SELECT RequestId,
			STUFF((
			SELECT ', ' + CAST(TransId AS VARCHAR(50)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId) 
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
		FROM #TransidInRequest r
		GROUP BY r.RequestId
	END
	
	--LogInfo Section
	IF @IssueTypeId = 1
	BEGIN
		--Error Table
			SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest

		--TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1

			SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest

			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(TransId AS VARCHAR(50)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId) 
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
			FROM #TransidInRequest r
			GROUP BY r.RequestId
		END
		ELSE
		BEGIN
			SELECT r.TransId AS TransIds
				,r.RequestId
			FROM #TransidInRequest r
		END
		
		--Loginfo table
		SELECT @MatchId AS MatchId 
			,l.LiveHomeScore
			,l.LiveAwayScore
			,l.VoidFromTime
			,l.VoidToTime
			,l.SingleCount
			,l.MainParlayCount
			,l.MinSingleTransId
			,l.MaxSingleTransId
			,l.MinMainParlayTransId
			,l.MaxMainParlayTransId
		FROM #logInfo l
	END



	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #transIdTemp
END
GO