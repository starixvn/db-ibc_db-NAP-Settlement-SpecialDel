/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_AB_Select] 
(
	@AbnormalBetTransIds  VARCHAR(MAX) = NULL
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
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20231115@July: [TVS] Abnormal Bet - Export the list of tickets that the user inputs to a request before Save it [Redmine: #194133]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's explanation:	
		- @AbnormalBetTransIds: '12343091763609600,12343108943478784'
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @TransInfoJson	VARBINARY(MAX)
		   ,@SiteDBGroupID	SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #TransInfo (
		matchid INT
		,transid BIGINT
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
		,recommend INT
		,mrecommend INT
		,srecommend INT
		,statuswinlost TINYINT
		,IsMixParlay BIT
		,IsMoved14 BIT
		,odds MONEY
		,oddsspread MONEY
		,oddstype TINYINT
		,betcheck NVARCHAR(50)
		,stake MONEY
		,CurrencyName NVARCHAR(50)
		,Transdesc NVARCHAR(1000)
		,ExtraInfo VARCHAR(1000)
		,BonusID INT
		,winlost        MONEY
		,actual_stake MONEY
		,Status NVARCHAR(10)
		,modds SMALLMONEY
		,SiteDBGroupID SMALLINT
		,winlostdate SMALLDATETIME
    )

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@AbnormalBetTransIds, ',')
	WHERE value <> ''

	--Search single tickets
	INSERT INTO #TransInfo(
			matchid 
			,transid
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
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,IsMoved14 
			,odds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,modds 
			,SiteDBGroupID
			,winlostdate
		)
	SELECT b.matchid
		,b.TransId
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
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,0 AS IsMixParlay 
		,0 AS IsMoved14 
		,b.odds 
		,b.oddsspread
		,b.oddstype 
		,b.betcheck 
		,b.stake 
		,b.CurrencyName 
		,b.Transdesc 
		,b.ExtraInfo 
		,b.BonusID 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.modds 
		,b.SiteDBGroupID
		,b.winlostdate
	FROM #transIdTemp t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (805, 806)			
		AND b.bettype NOT BETWEEN 901 AND 920
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID

	--Update Main MatchID for child match cricket (Sporttype = 50)
	IF(EXISTS(SELECT TOP 1 1 FROM #TransInfo WHERE bettype NOT IN (9, 29, 2799, 10449)))
	BEGIN
		UPDATE d
		SET d.matchid = m.ParentID
		FROM #TransInfo d
			INNER JOIN dbo.match m WITH (NOLOCK) ON	d.matchid = m.matchid AND m.sporttype = 50 AND m.ChildMatchType = 200
		WHERE d.bettype NOT IN (9, 29, 2799, 10449)
	END

	IF EXISTS (SELECT TOP(1) 1 
				FROM #transIdTemp t
					INNER JOIN dbo.bettrans14 b14 WITH (NOLOCK) ON b14.transid = t.transid
			)
	BEGIN
		INSERT INTO #TransInfo(
			matchid 
			,transid
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
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,IsMoved14 
			,odds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,modds 
			,SiteDBGroupID
			,winlostdate
		)
	SELECT b.matchid
		,b.TransId
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
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,0 AS IsMixParlay 
		,1 AS IsMoved14 
		,b.odds 
		,b.oddsspread
		,b.oddstype 
		,b.betcheck 
		,b.stake 
		,b.CurrencyName 
		,b.Transdesc 
		,b.ExtraInfo 
		,b.BonusID 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.modds 
		,b.SiteDBGroupID
		,b.winlostdate
	FROM #transIdTemp t
		INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (805, 806)			
		AND b.bettype NOT BETWEEN 901 AND 920
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
	END
						
	--RETURN DATA
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
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
		,recommend AS 're'
		,mrecommend AS 'mre'
		,srecommend AS 'sre'
		,statuswinlost AS 'statuswl'
		,IsMixParlay AS 'isP'
		,IsMoved14 AS 'isM'
		,odds AS 'o'
		,oddsspread AS 'os'
		,oddstype AS 'ost'
		,betcheck AS 'bcheck'
		,stake AS 'stake'
		,CurrencyName AS 'curr'
		,Transdesc AS 'tdes'
		,ExtraInfo AS 'ex'
		,BonusID AS 'bo'
		,winlost    AS 'w'    
		,actual_stake AS 'acstake'
		,Status AS 's' 
		,modds AS 'm'
		,SiteDBGroupID AS 'sitedb'
		,winlostdate AS 'wld'
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
END

GO

