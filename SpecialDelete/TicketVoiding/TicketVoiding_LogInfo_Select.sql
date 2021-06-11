/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_Select]
(	
	@MatchId              INT = 0
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
	,@KickOffTime		  DATETIME = NULL
	,@WrongScoreInfo	  VARCHAR(MAX) = ''
	,@DangerAcceptedInfo		VARCHAR(MAX)  = ''
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
		- 20210524@Max: [TVS] Wrong Score - Void 2H tickets in range time [Redmine: #155598]
		- 20210528@Max: Exclude some group bettypes [Redmine: #155598]
		- 20210531@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210526@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210611@Max: [TVS] Hotfix Highlight Min TransId [Redmine: #156832]
	
	Param's explanation:
		+@Filterby:
			- 0: By BetId (Hide on UI, not use)
			- 1: By Transdate
			- 2: By Checktime
		+ @WrongScoreInfo:
		<root>
			<r LiveHomeScore="0" LiveAwayScore="1" FilterFromTransTime ="" FilterToTransTime="" />
		</root>
		+ @DangerAcceptedInfo:
		<root>
			<r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterBy="" SubIssueTypeId=""/>
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
			,@DangerAcceptedInfoXML	XML  = NULL
	
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
			checktime			  DATETIME,
			accepttype			  TINYINT,
			SubIssueTypeId		SMALLINT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode  BIGINT,
			custid   INT,
			bettype  SMALLINT,
			transid  BIGINT,
			IsMarked BIT,
			MatchId	INT,
			SubIssueTypeId SMALLINT
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
		,HighLightTransId BIGINT
		,HighlightAcceptType TINYINT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, livehomescore SMALLINT, liveawayscore SMALLINT, MatchId INT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY, transdate DATETIME)
	CREATE TABLE #CashOuts (RequestId INT, MatchId INT, transid BIGINT, bettype SMALLINT, OriginalBetType SMALLINT, IsCOTicket BIT, livehomescore SMALLINT, liveawayscore SMALLINT)
	CREATE TABLE #WrongScores (MatchId INT, LiveHomeScore SMALLINT, LiveAwayScore SMALLINT, FilterFromTime DATETIME, FilterToTime DATETIME)
	CREATE TABLE #FilterInfo (MatchId INT, FilterFromTransTime DATETIME, FilterToTransTime DATETIME, FilterBy	TINYINT, SubIssueTypeId SMALLINT)
	
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblHighlightTransId TABLE (MatchId INT, Transid BIGINT, AcceptType TINYINT, VoidTime DATETIME)
	
	DECLARE @Validation AS TABLE (
			livehomescore SMALLINT
			,liveawayscore SMALLINT
			,IsInvalidTransId     BIT 
			,IsInValidTotalTickets   BIT 
			,IsInvalidLiveScore	  BIT
			,IsExistedInOtherRequest BIT 
			,IsExistSingle			  BIT 
			,IsExistParlay			  BIT 
			,IsExistFM				  BIT 
			,IsExistFM2			  BIT 
			,MatchProcessXML		  XML 
			,LiveScores NVARCHAR(300)
			,MatchId INT
		)
	DECLARE @InstantlySettleCount_tmp AS TABLE (transidCount BIGINT, livehomescore SMALLINT, liveawayscore SMALLINT, RequestId INT, MatchId INT)

	IF @IssueTypeId = 1
	BEGIN
		SET @DangerAcceptedInfoXML = CONVERT(XML, @DangerAcceptedInfo)
		INSERT INTO #FilterInfo( 
				MatchID				
				,FilterFromTransTime	
				,FilterToTransTime			
				,FilterBy				
				,SubIssueTypeId
			)
		SELECT t.c.value('@MatchId','INT') AS MatchID
				,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
				,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
				,t.c.value('@FilterBy','TINYINT') AS FilterBy
				,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
		FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))

		SET @FilterBy = (SELECT DISTINCT FilterBy FROM #FilterInfo)
			
	END
	ELSE --IF @IssueTypeId = 10
	BEGIN
		INSERT INTO #FilterInfo( 
				MatchID				
				,FilterFromTransTime	
				,FilterToTransTime			
				,FilterBy				
				,SubIssueTypeId
			)
		SELECT @MatchId, @FilterFromTransTime, @FilterToTransTime, @FilterBy, @SubIssueTypeId
	END

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype_matchid ON #InstantSettlementBettypes(bettype, matchid)

		--> Get status of match
		;WITH cte_match AS
		(
			SELECT t.matchid
			FROM #FilterInfo t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
		)
		,cte_isCalHT AS
		(
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM cte_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		)
		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO #InstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM cte_isCalHT c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_Set_Instant_GetBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	 	
	END	

	IF @IssueTypeId IN (1,10)
	BEGIN
		/*Generate LogInfo*/
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

		--Init Validation
		INSERT INTO @Validation (MatchId)
		SELECT MatchId
		FROM #FilterInfo
		
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
				,accepttype
				,SubIssueTypeId
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
				,b.matchid
				,b.statusID
				,b.checktime
				,CASE 
							WHEN b.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN b.checktime = DATEADD(SECOND,ISNULL(bi.LiveBetAcceptTime,0) + ISNULL(bi.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
						END AS accepttype
				,d.SubIssueTypeId
		FROM	bettrans b WITH (NOLOCK)	
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
			INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							 ELSE 0 END
				AND b.betfrom <> 'P'
				AND 1 = CASE WHEN d.FilterBy = 1 AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL AND b.checktime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 2 AND b.checktime IS NULL AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
							WHEN d.FilterBy = 0 AND b.transid BETWEEN @FilterFromBetId AND @FilterToBetId THEN 1
							ELSE 0 END
				AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
							 ELSE CASE WHEN d.SubIssueTypeId IN (55,57,60,75,79,82) AND b.bettype NOT IN (402,404,409,462,464) THEN 1 
									   WHEN d.SubIssueTypeId IN (68,70) AND b.bettype NOT IN (483,485) THEN 1
									   WHEN d.SubIssueTypeId IN (56,58,61,76,80,83) AND b.bettype NOT IN (401,403,407,461,463) THEN 1
									   WHEN d.SubIssueTypeId IN (69,71) AND b.bettype NOT IN (482,484) THEN 1
								       WHEN d.SubIssueTypeId IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
									   ELSE 0
							      END
						END
		
		---get sub ticket of a mix parlay	
		IF EXISTS (
				SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #FilterInfo d ON d.MatchId = bm.matchid
				WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
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
					,accepttype
					,SubIssueTypeId
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
					,sub.matchid
					,main.statusID
					,sub.checktime
					,CASE 
							WHEN sub.checktime IS NULL THEN 1 --Auto Accept
							ELSE CASE 
									  WHEN sub.checktime = DATEADD(SECOND,ISNULL(sub.LiveBetAcceptTime,0) + ISNULL(sub.SecAcceptTime,0), sub.transdate) THEN 2 --Second Accept
									  ELSE 3 --Pending Accept
								 END
					 END AS accepttype
					 ,d.SubIssueTypeId
			FROM	#FilterInfo d
					INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = d.MatchId
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno 
			WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						   ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND CASE WHEN d.FilterBy = 0 THEN sub.transdate
							WHEN d.FilterBy = 1 THEN sub.transdate
							WHEN d.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
							WHEN d.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
						END BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
					AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
								 ELSE CASE WHEN d.SubIssueTypeId IN (55,57,60,75,79,82) AND sub.bettype NOT IN (402,404,409,462,464) THEN 1 
										   WHEN d.SubIssueTypeId IN (68,70) AND sub.bettype NOT IN (483,485) THEN 1
									       WHEN d.SubIssueTypeId IN (56,58,61,76,80,83) AND sub.bettype NOT IN (401,403,407,461,463) THEN 1
									       WHEN d.SubIssueTypeId IN (69,71) AND sub.bettype NOT IN (482,484) THEN 1
									       WHEN d.SubIssueTypeId IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
									       ELSE 0
									  END
							END
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

		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
		
		
		--Init Validation
		INSERT INTO @Validation (livehomescore, liveawayscore, LiveScores)
		SELECT DISTINCT livehomescore, liveawayscore, CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
		FROM #WrongScores
		
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
				,CASE WHEN f.GroupName = '2H' THEN s.LiveHomeScore ELSE b.livehomescore END AS livehomescore
				,CASE WHEN f.GroupName = '2H' THEN s.LiveAwayScore ELSE b.liveawayscore END AS liveawayscore
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
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
			CROSS APPLY (
				SELECT LiveHomeScore, LiveAwayScore
				FROM #WrongScores c
				WHERE matchid = @MatchId
					AND 1 = CASE WHEN b.livehomescore = LiveHomeScore AND b.liveawayscore = LiveAwayScore AND b.transdate BETWEEN FilterFromTime AND FilterToTime THEN 1
								WHEN b.transdate BETWEEN FilterFromTime AND FilterToTime AND f.GroupName = '2H' THEN 1
							ELSE 0 END	
			)s
		WHERE	b.matchid = @matchid
				AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.betfrom <> 'P'
				AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
				
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
					,StatusId
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
					,CASE WHEN f.GroupName = '2H' THEN s.LiveHomeScore ELSE sub.livehomescore END AS livehomescore
					,CASE WHEN f.GroupName = '2H' THEN s.LiveAwayScore ELSE sub.liveawayscore END AS liveawayscore
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
			FROM	dbo.bettransm sub WITH (NOLOCK)				
					INNER HASH JOIN bettrans AS main WITH (NOLOCK) 
						ON	main.refno = sub.refno				
							AND sub.matchid = @matchid
					INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = sub.bettype
					CROSS APPLY (
						SELECT TOP(1) LiveHomeScore, LiveAwayScore
						FROM #WrongScores c
						WHERE matchid = @MatchId
							AND 1 = CASE WHEN sub.livehomescore = LiveHomeScore AND sub.liveawayscore = LiveAwayScore AND sub.transdate BETWEEN FilterFromTime AND FilterToTime THEN 1
										WHEN sub.transdate BETWEEN FilterFromTime AND FilterToTime AND f.GroupName = '2H' THEN 1
									ELSE 0 END	
					)s
					INNER JOIN @bettype_tmp bt ON bt.bettype = sub.bettype
			WHERE 1= CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
					AND sub.betfrom <> 'P'
					AND main.matchid = 29
					AND main.bettype = 29
					AND main.liveindicator = 0
					AND main.statusID NOT IN (102, 103)
					AND 1 = CASE WHEN sub.livehomescore = 0 AND sub.liveawayscore = 0 AND sub.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
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
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, IsMarked, transid, MatchId, SubIssueTypeId)
		SELECT RefCode, custid, bettype, IsMarked
				, MAX(transid) AS transid
				, matchid, SubIssueTypeId
		FROM #SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, IsMarked, matchid, SubIssueTypeId
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
						,SubIssueTypeId
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
						,b.matchid
						,b.statusID
						,b.checktime
						,t.SubIssueTypeId
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = t.MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
							  ELSE CASE WHEN ISNULL(t.SubIssueTypeId, @SubIssueTypeId) IN (55,57,60,75,79,82) AND b.bettype NOT IN (402,404,409,462,464) THEN 1 
									    WHEN ISNULL(t.SubIssueTypeId, @SubIssueTypeId) IN (68,70) AND b.bettype NOT IN (483,485) THEN 1
									    WHEN ISNULL(t.SubIssueTypeId, @SubIssueTypeId) IN (56,58,61,76,80,83) AND b.bettype NOT IN (401,403,407,461,463) THEN 1
									    WHEN ISNULL(t.SubIssueTypeId, @SubIssueTypeId) IN (69,71) AND b.bettype NOT IN (482,484) THEN 1
								        WHEN ISNULL(t.SubIssueTypeId, @SubIssueTypeId) IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
									    ELSE 0
								  END
						END
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
			,SubIssueTypeId
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
			,main.SubIssueTypeId
	FROM dbo.bettrans sub911 WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets main 
				ON	sub911.refno = main.transid	
					AND sub911.custid = main.custid					
					AND main.betdaqid = 0
					AND charindex ('p25',main.extrainfo)> 0			
					AND sub911.bettype = 911
					AND sub911.matchid = main.matchid
	WHERE 1 = CASE WHEN @ActionId <>2 AND sub911.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					WHEN @ActionId =2 AND sub911.statusID NOT IN (101, 103) THEN 1
					ELSE 0 END								
		AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
					  ELSE CASE WHEN ISNULL(main.SubIssueTypeId, @SubIssueTypeId) IN (55,57,60,75,79,82) AND main.bettype NOT IN (402,404,409,462,464) THEN 1 
								WHEN ISNULL(main.SubIssueTypeId, @SubIssueTypeId) IN (68,70) AND main.bettype NOT IN (483,485) THEN 1
								WHEN ISNULL(main.SubIssueTypeId, @SubIssueTypeId) IN (56,58,61,76,80,83) AND main.bettype NOT IN (401,403,407,461,463) THEN 1
								WHEN ISNULL(main.SubIssueTypeId, @SubIssueTypeId) IN (69,71) AND main.bettype NOT IN (482,484) THEN 1
								WHEN ISNULL(main.SubIssueTypeId, @SubIssueTypeId) IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
							    ELSE 0
					      END
				END
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
				,SubIssueTypeId
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
				,sub911.matchid
				,b.statusID
				,sub911.checktime
				,sub911.SubIssueTypeId
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
								AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
											   ELSE CASE WHEN ISNULL(sub911.SubIssueTypeId, @SubIssueTypeId) IN (55,57,60,75,79,82) AND b.bettype NOT IN (402,404,409,462,464) THEN 1 
														 WHEN ISNULL(sub911.SubIssueTypeId, @SubIssueTypeId) IN (68,70) AND b.bettype NOT IN (483,485) THEN 1
									                     WHEN ISNULL(sub911.SubIssueTypeId, @SubIssueTypeId) IN (56,58,61,76,80,83) AND b.bettype NOT IN (401,403,407,461,463) THEN 1
									                     WHEN ISNULL(sub911.SubIssueTypeId, @SubIssueTypeId) IN (69,71) AND b.bettype NOT IN (482,484) THEN 1
													     WHEN ISNULL(sub911.SubIssueTypeId, @SubIssueTypeId) IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
														 ELSE 0
												  END
										END
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
		ELSE IF @IssueTypeId = 1
		BEGIN
			INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
			SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
			FROM #SpecialDeleteBets t
				CROSS APPLY (
							SELECT rs.TransId, rs.TransId AS MainTransId, RequestId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							WHERE rs.TransId = t.transid
								AND rs.MatchId = t.MatchId
							UNION ALL
							SELECT rp.TransId, b.transid AS MainTransId, RequestId
							FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
								INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
								INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29
							WHERE rp.TransId = t.SubTransid
								AND rp.MatchId = t.matchid
					)tmp
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
			WHERE r.RequestId <> @RequestId
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

			IF EXISTS (SELECT TOP (1) 1 FROM @Validation)
			BEGIN
				IF @IssueTypeId = 1
				BEGIN
					UPDATE v SET v.IsExistedInOtherRequest = 1
					FROM @Validation v
					WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
				END
				ELSE IF @IssueTypeId = 3
				BEGIN
					UPDATE v SET v.IsExistedInOtherRequest = 1
					FROM @Validation v
					WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.livehomescore = v.livehomescore AND t.liveawayscore = v.liveawayscore)
				END
			END
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
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
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest t WHERE t.TransId = b.SubTransid)
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		IF @IssueTypeId NOT IN (1,3)
		BEGIN
			SELECT @IsInvalidTransId AS IsInvalidTransId
					,@IsInvalidLiveScore AS IsInvalidLiveScore
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,@IsExistedInOtherRequest AS IsExistedInOtherRequest
					,@IsExistSingle AS IsExistSingle
					,@IsExistParlay AS IsExistParlay
					,@IsExistFM AS IsExistFM
					,@IsExistFM2 AS IsExistFM2
					,@MatchProcessXML AS MatchProcessXML
		END
		ELSE IF @IssueTypeId = 3
		BEGIN
			SELECT CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
				,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
				,ISNULL(IsInvalidLiveScore,0) AS IsInvalidLiveScore
				,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
				,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
				,ISNULL(IsExistSingle,0) AS IsExistSingle
				,ISNULL(IsExistParlay,0) AS IsExistParlay
				,ISNULL(IsExistFM,0) AS IsExistFM
				,ISNULL(@IsExistFM2,0) AS IsExistFM2
				,MatchProcessXML AS MatchProcessXML
			FROM @Validation
		END
		ELSE IF @IssueTypeId = 1
		BEGIN
			SELECT MatchId
				,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
				,ISNULL(IsInvalidLiveScore,0) AS IsInvalidLiveScore
				,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
				,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
				,ISNULL(IsExistSingle,0) AS IsExistSingle
				,ISNULL(IsExistParlay,0) AS IsExistParlay
				,ISNULL(IsExistFM,0) AS IsExistFM
				,ISNULL(@IsExistFM2,0) AS IsExistFM2
				,MatchProcessXML AS MatchProcessXML
			FROM @Validation
		END

		--TransId in request table
		IF @IssueTypeId <> 3
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest r
		END
		ELSE
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId
				,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
			FROM #TransidInRequest r
		END

		/*Get log info for Void Page*/
		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, IsCOTicket, livehomescore, liveawayscore)
		SELECT @RequestId, s.MatchId, s.TransId, b.bettype, 0
			, CASE WHEN @IssueTypeId = 3 THEN b.livehomescore ELSE NULL END
			, CASE WHEN @IssueTypeId = 3 THEN b.liveawayscore ELSE NULL END
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid AND b.matchid = s.MatchId
		WHERE s.RequestId = @RequestId
			AND b.betdaqid = 0
			AND charindex ('p25',b.extrainfo)> 0	

		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, OriginalBetType, IsCOTicket, livehomescore, liveawayscore)
		SELECT @RequestId, sub911.matchid 
			,sub911.transid
			,sub911.bettype
			,main.bettype
			,1
			, CASE WHEN @IssueTypeId = 3 THEN main.livehomescore ELSE NULL END
			, CASE WHEN @IssueTypeId = 3 THEN main.liveawayscore ELSE NULL END
		FROM dbo.bettrans sub911 WITH(NOLOCK)
				INNER JOIN #CashOuts main 
					ON	sub911.refno = main.transid	
						AND sub911.matchid = main.MatchId

		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, OriginalBetType, IsCOTicket, livehomescore, liveawayscore)
		SELECT @RequestId, sub911.MatchId 
			,b.transid
			,b.bettype
			,sub911.OriginalBetType
			,1
			, CASE WHEN @IssueTypeId = 3 THEN sub911.livehomescore ELSE NULL END
			, CASE WHEN @IssueTypeId = 3 THEN sub911.liveawayscore ELSE NULL END
		FROM #CashOuts sub911
				CROSS APPLY (
								SELECT b.transid, b.bettype
								FROM dbo.bettrans b WITH (NOLOCK)
								WHERE b.refno = sub911.transid
									AND b.matchid = sub911.MatchId					
									AND b.bettype = sub911.OriginalBetType
							) AS b
		WHERE sub911.bettype = 911

		/*Get Instant settlement*/
		IF @IssueTypeId <> 3
		BEGIN
			INSERT INTO @InstantlySettleCount_tmp (transidCount, RequestId, MatchId)
			SELECT COUNT(s.TransId), @RequestId, b.matchid
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid AND s.MatchId =  b.matchid
			WHERE s.RequestId = @RequestId
				AND b.statusID IN (111,112,113)
				 AND EXISTS (SELECT TOP 1 1
							 FROM #InstantSettlementBettypes
							 WHERE bettype = b.bettype)
			GROUP BY b.matchid

			--Highlight Min TransId (based on the acceptance type of the ticket)
			IF @IssueTypeId = 1
			BEGIN

				IF EXISTS( SELECT TOP 1 RequestId FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) WHERE RequestId = @RequestId AND MinSingleTransId IS NOT NULL)
				BEGIN
					INSERT INTO @tblHighlightTransId (MatchId, Transid, AcceptType, VoidTime)
					SELECT rd.MatchId, B.transid , CASE 
											WHEN b.checktime IS NULL THEN 1 --Auto Accept
											ELSE CASE 
													  WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
													  ELSE 3 --Pending Accept
												 END
										END AS AcceptType, rd.VoidFromTime
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						CROSS APPLY (
								SELECT b.matchid, b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, bi.LiveBetAcceptTime, bi.SecAcceptTime
								FROM dbo.bettrans b WITH(NOLOCK) 
									LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
								WHERE rd.MatchId = b.matchid AND rd.MinSingleTransId = b.transid
						)b 
						CROSS APPLY (SELECT CASE WHEN rd.FilterBy = 1 THEN b.transdate
												 WHEN rd.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
												 WHEN rd.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
												 END AS VoidTime
									)act
					WHERE rd.VoidFromTime = act.VoidTime AND rd.RequestId = @RequestId
				END
			
				IF EXISTS( SELECT TOP 1 RequestId FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK) WHERE RequestId = @RequestId AND MinMainParlayTransId IS NOT NULL)
				BEGIN
					INSERT INTO @tblHighlightTransId (MatchId, Transid, AcceptType, VoidTime)
					SELECT rd.MatchId, s.MainTransId , CASE 
										WHEN b.checktime IS NULL THEN 1 --Auto Accept
										ELSE CASE 
												  WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
												  ELSE 3 --Pending Accept
											 END
									END AS AcceptType, rd.VoidFromTime
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
					INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH(NOLOCK) ON rd.MatchId = s.MatchId AND rd.MinMainParlayTransId = s.MainTransId
					CROSS APPLY  (
								SELECT bm.matchid, NULL AS transid, bm.transid AS subtransid, bm.bettype, bm.transdate, bm.checktime, bm.LiveBetAcceptTime, bm.SecAcceptTime
								FROM dbo.bettransm bm WITH(NOLOCK)
								WHERE rd.MatchId = bm.matchid AND s.TransId = bm.transid
							)b
					CROSS APPLY (SELECT CASE WHEN rd.FilterBy = 1 THEN b.transdate
											 WHEN rd.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
											 WHEN rd.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
											 END AS VoidTime
									)act
					WHERE rd.VoidFromTime = act.VoidTime
						AND rd.RequestId = @RequestId
				END
			
			END

			SELECT rd.MatchId
				,rd.IssueDetail AS LiveScores
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,c.CashOutCount AS CashOutCount
				,t.transidCount AS InstantlySettleCount
				,rd.MainParlayCount
				,rd.MinSingleTransId
				,rd.MaxSingleTransId
				,rd.MinMainParlayTransId
				,rd.MaxMainParlayTransId
				,h.HighLightTransId
				,h.HighlightAcceptType
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			  OUTER APPLY (
						SELECT COUNT(CASE WHEN IsCOTicket = 1 THEN transid ELSE NULL END) AS CashOutCount
						FROM #CashOuts
						WHERE RequestId = rd.RequestId	
							AND MatchId = rd.MatchId
				) c
			   OUTER APPLY (
						 SELECT  MatchId, Transid AS HighLightTransId , AcceptType AS HighlightAcceptType
						 FROM @tblHighlightTransId
						 WHERE matchId = rd.MatchId
							AND rd.VoidFromTime = VoidTime
							AND 1 = (CASE WHEN rd.MinSingleTransId IS NOT NULL AND rd.MinSingleTransId = TransId THEN 1
										  WHEN rd.MinMainParlayTransId IS NOT NULL AND rd.MinMainParlayTransId = TransId THEN 1
										  END
									)

					)h
				LEFT JOIN @InstantlySettleCount_tmp t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
			WHERE rd.RequestId = @RequestId
		END
		ELSE
		BEGIN
			INSERT INTO @InstantlySettleCount_tmp (transidCount, livehomescore, liveawayscore, RequestId)
			SELECT COUNT(s.TransId), b.livehomescore, b.liveawayscore, @RequestId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid
			WHERE s.RequestId = @RequestId
				AND s.MatchId = @MatchId
				AND b.statusID IN (111,112,113)
				 AND EXISTS (SELECT TOP 1 1
							 FROM #InstantSettlementBettypes
							 WHERE bettype = b.bettype)
			GROUP BY b.livehomescore, b.liveawayscore

			SELECT rd.MatchId
				,CAST(rd.livehomescore AS VARCHAR(2)) + '-' + CAST(rd.liveawayscore AS VARCHAR(2)) AS LiveScores
				,rd.IssueDetail AS ActualScore
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.SingleCount
				,c.CashOutCount AS CashOutCount
				,t.transidCount AS InstantlySettleCount
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
							AND livehomescore = rd.LiveHomeScore
							AND liveawayscore = rd.LiveAwayScore
						GROUP BY livehomescore, liveawayscore
					) c
				LEFT JOIN @InstantlySettleCount_tmp t ON t.RequestId = rd.RequestId AND t.livehomescore = rd.LiveHomeScore AND t.liveawayscore = rd.LiveAwayScore
			WHERE rd.RequestId = @RequestId
		END

		RETURN;
	END

	--For case no ticket valid
	IF @IssueTypeId IN (1, 10, 3)
	BEGIN
		SELECT @SingleCount = SUM(SingleCount)
			,@MainParlayCount = SUM(MainParlayCount)
		FROM #logInfo
		GROUP BY MatchId

		IF @SingleCount = 0 AND @MainParlayCount = 0
		BEGIN
			SELECT @IsInValidTotalTickets = 1

			IF @IssueTypeId NOT IN (1,3)
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
			END
			ELSE IF @IssueTypeId = 3
			BEGIN
				SELECT CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
					,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
					,ISNULL(IsInvalidLiveScore,0) AS IsInvalidLiveScore
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
					,ISNULL(IsExistSingle,0) AS IsExistSingle
					,ISNULL(IsExistParlay,0) AS IsExistParlay
					,ISNULL(IsExistFM,0) AS IsExistFM
					,ISNULL(@IsExistFM2,0) AS IsExistFM2
					,MatchProcessXML AS MatchProcessXML
				FROM @Validation
			END
			ELSE IF @IssueTypeId = 1
			BEGIN
				SELECT MatchId
					,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
					,ISNULL(IsInvalidLiveScore,0) AS IsInvalidLiveScore
					,@IsInValidTotalTickets AS IsInValidTotalTickets
					,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
					,ISNULL(IsExistSingle,0) AS IsExistSingle
					,ISNULL(IsExistParlay,0) AS IsExistParlay
					,ISNULL(IsExistFM,0) AS IsExistFM
					,ISNULL(@IsExistFM2,0) AS IsExistFM2
					,MatchProcessXML AS MatchProcessXML
				FROM @Validation
			END

			--TransId in request table
			IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
			BEGIN
				IF @IssueTypeId <> 3
				BEGIN
					SELECT RequestId,
						STUFF((
						SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
						FROM #TransidInRequest
						WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
						ORDER BY TransId
						FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
						,1,2,'') AS TransIds
						,MatchId
					FROM #TransidInRequest r
					GROUP BY r.RequestId, r.MatchId
				END
				ELSE 
				BEGIN
					SELECT RequestId,
						STUFF((
						SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
						FROM #TransidInRequest
						WHERE (RequestId = r.RequestId) 
						FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
						,1,2,'') AS TransIds
						,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
					FROM #TransidInRequest r
					GROUP BY r.RequestId
						,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2))
				END
			END
			ELSE
			BEGIN
				IF @IssueTypeId <> 3
				BEGIN
					SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
						,r.RequestId, r.MatchId
					FROM #TransidInRequest r
				END
				ELSE
				BEGIN
					SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
						,r.RequestId
						,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
					FROM #TransidInRequest r
				END
			END
			
			--Loginfo Table
			IF @IssueTypeId NOT IN (1,3)
			BEGIN
				SELECT MatchId
					,STUFF(w.scores,1,1,'') AS LiveScores
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
					,MIN(HighLightTransId) AS HighLightTransId
					,MIN(HighlightAcceptType) AS HighlightAcceptType
				FROM #logInfo l
					CROSS APPLY(
								SELECT '|' + LiveScores
								FROM #logInfo rd WITH(NOLOCK)
								where l.MatchId = rd.MatchId
								FOR XML PATH('')
								)w (scores)
				GROUP BY MatchId, w.scores
			END
			ELSE IF @IssueTypeId = 1
			BEGIN
				;WITH _cte AS (
						SELECT MatchId
							,STUFF(w.scores,1,1,'') AS LiveScores
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
						FROM #logInfo l
							CROSS APPLY(
										SELECT '|' + LiveScores
										FROM #logInfo rd WITH(NOLOCK)
										where l.MatchId = rd.MatchId
										FOR XML PATH('')
										)w (scores) 
						GROUP BY MatchId, w.scores
					)
				SELECT MatchId
					, LiveScores
					,VoidFromTime
					,VoidToTime
					,SingleCount
					,CashOutCount
					,InstantlySettleCount
					,MainParlayCount
					,MinSingleTransId
					,MaxSingleTransId
					,MinMainParlayTransId
					,MaxMainParlayTransId
					,tmpHighlight.HighLightTransId AS HighLightTransId
					,tmpHighlight.HighlightAcceptType AS HighlightAcceptType
				FROM _cte l
					CROSS APPLY (SELECT MIN(VoidFromTime) AS VoidFromTime_min
								 FROM #logInfo lg 
								 WHERE l.matchid = lg.matchid
								 ) AS Voidtime
					OUTER APPLY (SELECT TOP 1 b.transid AS HighLightTransId
									 ,b.accepttype HighlightAcceptType
								FROM #SpecialDeleteBets b 
										CROSS APPLY (SELECT CASE WHEN @FilterBy = 1 THEN b.transdate
																 WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
																 WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
																 END AS VoidTime
										)act
								WHERE l.MatchId = b.matchid AND Voidtime.VoidFromTime_min = act.VoidTime 
									AND 1 = (CASE WHEN l.MinSingleTransId IS NOT NULL AND b.transid = l.MinSingleTransId  THEN 1
												  WHEN l.MinMainParlayTransId IS NOT NULL AND b.transid = l.MinMainParlayTransId THEN 1
												END
											)
									ORDER BY CASE WHEN l.MinSingleTransId IS NOT NULL THEN 1 ELSE 0 END DESC
							
						) AS tmpHighlight
			END
			ELSE IF @IssueTypeId = 3
			BEGIN
				SELECT MatchId
					,LiveScores
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
				GROUP BY MatchId, LiveScores
			END
			RETURN;
		END
	END
	
	IF @IssueTypeId = 3
	BEGIN
		UPDATE v SET v.IsInValidTotalTickets = CASE WHEN (l.SingleCount = 0 AND l.MainParlayCount = 0) OR (l.SingleCount IS NULL AND l.MainParlayCount IS NULL) THEN 1 ELSE 0 END
		FROM @Validation v
			OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE LiveScores = v.LiveScores
				GROUP BY LiveScores
			)l
	END

	IF @IssueTypeId = 1
	BEGIN
		UPDATE v SET v.IsInValidTotalTickets = CASE WHEN (l.SingleCount = 0 AND l.MainParlayCount = 0) OR (l.SingleCount IS NULL AND l.MainParlayCount IS NULL) THEN 1 ELSE 0 END
		FROM @Validation v
			OUTER APPLY( 
				SELECT SUM(SingleCount) AS SingleCount
					,SUM(MainParlayCount) AS MainParlayCount
				FROM #logInfo
				WHERE MatchId = v.MatchId
				GROUP BY MatchId
			)l
	END 

	---Prepare for lock match---
	IF @IssueTypeId NOT IN (1,3)
	BEGIN
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
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
		UPDATE v SET 
				v.IsExistSingle = tmp.IsExistSingle
			, v.IsExistParlay = tmp.IsExistParlay
			, v.IsExistFM = tmp.IsExistFM
			, v.IsExistFM2 = tmp.IsExistFM2
		FROM @Validation v
		CROSS APPLY (
				SELECT   MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END) AS IsExistSingle
						, MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END) AS IsExistParlay
						, MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END) AS  IsExistFM
						, MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END) AS IsExistFM2
				FROM #SpecialDeleteBets AS t
					OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = t.Bettype
					)f
				WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
					AND t.livehomescore = v.livehomescore
					AND t.liveawayscore = v.liveawayscore
				GROUP BY t.livehomescore, t.liveawayscore
			)tmp
	END
	ELSE IF @IssueTypeId = 1
	BEGIN
		UPDATE v SET 
				v.IsExistSingle = tmp.IsExistSingle
			, v.IsExistParlay = tmp.IsExistParlay
			, v.IsExistFM = tmp.IsExistFM
			, v.IsExistFM2 = tmp.IsExistFM2
		FROM @Validation v
		CROSS APPLY (
				SELECT   MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END) AS IsExistSingle
						, MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END) AS IsExistParlay
						, MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END) AS  IsExistFM
						, MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END) AS IsExistFM2
				FROM #SpecialDeleteBets AS t
					OUTER APPLY (
							SELECT GroupId
							FROM dbo.f_TVS_CheckingProcessGroupBettypes()
							WHERE Bettype = t.Bettype
					)f
				WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
					AND t.matchid = v.MatchId
				GROUP BY t.matchid
			)tmp
	END

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

	--WC
	UPDATE @Validation SET MatchProcessXML = @MatchProcessXML

	--Error Table
	IF @IssueTypeId NOT IN (1,3)
	BEGIN
		SELECT @IsInvalidTransId AS IsInvalidTransId
				,@IsInvalidLiveScore AS IsInvalidLiveScore
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest
				,@IsExistSingle AS IsExistSingle
				,@IsExistParlay AS IsExistParlay
				,@IsExistFM AS IsExistFM
				,@IsExistFM2 AS IsExistFM2
				,@MatchProcessXML AS MatchProcessXML
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
		SELECT CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,ISNULL(IsInvalidLiveScore,0) AS IsInvalidLiveScore
			,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
			,ISNULL(IsExistSingle,0) AS IsExistSingle
			,ISNULL(IsExistParlay,0) AS IsExistParlay
			,ISNULL(IsExistFM,0) AS IsExistFM
			,ISNULL(@IsExistFM2,0) AS IsExistFM2
			,MatchProcessXML AS MatchProcessXML
		FROM @Validation
	END
	ELSE IF @IssueTypeId = 1
	BEGIN
		SELECT MatchId
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,ISNULL(IsInvalidLiveScore,0) AS IsInvalidLiveScore
			,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
			,ISNULL(IsExistSingle,0) AS IsExistSingle
			,ISNULL(IsExistParlay,0) AS IsExistParlay
			,ISNULL(IsExistFM,0) AS IsExistFM
			,ISNULL(@IsExistFM2,0) AS IsExistFM2
			,MatchProcessXML AS MatchProcessXML
		FROM @Validation
	END

	--TransId in request table
	--For EKO check transid exists in request		
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		IF @IssueTypeId <> 3
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE 
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId) 
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
			FROM #TransidInRequest r
			GROUP BY r.RequestId
				,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2))
		END
	END
	ELSE
	BEGIN
		IF @IssueTypeId <> 3
		BEGIN
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest r
		END
		ELSE
		BEGIN
				SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId
				,CAST(livehomescore AS VARCHAR(2)) + '-' + CAST(liveawayscore AS VARCHAR(2)) AS LiveScores
			FROM #TransidInRequest r
		END
	END

	--Loginfo table
	IF @IssueTypeId NOT IN (1,3)
	BEGIN
		SELECT MatchId
			,STUFF(w.scores,1,1,'') AS LiveScores
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
			,MIN(HighLightTransId) AS HighLightTransId
			,MIN(HighlightAcceptType) AS HighlightAcceptType
		FROM #logInfo l
			CROSS APPLY(
						SELECT '|' + LiveScores
						FROM #logInfo rd WITH(NOLOCK)
						where l.MatchId = rd.MatchId
						FOR XML PATH('')
						)w (scores)
		GROUP BY MatchId, w.scores
	END
	ELSE IF @IssueTypeId = 1
	BEGIN
		;WITH _cte AS (
				SELECT MatchId
					,STUFF(w.scores,1,1,'') AS LiveScores
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
				FROM #logInfo l
					CROSS APPLY(
								SELECT '|' + LiveScores
								FROM #logInfo rd WITH(NOLOCK)
								where l.MatchId = rd.MatchId
								FOR XML PATH('')
								)w (scores) 
				GROUP BY MatchId, w.scores
			)
		SELECT MatchId
			, LiveScores
			,VoidFromTime
			,VoidToTime
			,SingleCount
			,CashOutCount
			,InstantlySettleCount
			,MainParlayCount
			,MinSingleTransId
			,MaxSingleTransId
			,MinMainParlayTransId
			,MaxMainParlayTransId
			,tmpHighlight.HighLightTransId AS HighLightTransId
			,tmpHighlight.HighlightAcceptType AS HighlightAcceptType
		FROM _cte l
			CROSS APPLY (SELECT MIN(VoidFromTime) AS VoidFromTime_min
							FROM #logInfo lg 
							WHERE l.matchid = lg.matchid
							) AS Voidtime
			OUTER APPLY (SELECT TOP 1 b.transid AS HighLightTransId
								,b.accepttype HighlightAcceptType
						FROM #SpecialDeleteBets b 
								CROSS APPLY (SELECT CASE WHEN @FilterBy = 1 THEN b.transdate
															WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
															WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
															END AS VoidTime
								)act
						WHERE l.MatchId = b.matchid AND Voidtime.VoidFromTime_min = act.VoidTime 
							AND 1 = (CASE WHEN l.MinSingleTransId IS NOT NULL AND b.transid = l.MinSingleTransId  THEN 1
											WHEN l.MinMainParlayTransId IS NOT NULL AND b.transid = l.MinMainParlayTransId THEN 1
										END
									)
							ORDER BY CASE WHEN l.MinSingleTransId IS NOT NULL THEN 1 ELSE 0 END DESC
							
				) AS tmpHighlight
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
		SELECT MatchId
			,LiveScores
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
	DROP TABLE #FilterInfo

END
GO