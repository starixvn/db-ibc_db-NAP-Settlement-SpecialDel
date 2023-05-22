/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckUserName]
(
	 @UserNames			NVARCHAR(MAX) = ''
	,@RequestId			INT = 0
	,@ActionId			INT = 0
	,@ProductIds		VARCHAR(50)  = NULL
	,@StatusIds			VARCHAR(50)  = NULL
	,@FromDate			DATETIME     = NULL
    ,@ToDate			DATETIME     = NULL
	,@TransInfoJson		VARCHAR(MAX) = NULL
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
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20221212@July: [TVS] Changes of TVS to integrate E-Sports Pingoal [Redmine: #181087]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230425@July: [TVS] Support void Cricket tickets on TVS Abnormal Account [Redmine: #187051]
		- 20230517@July: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]

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
			,@IsOutright			  BIT = 0
			,@IsSaba				  BIT = 0
			,@movebetdate			  SMALLDATETIME
			,@maxdate 				  DATETIME = '9999-01-01'
			,@CountSMA				  INT
			,@CountMember             INT
			,@IsExceededTotalUsernames BIT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT
			,@TransInfoJson_Output	  VARBINARY(MAX) = NULL
			,@FromWinlostDate_14	  DATETIME = NULL
			,@ToWinlostDate_14		  DATETIME = NULL
			,@IsBeingMovebetdate	  BIT = 0 --1: movebet date comming up or being
			,@BeingMovebetDate		  SMALLDATETIME

	CREATE TABLE #TmpInValidUserName ( Username NVARCHAR(30))
	CREATE TABLE #InputUsernameList ( Username NVARCHAR(30), custid INT, roleid TINYINT, recommend INT, srecommend INT)
	CREATE TABLE #InputValidCustid_2 (custid INT PRIMARY KEY)
	CREATE TABLE #InputValidCustid_1 (custid INT PRIMARY KEY )
	CREATE TABLE #TransidInRequest (TransId BIGINT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT, winlostdate SMALLDATETIME, IsVoid14 BIT DEFAULT (0))

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	INSERT INTO #TmpInValidUserName (Username)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@UserNames, ',')
	WHERE value <> ''

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,custid INT	
	  ,refno BIGINT
      ,bettype SMALLINT
      ,betid BIGINT
      ,statusID TINYINT
	  ,winlostdate SMALLDATETIME
      ,recommend INT
	  ,srecommend INT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsVoid14 BIT
	)

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

		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END
	
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,custid		
		  ,bettype
		  ,betid
		  ,statusID
		  ,recommend
		  ,srecommend
		  ,winlostdate
		  ,IsMixParlay
		  ,SiteDBGroupID
		  ,IsVoid14
		)
	SELECT mid ,t ,ref ,c ,btype ,bid ,sid ,re ,sre
		,wld ,isP ,sitedb, isV14
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,ref ,c ,btype ,bid ,sid ,re ,sre
					  ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,isP ,sitedb ,isV14
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, ref BIGINT, c INT ,btype SMALLINT ,bid BIGINT ,sid TINYINT ,re INT ,sre INT
					 ,wld SMALLDATETIME ,isP BIT ,sitedb SMALLINT, isV14 BIT
				)
		) tbl
	WHERE f.value <> ''

	--Get Movebetdate
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	
	SELECT @FromWinlostDate_14 = CASE WHEN @FromDate <= @movebetdate THEN @FromDate ELSE NULL END
	     , @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
		 , @FromWinlostDate = CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
			
	IF @ToDate IS NULL
	BEGIN
		SET @ToDate = @maxdate
	END
	
	IF @FromWinlostDate_14 IS NOT NULL 
	BEGIN
		SET @ToWinlostDate_14 = @movebetdate
	END

	INSERT INTO @Status_tmp (StatusId)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@StatusIds, ',')

	SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END

	INSERT INTO #InputUsernameList (Username, custid, roleid, recommend, srecommend)
	SELECT l.Username
		  ,ci.custid
		  ,ci.roleid
		  ,ci.recommend
		  ,ci.srecommend
	FROM #TmpInValidUserName l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.Username = ci.username
	
	SET @invalidUserName = STUFF((SELECT  ',' + l.username
								  FROM #InputUsernameList l
										INNER JOIN CustDB.dbo.Dep_CustSuper dc WITH (NOLOCK) ON dc.custid = l.srecommend
									FOR XML PATH ('')),1,1,'')

	SELECT @CountSMA = SUM(CASE WHEN roleid IN (2,3,4) THEN 1 ELSE 0 END)
	      ,@CountMember = SUM(CASE WHEN roleid = 1 THEN 1 ELSE 0 END)
	FROM #InputUsernameList 
	
	IF @CountSMA > 50 OR @CountMember > 1000 OR @invalidUserName IS NOT NULL
	BEGIN
		SET @IsExceededTotalUsernames = CASE WHEN @CountSMA > 50 OR @CountMember > 1000 THEN 1 ELSE 0 END
		SELECT @IsExceededTotalUsernames AS IsExceededTotalUsernames
		      ,@InvalidUserName AS InvalidUserName

		SELECT NULL AS UnmarkTransIds
		
		SELECT @TransInfoJson_Output AS TransInfoJson

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
					ELSE 0 END
			END
		AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss', 'MG-SuperLive') -- Bet trade (BT-), MG
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno

	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_2)
	BEGIN
		INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype, winlostdate, IsVoid14)
		SELECT  b.transid
				,b.statusID
				,b.matchid
				,b.bettype
				,b.winlostdate
				,0 AS IsVoid14
		FROM #tmpTransInfo b 
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
			)ml
			INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsOutright = 1 OR @IsParlay = 1)
							AND ml.LeagueGroupID IS NULL THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)
			AND IsVoid14 = 0

		IF EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsVoid14 = 1)
		BEGIN
			INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype, winlostdate, IsVoid14)
			SELECT  b.transid
					,b.statusID
					,b.matchid
					,b.bettype
					,b.winlostdate
					,1 AS IsVoid14
			FROM #tmpTransInfo b 
				OUTER APPLY (
					SELECT TOP 1 1 LeagueGroupID 
					FROM dbo.match14 m WITH (NOLOCK)
						INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
					WHERE m.matchid = b.matchid
						AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
				)ml
				INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE b.winlostdate BETWEEN @FromWinlostDate_14 AND @ToWinlostDate_14 
				AND 1 = CASE 
							WHEN @IsSB = 1 
								AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
							WHEN (@IsSB = 1 OR @IsOutright = 1 OR @IsParlay = 1)
								AND ml.LeagueGroupID IS NULL THEN 1
							WHEN @IsSaba = 1 
								AND ml.LeagueGroupID IS NOT NULL THEN 1								
						ELSE 0 END	
				AND statusID IN (SELECT statusID FROM @Status_tmp)
				AND IsVoid14 = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #transIdTemp t WHERE b.transid = t.transid)
		END
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_1)
	BEGIN
		INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype, winlostdate, IsVoid14)
		SELECT b.transid
				,b.statusID
				,b.matchid
				,b.bettype
				,b.winlostdate
				,0 AS IsVoid14
		FROM #tmpTransInfo b 
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
			)ml
			INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsOutright = 1 OR @IsParlay = 1)
							AND ml.LeagueGroupID IS NULL THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)
			AND IsVoid14 = 0 AND NOT EXISTS (SELECT TOP 1 1 FROM #transIdTemp t WHERE b.transid = t.transid)
		
		IF EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsVoid14 = 1)
		BEGIN
			INSERT INTO #transIdTemp (transid,statusID, MatchId, bettype, winlostdate, IsVoid14)
			SELECT  b.transid
					,b.statusID
					,b.matchid
					,b.bettype
					,b.winlostdate
					,1 AS IsVoid14
			FROM #tmpTransInfo b 
				OUTER APPLY (
					SELECT TOP 1 1 LeagueGroupID 
					FROM dbo.match14 m WITH (NOLOCK)
						INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
					WHERE m.matchid = b.matchid
						AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122,151)
				)ml
				INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE b.winlostdate BETWEEN @FromWinlostDate_14 AND @ToWinlostDate_14 
				AND 1 = CASE 
							WHEN @IsSB = 1 
								AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
							WHEN (@IsSB = 1 OR @IsOutright = 1 OR @IsParlay = 1)
								AND ml.LeagueGroupID IS NULL THEN 1
							WHEN @IsSaba = 1 
								AND ml.LeagueGroupID IS NOT NULL THEN 1								
						ELSE 0 END	
				AND statusID IN (SELECT statusID FROM @Status_tmp)
				AND IsVoid14 = 1 AND NOT EXISTS (SELECT TOP 1 1 FROM #transIdTemp t WHERE b.transid = t.transid)
		END
	END
	
	SELECT @BeingMovebetDate = CONVERT(SMALLDATETIME, VValue)
	FROM dbo.SystemSettings
	WHERE VName = 'BeingMovebetDate'
	
	IF @BeingMovebetDate IS NOT NULL 
		AND EXISTS ( SELECT TOP 1 1 FROM #transIdTemp WHERE winlostdate = @BeingMovebetDate)
	BEGIN
		SET @IsBeingMovebetdate = 1 --Error msg: The system is running the Movebet process, please wait and try again
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

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #transIdTemp t
									WHERE t.StatusId IN (0,1) AND t.bettype NOT IN (9,29,10)
										AND t.IsVoid14 = 0
									FOR XML PATH('')), 1, 1, '')
									, '')
	END
	ELSE IF @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit from to time of Abnormal account issue -> unmark ticket change void time
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #transIdTemp tp WHERE rdt.TransId = tp.transid AND tp.IsVoid14 = 0)
												AND rdt.RequestId = @RequestId
												AND rdt.bettype NOT IN (9,29,10)
											FOR XML PATH('')), 1,1,'')
											,'')
			
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
											FROM #transIdTemp t
											WHERE t.StatusId IN (0,1) AND t.bettype NOT IN (9,29,10)
												AND t.IsVoid14 = 0
											FOR XML PATH('')), 1, 1, '')
									, '')

		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #transIdTemp t
									WHERE t.StatusId IN (0,1) AND t.bettype NOT IN (9,29,10)
										AND t.IsVoid14 = 0
									FOR XML PATH('')), 1, 1, '')
									, '')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CONVERT(VARCHAR(50), rdt.transid)
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
												AND rdt.bettype NOT IN (9,29,10)
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
		  ,@IsBeingMovebetdate AS IsBeingMovebetdate
		  
	--2. List ticket unmark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds

	--3. List TransinfoJson
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
		,b.IsVoid14 AS 'isV14'
	FROM #transIdTemp t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_1
	DROP TABLE #InputValidCustid_2
	DROP TABLE #TmpInValidUserName
	DROP TABLE #TransidInRequest
	DROP TABLE #transIdTemp
	DROP TABLE #tmpTransInfo
END

