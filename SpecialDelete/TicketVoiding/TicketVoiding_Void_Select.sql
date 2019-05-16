/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Void_Select] @MatchId     INT,
                                                  @KickOffDate DATETIME
AS;
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	     - 20190426@Jacob: Mark Tickets - Enhancement [112480]
	Param's explanation:	
		
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
              IsMarked              BIT
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
	
	SELECT	@SportType = Sporttype 
			,@LeagueId = leagueid
	FROM	dbo.match WITH(NOLOCK) 
	WHERE	matchid = @matchid
	

	DECLARE @SettlementStatus TINYINT = NULL
	SELECT @SettlementStatus = m.SettlementStatus FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId
	
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
	FROM	bettrans b WITH (NOLOCK)	
	   LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId			
	WHERE	b.matchid = @matchid
			AND b.transdate >= @KickOffDate
			AND b.statusID NOT IN (101, 102) -- reject, void
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
		FROM	Translog b WITH (NOLOCK)
			 LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.translogid = m.TransId		
		WHERE	b.EventID = @matchid
				AND b.transdate >= @KickOffDate
				AND b.statusID NOT IN (101, 102) -- REJECT, VOID
				AND b.liveindicator = 0
				AND b.GameID IN (805, 806) 
				AND b.betfrom <> 'P'				
	
	---get sub ticket of a mix parlay	
	IF EXISTS (
			SELECT 1
			FROM dbo.bettransm AS bm WITH (NOLOCK)
			WHERE bm.matchid = @matchid
				AND bm.transdate >= @KickOffDate
				AND bm.statusID NOT IN (101, 102)
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
				,main.winlost -main.actual_stake AS WinLost,
				0
		FROM	dbo.bettransm sub WITH (NOLOCK)				
				INNER JOIN bettrans AS main WITH (NOLOCK) 
					ON	main.refno = sub.refno				
						AND sub.matchid = @matchid
		WHERE	sub.transdate >= @KickOffDate
				AND sub.statusID NOT IN (101, 102) -- reject, void
				AND sub.liveindicator = 0
				AND sub.betfrom <> 'P'
				AND main.matchid IN (9, 29)
				AND main.bettype IN (9, 29)
				AND main.liveindicator = 0
				AND main.transdate >= @KickOffDate
				AND main.statusID NOT IN (101, 102)
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
	FROM #SpecialDeleteBets sub911
		 CROSS APPLY (
						  SELECT b.transid, b.refno, b.custid, b.oddsid, b.oddsspread, b.oddstype, b.transdate, b.bettype, b.betteam, b.betcheck, b.status
								,b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.creator, b.stake, b.CurrencyName, b.SecAcceptFlag, b.checktime, b.odds
								,b.srecommend, b.mrecommend, b.recommend, b.betid, b.transdesc, b.betdaqid, b.ExtraInfo, b.WalletType, b.RefCode, b.BonusID, b.winlost, b.actual_stake
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
			   ,'Credit' AS GroupName
			   ,s.WalletType		   
			   ,s.MainTransId
			   ,s.BonusID
			   ,s.RefCode
			   ,s.WinLost
			   ,s.IsMarked
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
		   ,s.WinLost
		   ,s.IsMarked
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
END
GO

