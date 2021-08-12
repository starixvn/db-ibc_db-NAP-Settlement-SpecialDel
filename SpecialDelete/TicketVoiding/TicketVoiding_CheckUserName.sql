/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CheckUserName]
(
	 @UserNames	 VARCHAR(MAX) = ''
	,@RequestId	 INT = 0
	,@ActionId	 INT = 0
	,@ProductIds VARCHAR(50)  = NULL
	,@StatusIds	 VARCHAR(50)  = NULL
	,@FromDate	 DATETIME     = NULL
    ,@ToDate	 DATETIME     = NULL
)
AS
/*
	Created: 20201106@July
	Task : [TVS] - Abnormal Account + Check lock match before add request
	DB: DBTXN/BODB02

	Revisions:
		- 20201106@July: Create new SP - Check username invalid [Redmine: #143666]
		- 20210222@July: Hotfix - AC Duplicated customer getting of add request validation [Redmine: #150382]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075] 
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @InvalidUserName		  VARCHAR(MAX) = ''
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
			--Add abnormal account
			,@IsExistParlay			  BIT = 0
			,@IsExistFM				  BIT = 0
			,@IsExistFM2			  BIT = 0
			,@IsExistSingle			  BIT = 0
			,@IsExistMG				  BIT = 0
			,@IsExistParlayVSBetradar BIT = 0
			,@IsExistOutright		  BIT = 0
			,@IsExistNG				  BIT = 0
			,@IsExistVS				  BIT = 0
			,@IsExistBB				  BIT = 0
			,@MatchProcessXML		  XML = NULL
			,@movebetdate SMALLDATETIME
			,@maxdate 	DATETIME = '9999-01-01'


	
	CREATE TABLE #TmpInValidUserName ( Username VARCHAR(30))
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT, recommend INT)
	CREATE TABLE #InputValidCustid_2 (custid INT PRIMARY KEY)
	CREATE TABLE #InputValidCustid_1 (custid INT PRIMARY KEY )
	CREATE TABLE #TransidInRequest (TransId BIGINT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT )

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	INSERT INTO #TmpInValidUserName (Username)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@UserNames, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	--1. Check valid
	SET @invalidUserName = STUFF((SELECT  ',' + l.username
								  FROM #TmpInValidUserName l
									LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
									WHERE ci.custid IS NULL	
									FOR XML PATH ('')
									),1,1,'')

	IF @invalidUserName IS NOT NULL
	BEGIN
		SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest
			,@InvalidUserName AS InvalidUserName
			,@IsInValidTotalTicket AS IsInValidTotalTicket
			,@MatchIDs AS MatchIDs
			,@NumberOfTickets AS NumberOfTickets
		RETURN;
	END

	--2. Get info match belong to username
	/*
	SELECT @moveBetDay14 = MAX(winlostdate) 
	FROM dbo.bettrans14 WITH(NOLOCK)
	*/
	
	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
	SELECT @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
			, @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
			
	IF @ToDate IS NULL
	BEGIN
		
		SET @ToDate = @maxdate
	END
	
	INSERT INTO @Status_tmp (StatusId)
	SELECT DISTINCT val 
	FROM dbo.f_SplitString(@StatusIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

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
		LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.Username = ci.username
	WHERE ci.custid IS NOT NULL
	
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
		AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
		AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno

	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_2)
	BEGIN
		INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype)
		SELECT	b.translogid AS transid
				,b.statusID 
				,b.EventID
				,b.GameID
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
		WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND b.statusID = 0
				AND @IsSB = 1
					
		UNION ALL
		SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
				,b.statusID
				,b.matchid
				,b.bettype
		FROM dbo.bettrans AS b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113)
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
							AND b.bettype BETWEEN 801 AND 806 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND b.bettype NOT BETWEEN 801 AND 806 -- MG
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
		INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype)
		SELECT	b.translogid AS transid
				,b.statusID 
				,b.EventID
				,b.GameID
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
		WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND b.statusID = 0
				AND @IsSB = 1
					
		UNION ALL
		SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
				,b.statusID
				,b.matchid
				,b.bettype
		FROM dbo.bettrans AS b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113)
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
							AND b.bettype BETWEEN 801 AND 806 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND b.bettype NOT BETWEEN 801 AND 806 -- MG
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
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						ON rs.RequestId = r.RequestId
			CROSS APPLY (
						SELECT TOP 1 t.MatchId, t.transid
						FROM #transIdTemp t
						WHERE t.MatchId = rs.MatchId 
							AND rs.TransId = t.transid
				)t
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
					
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END

		DELETE 
		FROM #transIdTemp
		WHERE transid IN ( SELECT transid FROM #TransidInRequest) 
		
		SET @NumberOfTickets = @@ROWCOUNT

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
	
	---Prepare for lock match---
	SELECT   @IsExistSingle 		    = MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@IsExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@IsExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@IsExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@IsExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@IsExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@IsExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@IsExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM	#transIdTemp t
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f

	SET @MatchProcessXML = (
		SELECT DISTINCT t.MatchId "@MatchId"
				, CASE 
					WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
							AND Bettype NOT BETWEEN 801 AND 899
							AND f.GroupId IS NULL
							AND Bettype NOT IN (1231,1232,1233)
						THEN 1 --SB,NG,LC
					WHEN Bettype = 10 THEN 2	-- Outright
					WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
					WHEN f.GroupId = 1 THEN 6 -- FM
					WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
					WHEN Bettype = 38 THEN 5 -- Bet Builder
					WHEN f.GroupId = 2 THEN 7 -- FM 228
					ELSE 0
				END AS "@KeyID" 
		FROM #transIdTemp t
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = t.Bettype
			)f
		FOR XML PATH('r'), ROOT('root')
			)

	--Error Table
	SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest
		  ,@InvalidUserName AS InvalidUserName
		  ,@MatchIDs AS MatchIDs
		  ,@NumberOfTickets AS NumberOfTickets
		  ,@IsInValidTotalTicket AS IsInValidTotalTicket
		  ,@MatchProcessXML AS MatchProcessXML
		  ,@IsExistSingle AS IsExistSingle				
		  ,@IsExistMG AS IsExistMG					
		  ,@IsExistOutright AS IsExistOutright			
		  ,@IsExistParlay AS IsExistParlay 			
		  ,@IsExistParlayVSBetradar	AS IsExistParlayVSBetradar		
		  ,@IsExistNG AS IsExistNG												
		  ,@IsExistVS AS IsExistVS				
		  ,@IsExistBB AS IsExistBB							    
		  ,@IsExistFM AS IsExistFM
		  ,@IsExistFM2 AS IsExistFM2		

	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_1
	DROP TABLE #InputValidCustid_2
	DROP TABLE #TmpInValidUserName
	DROP TABLE #TransidInRequest
	DROP TABLE #transIdTemp

END

