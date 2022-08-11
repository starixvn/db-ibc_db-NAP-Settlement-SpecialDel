/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckUserName]
(
	 @UserNames	    NVARCHAR(MAX) = ''
	,@RequestId	    INT = 0
	,@ActionId	    INT = 0
	,@ProductIds    VARCHAR(50)  = NULL
	,@StatusIds	    VARCHAR(50)  = NULL
	,@FromDate	    DATETIME     = NULL
    ,@ToDate	    DATETIME     = NULL
	,@TransInfo	    XML = NULL
)
AS
/*
	Created: 20201106@July
	Task : [TVS] - Abnormal Account + Check lock match before add request
	DB: DBCTG/bodb02

	Revisions:
		- 20201106@July: Create new SP - Check username invalid [Redmine: #143666]
		- 20210222@July: Hotfix - AC Duplicated customer getting of add request validation [Redmine: #150382]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075] 
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210803@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20211007@July: Change datatype validation username [Redmine:#161659]
		- 20220214@July: Intergrate new Saba Basketball PinGoal [Redmine: #168079]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220420@July: TVS - Abnormal Account - Phase 2 [Redmine: #170772]
		- 20220610@July: TVS - Check valid count SMA/member  [Redmine: #173229]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #173229]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @InvalidUserName		  NVARCHAR(MAX) = ''
			,@IsExistedInOtherRequest BIT = 0
			,@MatchIDs				  VARCHAR(MAX) = ''
			,@NumberOfTickets		  INT = 0
			,@IsInValidTotalTicket	  BIT = 0 -- 0 Exist valid ticket  -- 1: InValid
			,@FromWinlostDate		  DATETIME
			,@IsSB					  BIT = 0
			,@IsParlay				  BIT = 0
			,@IsBB					  BIT = 0
			,@IsOutright			  BIT = 0
			,@IsSaba				  BIT = 0
			,@IsNonSport			  BIT = 0
			,@movebetdate			  SMALLDATETIME
			,@maxdate 				  DATETIME = '9999-01-01'
			,@CountSMA				  INT
			,@CountMember             INT
			,@IsExceededTotalUsernames BIT = 0
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT

	CREATE TABLE #TmpInValidUserName ( Username NVARCHAR(30))
	CREATE TABLE #InputUsernameList ( Username NVARCHAR(30), custid INT, roleid TINYINT, recommend INT)
	CREATE TABLE #InputValidCustid_2 (custid INT PRIMARY KEY)
	CREATE TABLE #InputValidCustid_1 (custid INT PRIMARY KEY )
	CREATE TABLE #TransidInRequest (TransId BIGINT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT, RefNo BIGINT)

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	INSERT INTO #TmpInValidUserName (Username)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@UserNames, ',')
	WHERE value <> ''

	--1. Check valid
	SET @invalidUserName = STUFF((SELECT  ',' + l.username
								  FROM #TmpInValidUserName l
									LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
									WHERE ci.custid IS NULL	
									FOR XML PATH ('')
									),1,1,'')

	IF @invalidUserName IS NOT NULL
	BEGIN
		 
		SELECT @InvalidUserName AS InvalidUserName
			
		SELECT NULL AS UnmarkTransIds
		SELECT NULL AS TransInfo

		RETURN;
	END
	
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,custid INT	
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
      ,betteam NVARCHAR(10)
      ,betfrom NVARCHAR(1)
	  ,refno BIGINT
      ,bettype SMALLINT
      ,betid BIGINT
	  ,betdaqid BIGINT
      ,statusID TINYINT
	  ,winlostdate SMALLDATETIME
      ,recommend INT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,custid		
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,bettype
		  ,betdaqid 
		  ,statusID
		  ,winlostdate
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT t.c.value('@mid','INT') AS matchid
			,t.c.value('@t','BIGINT') AS transid
			,t.c.value('@ref','BIGINT') AS refno
			,t.c.value('@c','INT') AS custid
			,t.c.value('@lh','SMALLINT') AS livehomescore
			,t.c.value('@la','SMALLINT') AS liveawayscore
			,t.c.value('@li','BIT') AS liveindicator
			,t.c.value('@btype','SMALLINT') AS bettype
			,t.c.value('@bdaq','BIGINT') AS betdaqid
			,t.c.value('@sid','TINYINT') AS statusID
			,t.c.value('@wld','SMALLDATETIME') AS winlostdate
			,t.c.value('@isP','BIT') AS IsMixParlay
			,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
	FROM @TransInfo.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

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

	INSERT INTO #InputUsernameList (Username, custid, roleid,recommend)
	SELECT l.Username
		  ,ci.custid
		  ,ci.roleid
		  ,ci.recommend
	FROM #TmpInValidUserName l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.Username = ci.username
	
	SELECT @CountSMA = SUM(CASE WHEN roleid IN (2,3,4) THEN 1 ELSE 0 END)
	      ,@CountMember = SUM(CASE WHEN roleid = 1 THEN 1 ELSE 0 END)
	FROM #InputUsernameList 
	
	IF @CountSMA > 50 OR @CountMember > 1000
	BEGIN
		SET @IsExceededTotalUsernames = 1
		SELECT @IsExceededTotalUsernames AS IsExceededTotalUsernames

		SELECT NULL AS UnmarkTransIds
		SELECT NULL AS TransInfo
		RETURN;
	END

	INSERT INTO #InputValidCustid_2 (custid)		
	SELECT l.custid
	FROM #InputUsernameList l
	WHERE l.roleid = 2

	IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
	BEGIN
		INSERT INTO #InputValidCustid_2 (custid)	
		SELECT DISTINCT ci.custid
		FROM #InputUsernameList l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
			LEFT JOIN #InputValidCustid_2 ag ON ag.custid = ci.custid
		WHERE l.roleid = 3 AND ci.roleid = 2 AND ag.custid IS NULL	
	END

	IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
	BEGIN
		INSERT INTO #InputValidCustid_2 (custid)
		SELECT DISTINCT ci.custid
		FROM #InputUsernameList l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
			LEFT JOIN #InputValidCustid_2 ag ON ag.custid = ci.custid
		WHERE l.roleid = 4 AND ci.roleid = 2 AND ag.custid IS NULL	
	END
	
	-- list of member to process
	INSERT INTO #InputValidCustid_1 (CustID)
	SELECT  DISTINCT l1.CustID
	FROM #InputUsernameList l1
		LEFT JOIN #InputValidCustid_2 l2 ON l1.recommend = l2.custid 
	WHERE l1.roleid = 1 AND l2.custid IS NULL
	
	------------Prepare Data------------------------
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
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
		AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss', 'MG-SuperLive') -- Bet trade (BT-), MG
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno

	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_2)
	BEGIN
		INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype, RefNo)
		SELECT  b.transid
				,b.statusID
				,b.matchid
				,b.bettype
				,b.refno
		FROM #tmpTransInfo b 
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122)
			)ml
			INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
			OUTER APPLY (
				SELECT TOP 1 m.sporttype 
				FROM dbo.match m WITH (NOLOCK)
				WHERE m.matchid = b.matchid
					AND m.sporttype = 50
			)mc
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND ml.LeagueGroupID IS NULL 
							AND mc.sporttype IS NULL --exclude cricket
							THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_1)
	BEGIN
		INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype, RefNo)
		SELECT b.transid
				,b.statusID
				,b.matchid
				,b.bettype
				,b.refno
		FROM #tmpTransInfo b 
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
			INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND ml.LeagueGroupID IS NULL 
							AND mc.sporttype IS NULL --exclude cricket
							THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)

	END
	
	----------End of data prepare-----------------
	--3. TransId in request table
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId)
		SELECT DISTINCT rs.TransId
		FROM  dbo.TicketVoiding_Request r WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK) ON rs.RequestId = r.RequestId
			CROSS APPLY (
						SELECT TOP 1 t.MatchId, t.transid, t.StatusId
						FROM #transIdTemp t
						WHERE t.MatchId = rs.MatchId 
							AND rs.TransId = t.transid
				)t
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
		AND 1 = CASE WHEN r.IssueTypeId IN (11,15) AND t.StatusId NOT IN (111,112,113) THEN 1
					 WHEN r.IssueTypeId NOT IN (11,15) THEN 1
					 ELSE 0 END
					
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END

		DELETE FROM #transIdTemp
		WHERE transid IN ( SELECT transid FROM #TransidInRequest) 
		
		SET @NumberOfTickets = @@ROWCOUNT
	END

	IF @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId NOT IN (2)
		BEGIN
			--Edit from to time of Abnormal account issue -> unmark ticket change void time
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #transIdTemp tp WHERE rdt.TransId = tp.transid)
												AND rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
											,'')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CONVERT(VARCHAR(50), rdt.transid)
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
											FOR XML PATH('')), 1, 1, '')
										,'')
		END
	END

	--Get list match
	SELECT @MatchIDs = STUFF((SELECT DISTINCT  ',' + CAST( m.matchid AS VARCHAR(20))
							  FROM #transIdTemp m
							  FOR XML PATH ('')
							),1,1,'')

	IF EXISTS (SELECT TOP 1 1 FROM #transIdTemp) 
		SET @IsInValidTotalTicket = 0 
	ELSE 
		SET @IsInValidTotalTicket = 1 

	/*****************Return table **************************/
	
	-- 1. Validate Table
	SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest
		  ,@InvalidUserName AS InvalidUserName
		  ,@MatchIDs AS MatchIDs
		  ,@NumberOfTickets AS NumberOfTickets
		  ,@IsInValidTotalTicket AS IsInValidTotalTicket
		  
	--2. List ticket unmark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds

	--3. Transinfo table
	SELECT DISTINCT 
			t.matchid
		    ,t.transid
			,t.refno 
			,b.custid
			,b.bettype 
			,b.betid 
			,b.IsMixParlay 
			,b.SiteDBGroupID
	FROM #transIdTemp t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid

	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_1
	DROP TABLE #InputValidCustid_2
	DROP TABLE #TmpInValidUserName
	DROP TABLE #TransidInRequest
	DROP TABLE #transIdTemp
	DROP TABLE #tmpTransInfo
END

