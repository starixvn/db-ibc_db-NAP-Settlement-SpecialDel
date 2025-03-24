/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CheckUserName]
(
	 @UserNames			NVARCHAR(MAX) = ''
	,@RequestId			INT = 0
	,@ActionId			INT = 0
	,@ProductIds		VARCHAR(50)  = NULL
	,@StatusIds			VARCHAR(50)  = NULL
	,@FromDate			DATETIME     = NULL
    ,@ToDate			DATETIME     = NULL
	,@AdjustVoidLimit	VARCHAR(MAX) = NULL
	,@IsVoidAllArchivedTickets	BIT = 0
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
		- 20231003@July: [TVS] Abnormal Account - Increase the number of input Usernames to void [Redmine: #194095]
		- 20231102@Max: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
		- 20231208@Max: [TVS] Abnormal Account - Add confirmation popup before saving request for auto void actions [Redmine: #198164]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240305@Max: [TVS] Abnormal Account - Void full range of archived tickets [Redmine: #201130]
		- 20241126@Lani: [TVS] Change join type on 'recommend' and 'custid' columns, 'mrecommend' and 'custid' [Redmine: #213451]
		- 20241224@July: [TVS] Abnormal Account - Enhance Auto Void (Instant with Policy) [Redmine: #214444]
		- 20250311@Max: [TVS] Enhance the Auto Void flow (Instant with Policy) of Abnormal Account  [#Redmine: #217979]

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
			,@MaxSMA				  INT = 50
			,@MaxMember				  INT = 2000
			,@CountSMA				  INT
			,@CountMember             INT
			,@IsExceededTotalUsernames BIT = 0
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
			,@OldActionId			  TINYINT
			,@FromWinlostDate_14	  DATETIME = NULL
			,@ToWinlostDate_14		  DATETIME = NULL
			,@IsBeingMovebetdate	  BIT = 0 --1: movebet date comming up or being
			,@BeingMovebetDate		  SMALLDATETIME
			,@currentdate			  SMALLDATETIME = GETDATE()

	DECLARE @SiteDBGroupID			 SMALLINT
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #InputUsernameList ( Username NVARCHAR(30),custid INT, roleid TINYINT, credit MONEY)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT, Username NVARCHAR(30), credit MONEY)

	CREATE TABLE #TransidInRequest (TransId BIGINT)

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tmp_checkedTransId AS TABLE (TransId BIGINT)
	DECLARE @AdjustVoidLimit_tmp AS TABLE (CustId INT, AdjustLimit MONEY) 

	INSERT INTO #InputUsernameList (Username, custid, roleid, credit)
	SELECT CAST(l.value AS NVARCHAR(30))
			,ci.custid
			,ci.roleid
			,ci.credit
	FROM STRING_SPLIT(@UserNames, ',') l
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON CAST(l.value AS NVARCHAR(30)) = ci.username

	IF @AdjustVoidLimit <> ''
	BEGIN
		INSERT INTO @AdjustVoidLimit_tmp (CustId , AdjustLimit)
		SELECT ci, av
		FROM OPENJSON(@AdjustVoidLimit) 
		WITH( ci INT, av MONEY
	) tbl
	END

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
	  ,mrecommend INT
	  ,srecommend INT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsVoid14 BIT
	  ,winlost	MONEY
	  ,actual_stake MONEY
	  ,modds SMALLMONEY
	  ,transdate DATETIME
	  ,checktime DATETIME
	  ,hdp1 SMALLMONEY
	  ,hdp2 SMALLMONEY
	  ,livehomescore SMALLINT
	  ,liveawayscore SMALLINT
	  ,liveindicator BIT
	  ,betteam NVARCHAR(10)
	  ,betdaqid BIGINT
	  ,betfrom NVARCHAR(4)
	  ,statuswinlost TINYINT
	  ,odds MONEY
	  ,oddstype TINYINT
	  ,betcheck NVARCHAR(50)
	  ,stake MONEY
	  ,Status NVARCHAR(10)
	  ,oddsid INT
	  ,CurrencyName NVARCHAR(50)
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
	  ,oddsspread MONEY
	  ,Transdesc NVARCHAR(1000)
	  ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,ExtraInfo VARCHAR(1000)
	  ,credit money
	  ,id [int] IDENTITY (1,1) PRIMARY KEY
	)

	--1. Check valid
	SET @invalidUserName = STUFF((SELECT  ',' + l.username
								  FROM #InputUsernameList l
									LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.username = ci.username
									WHERE ci.custid IS NULL	
									FOR XML PATH ('')
									),1,1,'')

	IF @invalidUserName IS NOT NULL
	BEGIN		 
		SELECT @InvalidUserName AS InvalidUserName		
		SELECT NULL AS UnmarkTransIds

		RETURN;
	END
	
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
		SET @FromWinlostDate_14 = (SELECT MIN(winlostdate) FROM #tmpTransInfo)

		SELECT @FromWinlostDate_14 = CASE WHEN @FromWinlostDate_14 <= @FromDate THEN @FromDate ELSE @FromWinlostDate_14 END
		SET @ToWinlostDate_14 = @ToDate
	END
	ELSE IF @FromWinlostDate_14 IS NOT NULL 
	BEGIN
		IF @ToDate < @movebetdate
			SET @ToWinlostDate_14 = @ToDate
		ELSE
			SET @ToWinlostDate_14 = @movebetdate
	END

	--In case action auto void with policy: include ticket won/lost for UI
	IF @ActionId = 10 
	BEGIN 
		SET @StatusIds = @StatusIds + ',112,113'
	END

	INSERT INTO @Status_tmp (StatusId)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@StatusIds, ',')

	SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
			, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END

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
		WHERE l.roleid = 3 AND ci.roleid = 2 AND ci.custid NOT IN (SELECT custid FROM #InputValidCustid_2)
	END

	IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
	BEGIN
		INSERT INTO #InputValidCustid_2 (custid)
		SELECT ci.custid
		FROM #InputUsernameList l
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
		WHERE l.roleid = 4 AND ci.roleid = 2 AND ci.custid NOT IN (SELECT custid FROM #InputValidCustid_2)	
	END

	-- list of member to process
	INSERT INTO #InputValidCustid_tmp (CustID, Username, credit)
	SELECT  CustID, l.Username, l.credit
	FROM #InputUsernameList l
	WHERE l.roleid =1
	UNION
	SELECT ci.CustID, ci.username, ci.credit
	FROM #InputValidCustid_2 lt
		INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK)
		ON lt.custid = ci.recommend
	WHERE ci.roleid = 1

	--List member Offer Direct Member for Super/Master
	INSERT INTO #InputValidCustid_tmp (CustID, Username, credit)
	SELECT ci.custid, ci.username, ci.credit
	FROM #InputUsernameList AS l 
		INNER JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK)
		ON l.custid = ci.srecommend
	WHERE ci.recommend IN (-3,-4) 
		AND ci.roleid = 1
		AND ci.custid NOT IN (SELECT custid FROM #InputValidCustid_tmp)

	INSERT INTO #InputValidCustid_tmp (CustID, Username, credit)
	SELECT ci.custid, ci.username, ci.credit
	FROM #InputUsernameList AS l 
		INNER JOIN CustDB.dbo.custInfo AS ci WITH (NOLOCK)
		ON l.custid = ci.mrecommend
	WHERE ci.recommend = -3
		AND ci.roleid = 1
		AND ci.custid NOT IN (SELECT custid FROM #InputValidCustid_tmp)

	
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

	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,custid		
		  ,bettype
		  ,betid
		  ,statusID
		  ,recommend
		  ,mrecommend
		  ,srecommend
		  ,winlostdate
		  ,IsMixParlay
		  ,SiteDBGroupID
		  ,IsVoid14
		  ,winlost
		  ,actual_stake
		  ,modds
		  ,transdate 
		  ,checktime 
		  ,hdp1 
		  ,hdp2 
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,betteam 
		  ,betdaqid 
		  ,betfrom 
		  ,statuswinlost 
		  ,odds 
		  ,oddstype 
		  ,betcheck 
		  ,stake 
		  ,Status 
		  ,oddsid 
		  ,CurrencyName
		  ,oddsspread
		  ,Transdesc
		  ,WalletType
		  ,RefCode
		  ,ExtraInfo
		  ,username
		  ,credit
		)
	SELECT matchid
		  ,transid 
		  ,refno
		  ,b.custid		
		  ,b.bettype
		  ,betid
		  ,statusID
		  ,b.recommend
		  ,b.mrecommend
		  ,b.srecommend
		  ,winlostdate
		  ,CASE WHEN b.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END AS IsMixParlay 
		  ,b.SiteDBGroupID
		  ,0 AS IsVoid14
		  ,(winlost - actual_stake) AS winlost
		  ,actual_stake
		  ,modds
		  ,transdate 
		  ,checktime 
		  ,hdp1 
		  ,hdp2 
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,betteam 
		  ,betdaqid 
		  ,betfrom 
		  ,statuswinlost 
		  ,odds 
		  ,oddstype 
		  ,betcheck 
		  ,stake 
		  ,Status 
		  ,oddsid 
		  ,CurrencyName
		  ,oddsspread
		  ,Transdesc
		  ,WalletType
		  ,RefCode
		  ,ExtraInfo
		  ,c.Username
		  ,c.credit
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #InputValidCustid_tmp c ON c.custid = b.custid
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

	---UPDATE column show Affected Ticket popup
	BEGIN
		UPDATE b
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		FROM #tmpTransInfo b
			INNER JOIN dbo.match m WITH (NOLOCK) ON	b.matchid = m.matchid
		WHERE b.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
			AND b.IsVoid14 = 0
			
		UPDATE b
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,eventstatus = ISNULL(m.eventstatus,'')
			,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		FROM #tmpTransInfo b
			INNER JOIN dbo.match m WITH (NOLOCK) ON	b.matchid = m.matchid
		WHERE b.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
			AND b.IsVoid14 = 1

		-- UPDATE eventtype = 2 [Outright bettype]
		IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsVoid14 = 0 AND bettype IN (10)))
		BEGIN
			UPDATE b
			SET matchcode 	= odds.matchcode
				,homeid		= odds.teamid
				,awayid 	= 0
				,leagueid 	= odds.leagueid
				,sporttype 	= l.sporttype
				,eventstatus = ISNULL(odds.oddsstatus,'')
				,SettlementStatus = 0
			FROM #tmpTransInfo b
				INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
				ON	b.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) 
				ON	odds.leagueid = l.leagueid
			WHERE b.bettype IN (10) AND b.IsVoid14 = 0
		END

		IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsVoid14 = 1 AND bettype IN (10)))
		BEGIN
			UPDATE b
			SET matchcode 	= odds.matchcode
				,homeid		= odds.teamid
				,awayid 	= 0
				,leagueid 	= odds.leagueid
				,sporttype 	= l.sporttype
				,eventstatus = ISNULL(odds.oddsstatus,'')
				,SettlementStatus = 0
			FROM #tmpTransInfo b
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
				ON	b.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) 
				ON	odds.leagueid = l.leagueid
			WHERE b.bettype IN (10) AND b.IsVoid14 = 1
		END

		-- update username column
		UPDATE al
		SET username = ci.username
		FROM #tmpTransInfo al
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
				ON al.custid = ci.custid

		-- update Isdeposit
		UPDATE b 
			SET IsDeposit = 1
		FROM #tmpTransInfo b
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = b.srecommend)
	END

	-- get current beingmovebetdate if movebet in-progress, paste @currentdate to get @BeingMovebetDate only
	EXEC [dbo].[NAP_Admin_VerifySettleDate] @Winlostdate = @currentdate, @BeingMovebetDate = @BeingMovebetDate OUTPUT
	
	IF @BeingMovebetDate IS NOT NULL 
		AND EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo WHERE winlostdate = @BeingMovebetDate)
	BEGIN
		SET @IsBeingMovebetdate = 1 --Error msg: The system is running the Movebet process, please wait and try again
	END

	----------End of data prepare-----------------
	--3. TransId in request table
	declare @TransInfoJson			 VARBINARY(MAX)
	declare @pre as table (transid bigint)

	------ info for deployer
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch
		
	DECLARE @debug_message VARCHAR(500)
	SET @MaxRow = (SELECT MAX(ID) FROM #tmpTransInfo)
	SET @Threshold = 20000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold
	IF @ActionId <> 2
	BEGIN
		WHILE (@MaxRow IS NOT NULL)
		BEGIN
		
				SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
						,transid AS 't'
		
						,statusID AS 'sid'
				FROM #tmpTransInfo R
				WHERE ID BETWEEN @StartRow AND @StopRow
					FOR JSON PATH))

					--select @TransInfoJson
				insert into #TransidInRequest
				EXEC DBCTG.bodb02.dbo.TicketVoiding_Test @TransInfoJson = @TransInfoJson

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END

		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END

		DELETE FROM #tmpTransInfo
		WHERE transid IN ( SELECT transid FROM #TransidInRequest) 
		
		SET @NumberOfTickets = @@ROWCOUNT
	END
	--IF @ActionId NOT IN (2)
	--BEGIN
	--	INSERT INTO #TransidInRequest (TransId)
	--	SELECT DISTINCT rs.TransId
	--	FROM  DBCTG.bodb02.dbo.TicketVoiding_Request r WITH (NOLOCK) 
	--		INNER JOIN DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK) ON rs.RequestId = r.RequestId
	--		CROSS APPLY (
	--					SELECT TOP 1 t.MatchId, t.transid, t.StatusId
	--					FROM #tmpTransInfo t
	--					WHERE t.MatchId = rs.MatchId 
	--						AND rs.TransId = t.transid
	--			)t
	--	WHERE r.RequestId <> @RequestId 
	--	AND (r.ActionId NOT IN (2) AND r.IssueTypeId NOT IN (22))
	--	AND 1 = CASE WHEN r.IssueTypeId IN (11,15) AND t.StatusId NOT IN (111,112,113) THEN 1
	--				 WHEN r.IssueTypeId NOT IN (11,15) THEN 1
	--				 ELSE 0 END
					
	--	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	--	BEGIN
	--		SELECT @IsExistedInOtherRequest = 1
	--	END

	--	DELETE FROM #tmpTransInfo
	--	WHERE transid IN ( SELECT transid FROM #TransidInRequest) 
		
	--	SET @NumberOfTickets = @@ROWCOUNT
	--END

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #tmpTransInfo t
									WHERE t.StatusId IN (0,1) AND t.bettype NOT IN (9,29,10)
										AND t.IsVoid14 = 0
									FOR XML PATH('')), 1, 1, '')
									, '')
	END
	ELSE IF @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM DBCTG.bodb02.dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit from to time of Abnormal account issue -> unmark ticket change void time
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #tmpTransInfo tp WHERE rdt.TransId = tp.transid)
												AND rdt.RequestId = @RequestId
												AND rdt.bettype NOT IN (9,29,10)
											FOR XML PATH('')), 1,1,'')
											,'')
			
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
											FROM #tmpTransInfo t
											WHERE t.StatusId IN (0,1) AND t.bettype NOT IN (9,29,10)
												AND t.IsVoid14 = 0
											FOR XML PATH('')), 1, 1, '')
									, '')

		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #tmpTransInfo t
									WHERE t.StatusId IN (0,1) AND t.bettype NOT IN (9,29,10)
										AND t.IsVoid14 = 0
									FOR XML PATH('')), 1, 1, '')
									, '')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CONVERT(VARCHAR(50), rdt.transid)
											FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
												AND rdt.bettype NOT IN (9,29,10)
											FOR XML PATH('')), 1, 1, '')
										,'')
		END
	END

	--Get list match
	SELECT @MatchIDs = STUFF((SELECT DISTINCT  ',' + CAST( m.matchid AS VARCHAR(20))
							  FROM #tmpTransInfo m
							  FOR XML PATH ('')
							),1,1,'')

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo) 
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
		  ,@UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds

	--2. List TransId for case auto void with policy
	;WITH Capicity AS (
		SELECT SUM(CASE WHEN statusid = 112 THEN winlost ELSE 0 END) AS tot_win
			,SUM(CASE WHEN statusid = 113 THEN winlost ELSE 0 END) AS tot_lose
			,t.custid
			,ISNULL(tmp.AdjustLimit, t.credit) AS credit
		FROM #tmpTransInfo t
			INNER JOIN @AdjustVoidLimit_tmp tmp ON tmp.CustId = t.custid
		GROUP BY t.custid, credit, tmp.AdjustLimit
	)
	,RankedData AS (
		SELECT 
			transid,
			winlost,
			custid,
			SUM(winlost) OVER (PARTITION BY custid ORDER BY winlost DESC, matchid ROWS UNBOUNDED PRECEDING) AS RunningTotal
		FROM #tmpTransInfo
		WHERE statusID = 112
	)
	INSERT INTO @tmp_checkedTransId (TransId)
	SELECT transid
	FROM RankedData r
		CROSS APPLY (
			SELECT TOP 1 credit AS credit
			FROM Capicity t
			WHERE t.custid = r.custid
				AND r.RunningTotal <= ABS(t.credit - (ABS(t.tot_lose) - t.tot_win))
		)t

	SELECT b.transid
		,b.refno
		,b.username
		,b.transdate
		,b.stake
		,b.odds
		,b.oddsspread
		,b.OddsType
		,b.Status
		,b.CurrencyName
		,b.betteam
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.betcheck
		,b.Transdesc
		,b.betdaqid
		,b.custid        
		,b.statusID
		,ABS(winlost) AS winlost
		,b.IsVoid14
		,b.matchid
		,b.bettype
		,b.betid
		,b.IsMixParlay
		,b.SiteDBGroupID
		,b.actual_stake
		,b.WalletType
		,b.RefCode
		,b.ExtraInfo
		,b.winlostdate
		,b.IsDeposit
		,b.homeid 
		,b.awayid 
		,b.leagueid 
		,b.IsNeutral
		,b.matchcode 
		,b.SettlementStatus
		,b.sporttype
		,b.matchid AS GroupName
		,b.transid AS subtransid
		,IIF(tmp.TransId IS NOT NULL, 1, 0) AS IsChecked
	FROM #tmpTransInfo b
		LEFT JOIN @tmp_checkedTransId tmp ON tmp.TransId = b.transid

	--3. List members winlost amount for case auto void with policy
	SELECT DISTINCT b.CustId
		,b.username
		,b.credit AS GivenCredit
		,tmp.AdjustLimit AS AdjustVoidLimit
	FROM #tmpTransInfo b
		LEFT JOIN @AdjustVoidLimit_tmp tmp ON tmp.CustId = b.custid
	ORDER BY b.username

	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpTransInfo
	DROP TABLE #InputValidCustid_tmp
END

