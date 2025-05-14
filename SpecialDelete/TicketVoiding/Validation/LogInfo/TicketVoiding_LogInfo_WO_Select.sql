/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_WO_Select]
(	
	@RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 2
	,@WrongOddsInfo		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20230419@Max
	Task: [TVS] New issue type Wrong Odds [Redmine: #179934]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20230419@Max: Create new SP [Redmine:#179934]
		- 20231017@Max: [TVS] Update rule get tickets when offering wrong handicap [Redmine: #195445]
		- 20231023@Max: Extend datatype [Redmine: #192202]
		- 20240123@Max: TVS - Wrong Odds - Wrongly converting odds to search ticket [Redmine: #200123]
		- 20240124@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240618@July: [TVS] Support void wrong odds of Home/Away or Over/Under at the same time [Redmine: #205558] 
		- 20240722@July: [TVS] Add Details function for traders of LG/Early teams [Redmine: #206715]
		- 20240912@July: [TVS] Support Sportsbook for Wrong HDP, 1st HDP, OU, 1st OU, & Wrong Odds issue types [Redmine: #210152]
		- 20241007@July: TVS - Wrong Odds - Wrongly converting odds to search ticket [Redmine: #211890]
		- 20241211@July: TVS - Wrong Odds - Display tickets in the allowance odds ranges AND Add column GroupName [Redmine: #214196]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]
		- 20250507@July: Fix bug miss filter SiteDBGroupID [Redmine: #226513]
		- 20250512@July: System didnot unmark ticket when user edit request [Redmine: #227009]
		
	Param's explanation:
		+ @WrongOddsInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" SubIssueTypeId="" PoolHouseCheckedBetTypes ="1,2,3,4" IsLinkGroup1X2 ="" IsLinkGroupAIO = "" LiveIndicator =""/></root>
			(*) PoolHouseCheckedBetTypes   : ALL - (all bettype của ticket)
											 '1,2,3' - (bettype selected)
											 -1 - (no bettype affected)
											 '' - (uncheck all bettype PH)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
	        ,@WrongOddsInfoXML		  XML = NULL
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson		      VARBINARY(MAX) = NULL
			,@PHBettypes			  VARCHAR(MAX) =''
			,@PoolHouseCheckedBetTypes VARCHAR(MAX) = ''
			,@MatchId				   INT
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL
		    ,@SiteDBGroupID			  SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #logInfo (
		 MatchId						INT
		,LiveScores						NVARCHAR(300)
		,VoidFromTime					DATETIME
		,VoidToTime						DATETIME
		,SingleCount					INT
		,CashOutCount					INT
		,SettleCount					INT
		,InstantlySettleCount			INT
		,MainParlayCount 				INT
		,PoolHouseSingleCount			INT
		,PoolHouseCashOutCount			INT
		,PoolHouseSettleCount 			INT
		,PoolHouseInstantlySettleCount	INT
		,PoolHouseMainParlayCount 		INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT --parent matchid
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
		,PoolHouseCheckedBetTypes VARCHAR(MAX)
		,IsLinkGroup1X2			BIT DEFAULT(0) --Soccer: call API get link log | Other sports: No.default = 0
		,IsLinkGroupAIO			BIT DEFAULT(0) --Soccer: call API get link log | Other sports: No.default = 0
		,LiveIndicator			BIT DEFAULT(0)		
		,FilterFavoriteType		VARCHAR(10) -- "h" or "a"
		,FavoriteValue			SMALLMONEY -- "1.25"
		,WrongOU				SMALLMONEY -- "1.25"
		,Spread					MONEY
		,AllowanceRate			MONEY
		,CorrectOddsHomeOver	SMALLMONEY
		,CorrectOddsAwayUnder	SMALLMONEY
		,FromOddsNotVoidHomeOver SMALLMONEY
		,ToOddsNotVoidHomeOver	SMALLMONEY
		,FromOddsNotVoidAwayUnder SMALLMONEY
		,ToOddsNotVoidAwayUnder	SMALLMONEY
		,Sporttype				SMALLINT
		,MatchId_tmp			INT --child matchid
		
	)
	CREATE TABLE #logInfoVoidPage (
		RequestId						INT
		,MatchId						INT
		,PoolHouseSingleCount			INT
		,CashOutCount					INT
		,SettleCount					INT
		,InstantlySettleCount			INT
		,PoolHouseCashOutCount			INT
		,PoolHouseSettleCount			INT
		,PoolHouseInstantlySettleCount	INT
		,PoolHouseMainParlayCount 		INT
	)

	CREATE TABLE #TVSTicketBets(
	   matchid INT
	  ,transid BIGINT
	  ,Subtransid BIGINT
	  ,refno BIGINT
	  ,custid INT	
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
	  ,odds SMALLMONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(4)
      ,bettype SMALLINT
      ,betteam NVARCHAR(10)
	  ,betcheck NVARCHAR(50)
	  ,Status NVARCHAR(10)
      ,transdate DATETIME
	  ,checktime DATETIME
	  ,betid BIGINT
	  ,Transdesc NVARCHAR(1000)
	  ,statusID TINYINT
	  ,Subcustid INT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Sublivehomescore SMALLINT
      ,Subliveawayscore SMALLINT
	  ,Subliveindicator BIT
	  ,Subodds SMALLMONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(4)
	  ,Subbettype SMALLINT
	  ,Subbetteam  NVARCHAR(10)
	  ,Subbetcheck NVARCHAR(50)
	  ,SubStatus NVARCHAR(10)
	  ,Subtransdate DATETIME
	  ,Subchecktime DATETIME
	  ,SubTransdesc  NVARCHAR(1000)
	  ,SubstatusID TINYINT
	  ,srecommend INT
	  ,mrecommend INT
	  ,recommend INT
      ,creator INT
	  ,stake MONEY
	  ,oddstype TINYINT
	  ,CurrencyName NVARCHAR(50)
	  ,betdaqid BIGINT
	  ,ExtraInfo VARCHAR(1000)
	  ,BonusID INT
	  ,winlost	MONEY
	  ,actual_stake MONEY
	  ,winlostdate SMALLDATETIME
	  ,modds SMALLMONEY
	  ,statuswinlost TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,homeid INT
      ,awayid INT
	  ,leagueid INT
	  ,isNeutral BIT
	  ,matchcode NVARCHAR(50)
	  ,sporttype SMALLINT
	  ,eventstatus NVARCHAR(50)
	  ,SettlementStatus TINYINT
	  ,username NVARCHAR(50)
	  ,IsDeposit BIT
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,SettledType TINYINT -- 1: Instant Settlement, 2: Normal Settlement
	  ,GroupName		  VARCHAR(50)
	  ,SubIssueTypeId	  SMALLINT
	  ,FilterOdds		  MONEY
	  ,FilterBetteam	  NVARCHAR(10)
	  ,ID INT IDENTITY (1,1) PRIMARY KEY
	)

	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))
	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,MatchId                 INT
			,IsPoolHouseAffected	 BIT DEFAULT(0)
			,LogInfoTicketsJson		 VARCHAR(MAX)
		    ,IsFinish				 BIT
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpLogInfoTickets TABLE (TransId BIGINT, IsOtherTicket BIT DEFAULT(0))
	DECLARE @tmpOtherTicket AS TABLE (TransId BIGINT, sporttype SMALLINT, IsMixParlay BIT)

	SET @WrongOddsInfoXML = CONVERT(XML, @WrongOddsInfo)
	INSERT INTO #FilterInfo(
			MatchId
			,FilterFromTransTime
			,FilterToTransTime
			,SubIssueTypeId
			,PoolHouseCheckedBetTypes
			,IsLinkGroup1X2
			,IsLinkGroupAIO
			,LiveIndicator
			,FilterFavoriteType
			,FavoriteValue
			,WrongOU
			,Spread
			,AllowanceRate
			,CorrectOddsHomeOver
			,CorrectOddsAwayUnder
			,FromOddsNotVoidHomeOver 
			,ToOddsNotVoidHomeOver	
			,FromOddsNotVoidAwayUnder
			,ToOddsNotVoidAwayUnder	
		)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,t.c.value('@PoolHouseCheckedBetTypes','VARCHAR(MAX)') AS PoolHouseCheckedBetTypes
			,t.c.value('@IsLinkGroup1X2','BIT') AS IsLinkGroup1X2
			,t.c.value('@IsLinkGroupAIO','BIT') AS IsLinkGroupAIO
			,t.c.value('@LiveIndicator','BIT') AS LiveIndicator
			,t.c.value('@FilterFavoriteType', 'VARCHAR(10)') AS FilterFavoriteType
			,t.c.value('@FavoriteValue', 'SMALLMONEY') AS FavoriteValue
			,t.c.value('@WrongOU', 'SMALLMONEY') AS WrongOU
			,t.c.value('@Spread', 'MONEY') AS Spread
			,t.c.value('@AllowanceRate', 'MONEY') AS AllowanceRate
			,t.c.value('@CorrectOddsHomeOver', 'SMALLMONEY') AS CorrectOddsHomeOver
			,t.c.value('@CorrectOddsAwayUnder', 'SMALLMONEY') AS CorrectOddsAwayUnder
			,t.c.value('@FromOddsNotVoidHomeOver', 'SMALLMONEY') AS FromOddsNotVoidHomeOver 
			,t.c.value('@ToOddsNotVoidHomeOver', 'SMALLMONEY') AS ToOddsNotVoidHomeOver	
			,t.c.value('@FromOddsNotVoidAwayUnder', 'SMALLMONEY') AS FromOddsNotVoidAwayUnder
			,t.c.value('@ToOddsNotVoidAwayUnder', 'SMALLMONEY') AS ToOddsNotVoidAwayUnder	
	FROM	@WrongOddsInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongOddsInfoXML = NULL ))

	--Init Validation
	INSERT INTO @Validation (MatchId, IsPoolHouseAffected)
	SELECT MatchId, CASE WHEN d.IsLinkGroup1X2 = 0 AND d.IsLinkGroupAIO = 0 THEN 0 ELSE 1 END
	FROM #FilterInfo d
	
	BEGIN -- Instant Settlement declaration
		
		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT)
		CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

		INSERT INTO #CTE_match (matchid, sporttype)
		SELECT DISTINCT t.matchid, m.sporttype
		FROM #FilterInfo t
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
			
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 1) --Soccer	 
		BEGIN 
			INSERT INTO #CTE_isCal (matchid, IsHTCal)
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM #CTE_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
			WHERE m.sporttype = 1

			--> Build bettype list supported for instant settlement based on settlement status of match
			INSERT INTO #InstantSettlementBettypes (matchid, bettype)
			SELECT c.matchid,  f.bettype
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype
						FROM dbo.f_TVS_GetInstantBettypes() 
						WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
									   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
									ELSE 0 END
				)f	 	
		END
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 2) --Basketball
		BEGIN
			INSERT INTO #CTE_isCal (matchid, ResourceId)
			SELECT m.matchid, rd.ResourceId
			FROM #CTE_match m
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
					ON rd.matchid = m.matchid
					AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 
			WHERE m.sporttype = 2

			INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
			SELECT DISTINCT c.matchid, f.bettype, f.betid
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype, betid
						FROM dbo.f_TVS_GetInstantBettypes()
						WHERE InstantType IS NULL
						AND 1 = CASE WHEN c.ResourceId IS NULL THEN 1 --NOT executed on this match.
									 WHEN c.ResourceId IS NOT NULL AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal) THEN 1
									 ELSE 0 END
				)f	 	
		END
		DROP TABLE #CTE_match
		DROP TABLE #CTE_isCal
	END	

	UPDATE d
	SET d.Sporttype = m.sporttype, MatchId_tmp = d.MatchId
	FROM #FilterInfo d
		INNER JOIN dbo.match m ON d.MatchId = m.MatchId

	--Cricket/Baseball - Get child match
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE Sporttype IN (50,8))
	BEGIN
		INSERT INTO #FilterInfo(
				MatchId
				,FilterFromTransTime
				,FilterToTransTime
				,SubIssueTypeId
				,PoolHouseCheckedBetTypes
				,IsLinkGroup1X2
				,IsLinkGroupAIO
				,LiveIndicator
				,FilterFavoriteType
				,FavoriteValue
				,WrongOU
				,Spread
				,AllowanceRate
				,CorrectOddsHomeOver
				,CorrectOddsAwayUnder
				,FromOddsNotVoidHomeOver 
				,ToOddsNotVoidHomeOver	
				,FromOddsNotVoidAwayUnder
				,ToOddsNotVoidAwayUnder	
				,Sporttype
				,MatchId_tmp
			)
		SELECT d.MatchId, d.FilterFromTransTime, d.FilterToTransTime 
				,d.SubIssueTypeId
				,d.PoolHouseCheckedBetTypes
				,d.IsLinkGroup1X2
				,d.IsLinkGroupAIO
				,d.LiveIndicator
				,d.FilterFavoriteType
				,d.FavoriteValue
				,d.WrongOU
				,d.Spread
				,d.AllowanceRate
				,d.CorrectOddsHomeOver
				,d.CorrectOddsAwayUnder
				,d.FromOddsNotVoidHomeOver 
				,d.ToOddsNotVoidHomeOver	
				,d.FromOddsNotVoidAwayUnder
				,d.ToOddsNotVoidAwayUnder	
				,m.Sporttype
				,m.MatchId AS MatchId_tmp
		FROM #FilterInfo d
			INNER JOIN dbo.match m WITH(NOLOCK) ON d.MatchId = m.ParentID
		WHERE m.sporttype IN (50,8) AND m.ChildMatchType = 200 
	END

	--Search single tickets
	INSERT INTO #TVSTicketBets(
			matchid 
			,transid
			,Subtransid 
			,custid                
			,transdate 
			,checktime 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,creator 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,statusID 
			,WalletType 
			,RefCode 
			,Subcustid         
			,Sublivehomescore 
			,Subliveawayscore 
			,Subhdp1 
			,Subhdp2 
			,Subbetfrom 
			,Subbettype 
			,SubstatusID 
			,Subtransdate 
			,Subchecktime 
			,Subliveindicator 
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,odds 
			,Subodds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,Subbetcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,winlost        
			,actual_stake 
			,Status
			,SubStatus 
			,Subbetteam  
			,Suboddsspread 
			,SubTransdesc  
			,modds 
			,SiteDBGroupID
			,FilterOdds
			,FilterBetteam
			,SubIssueTypeId
			,GroupName
		)
	SELECT DISTINCT d.MatchId
		,b.TransId
		,b.transid AS SubTransID
		,b.custid
		,b.transdate
		,b.checktime
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.betteam
		,b.creator
		,b.refno
		,b.betid
		,b.bettype
		,b.betdaqid 
		,b.betfrom 
		,b.statusID 
		,b.WalletType 
		,b.RefCode 
		,b.custid Subcustid         
		,b.livehomescore AS Sublivehomescore 
		,b.liveawayscore AS Subliveawayscore 
		,b.hdp1 AS Subhdp1 
		,b.hdp2 AS Subhdp2 
		,b.betfrom AS Subbetfrom 
		,b.bettype AS Subbettype 
		,b.statusID AS SubstatusID 
		,b.transdate AS Subtransdate 
		,b.checktime AS Subchecktime 
		,b.liveindicator AS Subliveindicator 
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,0 AS IsMixParlay 
		,b.odds 
		,b.odds AS Subodds 
		,b.oddsspread
		,b.oddstype 
		,b.betcheck 
		,b.betcheck AS Subbetcheck 
		,b.stake 
		,b.CurrencyName 
		,b.Transdesc 
		,b.ExtraInfo 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.status AS SubStatus 
		,b.betteam AS Subbetteam  
		,b.oddsspread AS Suboddsspread 
		,b.transdesc SubTransdesc  
		,b.modds 
		,b.SiteDBGroupID
		,b.odds
		,b.betteam
		,d.SubIssueTypeId
		,CASE WHEN b.bettype IN (1,3,7,8) THEN 'WO'
				  WHEN f.BetType IS NOT NULL AND f.GroupMatch = 0 THEN 'PH' --1X2
				  WHEN f.BetType IS NOT NULL AND f.GroupMatch <> 0 THEN 'PH' --AIO
			END AS GroupName
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
		LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND b.bettype = f.BetType AND f.SubIssueTypeId = d.SubIssueTypeId
	WHERE b.betfrom <> 'P' 
		AND b.SiteDBGroupID = @SiteDBGroupID  
		AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
		AND b.liveindicator = d.LiveIndicator 
		AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
		AND 1 = CASE WHEN d.SubIssueTypeId IN (6) 
							AND b.bettype IN (1)
							AND (
								(d.FavoriteValue <> 0
									AND((d.FilterFavoriteType = 'h' AND b.hdp1 = d.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND b.hdp2 = d.FavoriteValue))
								)
								OR (d.FavoriteValue = 0 AND b.hdp1 = 0 AND b.hdp2 = 0)
							)
						THEN 1
					 WHEN d.SubIssueTypeId IN (119) 
							AND b.bettype IN (7)
							AND (
								(d.FavoriteValue <> 0
									AND((d.FilterFavoriteType = 'h' AND b.hdp1 = d.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND b.hdp2 = d.FavoriteValue))
								)
								OR (d.FavoriteValue = 0 AND b.hdp1 = 0 AND b.hdp2 = 0)
							)
						THEN 1
					 WHEN d.SubIssueTypeId IN (120)
							AND b.bettype IN (3)
							AND b.hdp1 = d.WrongOU
						THEN 1
					 WHEN d.SubIssueTypeId IN (121)
							AND b.bettype IN (8)
							AND b.hdp1 = d.WrongOU
						THEN 1
					 WHEN d.sporttype = 1 AND f.BetType IS NOT NULL AND f.GroupMatch = 0 AND d.IsLinkGroup1X2 = 1 THEN 1 --Only support soccer
					 WHEN d.sporttype = 1 AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND d.IsLinkGroupAIO = 1 THEN 1 --Only support soccer 
					 ELSE 0 END
	
	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #FilterInfo d ON bm.matchid = d.MatchId_tmp
					WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  			       WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   				   ELSE 0 END
						AND bm.betfrom <> 'P' AND bm.SiteDBGroupID = @SiteDBGroupID
					)
	BEGIN	
		INSERT INTO #TVSTicketBets(
				matchid 
				,transid
				,Subtransid 
				,custid                
				,transdate 
				,checktime 
				,hdp1 
				,hdp2 
				,livehomescore 
				,liveawayscore 
				,liveindicator 
				,betteam 
				,creator 
				,refno 
				,betid 
				,bettype 
				,betdaqid 
				,betfrom 
				,statusID 
				,WalletType 
				,RefCode 
				,Subcustid         
				,Sublivehomescore 
				,Subliveawayscore 
				,Subhdp1 
				,Subhdp2 
				,Subbetfrom 
				,Subbettype 
				,SubstatusID 
				,Subtransdate 
				,Subchecktime 
				,Subliveindicator 
				,recommend 
				,mrecommend 
				,srecommend 
				,statuswinlost 
				,IsMixParlay 
				,odds 
				,Subodds 
				,oddsspread 
				,oddstype 
				,betcheck 
				,Subbetcheck 
				,stake 
				,CurrencyName 
				,Transdesc 
				,ExtraInfo 
				,winlost        
				,actual_stake 
				,Status
				,SubStatus 
				,Subbetteam  
				,Suboddsspread 
				,SubTransdesc  
				,modds 
				,SiteDBGroupID
				,FilterOdds
				,FilterBetteam
				,SubIssueTypeId
				,GroupName
			)
		SELECT d.MatchId
			,b.TransId
			,sub.transid AS SubTransID
			,b.custid
			,b.transdate
			,b.checktime
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.betteam
			,b.creator
			,b.refno
			,b.betid
			,b.bettype
			,b.betdaqid 
			,b.betfrom 
			,b.statusID 
			,b.WalletType 
			,b.RefCode 
			,b.custid Subcustid         
			,sub.livehomescore AS Sublivehomescore 
			,sub.liveawayscore AS Subliveawayscore 
			,sub.hdp1 AS Subhdp1 
			,sub.hdp2 AS Subhdp2 
			,sub.betfrom AS Subbetfrom 
			,sub.bettype AS Subbettype 
			,sub.statusID AS SubstatusID 
			,sub.transdate AS Subtransdate 
			,sub.checktime AS Subchecktime 
			,sub.liveindicator AS Subliveindicator 
			,b.recommend 
			,b.mrecommend 
			,b.srecommend 
			,b.statuswinlost 
			,1 AS IsMixParlay 
			,b.odds 
			,Sub.odds AS Subodds 
			,b.oddsspread
			,b.oddstype 
			,b.betcheck 
			,sub.betcheck AS Subbetcheck 
			,b.stake 
			,b.CurrencyName 
			,b.Transdesc 
			,b.ExtraInfo 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,sub.status AS SubStatus 
			,sub.betteam AS Subbetteam  
			,sub.oddsspread AS Suboddsspread 
			,sub.transdesc SubTransdesc  
			,b.modds
			,sub.SiteDBGroupID
			,sub.odds AS FilterOdds
			,sub.betteam AS FilterBetteam
			,d.SubIssueTypeId
			,CASE WHEN d.sporttype = 1 THEN 'PH' ELSE 'WO' END AS GroupName
		FROM #FilterInfo d
			 INNER JOIN dbo.bettransm sub ON d.MatchId_tmp = sub.matchid
			 INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			 LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND sub.bettype = f.BetType AND f.SubIssueTypeId = d.SubIssueTypeId
		WHERE 1 = CASE WHEN @ActionId <> 2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND sub.betfrom <> 'P' 
				AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID 
				AND sub.liveindicator = d.LiveIndicator
				AND sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND 1 = CASE WHEN d.SubIssueTypeId IN (6) 
									AND sub.bettype IN (1)
									AND (
										(d.FavoriteValue <> 0
											AND((d.FilterFavoriteType = 'h' AND sub.hdp1 = d.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND sub.hdp2 = d.FavoriteValue))
										)
										OR (d.FavoriteValue = 0 AND sub.hdp1 = 0 AND sub.hdp2 = 0)
									)
								THEN 1
							 WHEN d.SubIssueTypeId IN (119) 
									AND sub.bettype IN (7)
									AND (
										(d.FavoriteValue <> 0
											AND((d.FilterFavoriteType = 'h' AND sub.hdp1 = d.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND sub.hdp2 = d.FavoriteValue))
										)
										OR (d.FavoriteValue = 0 AND sub.hdp1 = 0 AND sub.hdp2 = 0)
									)
								THEN 1
							 WHEN d.SubIssueTypeId IN (120)
									AND sub.bettype IN (3)
									AND sub.hdp1 = d.WrongOU
								THEN 1
							 WHEN d.SubIssueTypeId IN (121)
									AND sub.bettype IN (8)
									AND sub.hdp1 = d.WrongOU
								THEN 1
							 WHEN d.sporttype = 1 AND f.BetType IS NOT NULL AND f.GroupMatch = 0 AND d.IsLinkGroup1X2 = 1 THEN 1 --Only support soccer
							 WHEN d.sporttype = 1 AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND d.IsLinkGroupAIO = 1 THEN 1 --Only support soccer
						ELSE 0 END
	END  

	---UPDATE column show loginfo details
	BEGIN
		UPDATE s
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
			,username = ci.username
		FROM #TVSTicketBets s
			INNER JOIN dbo.match m WITH (NOLOCK) ON	s.matchid = m.matchid
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON s.custid = ci.custid
	
		-- update Isdeposit
		UPDATE s 
			SET IsDeposit = 1
		FROM	#TVSTicketBets s
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = s.srecommend)
	
		-- update get instant/settle
		UPDATE b
		SET  b.SettledType = CASE 
								WHEN ISNULL(b.eventstatus, '') <> @eventstatus_completed
									THEN CASE
											WHEN b.sporttype = 1 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype
												) THEN 1
											WHEN b.sporttype = 2 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype AND (b.betid = i.betid OR b.betid IS NULL)
												) THEN 1
											ELSE 2
										END
								ELSE 2
							END
		FROM #TVSTicketBets b 
		WHERE ISNULL(b.betdaqid,0) <> -2 AND b.SubStatusId IN (111, 112, 113) 
	
	END

	DECLARE @Odds_str		NVARCHAR(100)
		  , @FromOdds	    SMALLMONEY = 0
		  , @ToOdds			SMALLMONEY = 0
		  , @tmp_ToOdds		SMALLMONEY = 0
		  , @tmp_FromOdds	SMALLMONEY = 0
		  , @Betteam		NVARCHAR(10)

	DECLARE @tmp_Odds AS TABLE (Odds SMALLMONEY, OddsType TINYINT)
	DECLARE @tmp_OddsRange TABLE (FromOdds SMALLMONEY, ToOdds SMALLMONEY, Betteam NVARCHAR(10), IsFinish BIT)

	INSERT INTO @tmp_OddsRange(FromOdds, ToOdds, Betteam)
	SELECT FromOddsNotVoidHomeOver, ToOddsNotVoidHomeOver, 'h'
	FROM #FilterInfo
	UNION 
	SELECT FromOddsNotVoidAwayUnder, ToOddsNotVoidAwayUnder, 'a'
	FROM #FilterInfo 

	WHILE (1=1)
	BEGIN
		DELETE FROM @tmp_Odds

		UPDATE TOP(1) d
		SET @FromOdds = d.FromOdds
		  , @ToOdds = d.ToOdds
		  , @Betteam = d.Betteam
		  , IsFinish = 1
		FROM @tmp_OddsRange d
		WHERE d.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK;

		IF (@FromOdds < 0 AND @ToOdds > 0) OR (@FromOdds > 0 AND @ToOdds < 0)
		BEGIN
			--Range 1: negative
			SET @tmp_FromOdds = CASE WHEN @FromOdds < 0 THEN @FromOdds ELSE @ToOdds END
			SET @tmp_ToOdds = -1.00

			SET @Odds_str = (SELECT CAST(@tmp_FromOdds AS VARCHAR(10)) + ',' + CAST(@tmp_ToOdds AS VARCHAR(10)))
		
			INSERT INTO @tmp_Odds (Odds, OddsType)
			SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

			;WITH cte AS
			(
				SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
				FROM @tmp_Odds
				GROUP BY OddsType
			)
			--Remove transid-> NOT VOID affect main bettype
			DELETE b
				OUTPUT deleted.SubTransid, deleted.sporttype, deleted.IsMixParlay
				INTO @tmpOtherTicket (TransId, sporttype, IsMixParlay)
			FROM #TVSTicketBets b
				INNER JOIN cte tp ON tp.OddsType = b.OddsType
			WHERE 1 = CASE WHEN b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) THEN 1
						   WHEN b.IsMixParlay = 0 AND b.GroupName = 'WO' THEN 1
						   ELSE 0 END
				AND b.FilterBetteam = @Betteam
				AND b.FilterOdds BETWEEN tp.FromOdds AND ToOdds

			DELETE @tmp_Odds
			--Range 1: possitive
			SET @tmp_FromOdds =  CASE WHEN @ToOdds > 0 THEN @ToOdds ELSE @FromOdds END
			SET @tmp_ToOdds = 1.00

			SET @Odds_str = (SELECT CAST(@tmp_FromOdds AS VARCHAR(10)) + ',' + CAST(@tmp_ToOdds AS VARCHAR(10)))
		
			INSERT INTO @tmp_Odds (Odds, OddsType)
			SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

			;WITH cte AS
			(
				SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
				FROM @tmp_Odds
				GROUP BY OddsType
			)
			--Remove transid-> NOT VOID affect main bettype
			DELETE b
				OUTPUT deleted.SubTransid, deleted.sporttype, deleted.IsMixParlay
				INTO @tmpOtherTicket (TransId, sporttype, IsMixParlay)
			FROM #TVSTicketBets b
				INNER JOIN cte tp ON tp.OddsType = b.OddsType
			WHERE 1 = CASE WHEN b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) THEN 1
						   WHEN b.IsMixParlay = 0 AND b.GroupName = 'WO' THEN 1
						   ELSE 0 END
				AND b.FilterBetteam = @Betteam
				AND b.FilterOdds BETWEEN tp.FromOdds AND ToOdds
		END
		ELSE
		BEGIN 
			SET @Odds_str = (SELECT CAST(@FromOdds AS VARCHAR(10)) + ',' + CAST(@ToOdds AS VARCHAR(10)))
		
			INSERT INTO @tmp_Odds (Odds, OddsType)
			SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

			;WITH cte AS
			(
				SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
				FROM @tmp_Odds
				GROUP BY OddsType
			)
			--Remove transid-> NOT VOID affect main bettype
			DELETE b
				OUTPUT deleted.SubTransid, deleted.sporttype, deleted.IsMixParlay
				INTO @tmpOtherTicket (TransId, sporttype, IsMixParlay)
			FROM #TVSTicketBets b
				INNER JOIN cte tp ON tp.OddsType = b.OddsType
			WHERE 1 = CASE WHEN b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) THEN 1
						   WHEN b.IsMixParlay = 0 AND b.GroupName = 'WO' THEN 1
						   ELSE 0 END
				AND b.FilterBetteam = @Betteam
				AND b.FilterOdds BETWEEN tp.FromOdds AND ToOdds
		END
	END

	/*Get Transid in Request of range Transid*/
	DECLARE @TransInfoJson_Request		VARBINARY(MAX)
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	SET @MaxRow = (SELECT MAX(ID) FROM #TVSTicketBets)
	SET @Threshold = 20000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold
	IF @ActionId <> 2
	BEGIN
		WHILE (@MaxRow IS NOT NULL)
		BEGIN
		
				SET @TransInfoJson_Request = COMPRESS((SELECT matchid AS 'mid'
						,transid AS 't'
						,SubTransid AS 's_t'
				FROM #TVSTicketBets R
				WHERE ID BETWEEN @StartRow AND @StopRow
					FOR JSON PATH))

				INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
				EXEC DBCTG.bodb02.dbo.TicketVoiding_CheckExistingRequest
					@TransInfoJson = @TransInfoJson_Request
					,@RequestId = @RequestId
					,@Mode = 1

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END
		
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
		END

		
	END

	SELECT @PoolHouseCheckedBetTypes = PoolHouseCheckedBetTypes FROM #FilterInfo 

	IF @PoolHouseCheckedBetTypes = 'ALL'
	BEGIN
		SET @PHBettypes = STUFF((SELECT DISTINCT ',' + CAST(Subbettype AS VARCHAR(10))
										FROM #TVSTicketBets 
										WHERE 1 = CASE WHEN IsMixParlay = 0 AND Subbettype NOT IN (1,3,7,8) THEN 1
														WHEN IsMixParlay = 1 THEN 1
														ELSE 0 END
										FOR XML PATH ('')
								),1,1,'')
		UPDATE #FilterInfo
		SET PoolHouseCheckedBetTypes = @PHBettypes
	END

	/*Remove Transid poolhouse bettype un-check*/
	DELETE b
	FROM #TVSTicketBets b
		INNER JOIN #FilterInfo d ON b.matchid = d.MatchId
		OUTER APPLY (
				SELECT value AS bettype
				FROM STRING_SPLIT(d.PoolHouseCheckedBetTypes, ',')
				WHERE b.Subbettype = CAST (value AS SMALLINT)		
			)xPH
	WHERE GroupName = 'PH' 
	   AND 1 = CASE WHEN ISNULL(@PoolHouseCheckedBetTypes,'') <> '' AND xPH.bettype IS NULL THEN 1
					WHEN ISNULL(@PoolHouseCheckedBetTypes,'') = '' THEN 1
					ELSE 0 END
		
	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE v SET v.IsPoolHouseAffected = 1
		FROM @Validation v
			INNER JOIN #FilterInfo d ON v.matchid = d.MatchId
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, SettleCount, InstantlySettleCount, MainParlayCount, PoolHouseSingleCount, PoolHouseCashOutCount, PoolHouseSettleCount, PoolHouseInstantlySettleCount, PoolHouseMainParlayCount)
	SELECT b.matchid AS MatchId
		,CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(b.Subtransdate) AS VoidFromTime
		,MAX(b.Subtransdate) AS VoidToTime
		,COUNT(CASE WHEN b.GroupName = 'WO' AND b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.GroupName = 'WO' AND b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.GroupName = 'WO' AND b.transid = b.SubTransid AND b.SettledType = 2 THEN b.transid ELSE NULL END) AS SettleCount
		,COUNT(CASE WHEN b.GroupName = 'WO' AND b.transid = b.SubTransid AND b.SettledType = 1 THEN b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.GroupName = 'WO' AND b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MainParlayCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS PoolHouseSingleCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS PoolHouseCashOutCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid AND b.SettledType = 2 THEN b.transid ELSE NULL END) AS PoolHouseSettleCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid = b.SubTransid AND b.SettledType = 1 THEN b.transid ELSE NULL END) AS PoolHouseInstantlySettleCount
		,COUNT(CASE WHEN b.GroupName = 'PH' AND b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS PoolHouseMainParlayCount
	FROM #TVSTicketBets b 
	GROUP BY CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.Sublivehomescore AS VARCHAR(2)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(2)) ASC

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
		,v.IsPoolHouseAffected = CASE WHEN v.IsPoolHouseAffected = 1 THEN v.IsPoolHouseAffected ELSE l.IsPoolHouseAffected END
	FROM @Validation v
		OUTER APPLY( 
			SELECT ISNULL(SUM(SingleCount),0) + ISNULL(SUM(PoolHouseSingleCount),0) AS SingleCount
				  ,ISNULL(SUM(MainParlayCount),0) + ISNULL(SUM(PoolHouseMainParlayCount),0) AS MainParlayCount
				  ,MAX(CASE WHEN PoolHouseMainParlayCount <> 0 THEN 1 ELSE 0 END) AS IsPoolHouseAffected
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l 
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpOtherTicket WHERE IsMixParlay = 1 AND sporttype = 1)
	BEGIN
		--Remove case LG/Early for soccer show Other Ticket have Parlay ticket
		DELETE o
		FROM @tmpOtherTicket o
		WHERE o.IsMixParlay = 1 AND o.sporttype = 1
	END

	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, MainParlayCount INT, ActionId TINYINT)
	CREATE TABLE #CTE_Ticket_Single (RequestId INT, MatchId INT, TransId BIGINT, Bettype SMALLINT, SubIssueTypeId INT)
	CREATE TABLE #CTE_Ticket_SubParlay (RequestId INT, MatchId INT, TransId BIGINT)

	DECLARE @cnt_s INT , @cnt_p INT	

	INSERT INTO #CTE_RequestDetail (RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, MainParlayCount, ActionId)
	SELECT rd.RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, MainParlayCount, ActionId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
	WHERE rd.RequestId = @RequestId

	INSERT INTO #CTE_Ticket_Single (RequestId, MatchId, TransId, Bettype, SubIssueTypeId)
	SELECT RequestId, MatchId, TransId, Bettype, SubIssueTypeId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
	WHERE RequestId = @RequestId AND SiteDBGroupID = @SiteDBGroupID 
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId)
	SELECT RequestId, MatchId, TransId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId AND SiteDBGroupID = @SiteDBGroupID 
	SET @cnt_p = @@ROWCOUNT

	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId, IsOtherTicket)
		SELECT SubTransid, 0
		FROM #TVSTicketBets WHERE GroupName = 'WO'
		UNION ALL
		SELECT TransId, 1
		FROM @tmpOtherTicket
	END
	ELSE --Edit request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId, IsOtherTicket)
		SELECT TransId, 0 
		FROM #CTE_Ticket_Single WITH (NOLOCK) 
		WHERE   1 = CASE WHEN SubIssueTypeId = 6   AND bettype = 1 THEN 1
			             WHEN SubIssueTypeId = 119 AND bettype = 7 THEN 1
						 WHEN SubIssueTypeId = 120 AND bettype = 3 THEN 1
						 WHEN SubIssueTypeId = 121 AND bettype = 8 THEN 1
						 ELSE 0 END
		UNION ALL
		SELECT s.TransId, 0
		FROM #CTE_Ticket_SubParlay s WITH (NOLOCK) 
			CROSS APPLY (
				SELECT TOP 1 sporttype
				FROM #CTE_RequestDetail rd WITH (NOLOCK) 
				WHERE s.MatchId = rd.MatchId
			)rd
		WHERE rd.Sporttype <> 1 --Other sports
		UNION ALL
		SELECT TransId, 1
		FROM @tmpOtherTicket

	END

	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) v
		SET v.IsFinish = 1, @MatchId = v.MatchId
		FROM @Validation v
		WHERE IsFinish IS NULL 

		IF @@ROWCOUNT = 0 BREAK;

		SET @LogInfoTicketsJson = COMPRESS((SELECT m.transid AS 'transid'
			   ,m.refno AS 'refno'		
			   ,m.SubTransId AS 'SubTransId'	
			   ,m.username AS 'username'		
			   ,m.transdate AS 'transdate'	
			   ,m.Stake AS 'Stake'	
			   ,m.odds AS 'odds'	
			   ,m.SubOdds AS 'SubOdds'
			   ,m.oddsspread AS 'oddsspread'	
			   ,m.OddsType AS 'OddsType'
			   ,m.bettype AS 'bettype'
			   ,m.SubBettype AS 'SubBettype'
			   ,m.STATUS AS 'STATUS'
			   ,m.SubStatus AS 'SubStatus'
			   ,m.currencyname AS 'currencyname'
			   ,m.betteam AS 'betteam'
			   ,m.SubBetTeam AS 'SubBetTeam'
			   ,m.Subhdp1 AS 'Subhdp1'
			   ,m.Subhdp2 AS 'Subhdp2'
			   ,m.hdp1 AS 'hdp1'
			   ,m.hdp2 AS 'hdp2'
			   ,m.livehomescore AS 'livehomescore'
			   ,m.liveawayscore AS 'liveawayscore'
			   ,m.betid AS 'betid'
			   ,m.betcheck AS 'betcheck'
			   ,m.Subchecktime AS 'Subchecktime'
			   ,m.IsMixParlay AS 'IsMixParlay'
			   ,m.Transdesc AS 'Transdesc'
			   ,m.betdaqid AS 'betdaqid'
			   ,m.WalletType AS 'WalletType'
			   ,m.RefCode AS 'RefCode'
			   ,CAST(m.winlost AS VARCHAR) AS 'winlost'
			   ,m.LiveIndicator AS 'IsLiveIndicator' 
			   ,m.actual_stake AS 'ActualStake'
			   ,m.ExtraInfo AS 'ExtraInfo'
			   ,m.winlostdate AS 'winlostdate'
			   ,m.IsDeposit AS 'IsDeposit'
			   ,m.matchid AS 'matchid'
			   ,m.homeid AS 'homeid'
			   ,m.awayid AS 'awayid'
			   ,m.leagueid AS 'leagueid'
			   ,m.IsNeutral AS 'IsNeutral'
			   ,m.matchcode AS 'matchcode'
			   ,m.SettlementStatus AS 'SettlementStatus'
			   ,m.sporttype AS 'sporttype'
			   ,ISNULL(s.IsOtherTicket,0) AS 'IsOtherTicket'
			   ,CASE WHEN m.IsMixParlay = 1 THEN 'Parlay' ELSE bt.typenamee END AS 'GroupName' --Feature: [#213960]
		FROM @tmpLogInfoTickets s
			INNER JOIN #TVSTicketBets m ON s.transid = m.Subtransid
			INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = m.Subbettype 
		WHERE m.matchid = @MatchId
		FOR JSON PATH))

		UPDATE v
		SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
		FROM @Validation v
		WHERE MatchId = @MatchId

	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		/*Support case uncheck bettype PH -> still show PH count = 0 & case voided*/
		UPDATE v
		SET v.IsPoolHouseAffected = CASE WHEN v.IsPoolHouseAffected = 1 THEN v.IsPoolHouseAffected ELSE 1 END
		FROM @Validation v
		INNER JOIN #CTE_RequestDetail rd WITH (NOLOCK) ON v.MatchId = rd.MatchId
		WHERE rd.Sporttype = 1
			AND rd.TransIds NOT LIKE '%PoolHouseCheckedBetTypes="-1"%'

		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,IsPoolHouseAffected 
		FROM @Validation

		-- 2. TransId in request table
		SELECT RequestId, MatchId, 
			   STUFF((SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,2,'') AS TransIds
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, SettleCount, InstantlySettleCount, PoolHouseCashOutCount, PoolHouseSettleCount, PoolHouseInstantlySettleCount)
		SELECT @RequestId
				,b.matchid
				, COUNT(CASE WHEN b.bettype IN (1,3,7,8) AND b.betdaqid = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
				, COUNT(CASE WHEN b.bettype IN (1,3,7,8) AND b.SettledType = 2 THEN s.TransId ELSE NULL END) AS SettleCount
				, COUNT(CASE WHEN b.bettype IN (1,3,7,8) AND b.SettledType = 1 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
				, COUNT(CASE WHEN b.bettype NOT IN (1,3,7,8) AND b.betdaqid = -2 AND b.sporttype = 1 THEN s.TransId ELSE NULL END) AS PoolHouseCashOutCount
				, COUNT(CASE WHEN b.bettype NOT IN (1,3,7,8) AND b.SettledType = 2 AND b.sporttype = 1 THEN s.TransId ELSE NULL END) AS PoolHouseSettleCount
				, COUNT(CASE WHEN b.bettype NOT IN (1,3,7,8) AND b.SettledType = 1 AND b.sporttype = 1 THEN s.TransId ELSE NULL END) AS PoolHouseInstantlySettleCount
		FROM #CTE_Ticket_Single s WITH (NOLOCK)
			INNER JOIN #TVSTicketBets b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
		WHERE b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid
		
		--Check score for void message
		IF @cnt_s > 0
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT b.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
			FROM #CTE_Ticket_Single s WITH (NOLOCK)
				INNER JOIN #TVSTicketBets b ON b.transid = s.TransId AND b.IsMixParlay = 0
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
			WHERE f.GroupName <> '2H'
		END

		IF @cnt_p > 0
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT b.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
			FROM #CTE_Ticket_SubParlay s WITH (NOLOCK)
				INNER JOIN #TVSTicketBets b ON b.Subtransid = s.TransId AND b.IsMixParlay = 1
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype			
			WHERE f.GroupName <> '2H'
		END

		IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
			SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(10)) + '-' + CAST(m.liveawayscore AS VARCHAR(10))
			FROM #CTE_RequestDetail rd WITH (NOLOCK)
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
		END

		-- 3. Loginfo table
		SELECT rd.MatchId
			,CASE WHEN @SiteDBGroupID = 0 THEN SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) ELSE NULL END AS LiveScores
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			,CASE WHEN @SiteDBGroupID = 0 THEN SUBSTRING(rd.IssueDetail, CHARINDEX('SingleCount:',rd.IssueDetail) + LEN('SingleCount:'), CHARINDEX(';PoolHouseSingleCount:',rd.IssueDetail) - (CHARINDEX('SingleCount:',rd.IssueDetail) + LEN('SingleCount:'))) ELSE NULL END AS SingleCount
			,t.CashOutCount
			,t.SettleCount
			,t.InstantlySettleCount
			,CASE WHEN @SiteDBGroupID = 0 THEN CASE WHEN rd.Sporttype <> 1 THEN rd.MainParlayCount ELSE 0 END ELSE NULL END AS MainParlayCount --Other sports
			,CASE WHEN @SiteDBGroupID = 0 THEN SUBSTRING(rd.IssueDetail,CHARINDEX('PoolHouseSingleCount:',rd.IssueDetail) + LEN('PoolHouseSingleCount:'), CHARINDEX(';PoolHouseMainParlayCount:',rd.IssueDetail) - ( CHARINDEX('PoolHouseSingleCount:',rd.IssueDetail)+ LEN('PoolHouseSingleCount:'))) ELSE NULL END AS PoolHouseSingleCount
			,t.PoolHouseCashOutCount
			,t.PoolHouseSettleCount 
			,t.PoolHouseInstantlySettleCount
			,CASE WHEN @SiteDBGroupID = 0 THEN CASE WHEN rd.Sporttype = 1 THEN rd.MainParlayCount ELSE 0 END ELSE NULL END AS PoolHouseMainParlayCount --Soccer
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
		    ,v.LogInfoTicketsJson
		FROM #CTE_RequestDetail rd WITH (NOLOCK)
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreNormalTicket
				FROM @tblScoreMessage l
				WHERE l.MatchId = rd.MatchId
				FOR XML PATH('')
			)s2(ScoreTicket2H)
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreOfMatch
				FROM @tblScoreMessage l
				WHERE l.MatchId = rd.MatchId
				FOR XML PATH('')
			)sm(ScoreOfMatch)
			INNER JOIN @Validation v ON rd.MatchId = v.MatchId

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		RETURN;
	END
	
	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT ISNULL(SUM(SingleCount),0)+ ISNULL(SUM(PoolHouseSingleCount),0) AS SingleCount
				,ISNULL(SUM(MainParlayCount),0) + ISNULL(SUM(PoolHouseMainParlayCount),0) AS MainParlayCount
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		INSERT INTO @tmpMarkTransId (TransId)
		SELECT tp.SubTransid
		FROM #TVSTicketBets tp
		WHERE tp.SubStatusId IN (0,1)
	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SET @OldActionId = (SELECT TOP 1 ISNULL(ActionId,0) FROM #CTE_RequestDetail WITH(NOLOCK))
		
		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT um.TransId
			FROM ( 
					SELECT TransId FROM #CTE_Ticket_Single s
					UNION ALL 
					SELECT TransId FROM #CTE_Ticket_SubParlay p
				)um
				LEFT JOIN #TVSTicketBets tp ON um.TransId = tp.SubTransid 
			WHERE tp.TransId IS NULL 

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			--Unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT TransId FROM #CTE_Ticket_Single s
			UNION ALL 
			SELECT TransId FROM #CTE_Ticket_SubParlay p
		END

	END
	
	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,''),'')

	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId
											FOR XML PATH('')), 1,1,''),'')

	/*****************Return table **************************/
	-- 1. Validate table
	SELECT MatchId
		,IsInValidTotalTickets
		,IsExistedInOtherRequest
		,IsPoolHouseAffected
	FROM @Validation

	-- 2. TransId exists in other request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
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
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	SELECT l.MatchId
		,STUFF(w.scores,1,1,'') AS LiveScores
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,SUM(CashOutCount) AS CashOutCount
		,SUM(SettleCount) AS SettleCount
		,SUM(InstantlySettleCount) AS InstantlySettleCount
		,SUM(MainParlayCount) AS MainParlayCount
		,SUM(PoolHouseSingleCount) AS PoolHouseSingleCount
		,SUM(PoolHouseCashOutCount) AS PoolHouseCashOutCount
		,SUM(PoolHouseSettleCount) AS PoolHouseSettleCount
		,SUM(PoolHouseInstantlySettleCount) AS PoolHouseInstantlySettleCount
		,SUM(PoolHouseMainParlayCount) AS PoolHouseMainParlayCount
		,v.LogInfoTicketsJson
	FROM #logInfo l
		CROSS APPLY(
					SELECT '|' + LiveScores
					FROM #logInfo rd
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
		INNER JOIN @Validation v ON l.MatchId = v.MatchId
	GROUP BY l.MatchId, w.scores, v.LogInfoTicketsJson

	SET @TransInfoJson = COMPRESS((SELECT b.matchid AS 'mid'
		,b.transid AS 't'
		,b.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.Subbettype AS 's_btype'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets b
	FOR JSON PATH))
	
	-- 4. List ticket unmark/mark & Transinfo table (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds
		  ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #CTE_Ticket_Single
	DROP TABLE #CTE_Ticket_SubParlay
	DROP TABLE #CTE_RequestDetail
END
GO

