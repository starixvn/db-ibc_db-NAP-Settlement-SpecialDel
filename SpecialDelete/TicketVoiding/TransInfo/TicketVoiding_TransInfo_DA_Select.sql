/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_DA_Select] 
(
	@DangerAcceptedInfo  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]

	Param's explanation:	
		- @DangerAcceptedInfo: <root><r MatchId="" FilterFromTransTime="" FilterToTransTime ="" FilterBy=""/></root>
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @DangerAcceptedXML	XML
		   ,@TransInfoJson		VARBINARY(MAX)
		   ,@SiteDBGroupID		SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterBy				TINYINT
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
		,betfrom NVARCHAR(3)
		,statusID TINYINT
		,WalletType TINYINT
		,RefCode BIGINT
		,LiveBetAcceptTime SMALLINT
		,SecAcceptTime TINYINT
		,Subcustid INT        
		,Sublivehomescore SMALLINT
		,Subliveawayscore SMALLINT
		,Subhdp1 SMALLMONEY
		,Subhdp2 SMALLMONEY
		,Subbetfrom NVARCHAR(3)
		,Subbettype SMALLINT
		,SubstatusID TINYINT
		,Subtransdate DATETIME
		,Subchecktime DATETIME
		,Subliveindicator BIT
		,SubLiveBetAcceptTime SMALLINT
		,SubSecAcceptTime TINYINT
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
		,IsCancelCashOut 	BIT
	)

	SET @DangerAcceptedXML = CONVERT(XML, @DangerAcceptedInfo)
	INSERT INTO #FilterInfo (MatchId, FilterFromTransTime, FilterToTransTime, FilterBy)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
			,t.c.value('@FilterBy','TINYINT') AS FilterBy
	FROM @DangerAcceptedXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@DangerAcceptedXML = NULL)) 

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
			,LiveBetAcceptTime 
			,SecAcceptTime 
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
			,SubLiveBetAcceptTime 
			,SubSecAcceptTime 
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
			,IsCancelCashOut
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
		,bi.LiveBetAcceptTime 
		,bi.SecAcceptTime 
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
		,bi.LiveBetAcceptTime AS SubLiveBetAcceptTime 
		,bi.SecAcceptTime AS SubSecAcceptTime 
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
		,CASE WHEN c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1 ELSE 0 END AS IsCancelCashOut
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
		LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
		CROSS APPLY (
			SELECT CASE WHEN d.FilterBy = 1 THEN b.transdate 
					WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
					WHEN d.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
			END AS VoidTime
		)act
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (9, 29)			
		AND b.betfrom <> 'P'
		AND 1 = CASE WHEN act.VoidTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
					 ELSE CASE WHEN c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
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
				,LiveBetAcceptTime 
				,SecAcceptTime 
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
				,SubLiveBetAcceptTime 
				,SubSecAcceptTime 
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
			,NULL AS LiveBetAcceptTime 
			,NULL AS SecAcceptTime 
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
			,sub.LiveBetAcceptTime AS SubLiveBetAcceptTime 
			,sub.SecAcceptTime AS SubSecAcceptTime 
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
		FROM #FilterInfo d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
		WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND sub.betfrom <> 'P'
			AND b.matchid = 29
			AND b.bettype = 29
			AND CASE WHEN d.FilterBy = 1 THEN sub.transdate
						WHEN d.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
						WHEN d.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
				END BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
			AND sub.SiteDBGroupID = @SiteDBGroupID
	END 
			
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
		,LiveBetAcceptTime AS 'lbat'
		,SecAcceptTime AS 'sat'
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
		,SubLiveBetAcceptTime AS 's_lbat'
		,SubSecAcceptTime AS 's_sat'
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
		,ISNULL(IsCancelCashOut,0) AS 'isCCO'
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #FilterInfo
END

GO

