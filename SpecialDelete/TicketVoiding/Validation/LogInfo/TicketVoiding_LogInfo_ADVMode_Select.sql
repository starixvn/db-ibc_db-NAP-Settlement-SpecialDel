/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_ADVMode_Select]
(	
	 @RequestId			  INT = 0
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@AdvancedModeInfo	  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20240522@Max
	Task: [TVS] Wrong Market Offered issue type [Redmine: #197051]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20240522@Max: Create new SP [Redmine:#197051]
		- 20240727@Max: Modify betid return [Redmine:#197051]
		- 20240727@Max: Change validation for transdesc [Redmine: #197051]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20240823@July: WMKO/TE - Add Details of bet list for issue types [Redmine: #208628]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]
		- 20241216@Lani: Add 'GroupName' column returned [Redmine: #213960]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:	
		- @AdvancedModeInfo: <root><r MatchId="" FilterFromTransTime="" FilterToTransTime =""/></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			INT = 0
			,@MainParlayCount		INT = 0
			,@UnmarkTransIds		VARCHAR(MAX) =''
			,@MarkTransIds		    VARCHAR(MAX) =''
			,@OldActionId			TINYINT
			,@LogInfoTicketsJson	VARBINARY(MAX) = NULL
		    ,@SiteDBGroupID			SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE	@AdvancedModeInfoXML	XML = NULL
		   ,@MatchId				INT	= 0
		   ,@TransInfoJson		    VARBINARY(MAX) = NULL
		   ,@AdvancedExtraInfo	    NVARCHAR(MAX)
		   ,@ValueDefault           SMALLMONEY = 9999.00

	CREATE TABLE #logInfo (
		 Id						INT --Diffrence rangetime
		,MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,CashOutCount			INT
		,SettleCount            INT
		,MainParlayCount		INT
		,CancelCashOutCount		INT
	)

	CREATE TABLE #TransidInRequest (Id INT, TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, CreatedBy INT)
	CREATE TABLE #logInfoVoidPage (Id INT, RequestId INT, MatchId INT, SettleCount INT, CancelCashOutCount INT)

	CREATE TABLE #FilterInfo (
		 Id						INT --Diffrence rangetime
		,MatchId				INT
		,AdvancedExtraInfo		VARCHAR(MAX)
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
		,Sporttype				SMALLINT
		,MatchId_tmp			INT
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
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
	  ,CheckTimeCashOut DATETIME
	  ,AcceptModeCashOut  TINYINT
	  ,OddsId INT
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
	  ,GroupDisplay		  INT
	  ,GroupBettype		  SMALLINT
	  ,GroupTransdesc     NVARCHAR(1000)
	  ,GroupBetteam		  NVARCHAR(10)
	  ,Groupbetid		  NVARCHAR(50)
	  ,GroupOddsId		  INT
	  ,Id				  INT
	  ,SubIssueTypeId	 SMALLINT
	  ,IsCancelCashOut	 BIT
	  ,No_ID INT IDENTITY (1,1) PRIMARY KEY
	)

	DECLARE @Validation AS TABLE (
			 Id						 INT
			,MatchId                 INT	
			,IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,IsExistsSecondAccept	 BIT DEFAULT(0) 	
			,LogInfoTicketsJson		 NVARCHAR(MAX)
			,IsFinish				 BIT
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpLogInfoTickets TABLE (Id INT, TransId BIGINT, IsCancelCashOut BIT)

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

	SET @AdvancedModeInfoXML = CONVERT(XML, @AdvancedModeInfo)
	INSERT INTO #FilterInfo (Id, MatchId, AdvancedExtraInfo, FilterFromTransTime, FilterToTransTime, SubIssueTypeId)
	SELECT  CASE WHEN t.c.value('@Id','INT') IS NULL THEN 1 ELSE t.c.value('@Id','INT') END AS Id --Default = 1 with case old request
	        ,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@AdvancedExtraInfo','VARCHAR(MAX)')
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
		    ,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM @AdvancedModeInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AdvancedModeInfoXML = NULL))

	--Init Validation
	INSERT INTO @Validation (Id, MatchId)
	SELECT Id, MatchId
	FROM #FilterInfo

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
		INSERT INTO #FilterInfo (Id, MatchId, AdvancedExtraInfo, FilterFromTransTime, FilterToTransTime, SubIssueTypeId, Sporttype, MatchId_tmp)
		SELECT d.Id, m.MatchId, d.AdvancedExtraInfo, d.FilterFromTransTime, d.FilterToTransTime, d.SubIssueTypeId, m.sporttype, d.MatchId
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
			,FilterOddsSpread
			,GroupDisplay
			,GroupBettype
			,GroupBetteam
			,GroupTransdesc
			,Groupbetid
			,GroupOddsId
			,Id
			,SubIssueTypeId
			,IsCancelCashOut
		)
	SELECT DISTINCT d.MatchId_tmp AS matchid
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
		,b.oddsspread AS FilterOddsSpread
		,ISNULL(tb.parentid, b.bettype)
		,b.bettype
		,b.betteam
		,b.Transdesc
		,CONVERT(NVARCHAR(50), b.betid)
		,b.OddsId
		,d.Id
		,d.SubIssueTypeId
		,CASE WHEN b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 0
				  ELSE CASE WHEN b.betdaqid = -2 AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
							ELSE 0 END
				  END AS IsCancelCashOut
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
		LEFT JOIN @tmpConsolidatedBettypes tb ON  tb.typeid = b.bettype
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.betfrom <> 'P'
		AND 1 = CASE 
					WHEN d.FilterFromTransTime IS NULL AND d.FilterToTransTime IS NULL THEN 1
					WHEN b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
				ELSE CASE 
					WHEN b.betdaqid = -2 AND c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
					ELSE 0 END
			END
		AND b.SiteDBGroupID = @SiteDBGroupID

	-- Fix case: WMO 2 range time: Original range time 1, Canel CO: range time 2
	DECLARE @tmpRemoveDuplCancelCO TABLE (TransId BIGINT)
	INSERT INTO @tmpRemoveDuplCancelCO (TransId)
	SELECT TransId
	FROM #TVSTicketBets 
	GROUP BY transid
	HAVING COUNT(TransId) >=2

	IF EXISTS (SELECT TOP 1 1 FROM @tmpRemoveDuplCancelCO)
	BEGIN
		DELETE t
		FROM #TVSTicketBets t
		WHERE t.IsCancelCashOut = 1 
		 AND t.transid IN ( SELECT transid FROM @tmpRemoveDuplCancelCO)
	END

	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN #FilterInfo d oN d.MatchId = bm.matchid
					WHERE bm.statusID NOT IN (101, 102, 103)
						AND bm.betfrom <> 'P'
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
				,GroupDisplay
			    ,GroupBettype
			    ,GroupBetteam
			    ,GroupTransdesc
			    ,Groupbetid
			    ,GroupOddsId
			    ,Id
			    ,SubIssueTypeId
			    ,IsCancelCashOut
			)
		SELECT DISTINCT d.MatchId_tmp AS matchid
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
			,sub.oddsspread AS FilterOddsSpread
			,ISNULL(tb.parentid, sub.bettype)
			,sub.bettype
			,sub.betteam
			,sub.Transdesc
			,sub.betcheck
			,b.OddsId
			,d.Id
			,d.SubIssueTypeId
			,0 AS IsCancelCashOut
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			LEFT JOIN @tmpConsolidatedBettypes tb ON tb.typeid = sub.bettype
		WHERE  1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
			AND sub.betfrom <> 'P'
			AND b.matchid = 29 AND b.bettype = 29
			AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID
			AND (sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
					OR (d.FilterFromTransTime IS NULL AND d.FilterToTransTime IS NULL)
				)
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
	END


	/*Get Transid in Request of range Transid*/
	DECLARE @TransInfoJson_Request		VARBINARY(MAX)
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	SET @MaxRow = (SELECT MAX(No_ID) FROM #TVSTicketBets)
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
						,Id AS 'id'
				FROM #TVSTicketBets R
				WHERE No_ID BETWEEN @StartRow AND @StopRow
					FOR JSON PATH))

				INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId, CreatedBy, Id)
				EXEC DBCTG.bodb02.dbo.TicketVoiding_CheckExistingRequest
					@TransInfoJson = @TransInfoJson_Request
					,@RequestId = @RequestId
					,@Mode = 1
					,@IssueTypeId = @IssueTypeId

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END
	
		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
				INNER JOIN #TransidInRequest t ON t.MatchId = v.MatchId
			WHERE v.Id = t.Id
		END
		
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
		
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, VoidFromTime, VoidToTime, SingleCount, MainParlayCount, SettleCount, Id)
	SELECT @MatchId AS MatchId
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount
		,b.Id
	FROM #TVSTicketBets b
	WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.Id
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.Id

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsCancelCashOut = 1)
	BEGIN
		UPDATE li
		SET CancelCashOutCount = b.CancelCashOutCount
		   ,VoidFromTime = CASE WHEN b.MIN_CheckTimeCashOut < li.VoidFromTime THEN b.MIN_CheckTimeCashOut ELSE li.VoidFromTime END
		   ,VoidToTime = CASE WHEN b.MAX_CheckTimeCashOut >  li.VoidToTime THEN b.MAX_CheckTimeCashOut ELSE li.VoidToTime END
		FROM #logInfo li
			CROSS APPLY(
				SELECT COUNT(b.transid) AS CancelCashOutCount
					  ,MIN(CheckTimeCashOut) AS MIN_CheckTimeCashOut
					  ,MAX(CheckTimeCashOut) AS MAX_CheckTimeCashOut
				FROM #TVSTicketBets b
				WHERE li.MatchId = b.matchid AND b.IsCancelCashOut = 1 AND li.Id = b.Id
				GROUP BY b.matchid, b.Id
			)b
	END

	--Not display Score in message template when voiding non-live tickets only [193108]
	IF NOT EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE liveindicator = 1)
	BEGIN
		UPDATE l SET l.LiveScores = ''
		FROM #logInfo l
	END

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
	WHERE RequestId = @RequestId
	SET @cnt_s = @@ROWCOUNT

	INSERT INTO #CTE_Ticket_SubParlay (RequestId, MatchId, TransId, RequestDetailId)
	SELECT RequestId, MatchId, TransId, RequestDetailId
	FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
	WHERE RequestId = @RequestId
	SET @cnt_p = @@ROWCOUNT

	IF @IsShowLogOnly = 0
	BEGIN
		INSERT INTO @tmpLogInfoTickets (Id, TransId, IsCancelCashOut)
		SELECT Id, SubTransid, IsCancelCashOut
		FROM #TVSTicketBets
	END
	ELSE --Edit request
	BEGIN
		DECLARE @tmpRowNumber table (Id INT, RequestDetailId INT ) --Suport filter time range Id
		INSERT INTO @tmpRowNumber (Id, RequestDetailId)
		SELECT ROW_NUMBER() OVER(ORDER BY Id ASC) AS Id, Id AS RequestDetailId
		FROM  #CTE_RequestDetail WITH (NOLOCK) 
		
		INSERT INTO @tmpLogInfoTickets (Id, TransId, IsCancelCashOut)
		SELECT r.Id, TransId, IsCancelCO
		FROM #CTE_Ticket_Single s WITH (NOLOCK) 
			INNER JOIN @tmpRowNumber r ON s.RequestDetailId = r.RequestDetailId
		UNION ALL
		SELECT r.Id, TransId, 0
		FROM #CTE_Ticket_SubParlay s WITH (NOLOCK) 
			INNER JOIN @tmpRowNumber r ON s.RequestDetailId = r.RequestDetailId
			
	END
	
	DECLARE @Id INT
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) v
		SET v.IsFinish = 1, @Id = v.Id
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
				,ISNULL(tb.parentid, m.Subbettype) AS 'GroupBettypeId' --Return for web filter bettype
				,s.IsCancelCashOut AS 'IsCancelCashOut'
			,CASE 
				WHEN m.IsMixParlay = 1 THEN 'Parlay'
				ELSE 'Single'
			END AS 'GroupName'
		FROM @tmpLogInfoTickets s
			INNER JOIN #TVSTicketBets m ON s.transid = m.Subtransid
			LEFT JOIN @tmpConsolidatedBettypes tb ON tb.typeid = m.Subbettype
		WHERE s.Id = @Id
		FOR JSON PATH))

		UPDATE v
		SET v.LogInfoTicketsJson = CONVERT(VARCHAR(MAX), @LogInfoTicketsJson, 1)
		FROM @Validation v
		WHERE Id = @Id
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT Id
			 , MatchId
			 , IsInValidTotalTickets
			 , IsExistedInOtherRequest
			 , IsExistsSecondAccept
		FROM @Validation

		-- 2. TransId in request table
		SELECT Id, RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (Id, RequestId, MatchId, CancelCashOutCount, SettleCount)
		SELECT b.Id
			  ,@RequestId
			  ,s.matchid
			  ,COUNT(CASE WHEN s.IsCancelCO = 1 THEN s.transid ELSE NULL END) AS CancelCashOutCount
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
		FROM #CTE_Ticket_Single s WITH (NOLOCK)
			LEFT JOIN #TVSTicketBets b ON b.transid = s.transid AND b.IsMixParlay = 0
		WHERE b.StatusId IN (111, 112, 113)
		GROUP BY b.Id, s.matchid 

		-- 3. Loginfo Table
		SELECT rd.Id
		      ,CASE WHEN @SiteDBGroupID = 0 THEN rd.MatchId ELSE NULL END AS MatchId
			  ,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
			  ,CASE WHEN @SiteDBGroupID = 0 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
			  ,CASE WHEN @SiteDBGroupID = 0 THEN rd.SingleCount ELSE NULL END AS SingleCount
			  ,CASE WHEN @SiteDBGroupID = 0 THEN rd.MainParlayCount ELSE NULL END AS MainParlayCount
			  ,t.CancelCashOutCount
			  ,t.SettleCount
			  ,v.LogInfoTicketsJson
		FROM (
				SELECT ROW_NUMBER() OVER(ORDER BY Id ASC) AS Id, RequestId
					  ,MatchId, VoidFromTime, VoidToTime, SingleCount, MainParlayCount
				FROM #CTE_RequestDetail  WITH (NOLOCK)
			)rd
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId AND rd.Id = t.Id
			INNER JOIN @Validation v ON rd.MatchId = v.MatchId AND v.Id = rd.Id

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		-- 5. Count detail group by bettype
		SELECT DENSE_RANK() OVER (ORDER BY rd.Id ASC) AS Id
		    ,bt.bettypeid
			,bt.betid
			,bt.TicketsCount
			,t.typenamee AS originalBetTypeName
			,bt.PlayerName
		FROM #CTE_RequestDetail rd WITH (NOLOCK)
			CROSS APPLY (
				SELECT bettypeid AS bettypeid, betid AS betid , TicketsCount AS TicketsCount, PlayerName AS PlayerName
				FROM OPENJSON(NULLIF(rd.TransIds,'')) 
				WITH( BetTypeId SMALLINT, BetId NVARCHAR(50),  TicketsCount INT, PlayerName NVARCHAR(MAX))
			)bt
			INNER JOIN dbo.bettype t WITH (NOLOCK) ON t.typeid = bt.bettypeid
		WHERE rd.RequestId = @RequestId
		ORDER BY DENSE_RANK() OVER (ORDER BY rd.Id ASC), t.typenamee

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo

	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT Id
			 , MatchId
			 , 1 AS IsInValidTotalTickets
			 , IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT r.Id, RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId AND Id = r.Id)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
				,c.username AS CreatedBy
			FROM #TransidInRequest r
				INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
			GROUP BY r.Id, r.RequestId, r.MatchId, c.username
		END
		ELSE
		BEGIN
			SELECT Id, RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest 
		END
			
		-- 3. Loginfo table (No need -> return table)
		SELECT MatchId FROM #logInfo WHERE Matchid IS NULL

		-- 4. Unmark/Transinfo table (No need -> return table)
		SELECT TransId AS UnmarkTransIds, @TransInfoJson AS TransInfoJson FROM @tmpUnmarkTransId

		RETURN;
	END

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
	OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
			WHERE MatchId = v.MatchId AND v.Id = Id
			GROUP BY MatchId, Id
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
	
	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(mt.TransId AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId mt
											WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction m WITH (NOLOCK) WHERE mt.TransId = m.TransId)
											FOR XML PATH('')), 1,1,'')
											,'')

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(mt.TransId AS VARCHAR(50)) 
										FROM @tmpMarkTransId mt
										WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction m WITH (NOLOCK) WHERE mt.TransId = m.TransId)
										FOR XML PATH('')), 1,1,'')
										,'')


	/*****************Return table **************************/
	-- 1. Validate table
	SELECT Id
		, MatchId
		, IsInValidTotalTickets
		, IsExistedInOtherRequest
		, IsExistsSecondAccept
	FROM @Validation

	-- 2. TransId exists in other request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT r.Id, RequestId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId AND Id = r.Id)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,MatchId
			,c.username AS CreatedBy
		FROM #TransidInRequest r
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = r.CreatedBy
		GROUP BY r.Id, r.RequestId, r.MatchId, c.username
	END
	ELSE
	BEGIN
		SELECT Id, RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
	SELECT l.Id
	    ,l.MatchId 
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(SingleCount) AS SingleCount
		,SUM(ISNULL(CancelCashOutCount,0)) AS CancelCashOutCount
		,SUM(MainParlayCount) AS MainParlayCount
		,SUM(SettleCount) AS SettleCount
		,v.LogInfoTicketsJson
	FROM #logInfo l
		INNER JOIN @Validation v ON l.MatchId = v.MatchId AND l.Id = v.Id
	GROUP BY l.Id, l.MatchId, v.LogInfoTicketsJson

	-- 4. List ticket unmark/mark & Transinfo table (if any)
	SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,t.custid AS  'c'           
		,t.bettype AS 'btype'
		,t.betid AS 'bid'
		,t.IsMixParlay AS 'isP'
		,t.SiteDBGroupID AS 'sitedb'
		,t.IsCancelCashOut AS 'isCCO'
		,li.VoidFromTime AS 'vft'
		,li.VoidToTime AS 'vtt'
		,@MatchId AS 'm_mid'
	FROM #TVSTicketBets t
		CROSS APPLY (
				SELECT MIN(VoidFromTime) AS VoidFromTime
					,MAX(VoidToTime) AS VoidToTime
				FROM #logInfo li 
				WHERE li.MatchId = t.matchid AND t.Id = li.Id
				GROUP BY li.matchid
			)li
	FOR JSON PATH))
		
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	-- 5. Count detail group by bettype
	SELECT bt.Id
	    ,bt.bettypeid
		,bt.originalBetTypeName
		,bt.bettypecount AS TicketsCount
		,bt.betid
		,bt.PlayerName
		,bt.PlayerAndOdds 
	FROM (
		SELECT b.Id
			,b.GroupDisplay AS bettypeid
			,CASE WHEN ISNULL(b.Groupbetid,'') = '' OR b.GroupDisplay = 501 THEN '0' ELSE b.Groupbetid END AS betid
			,COUNT(b.transid) AS bettypecount
			,bt.typenamee AS originalBetTypeName
			,NULL AS PlayerName
			,NULL AS PlayerAndOdds
		FROM #TVSTicketBets b
			INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = b.GroupDisplay 
		WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
			AND b.GroupBettype NOT IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc())
		GROUP BY b.Id, b.GroupDisplay, bt.typenamee, CASE WHEN ISNULL(b.Groupbetid,'') = '' OR b.GroupDisplay = 501 THEN '0' ELSE b.Groupbetid END 
	
		UNION ALL
		SELECT b.Id
			,b.GroupDisplay AS bettypeid
			,'0' AS betid
			,COUNT(b.transid) AS bettypecount
			,bt.typenamee AS originalBetTypeName
			,NULL AS PlayerName
			,b.GroupBetteam +'$'+ CONVERT(NVARCHAR(1000),b.GroupOddsId) AS PlayerAndOdds
		FROM #TVSTicketBets b
			INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = b.GroupDisplay 
		WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
			AND b.GroupBettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc() WHERE TypeId = 1)
		GROUP BY b.Id, b.GroupDisplay, bt.typenamee, b.GroupBetteam +'$'+ CONVERT(NVARCHAR(1000),b.GroupOddsId)

		UNION ALL
		SELECT t1.Id
		    ,t1.bettypeid
			,'0' AS betid
			,t1.bettypecount
			,t1.originalBetTypeName
			,t.teamname AS PlayerName
			,NULL AS PlayerAndOdds
		FROM
		(
			SELECT b.Id
			    ,b.GroupDisplay AS bettypeid
				,COUNT(b.transid) AS bettypecount
				,bt.typenamee AS originalBetTypeName
				,CONVERT(BIGINT, b.GroupTransdesc) AS PlayerId
			FROM #TVSTicketBets b
				INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = b.GroupDisplay 
			WHERE b.IsCancelCashOut <> 1 -- Not count ticket cancel CO
				AND b.GroupBettype IN (SELECT bettype FROM f_TVS_BettypesUsingTransdesc() WHERE TypeId = 0)
			GROUP BY b.Id, b.GroupDisplay, bt.typenamee,CONVERT(BIGINT, b.GroupTransdesc) 
		)t1
		LEFT JOIN dbo.Team t WITH (NOLOCK) ON t.teamid = t1.PlayerId
	)bt
	ORDER BY bt.Id
	        ,bt.originalBetTypeName
			,bt.bettypeid 

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #FilterInfo
	DROP TABLE #CTE_Ticket_Single
	DROP TABLE #CTE_Ticket_SubParlay
	DROP TABLE #CTE_RequestDetail
END
GO

