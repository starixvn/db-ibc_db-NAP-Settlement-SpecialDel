/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_RO_Select] 
(
	@ReducedOverInfo  VARCHAR(MAX) = NULL
)
AS
/*	
	Created: 20230608@Max  
    Task : [TVS] Support void Cricket when reducing over [Redmine: #185833]
    DB: DBTXN/bodb02 
      
    Revisions:      
        - 20230608@Max: Create SP - [Redmine: #185833]

	Param's explanation:	
		- @ReducedOverInfo: 
		<root>
			<r MatchId="" SubIssueTypeId="" BetTypes="1" WicketOver ="" PlayerIds="" Runs="" Live="" NonLive=""/>
			<r MatchId="" SubIssueTypeId="" BetTypes="1,2" WicketOver ="" PlayerIds="" Runs="" Live="" NonLive=""/>
		</root>
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @ReducedOverXML	XML
		   ,@TransInfoJson		VARBINARY(MAX)
		   ,@SiteDBGroupID		SMALLINT
		   ,@MatchId			INT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo(
		MatchId				INT
		,Bettype				SMALLINT
		,FilterSet          VARCHAR(50)
        ,FilterRuns		    SMALLMONEY
		,FilterTransdesc	NVARCHAR(2000)
		,FilterLive			BIT
		,FilterNonLive		BIT
		,IsFancy			BIT DEFAULT (0)
	)
	
	DECLARE @tmpMatchId TABLE (MatchId INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

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
		,LiveBetAcceptTime SMALLINT
		,SecAcceptTime TINYINT
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
		,CheckTimeCashOut  DATETIME
	)

	SET @ReducedOverXML = CONVERT(XML, @ReducedOverInfo)
	INSERT INTO #FilterInfo (MatchId, Bettype, FilterTransdesc, FilterSet, FilterRuns, FilterLive, FilterNonLive)
	SELECT t.c.value('@MatchId','INT')		
		,bt.bettype
		,pl.Transdesc
		,t.c.value('@WicketOver','VARCHAR(50)')
		,t.c.value('@Runs','SMALLMONEY')
		,t.c.value('@Live','BIT')
		,t.c.value('@NonLive','BIT')
	FROM @ReducedOverXML.nodes('root/r') t(c)
		CROSS APPLY (
			SELECT value AS bettype
			FROM string_split (t.c.value('@BetTypeIds','VARCHAR(2000)'),',')
		)bt
		CROSS APPLY (
			SELECT value AS Transdesc
			FROM string_split (t.c.value('@PlayerIds','VARCHAR(2000)'),',')
		)pl
	OPTION (OPTIMIZE FOR (@ReducedOverXML = NULL))
	
	UPDATE d SET d.IsFancy = 1
	FROM #FilterInfo d
		INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = d.Bettype
	WHERE bt.typenamee LIKE '%Fancy'

	SET @MatchId = (SELECT TOP(1) MatchId FROM #FilterInfo)

	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match WITH(NOLOCK)
	WHERE (matchid = @MatchId OR ParentID = @MatchId)

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT bettype
	FROM #FilterInfo
	
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
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN @tmpMatchId m ON m.MatchId = b.matchid
		INNER JOIN @bettype_tmp d ON b.bettype = d.bettype
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (805, 806, 9, 29)			
		AND b.bettype NOT BETWEEN 901 AND 920
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	--Search sub-parlay
	IF EXISTS (
					SELECT TOP(1) 1
					FROM dbo.bettransm AS bm WITH (NOLOCK)
						INNER JOIN @tmpMatchId d oN d.MatchId = bm.matchid
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
		FROM @tmpMatchId d
			INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId = sub.matchid
			INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			INNER JOIN @bettype_tmp t ON t.bettype = sub.bettype
		WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
			AND sub.betfrom <> 'P'
			AND b.matchid = 29
			AND b.bettype = 29
			AND sub.SiteDBGroupID = @SiteDBGroupID
	END
	
	DELETE b
		FROM  #TransInfo b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #FilterInfo tp
			WHERE tp.Bettype = b.bettype 
			AND (tp.FilterSet = '' OR b.Subbetcheck = tp.FilterSet))

	DELETE b
		FROM  #TransInfo b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #FilterInfo tp
			WHERE tp.Bettype = b.bettype 
			AND 1 = CASE WHEN tp.FilterLive = 1 AND b.liveindicator = 1 THEN 1
						WHEN tp.FilterNonLive = 1 AND b.liveindicator = 0 THEN 1
					ELSE 0 END
			) 

	DELETE b
		FROM  #TransInfo b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #FilterInfo tp
			WHERE tp.Bettype = b.bettype AND  (tp.FilterTransdesc = '' OR b.Transdesc = tp.FilterTransdesc))

	DELETE b
		FROM  #TransInfo b
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM #FilterInfo tp
			WHERE tp.Bettype = b.bettype 
			AND 1 = CASE WHEN tp.FilterRuns = '' THEN 1
						WHEN tp.FilterRuns <> '' AND tp.IsFancy = 0 AND b.hdp1 = FilterRuns THEN 1
						WHEN tp.FilterRuns <> '' AND tp.IsFancy = 1 AND (b.hdp1 = tp.FilterRuns OR b.hdp2 = tp.FilterRuns) THEN 1
					ELSE 0 END
		)
			
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
		,CheckTimeCashOut AS 'checktCO' 
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #FilterInfo
END

GO

