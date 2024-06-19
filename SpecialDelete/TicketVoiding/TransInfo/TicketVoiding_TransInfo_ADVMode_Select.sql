/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_ADVMode_Select] 
(
	@AdvancedModeInfo  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240522@Max
	Task: [TVS] Wrong Market Offered issue type [Redmine: #197051]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#197051]

	Param's explanation:	
		- @AdvancedModeInfo: <root><r MatchId="" FilterFromTransTime="" FilterToTransTime ="" FilterBy=""/></root>
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @AdvancedModeInfoXML	XML
		   ,@TransInfoJson		VARBINARY(MAX)
		   ,@SiteDBGroupID		SMALLINT
		   ,@MatchID			INT
		   ,@AdvancedExtraInfo	NVARCHAR(MAX)
		   ,@ValueDefault SMALLMONEY = 9999.00

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo(
		MatchId				INT
	)

	CREATE TABLE #TransInfo (
		matchid INT
		,transid BIGINT
		,Subtransid BIGINT
		,custid        INT        
		,transdate DATETIME
		,checktime DATETIME
		,hdp1 SMALLMONEY
		,hdp2 SMALLMONEY
		,livehomescore SMALLINT
		,liveawayscore SMALLINT
		,liveindicator BIT
		,betteam NVARCHAR(10)
		,creator INT
		,refno BIGINT
		,betid BIGINT
		,bettype SMALLINT
		,betdaqid BIGINT
		,betfrom NVARCHAR(4)
		,statusID TINYINT
		,WalletType TINYINT
		,RefCode BIGINT
		,Subcustid INT        
		,Sublivehomescore SMALLINT
		,Subliveawayscore SMALLINT
		,Subhdp1 SMALLMONEY
		,Subhdp2 SMALLMONEY
		,Subbetfrom NVARCHAR(4)
		,Subbettype SMALLINT
		,SubstatusID TINYINT
		,Subtransdate DATETIME
		,Subchecktime DATETIME
		,Subliveindicator BIT
		,recommend INT
		,mrecommend INT
		,srecommend INT
		,statuswinlost TINYINT
		,IsMixParlay BIT
		,odds MONEY
		,Subodds MONEY
		,oddsspread MONEY
		,oddstype TINYINT
		,betcheck NVARCHAR(50)
		,Subbetcheck NVARCHAR(50)
		,stake MONEY
		,CurrencyName NVARCHAR(50)
		,Transdesc NVARCHAR(1000)
		,ExtraInfo VARCHAR(1000)
		,BonusID INT
		,winlost        MONEY
		,actual_stake MONEY
		,Status NVARCHAR(10)
		,SubStatus NVARCHAR(10)
		,Subbetteam  NVARCHAR(10)
		,Suboddsspread MONEY
		,SubTransdesc  NVARCHAR(1000)
		,modds SMALLMONEY
		,SiteDBGroupID SMALLINT
		,CheckTimeCashOut  DATETIME
		,AcceptModeCashOut  TINYINT
		--For Advanced Mode
		,FilterBettype	SMALLINT
		,FilterBetteam NVARCHAR(10)
		,FilterHdp1 SMALLMONEY
		,FilterHdp2 SMALLMONEY
		,FilterWicketOver  NVARCHAR(50)
		,FilterQuarter  NVARCHAR(50)
		,FilterSet  NVARCHAR(50)
		,FilterGame  NVARCHAR(50)
		,FilterMap  NVARCHAR(50)
		,FilterRound  NVARCHAR(50)
		,FilterPoint  NVARCHAR(50)
		,FilterKill  NVARCHAR(50)
		,FilterTower   SMALLMONEY
		,FilterTurret  NVARCHAR(50)
		,FilterBall  NVARCHAR(50)
		,FilterDelivery NVARCHAR(50)
		,FilterTransdesc NVARCHAR(1000)
		,FilterPlayerAndOdds NVARCHAR(1000)	
	)

	DECLARE @bettype_detail AS TABLE (
		Bettype				SMALLINT
		,FilterBetteam      NVARCHAR(10)
		,FilterHDP		    SMALLMONEY
		,FilterSet          NVARCHAR(50)
        ,FilterRuns		    SMALLMONEY
		,FilterTransdesc	NVARCHAR(2000)
		,IsFancy			BIT DEFAULT (0)
		,FilterWicketOver  NVARCHAR(50)
		,FilterQuarter  NVARCHAR(50)
		,FilterGame  NVARCHAR(50)
		,FilterMap  NVARCHAR(50)
		,FilterRound  NVARCHAR(50)
		,FilterPoint  NVARCHAR(50)
		,FilterKill  NVARCHAR(50)
		,FilterTower   SMALLMONEY
		,FilterTurret  NVARCHAR(50)
		,FilterBall  NVARCHAR(50)
		,FilterDelivery NVARCHAR(50)
		,FilterPlayerAndOdds NVARCHAR(1000)	
	)

	SET @AdvancedModeInfoXML = CONVERT(XML, @AdvancedModeInfo)

	SELECT @MatchID = t.c.value('@MatchId','INT')	
		,@AdvancedExtraInfo = t.c.value('@AdvancedExtraInfo','VARCHAR(MAX)')
	FROM @AdvancedModeInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AdvancedModeInfoXML = NULL))

	INSERT INTO #FilterInfo (MatchId)
	SELECT MatchId
	FROM dbo.match m WITH(NOLOCK)
	WHERE 1 = CASE WHEN m.matchid = @MatchId THEN 1
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 AND m.ParentID = @MatchId THEN 1
			ELSE 0 END
	
	INSERT INTO @bettype_detail (Bettype
		,FilterBetteam
		,FilterHDP
		,FilterMap
		,FilterWicketOver
		,FilterTransdesc
		,FilterQuarter
		,FilterGame  
		,FilterRound 
		,FilterPoint
		,FilterKill 
		,FilterTower   
		,FilterTurret  
		,FilterBall  
		,FilterDelivery 
		,FilterPlayerAndOdds 
		,FilterSet
		,FilterRuns
	)
	SELECT tmp.bettype, tmp.betteam
		,CAST(CASE WHEN vhdp1.value = '' THEN @ValueDefault
						ELSE vhdp1.value END AS SMALLMONEY) AS ValueHdp1
		,map.value AS FilterMap
		,wk.value AS FilterWicketOver
		,pl.value AS FilterTransdesc
		,qt.value AS FilterQuarter
		,'' FilterGame  
		,'' FilterRound 
		,'' FilterPoint
		,'' FilterKill 
		,@ValueDefault FilterTower   
		,'' FilterTurret  
		,'' FilterBall  
		,'' FilterDelivery 
		,'' FilterPlayerAndOdds 
		,'' AS FilterSet
		,'' AS FilterRuns
	FROM (
		SELECT Id AS bettype
			,ISNULL(Team, 'All') AS betteam
			,ISNULL(Hdp, '') AS HDPs
			,ISNULL(Map,'') AS Maps
			,ISNULL(Player, '') AS Players
			,ISNULL(Wicket,'') AS Wickets
			,ISNULL([Quarter],'') AS Quarters
		FROM OPENJSON(@AdvancedExtraInfo) 
		WITH( Id SMALLINT, Team NVARCHAR(10), Hdp VARCHAR(100), Player VARCHAR(1000), Map VARCHAR(1000)
			, Wicket VARCHAR(100), [Quarter] VARCHAR(100))
	)tmp
	CROSS APPLY STRING_SPLIT(tmp.HDPs, '&') vhdp1
	CROSS APPLY STRING_SPLIT(tmp.Maps, ',') map
	CROSS APPLY STRING_SPLIT(tmp.Players, ',') pl
	CROSS APPLY STRING_SPLIT(tmp.Wickets, '&') wk
	CROSS APPLY STRING_SPLIT(tmp.Quarters, ',') qt

	--Search single tickets
	INSERT INTO #TransInfo(
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
			,CheckTimeCashOut
			,AcceptModeCashOut
			--For Advanced Mode
			,FilterBettype	
			,FilterBetteam 
			,FilterHdp1 
			,FilterHdp2 
			,FilterWicketOver 
			,FilterQuarter
			,FilterSet  
			,FilterGame  
			,FilterMap 
			,FilterRound  
			,FilterPoint 
			,FilterKill 
			,FilterTower  
			,FilterTurret  
			,FilterBall 
			,FilterDelivery 
			,FilterTransdesc 
			,FilterPlayerAndOdds 
		)
	SELECT b.matchid
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
		,c.CheckTime AS CheckTimeCashOut
		,c.AcceptMode AS AcceptModeCashOut
		,b.bettype AS FilterBettype	
		,b.betteam AS FilterBetteam 
		,b.hdp1 AS FilterHdp1 
		,b.hdp2 AS FilterHdp2 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterWicketOver 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterQuarter 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterSet  
		,RIGHT(b.betid, 2) AS FilterGame
		,CONVERT(NVARCHAR(50), b.betid) AS FilterMap 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterRound  
		,CONVERT(NVARCHAR(50), b.betid) AS FilterPoint 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterKill 
		,b.hdp1 AS FilterTower  
		,CONVERT(NVARCHAR(50), b.betid) AS FilterTurret  
		,CONVERT(NVARCHAR(50), b.betid) AS FilterBall 
		,CONVERT(NVARCHAR(50), b.betid) AS FilterDelivery 
		,b.transdesc AS FilterTransdesc 
		,b.oddsid AS FilterPlayerAndOdds 
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (805, 806, 9, 29)			
		AND b.bettype NOT BETWEEN 901 AND 920
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID

	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #FilterInfo d oN d.MatchId = bm.matchid
					WHERE bm.statusID NOT IN (101, 102, 103)
						AND bm.betfrom <> 'P'
					)
	BEGIN		
		INSERT INTO #TransInfo(
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
				--For Advanced Mode
				,FilterBettype	
				,FilterBetteam 
				,FilterHdp1 
				,FilterHdp2 
				,FilterWicketOver 
				,FilterQuarter
				,FilterSet  
				,FilterGame  
				,FilterMap 
				,FilterRound  
				,FilterPoint 
				,FilterKill 
				,FilterTower  
				,FilterTurret  
				,FilterBall 
				,FilterDelivery 
				,FilterTransdesc 
				,FilterPlayerAndOdds 
			)
		SELECT sub.matchid
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
			,sub.bettype AS FilterBettype	
			,sub.betteam AS FilterBetteam 
			,sub.hdp1 AS FilterHdp1 
			,sub.hdp2 AS FilterHdp2 
			,sub.betcheck AS FilterWicketOver 
			,sub.betcheck AS FilterQuarter
			,sub.betcheck AS FilterSet  
			,RIGHT(sub.betcheck, 2) AS FilterGame
			,sub.betcheck AS FilterMap 
			,sub.betcheck AS FilterRound  
			,sub.betcheck AS FilterPoint 
			,sub.betcheck AS FilterKill 
			,sub.hdp1 AS FilterTower  
			,sub.betcheck AS FilterTurret  
			,sub.betcheck AS FilterBall 
			,sub.betcheck AS FilterDelivery 
			,sub.transdesc AS FilterTransdesc 
			,sub.oddsid AS FilterPlayerAndOdds 
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
		WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND sub.betfrom <> 'P'
			AND b.matchid = 29
			AND b.bettype = 29
			AND sub.SiteDBGroupID = @SiteDBGroupID
	END 

	--Remove invalid data
	DELETE b
	FROM #TransInfo b
		OUTER APPLY (
			SELECT TOP 1 Bettype
			FROM @bettype_detail f
			WHERE f.Bettype = b.FilterBettype
				AND (f.FilterBetteam = 'All' OR b.FilterBetteam = f.FilterBetteam)
				AND (f.FilterHDP = @ValueDefault OR b.FilterHdp1 = f.FilterHDP)
				AND (f.FilterTower = @ValueDefault OR b.FilterHdp1 = f.FilterTower)
				AND (f.FilterSet = '' OR b.FilterSet LIKE f.FilterSet + '%')
				AND (f.FilterDelivery = '' OR b.FilterDelivery = f.FilterDelivery)
				AND (f.FilterWicketOver = '' OR b.FilterWicketOver = f.FilterWicketOver)
				AND (f.FilterQuarter = '' OR b.FilterQuarter = f.FilterQuarter)
				AND (f.FilterKill = '' OR b.FilterKill = f.FilterKill)
				AND (f.FilterMap = '' OR b.FilterMap = f.FilterMap)
				AND (f.FilterPoint = '' OR b.FilterPoint = f.FilterPoint)
				AND (f.FilterRound = '' OR b.FilterRound = f.FilterRound)
				AND (f.FilterTurret = '' OR b.FilterTurret = f.FilterTurret)
				AND (f.FilterTransdesc = '' OR b.FilterTransdesc = f.FilterTransdesc)
				AND 1 = CASE WHEN f.FilterRuns = '' THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 0 AND b.FilterHdp1 > FilterRuns THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 1 AND b.FilterBetteam = 'y' AND b.FilterHdp2 > f.FilterRuns THEN 1
							WHEN f.FilterRuns <> '' AND f.IsFancy = 1 AND b.FilterBetteam = 'n' AND b.FilterHdp1 > f.FilterRuns THEN 1
					ELSE 0 END
		)t
	WHERE t.Bettype IS NULL
			
	--RETURN DATA
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
		,Subtransid AS 's_t'
		,custid    AS  'c'           
		,transdate AS 'tdate'
		,checktime AS 'checkt'
		,hdp1 AS 'hdp1'
		,hdp2 AS 'hdp2'
		,livehomescore AS 'lh'
		,liveawayscore AS 'la'
		,liveindicator AS 'li'
		,betteam AS 'bteam'
		,creator AS 'cr'
		,refno AS 'ref'
		,betid AS 'bid'
		,bettype AS 'btype'
		,betdaqid AS 'bdaq'
		,betfrom AS 'bfr'
		,statusID AS 'sid'
		,WalletType AS 'wt'
		,RefCode AS 'refc'
		,Subcustid    AS     's_c' 
		,Sublivehomescore AS 's_lh'
		,Subliveawayscore AS 's_la'
		,Subhdp1 AS 's_hdp1'
		,Subhdp2 AS 's_hdp2'
		,Subbetfrom AS 's_bfr'
		,Subbettype AS 's_btype'
		,SubstatusID AS 's_sid'
		,Subtransdate AS 's_tdate'
		,Subchecktime AS 's_checkt'
		,Subliveindicator AS 's_li'
		,recommend AS 're'
		,mrecommend AS 'mre'
		,srecommend AS 'sre'
		,statuswinlost AS 'statuswl'
		,IsMixParlay AS 'isP'
		,odds AS 'o'
		,Subodds AS 's_o'
		,oddsspread AS 'os'
		,oddstype AS 'ost'
		,betcheck AS 'bcheck'
		,Subbetcheck AS 's_bcheck'
		,stake AS 'stake'
		,CurrencyName AS 'curr'
		,Transdesc AS 'tdes'
		,ExtraInfo AS 'ex'
		,BonusID AS 'bo'
		,winlost    AS 'w'    
		,actual_stake AS 'acstake'
		,Status AS 's' 
		,SubStatus AS 's_s'
		,Subbetteam  AS 's_bteam'
		,Suboddsspread AS 's_os'
		,SubTransdesc  AS 's_tdes'
		,modds AS 'm'
		,SiteDBGroupID AS 'sitedb'
		,CheckTimeCashOut AS 'checktCO' 
		,AcceptModeCashOut  AS 'amCO' 
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #FilterInfo
END

GO

