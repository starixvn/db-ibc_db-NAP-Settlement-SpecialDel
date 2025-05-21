/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_HDP_Select] 
(
	@WrongHDPInfo  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240912@July: [TVS] Support Sportsbook for Wrong HDP, 1st HDP, OU, 1st OU, & Wrong Odds issue types [Redmine: #210152]

	Param's explanation:	
		- @WrongHDPInfo: <root><r MatchId="" FilterFromTransTime="" FilterToTransTime =""/></root>
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @WrongHDPXML	XML
		   ,@TransInfoJson	VARBINARY(MAX)
		   ,@SiteDBGroupID	SMALLINT
		   ,@MatchId		INT
		   ,@FilterFromTransTime DATETIME
		   ,@FilterToTransTime DATETIME

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
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
    )

	SET @WrongHDPXML = CONVERT(XML, @WrongHDPInfo)
	INSERT INTO #FilterInfo (MatchId, FilterFromTransTime, FilterToTransTime)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
	FROM @WrongHDPXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongHDPXML = NULL)) 

	DECLARE @tmpMatchId TABLE (MatchId INT
		, ParentId INT
		, ChildMatchType INT
		, Sporttype INT
		, FilterFromTransTime DATETIME
		, FilterToTransTime	DATETIME
		, IsFinish BIT
	)
	INSERT INTO @tmpMatchId (MatchId, ParentId, ChildMatchType, Sporttype, FilterFromTransTime, FilterToTransTime)
	SELECT m.MatchId, m.ParentId, m.ChildMatchType, m.Sporttype, d.FilterFromTransTime, d.FilterToTransTime
	FROM #FilterInfo d
	CROSS APPLY (
			SELECT m.matchid, m.ParentID, m.ChildMatchType, m.sporttype
			FROM dbo.match m WITH(NOLOCK)
			WHERE 1 = CASE WHEN m.sporttype NOT IN (50,8) AND m.matchid = d.MatchId THEN 1
						WHEN m.sporttype IN (50,8)
							AND ((m.matchid = d.MatchId) 
								OR (m.ChildMatchType = 200 AND m.ParentID = d.MatchId)) THEN 1
					ELSE 0 END
		)m
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) m 
		SET @MatchId = m.MatchId
		  , @FilterFromTransTime = m.FilterFromTransTime
		  , @FilterToTransTime = m.FilterToTransTime
		  , m.IsFinish = 1
		FROM @tmpMatchId m 
		WHERE m.IsFinish IS NULL

		IF @@ROWCOUNT = 0
			BREAK

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
		WHERE b.statusID NOT IN (101, 102, 103)
			AND b.bettype NOT IN (805, 806, 9, 29)			
			AND b.bettype NOT BETWEEN 901 AND 920
			AND b.betfrom <> 'P'
			AND b.matchid = @MatchId
			AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
			AND b.SiteDBGroupID = @SiteDBGroupID
	
		--Search sub-parlay
		IF EXISTS (
						SELECT TOP(1) 1
						FROM dbo.bettransm AS bm WITH (NOLOCK)
						WHERE bm.statusID NOT IN (101, 102, 103)
							AND bm.betfrom <> 'P' AND bm.matchid = @MatchId
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
			FROM dbo.bettransm sub 
				INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
			WHERE sub.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND sub.betfrom <> 'P'
				AND b.matchid = 29
				AND b.bettype = 29
				AND sub.matchid = @MatchId
				AND sub.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
				AND sub.SiteDBGroupID = @SiteDBGroupID
		END 
	END
			
	--Update Main MatchID for child match cricket/baseball
	IF EXISTS(SELECT TOP 1 1 FROM @tmpMatchId WHERE Sporttype IN (50,8))
	BEGIN
		UPDATE d
		SET d.matchid = m.ParentID
		FROM #TransInfo d
			INNER JOIN @tmpMatchId m ON	d.matchid = m.matchid AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
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
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #FilterInfo
END

GO

