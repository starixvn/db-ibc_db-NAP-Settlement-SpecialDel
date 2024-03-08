/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TransInfo_ACC_Select] 
(
	@AbnormalAccounts  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221124@Max: [TVS] Increase data size when sending data between web and DB [Redmine:	#180863]
		- 20221212@July: [TVS] Changes of TVS to integrate E-Sports Pingoal [Redmine: #181087]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230425@July: [TVS] Support void Cricket tickets on TVS Abnormal Account [Redmine: #187051]
		- 20230517@July: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20231102@Max: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
		- 20240305@Max: [TVS] Abnormal Account - Void full range of archived tickets [Redmine: #201130]

	Param's explanation:	
		- @AbnormalAccounts: <roor><r @UserNames = 'abc,xyz' @ProductIds="1,2" @StatusIds="112,111" @FromDate="" @ToDate=""/></root>
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @AbnormalAccountInfoXML  XML = NULL
		   ,@TransInfoJson			 VARBINARY(MAX)
		   ,@SiteDBGroupID			 SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #TransInfo (
		matchid INT
		,transid BIGINT
		,refno BIGINT
		,custid INT        
		,bettype SMALLINT
		,betid BIGINT
		,statusID TINYINT
		,recommend INT
		,srecommend INT
		,winlostdate SMALLDATETIME
		,IsMixParlay BIT
		,SiteDBGroupID SMALLINT
		,IsVoid14 BIT DEFAULT(0)
		,winlost	MONEY
		,actual_stake	MONEY
    )
	
	CREATE TABLE #InputUsernameList ( Username NVARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT, ProductID TINYINT)

	DECLARE @UserNames			NVARCHAR(MAX) = NULL
			,@ProductIds		VARCHAR(50) = NULL
			,@StatusIds			VARCHAR(50) = NULL
			,@FromDate			DATETIME = NULL
			,@ToDate			DATETIME = NULL
			,@FromWinlostDate   DATETIME
			,@maxdate 			DATETIME = '9999-01-01'
			,@movebetdate		DATETIME
			,@IsSB				BIT = 0
			,@IsParlay			BIT = 0
			,@IsOutright		BIT = 0
			,@IsSaba			BIT = 0
			,@FromWinlostDate_14 DATETIME = NULL
			,@ToWinlostDate_14  DATETIME = NULL
			,@IsVoidAllArchivedTickets	BIT = 0

	SET @AbnormalAccountInfoXML = CONVERT(XML, @AbnormalAccounts)
	SELECT @UserNames = t.c.value('@Usernames','NVARCHAR(MAX)') 
			,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
			,@StatusIds = t.c.value('@StatusIds','VARCHAR(50)')
			,@FromDate = t.c.value('@FromDate','DATETIME')
			,@ToDate = NULLIF(t.c.value('@ToDate','DATETIME'), '')
			,@IsVoidAllArchivedTickets = t.c.value('@IsVoidAllArchivedTickets','BIT')
	FROM @AbnormalAccountInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AbnormalAccountInfoXML = NULL))	

	--Get Movebetdate
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	
	SELECT @FromWinlostDate_14 = CASE WHEN @FromDate <= @movebetdate THEN @FromDate ELSE NULL END
	     , @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
		 , @FromWinlostDate = CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
	
	IF @ToDate IS NULL
	BEGIN
		SET @ToDate = @maxdate
	END

	IF @IsVoidAllArchivedTickets = 1
	BEGIN
		SET @FromWinlostDate_14 = (SELECT MIN(winlostdate) FROM dbo.bettrans14 WITH (NOLOCK))

		SELECT @FromWinlostDate_14 = CASE WHEN @FromWinlostDate_14 <= @FromDate THEN @FromDate ELSE NULL END
		SET @ToWinlostDate_14 = @ToDate
	END
	ELSE IF @FromWinlostDate_14 IS NOT NULL 
	BEGIN
		IF @ToDate < @movebetdate
			SET @ToWinlostDate_14 = @ToDate
		ELSE
			SET @ToWinlostDate_14 = @movebetdate
	END

	SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END

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
					ELSE 0 END
			END
		AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)  -- NOT IN [Racing, Casino]
			AND pt.bettype NOT BETWEEN 1501 AND 1599   -- NOT IN Keno
	
	INSERT INTO #InputUsernameList (Username, custid, roleid)
	SELECT CAST(l.value AS NVARCHAR(30))
			,ci.custid
			,ci.roleid
	FROM STRING_SPLIT(@UserNames, ',') l
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

	--Search single tickets (bettrans)
	INSERT INTO #TransInfo(
			matchid 
			,transid
			,custid                
			,refno 
			,bettype 
			,betid 
			,statusID 
			,recommend 
			,srecommend 
			,winlostdate
			,IsMixParlay 
			,SiteDBGroupID
			,IsVoid14
			,winlost
			,actual_stake
		)
	SELECT b.matchid
		,b.TransId
		,b.custid
		,b.refno
		,b.bettype
		,b.betid
		,b.statusID 
		,b.recommend 
		,b.srecommend 
		,b.winlostdate
		,CASE WHEN b.bettype IN (9,29, 2799) THEN 1 ELSE 0 END AS IsMixParlay 
		,b.SiteDBGroupID
		,0 AS IsVoid14
		,b.winlost
		,b.actual_stake
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
		INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
			)ml
		LEFT JOIN CustDB.dbo.Dep_CustSuper dc WITH(NOLOCK) ON dc.custid = b.srecommend
	WHERE b.statusID NOT IN (101, 102, 103)
		AND b.betfrom <> 'P'
		AND b.SiteDBGroupID = @SiteDBGroupID
		AND b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
		AND 1 = CASE 
					WHEN @IsSB = 1 
						AND b.bettype BETWEEN 801 AND 806 
						AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
					WHEN (@IsSB = 1 OR @IsOutright = 1 OR @IsParlay = 1)
						AND b.bettype NOT BETWEEN 801 AND 806-- MG
						AND ml.LeagueGroupID IS NULL THEN 1
					WHEN @IsSaba = 1 
						AND ml.LeagueGroupID IS NOT NULL THEN 1								
				ELSE 0 END	
		AND dc.custid IS NULL
	
	--Update Main MatchID for child match cricket (Sporttype = 50)
	UPDATE d
	SET d.matchid = m.ParentID
	FROM #TransInfo d
		INNER JOIN dbo.match m WITH (NOLOCK) ON	d.matchid = m.matchid AND m.sporttype = 50 AND m.ChildMatchType = 200
	WHERE d.bettype NOT IN (9, 29, 2799) AND d.IsVoid14 = 0

	IF @FromWinlostDate_14 IS NOT NULL
	BEGIN
		--Search single tickets (bettrans14)
		INSERT INTO #TransInfo(
			matchid 
			,transid
			,custid                
			,refno 
			,bettype 
			,betid 
			,statusID 
			,recommend 
			,srecommend
			,winlostdate
			,IsMixParlay 
			,SiteDBGroupID
			,IsVoid14
			,winlost
			,actual_stake
			)
		SELECT b.matchid
			,b.TransId
			,b.custid
			,b.refno
			,b.bettype
			,b.betid
			,b.statusID 
			,b.recommend 
			,b.srecommend
			,b.winlostdate
			,CASE WHEN b.bettype IN (9,29, 2799) THEN 1 ELSE 0 END AS IsMixParlay 
			,b.SiteDBGroupID
			,1 AS IsVoid14
			,b.winlost
			,b.actual_stake
		FROM dbo.bettrans14 b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			OUTER APPLY (
					SELECT TOP 1 1 LeagueGroupID 
					FROM dbo.match14 m WITH (NOLOCK)
						INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
					WHERE m.matchid = b.matchid
						AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
				)ml
			LEFT JOIN CustDB.dbo.Dep_CustSuper dc WITH(NOLOCK) ON dc.custid = b.srecommend
		WHERE b.statusID NOT IN (101, 102, 103)
			AND b.betfrom <> 'P'
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND b.winlostdate BETWEEN @FromWinlostDate_14 AND @ToWinlostDate_14 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.bettype BETWEEN 801 AND 806 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsOutright = 1 OR @IsParlay = 1)
							AND b.bettype NOT BETWEEN 801 AND 806-- MG
							AND ml.LeagueGroupID IS NULL THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND dc.custid IS NULL

	END
	
	--RETURN DATA
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
		,refno AS 'ref'
		,custid AS  'c'           
		,bettype AS 'btype'
		,betid AS 'bid'
		,statusID AS 'sid'
		,recommend AS 're'
		,srecommend AS 'sre'
		,winlostdate AS 'wld'
		,IsMixParlay AS 'isP'
		,SiteDBGroupID AS 'sitedb'
		,IsVoid14 AS 'isV14'
		,winlost AS 'wl'
		,actual_stake AS 'act_s'
	FROM #TransInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #InputValidCustid_tmp
END

GO

