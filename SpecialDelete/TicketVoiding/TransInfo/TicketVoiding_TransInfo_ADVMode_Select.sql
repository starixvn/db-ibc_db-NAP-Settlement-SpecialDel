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
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20240916@Max: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]

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
		   ,@FilterFromTransTime DATETIME = NULL
		   ,@FilterToTransTime DATETIME = NULL

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo(
		MatchId				INT
		,FilterFromTransTime DATETIME
		,FilterToTransTime DATETIME
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
		,FilterHdp	SMALLMONEY --hdp1 + hdp2
		,FilterX  NVARCHAR(50)
		,FilterY  NVARCHAR(50)
		,FilterXY  NVARCHAR(50)
		,FilterTransdesc NVARCHAR(1000)
		,FilterPlayerAndOdds NVARCHAR(1000)	
		,FilterBetOption		NVARCHAR(250)
	)

	DECLARE @bettype_detail AS TABLE (
		Bettype				SMALLINT
		,FilterBetteam      NVARCHAR(10)
		,FilterHDP		    SMALLMONEY
		,FilterHDP1		    SMALLMONEY
		,FilterHDP2		    SMALLMONEY
        ,FilterRuns		    SMALLMONEY
		,FilterTransdesc	NVARCHAR(2000)
		,IsFancy			BIT DEFAULT (0)
		,FilterPlayerAndOdds NVARCHAR(2000)	
		,FilterX  NVARCHAR(50)
		,FilterY  NVARCHAR(50)
		,FilterXY  NVARCHAR(50)
		,FilterBetOption	NVARCHAR(250)
	)

	SET @AdvancedModeInfoXML = CONVERT(XML, @AdvancedModeInfo)

	SELECT @MatchID = t.c.value('@MatchId','INT')	
		,@AdvancedExtraInfo = t.c.value('@AdvancedExtraInfo','VARCHAR(MAX)')
		,@FilterFromTransTime = t.c.value('@FilterFromTransTime','DATETIME')
		,@FilterToTransTime = t.c.value('@FilterToTransTime','DATETIME')
	FROM @AdvancedModeInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AdvancedModeInfoXML = NULL))

	INSERT INTO #FilterInfo (MatchId, FilterFromTransTime, FilterToTransTime)
	SELECT MatchId, @FilterFromTransTime, @FilterToTransTime
	FROM dbo.match m WITH(NOLOCK)
	WHERE 1 = CASE WHEN m.matchid = @MatchId THEN 1
				WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 AND m.ParentID = @MatchId THEN 1
			ELSE 0 END
	
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
	)
	SELECT tmp.bettype
		, tmp.betteam
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
	FROM (
		SELECT Id AS bettype
			,ISNULL(Team, 'All') AS betteam
			,ISNULL(Hdp, '') AS HDPs
			,ISNULL(Player, '') AS Players
			,ISNULL(REPLACE(FilterBetIdX,'&',','),'') AS betIdX
			,ISNULL(REPLACE(FilterBetIdY,'&',','),'') AS betIdY
			,ISNULL(PlayerAndOdds, '') AS PlayerAndOdds
			,ISNULL(Hdp1, '') AS HDP1s
			,ISNULL(Hdp2, '') AS HDP2s
			,ISNULL(BetOption, '') AS BetOption
		FROM OPENJSON(@AdvancedExtraInfo) 
		WITH( Id SMALLINT, Team NVARCHAR(10), Hdp VARCHAR(100), Player VARCHAR(1000)
			, FilterBetIdX VARCHAR(1000), FilterBetIdY VARCHAR(1000), PlayerAndOdds VARCHAR(2000)
			, Hdp1 VARCHAR(100), Hdp2 VARCHAR(100), BetOption NVARCHAR(250))
	)tmp
	CROSS APPLY STRING_SPLIT(tmp.HDPs, '&') vhdp
	CROSS APPLY STRING_SPLIT(tmp.Players, ',') pl
	CROSS APPLY STRING_SPLIT(tmp.betIdX, ',') x
	CROSS APPLY STRING_SPLIT(tmp.betIdY, ',') y
	CROSS APPLY STRING_SPLIT(tmp.PlayerAndOdds, ',') plo
	CROSS APPLY STRING_SPLIT(tmp.HDP1s, '&') vhdp1
	CROSS APPLY STRING_SPLIT(tmp.HDP2s, '&') vhdp2
	CROSS APPLY STRING_SPLIT(tmp.BetOption, ',') bop

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
			,FilterX
			,FilterY
			,FilterXY
			,FilterTransdesc 
			,FilterPlayerAndOdds 
			,FilterHdp
			,FilterBetOption
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
		,CONVERT(NVARCHAR(50), b.betid) AS FilterX  
		,RIGHT(b.betid, 2) AS FilterY
		,CONVERT(NVARCHAR(50), b.betid) AS FilterXY 
		,b.transdesc AS FilterTransdesc 
		,b.oddsid AS FilterPlayerAndOdds 
		,b.hdp1 + b.hdp2 AS FilterHdp
		,CAST(CAST(b.hdp2 AS INT) AS VARCHAR(50)) + '-' + b.betteam AS FilterBetOption
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (805, 806, 9, 29)			
		AND b.bettype NOT BETWEEN 901 AND 920
		AND b.betfrom <> 'P'
		AND 1 = CASE WHEN b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
				ELSE CASE WHEN b.betdaqid = -2 AND c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
					ELSE 0 END
			END
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
				,FilterX
				,FilterY
				,FilterXY
				,FilterTransdesc 
				,FilterPlayerAndOdds 
				,FilterHdp
				,FilterBetOption
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
			,sub.betcheck AS FilterX 
			,RIGHT(sub.betcheck, 2) AS FilterY
			,sub.betcheck AS FilterXY
			,sub.transdesc AS FilterTransdesc 
			,sub.oddsid AS FilterPlayerAndOdds 
			,sub.hdp1 + sub.hdp2 AS FilterHdp
			,CAST(CAST(sub.hdp2 AS INT) AS VARCHAR(50)) + '-' + sub.betteam AS FilterBetOption
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
		WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND sub.betfrom <> 'P'
			AND b.matchid = 29
			AND b.bettype = 29
			AND sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
			AND sub.SiteDBGroupID = @SiteDBGroupID
	END 

	--Remove invalid data
	DELETE b
	FROM #TransInfo b
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
				AND (f.FilterHDP = @ValueDefault OR b.FilterHdp = f.FilterHDP)
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
		,FilterPlayerAndOdds AS 'f_oid'
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #FilterInfo
END

GO

