/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_OtherIssues_Select]
(	
	@RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 25
	,@OtherIssuesInfo	  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20241021@Max
	Task: [TVS] New Issue Type - Other Issues [Redmine: #211913]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20241021@Max: Create new SP [Redmine: #211913]
		- 20241216@Lani: Add 'GroupName' column returned [Redmine: #213960]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
	        ,@OtherIssuesInfoXML		  XML = NULL
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson			  VARBINARY(MAX) = NULL
			,@MainMatchId			  INT
			,@LogInfoTicketsJson	  VARBINARY(MAX) = NULL
			,@SiteDBGroupID			  SMALLINT
		    ,@ValueDefault SMALLMONEY = 9999.00
		    ,@AdvancedExtraInfo	NVARCHAR(MAX)
		    ,@MatchId				INT	= 0
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	CREATE TABLE #logInfo (
		 MatchId						INT
		,LiveScores						NVARCHAR(300)
		,VoidFromTime					DATETIME
		,VoidToTime						DATETIME
		,SingleCount					INT
		,CashOutCount					INT
		,SettleCount					INT
		,MainParlayCount				INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #FilterInfo (
		 Id						INT --Diffrence rangetime
		,MatchId				INT --parent matchid
		,AdvancedExtraInfo		VARCHAR(MAX)
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
		,isFinish				BIT
		,Sporttype				SMALLINT
		,MatchId_tmp			INT --child matchid
	)
	CREATE TABLE #logInfoVoidPage (
		RequestId						INT
		,MatchId						INT
		,SingleCount					INT
		,CashOutCount					INT
		,SettleCount					INT
		,MainParlayCount				INT
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
	  ,WalletType TINYINT
	  ,RefCode BIGINT
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
	  ,SettledType TINYINT -- 1: Instant Settlement, 2: Normal Settlement
	  ,SubIssueTypeId	  SMALLINT
	  --For Advanced Mode
	  ,FilterBettype	SMALLINT
	  ,FilterBetteam NVARCHAR(10)
	  ,FilterHdp1 SMALLMONEY
	  ,FilterHdp2 SMALLMONEY
	  ,FilterHdp	SMALLMONEY --hdp1 + hdp2
	  ,FilterX  NVARCHAR(50)
	  ,FilterY  NVARCHAR(50)
	  ,FilterXY  NVARCHAR(50)
	  ,FilterTransdesc NVARCHAR(1000)
	  ,FilterPlayerAndOdds NVARCHAR(1000)	
	  ,FilterBetOption		NVARCHAR(250)
	  ,FilterOddsSpread MONEY
	  ,ID INT IDENTITY (1,1) PRIMARY KEY
	)

	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))
	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,IsHasSettledTicket		 BIT DEFAULT(0) 
			,IsHasInstantlySettledTicket BIT DEFAULT(0)
			,MatchId                 INT
			,LogInfoTicketsJson		 NVARCHAR(MAX)
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpLogInfoTickets TABLE (TransId BIGINT)
	DECLARE @tmpConsolidatedBettypes TABLE (
        parentid        INT
        ,typeid         INT PRIMARY KEY
    )
    
	DECLARE @bettype_detail AS TABLE (
		Bettype				SMALLINT
		,FilterBetteam      NVARCHAR(2000)
		,FilterHDP		    SMALLMONEY
		,FilterHDP1		    SMALLMONEY
		,FilterHDP2		    SMALLMONEY
        ,FilterRuns		    SMALLMONEY
		,FilterTransdesc	NVARCHAR(2000)
		,IsFancy			BIT DEFAULT (0)
		,FilterPlayerAndOdds NVARCHAR(2000)	
		,FilterX			NVARCHAR(50)
		,FilterY			NVARCHAR(50)
		,FilterXY			NVARCHAR(50)
		,FilterBetOption	NVARCHAR(250)
		,FilterOddsSpread	MONEY --Support bettype 228,229
	)

    INSERT INTO @tmpConsolidatedBettypes (parentid, typeid)
    SELECT f.GroupTypeId AS parentid
		 , f.Bettype AS typeid
    FROM [dbo].[f_SD_GroupDisplayBettype] () f

	SET @OtherIssuesInfoXML = CONVERT(XML, @OtherIssuesInfo)
	INSERT INTO #FilterInfo (Id, MatchId, AdvancedExtraInfo, FilterFromTransTime, FilterToTransTime, SubIssueTypeId)
	SELECT  CASE WHEN t.c.value('@Id','INT') IS NULL THEN 1 ELSE t.c.value('@Id','INT') END AS Id --Default = 1 with case old request
	        ,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@AdvancedExtraInfo','VARCHAR(MAX)')
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
		    ,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM	@OtherIssuesInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@OtherIssuesInfoXML = NULL ))

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId
	FROM #FilterInfo d

	BEGIN -- Instant Settlement declaration
		
		CREATE TABLE #InstantSettlementBettypes (matchid INT, bettype SMALLINT, betid BIGINT)	
		DECLARE @SupportInstantSettleSABABettype TABLE (bettype SMALLINT);

		INSERT INTO @SupportInstantSettleSABABettype (bettype)
		VALUES (228) --SABA OU Time Machine
			 , (229) --SABA HDP Time Machine

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
	END	
	
	SELECT TOP (1) @AdvancedExtraInfo = AdvancedExtraInfo
	              ,@MatchID = MatchId --get main match
	FROM #FilterInfo

	--Parse json advanced mode filter
	INSERT INTO @bettype_detail (Bettype
		,FilterBetteam
		,FilterHDP
		,FilterTransdesc
		,FilterPlayerAndOdds 
		,FilterRuns
		,FilterX
		,FilterY
		,FilterXY
		,FilterHDP1
		,FilterHDP2
		,FilterBetOption
		,FilterOddsSpread
	)
	SELECT tmp.bettype
		, t.value AS betteam
		,CAST(CASE WHEN vhdp.value = '' THEN @ValueDefault
						ELSE vhdp.value END AS SMALLMONEY) AS ValueHdp
		,pl.value AS FilterTransdesc
		,plo.value FilterPlayerAndOdds 
		,'' AS FilterRuns
		,CASE WHEN CHARINDEX('_', x.value) = 0 THEN x.value ELSE '' END
		,CASE WHEN CHARINDEX('_', x.value) = 0 AND CHARINDEX('_',y.value) = 0 THEN y.value ELSE '' END
		,CASE WHEN CHARINDEX('_', x.value) = 1 AND x.value + y.value <> '______' THEN x.value + y.value ELSE '' END
		,CAST(CASE WHEN vhdp1.value = '' THEN @ValueDefault
						ELSE vhdp1.value END AS SMALLMONEY) AS ValueHdp1
		,CAST(CASE WHEN vhdp2.value = '' THEN @ValueDefault
						ELSE vhdp2.value END AS SMALLMONEY) AS ValueHdp2
		,bop.value AS FilterBetOption
		,os.value AS FilterOddsSpread
	FROM (
		SELECT Id AS bettype
			,ISNULL(Team, 'All') AS betteam
			,ISNULL(REPLACE(Hdp,'&',','), '') AS HDPs
			,ISNULL(Player, '') AS Players
			,ISNULL(REPLACE(FilterBetIdX,'&',','),'') AS betIdX
			,ISNULL(REPLACE(FilterBetIdY,'&',','),'') AS betIdY
			,ISNULL(PlayerAndOdds, '') AS PlayerAndOdds
			,ISNULL(NULLIF(Hdp1, 'All'), '') AS HDP1s
			,ISNULL(Hdp2, '') AS HDP2s
			,ISNULL(BetOption, '') AS BetOption
			,ISNULL(OddsSpread, '') AS OddsSpread
		FROM OPENJSON(@AdvancedExtraInfo) 
		WITH( Id SMALLINT, Team NVARCHAR(2000), Hdp VARCHAR(MAX), Player VARCHAR(1000)
			, FilterBetIdX VARCHAR(1000), FilterBetIdY VARCHAR(1000), PlayerAndOdds VARCHAR(2000)
			, Hdp1 VARCHAR(500), Hdp2 VARCHAR(500), BetOption NVARCHAR(500), OddsSpread VARCHAR(500))
	)tmp
	CROSS APPLY STRING_SPLIT(tmp.betteam, ',') t
	CROSS APPLY STRING_SPLIT(tmp.HDPs, ',') vhdp
	CROSS APPLY STRING_SPLIT(tmp.Players, ',') pl
	CROSS APPLY STRING_SPLIT(tmp.betIdX, ',') x
	CROSS APPLY STRING_SPLIT(tmp.betIdY, ',') y
	CROSS APPLY STRING_SPLIT(tmp.PlayerAndOdds, ',') plo
	CROSS APPLY STRING_SPLIT(tmp.HDP1s, '&') vhdp1
	CROSS APPLY STRING_SPLIT(tmp.HDP2s, '&') vhdp2
	CROSS APPLY STRING_SPLIT(tmp.BetOption, ',') bop
	CROSS APPLY STRING_SPLIT(tmp.OddsSpread, '&') os

	UPDATE d SET d.IsFancy = 1
	FROM @bettype_detail d
		INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = d.Bettype
	WHERE bt.typenamee LIKE '%Fancy'

	UPDATE d
	SET d.Sporttype = m.sporttype, MatchId_tmp = d.MatchId
	FROM #FilterInfo d
		INNER JOIN dbo.match m ON d.MatchId = m.MatchId

	--Cricket/Baseball - Get child match
	IF EXISTS (SELECT TOP 1 1 FROM #FilterInfo WHERE Sporttype IN (50,8))
	BEGIN
		INSERT INTO #FilterInfo (Id, MatchId, AdvancedExtraInfo, FilterFromTransTime, FilterToTransTime, SubIssueTypeId, MatchId_tmp)
		SELECT d.Id, d.MatchId, d.AdvancedExtraInfo, d.FilterFromTransTime, d.FilterToTransTime, d.SubIssueTypeId, m.MatchId AS MatchId_tmp
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
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,SubStatus 
			,Subbetteam  
			,Suboddsspread 
			,SubTransdesc  
			,modds 
			,SiteDBGroupID
			,SubIssueTypeId
			--For Advanced Mode
			,FilterBettype	
			,FilterBetteam 
			,FilterHdp1 
			,FilterHdp2 
			,FilterX
			,FilterY
			,FilterXY
			,FilterTransdesc 
			,FilterPlayerAndOdds 
			,FilterHdp
			,FilterBetOption
			,FilterOddsSpread
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
		,b.BonusID 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.status AS SubStatus 
		,b.betteam AS Subbetteam  
		,b.oddsspread AS Suboddsspread 
		,b.transdesc SubTransdesc  
		,b.modds 
		,b.SiteDBGroupID
		,d.SubIssueTypeId
		,b.bettype AS FilterBettype	
		,b.betteam AS FilterBetteam 
		,b.hdp1 AS FilterHdp1 
		,b.hdp2 AS FilterHdp2 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterX  
		,RIGHT(b.betid, 2) AS FilterY
		,CONVERT(NVARCHAR(50), b.betid) AS FilterXY 
		,b.transdesc AS FilterTransdesc 
		,b.oddsid AS FilterPlayerAndOdds 
		,b.hdp1 + b.hdp2 AS FilterHdp
		,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
		,b.oddsspread AS FilterOddsSpread
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
	WHERE b.betfrom <> 'P'  
		AND b.SiteDBGroupID = @SiteDBGroupID
		AND (b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime OR (d.FilterFromTransTime IS NULL AND d.FilterToTransTime IS NULL))
		AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
	
	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #FilterInfo d oN d.MatchId_tmp = bm.matchid
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
				,BonusID 
				,winlost        
				,actual_stake 
				,Status
				,SubStatus 
				,Subbetteam  
				,Suboddsspread 
				,SubTransdesc  
				,modds 
				,SiteDBGroupID
				,SubIssueTypeId
				--For Advanced Mode
				,FilterBettype	
				,FilterBetteam 
				,FilterHdp1 
				,FilterHdp2 
				,FilterX
				,FilterY
				,FilterXY
				,FilterTransdesc 
				,FilterPlayerAndOdds 
				,FilterHdp
				,FilterBetOption
				,FilterOddsSpread
		)
		SELECT DISTINCT d.MatchId
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
			,b.BonusID 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,sub.status AS SubStatus 
			,sub.betteam AS Subbetteam  
			,sub.oddsspread AS Suboddsspread 
			,sub.transdesc SubTransdesc  
			,b.modds
			,sub.SiteDBGroupID
			,d.SubIssueTypeId
			,sub.bettype AS FilterBettype	
			,sub.betteam AS FilterBetteam 
			,sub.hdp1 AS FilterHdp1 
			,sub.hdp2 AS FilterHdp2 
			,sub.betcheck AS FilterX 
			,RIGHT(sub.betcheck, 2) AS FilterY
			,sub.betcheck AS FilterXY
			,sub.transdesc AS FilterTransdesc 
			,sub.oddsid AS FilterPlayerAndOdds 
			,sub.hdp1 + sub.hdp2 AS FilterHdp
			,CAST(CAST(sub.hdp2 AS INT) AS VARCHAR(50)) + '-' + sub.betteam AS FilterBetOption
			,sub.oddsspread AS FilterOddsSpread
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
		WHERE 1 = CASE WHEN @ActionId <> 2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND sub.betfrom <> 'P'
				AND (sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
						OR (d.FilterFromTransTime IS NULL AND d.FilterToTransTime IS NULL))
			    AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID

	END  

	--Remove invalid data
	DELETE b
	FROM #TVSTicketBets b
		OUTER APPLY (
			SELECT TOP 1 Bettype
			FROM @bettype_detail f
			WHERE f.Bettype = b.FilterBettype
				AND (					
					CASE
						WHEN f.Bettype <> 376 THEN CASE WHEN f.FilterBetteam = 'All' OR b.FilterBetteam = f.FilterBetteam THEN 1 ELSE 0 END
						ELSE 
							CASE f.FilterBetteam
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
				AND (f.FilterHDP = @ValueDefault 
					OR 1 = CASE WHEN f.IsFancy = 0 AND b.FilterHdp = f.FilterHDP THEN 1
								WHEN f.IsFancy = 1 AND b.FilterBetteam = 'n' AND b.FilterHdp1 = f.FilterHDP THEN 1
								WHEN f.IsFancy = 1 AND b.FilterBetteam = 'y' AND b.FilterHdp2 = f.FilterHDP THEN 1
								ELSE 0 END
					)

				AND (f.FilterHDP1 = @ValueDefault OR b.FilterHdp1 = f.FilterHDP1)
				AND (f.FilterHDP2 = @ValueDefault OR b.FilterHdp2 = f.FilterHDP2)
				AND (f.FilterTransdesc = '' OR b.FilterTransdesc = f.FilterTransdesc)
				AND (f.FilterX = '' OR b.FilterX LIKE f.FilterX + '%')
				AND (f.FilterY = '' OR (f.FilterY LIKE '>%' AND b.FilterY > RIGHT(f.FilterY, 2)) OR (b.FilterY = f.FilterY))
				AND (f.FilterXY = '' OR b.FilterXY LIKE f.FilterXY + '%')
				AND (f.FilterPlayerAndOdds = '' 
						OR (b.FilterBetteam = LEFT(f.FilterPlayerAndOdds, 2) AND b.FilterPlayerAndOdds = SUBSTRING(FilterPlayerAndOdds,4,LEN(FilterPlayerAndOdds)))
					)
				AND 1 = CASE WHEN f.FilterRuns = '' THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 0 AND b.FilterHdp1 > FilterRuns THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 1 AND b.FilterBetteam = 'y' AND b.FilterHdp2 > f.FilterRuns THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 1 AND b.FilterBetteam = 'n' AND b.FilterHdp1 > f.FilterRuns THEN 1
					ELSE 0 END
				AND (f.FilterBetOption = '' OR b.FilterBetOption = f.FilterBetOption)
				AND (f.FilterOddsSpread = '' OR b.FilterOddsSpread = f.FilterOddsSpread)
		)t
	WHERE t.Bettype IS NULL

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
	
		--Update check instant settled
		UPDATE b
		SET  b.SettledType = CASE 
								WHEN ISNULL(m.eventstatus, '') <> @eventstatus_completed
									THEN CASE
											WHEN m.sporttype = 1 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype
												) THEN 1
											WHEN m.sporttype = 2 AND EXISTS (
												SELECT TOP 1 1
												FROM #InstantSettlementBettypes AS i
												WHERE b.Subbettype = i.bettype AND (b.betid = i.betid OR b.betid IS NULL)
												) THEN 1
											WHEN ib.bettype IS NOT NULL THEN 3
											ELSE 2
										END
								WHEN ib.bettype IS NOT NULL THEN 3
								ELSE 2
							END
		FROM #TVSTicketBets b 
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN @SupportInstantSettleSABABettype ib ON b.Subbettype = ib.bettype
		WHERE ISNULL(b.betdaqid,0) <> -2
			  AND b.SubStatusId IN (111, 112, 113)
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
	
	UPDATE v 
	SET v.IsHasSettledTicket = l.IsHasSettledTicket
	   ,v.IsHasInstantlySettledTicket = l.IsHasInstantlySettledTicket
	FROM @Validation v
	OUTER APPLY( 
			SELECT MAX(CASE WHEN SettledType = 2 THEN 1 ELSE 0 END) AS IsHasSettledTicket
				 , MAX(CASE WHEN SettledType IN (1,3) THEN 1 ELSE 0 END) AS IsHasInstantlySettledTicket
			FROM #TVSTicketBets
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l

	--Data Section
	INSERT INTO #logInfo (MatchId, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, SettleCount, CashOutCount)
	SELECT b.matchid AS MatchId
		,MIN(b.Subtransdate) AS VoidFromTime
		,MAX(b.Subtransdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
	FROM #TVSTicketBets b 
	GROUP BY b.matchid

	CREATE TABLE #CTE_RequestDetail (RequestId INT, MatchId INT, Sporttype SMALLINT, TransIds VARCHAR(MAX), IssueDetail NVARCHAR(MAX), VoidFromTime DATETIME, VoidToTime DATETIME, SingleCount INT, MainParlayCount INT, ActionId TINYINT, Id INT)
	CREATE TABLE #CTE_Ticket_Single (RequestId INT, MatchId INT, TransId BIGINT, Bettype SMALLINT, IsCancelCO BIT, RequestDetailId INT)
	CREATE TABLE #CTE_Ticket_SubParlay (RequestId INT, MatchId INT, TransId BIGINT, RequestDetailId INT)

	DECLARE @cnt_s INT , @cnt_p INT	

	INSERT INTO #CTE_RequestDetail (RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, ActionId, Id)
	SELECT rd.RequestId, MatchId, Sporttype, TransIds, IssueDetail, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, ActionId, Id
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
	WHERE rd.RequestId = @RequestId

	INSERT INTO #CTE_Ticket_Single (RequestId, MatchId, TransId, Bettype, IsCancelCO, RequestDetailId)
	SELECT RequestId, MatchId, TransId, Bettype, IsCancelCO, RequestDetailId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
	WHERE RequestId = @RequestId AND SiteDBGroupID = @SiteDBGroupID 
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId, RequestDetailId)
	SELECT RequestId, MatchId, TransId, RequestDetailId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId AND SiteDBGroupID = @SiteDBGroupID 
	SET @cnt_p = @@ROWCOUNT

	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT SubTransid
		FROM #TVSTicketBets
	END
	ELSE --Edit request
	BEGIN
		INSERT INTO @tmpLogInfoTickets (TransId)
		SELECT TransId FROM #CTE_Ticket_Single s
		UNION ALL 
		SELECT TransId FROM #CTE_Ticket_SubParlay p
			
	END

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
		    ,ISNULL(tb.parentid, m.Subbettype) AS 'GroupBettypeId' --Return for web filter bettype
			,CASE 
				WHEN m.IsMixParlay = 1 THEN 'Parlay'
				ELSE 'Single'
			END AS 'GroupName'
	FROM @tmpLogInfoTickets s
		INNER JOIN #TVSTicketBets m ON s.transid = m.Subtransid
		LEFT JOIN @tmpConsolidatedBettypes tb ON tb.typeid = m.Subbettype
	FOR JSON PATH))

	UPDATE v
	SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
	FROM @Validation v

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,IsHasSettledTicket
			,IsHasInstantlySettledTicket
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
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, SettleCount, CashOutCount)
		SELECT @RequestId
				,b.matchid
				,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
				,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
		FROM #CTE_Ticket_Single s WITH (NOLOCK)
			INNER JOIN #TVSTicketBets b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
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
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.SingleCount ELSE NULL END AS SingleCount
			,CASE WHEN @SiteDBGroupID = 0 THEN rd.MainParlayCount ELSE NULL END AS MainParlayCount
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
			,0 AS CancelCashOutCount
			,t.SettleCount
			,t.CashOutCount
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

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo

	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			, 1 AS IsInValidTotalTickets
			, IsExistedInOtherRequest
			, IsHasSettledTicket
			, IsHasInstantlySettledTicket
		FROM @Validation

		-- 2. TransId in request table
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
			
		-- 3. Loginfo table (No need -> return table)
		SELECT MatchId FROM #logInfo WHERE Matchid IS NULL

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		RETURN;
	END

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
		,IsHasSettledTicket
		,IsHasInstantlySettledTicket
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
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,0 AS CancelCashOutCount
		,SUM(MainParlayCount) AS MainParlayCount
		,SUM(SettleCount) AS SettleCount
		,SUM(CashOutCount) AS CashOutCount
		,v.LogInfoTicketsJson
	FROM #logInfo l
		INNER JOIN @Validation v ON l.MatchId = v.MatchId
	GROUP BY l.MatchId, v.LogInfoTicketsJson

	
	-- 4. List ticket unmark/mark & Transinfo table (if any)
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

