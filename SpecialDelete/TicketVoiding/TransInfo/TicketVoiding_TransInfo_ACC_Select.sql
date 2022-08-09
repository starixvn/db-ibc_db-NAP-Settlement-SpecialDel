/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_ACC_Select] 
(
	@AbnormalAccounts  VARCHAR(MAX) = NULL
	,@IsCentral BIT = 0
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]

	Param's explanation:	
		- @AbnormalAccounts: <roor><r @UserNames = 'abc,xyz' @ProductIds="1,2" @StatusIds="112,111" @FromDate="" @ToDate=""/></root>
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @AbnormalAccountInfoXML  XML = NULL

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
		,betfrom NVARCHAR(1)
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
		,Subbetfrom NVARCHAR(1)
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
		,IsMoved14 BIT
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
		,oddsid INT
		,winlostdate SMALLDATETIME
    )

	CREATE TABLE #InputUsernameList ( Username NVARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT, ProductID TINYINT)

	DECLARE @UserNames			NVARCHAR(MAX) = NULL
			,@ProductIds			VARCHAR(50) = NULL
			,@StatusIds			VARCHAR(50) = NULL
			,@FromDate			DATETIME = NULL
			,@ToDate			DATETIME = NULL
			,@FromWinlostDate   DATETIME
			,@maxdate 			SMALLDATETIME = '9999-01-01'
			,@movebetdate		SMALLDATETIME
			,@IsSB				  BIT = 0
			,@IsParlay			  BIT = 0
			,@IsBB				  BIT = 0
			,@IsOutright		  BIT = 0
			,@IsSaba			  BIT = 0
			,@IsNonSport		  BIT = 0

	SET @AbnormalAccountInfoXML = CONVERT(XML, @AbnormalAccounts)
	SELECT @UserNames = t.c.value('@Usernames','NVARCHAR(MAX)') 
			,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
			,@StatusIds = t.c.value('@StatusIds','VARCHAR(50)')
			,@FromDate = t.c.value('@FromDate','DATETIME')
			,@ToDate = t.c.value('@ToDate','DATETIME')
	FROM @AbnormalAccountInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AbnormalAccountInfoXML = NULL))	

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
	SELECT @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
			, @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
		
	IF @ToDate IS NULL
	BEGIN
		SET @ToDate = @maxdate
	END

	INSERT INTO @Status_tmp (StatusId)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@StatusIds, ',')

	SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsBB = CASE WHEN CHARINDEX('3',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsNonSport = CASE WHEN CHARINDEX('6',@ProductIds) > 0 THEN 1 ELSE 0 END

	INSERT INTO @bettype_tmp (bettype, ProductID)
	SELECT DISTINCT pt.bettype, pt.ProductID
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE 1 = CASE WHEN @UserNames IS NULL THEN 1
				ELSE CASE
						WHEN (@IsSB = 1 OR @IsSaba = 1) 
							AND pt.ProductID = 1 
							AND pt.BetType NOT IN (9,29,10)
							AND pt.SubProduct NOT IN ('Bet Builder') THEN 1 -- Sportsbook
						WHEN @IsOutright = 1 AND pt.bettype IN (10) THEN 1 --Outright
						WHEN @IsParlay = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
						WHEN @IsBB = 1 AND pt.SubProduct IN ('Bet Builder') THEN 1 --Bet Builder
						WHEN @IsNonSport = 1 AND ProductID IN (3,5,27) AND pt.SportType NOT IN (168) THEN 1
					ELSE 0 END
			END
		AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)  -- NOT IN [Racing, Casino]
			AND pt.bettype NOT BETWEEN 1501 AND 1599   -- NOT IN Keno

	INSERT INTO #InputUsernameList (Username, custid, roleid)
	SELECT CAST(l.value AS NVARCHAR(30))
			,ci.custid
			,ci.roleid
	FROM STRING_SPLIT(@AbnormalAccounts, ',') l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON CAST(l.value AS NVARCHAR(30)) = ci.username

	-- get SMA roleid = 2
	INSERT INTO #InputValidCustid_2 (custid)		
	SELECT l.custid
	FROM #InputUsernameList l
	WHERE l.roleid = 2

	IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
	BEGIN
		INSERT INTO #InputValidCustid_2 (custid)	
		SELECT ci.custid
		FROM #InputUsernameList l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
		WHERE l.roleid = 3 AND ci.roleid = 2
	END

	IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
	BEGIN
		INSERT INTO #InputValidCustid_2 (custid)
		SELECT ci.custid
		FROM #InputUsernameList l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
		WHERE l.roleid = 4 AND ci.roleid = 2	
	END

	-- list of member to process
	INSERT INTO #InputValidCustid_tmp (CustID)
	SELECT  CustID
	FROM #InputUsernameList l
	WHERE l.roleid =1
	UNION
	SELECT ci.CustID
	FROM #InputValidCustid_2 lt
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK)
		ON lt.custid = ci.recommend
	WHERE ci.roleid = 1

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
			,IsMoved14 
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
			,oddsid
			,winlostdate
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
		,NULL AS LiveBetAcceptTime 
		,NULL AS SecAcceptTime 
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
		,NULL AS SubLiveBetAcceptTime 
		,NULL AS SubSecAcceptTime 
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,0 AS IsMixParlay 
		,0 AS IsMoved14 
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
		,b.oddsid
		,b.winlostdate
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122)
			)ml
			OUTER APPLY (
				SELECT TOP 1 m.sporttype 
				FROM dbo.match m WITH (NOLOCK)
				WHERE m.matchid = b.matchid
					AND m.sporttype = 50
			)mc
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.bettype NOT IN (805, 806)			
		AND b.bettype NOT BETWEEN 901 AND 920
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
		AND 1 = CASE 
					WHEN @IsSB = 1 
						AND b.bettype BETWEEN 801 AND 806 
						AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
					WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
						AND b.bettype NOT BETWEEN 801 AND 806-- MG
						AND ml.LeagueGroupID IS NULL 
						AND mc.sporttype IS NULL --exclude cricket
						THEN 1
					WHEN @IsSaba = 1 
						AND ml.LeagueGroupID IS NOT NULL THEN 1								
				ELSE 0 END	
		AND statusID IN (SELECT statusID FROM @Status_tmp)
						
	--RETURN DATA
	SELECT matchid 
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
		,IsMoved14 
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
		,oddsid
		,winlostdate
	FROM #TransInfo
	
	DROP TABLE #TransInfo
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #InputValidCustid_tmp
END

GO

