/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoid_Update_MP]
(
	@MatchId		INT = 29
	,@RequestID		INT  = 0
	,@UserId		INT = 10278938
	,@UserName		VARCHAR(100) = 'starixIT'
	,@IP			VARCHAR(50)		= '125.227.140.97'
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@VoidingHistoryIds VARCHAR(MAX) = '' OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = '' OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT
)
AS
/*	
	Created by: Max
	Date 20211116
	Task: [TVS] Void abnormal bet of parlay
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20211116@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]

	Param's explanation:	
		
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT 
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@Void_cnt			INT = 0
			,@Recalculate_cnt	INT = 0
			,@TransIDList_tmp	VARCHAR(MAX)= ''
			,@VoidingHistoryIdList VARCHAR(MAX)= ''
			,@query NVARCHAR(MAX) = ''
			,@ExecuteSQL NVARCHAR(MAX) = ''
			,@VoidDataXML       XML = NULL
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@Movebetdate		DATETIME
			,@MatchId_cnt		INT = 0
			,@ThreadHold		INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
			,@totalMainParlay	INT = 0
			,@strRefno		VARCHAR(MAX) = ''

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL
	
	DECLARE @avaiableProcess BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@CustBalance XML
			,@IssueTypeId	TINYINT
			,@winlostdate				DATETIME
			,@isExistParlay				BIT = 0
	
	DECLARE @AutoVoid_ValidRequest AS TABLE (RequestID INT, Transids VARCHAR(MAX), IssueTypeId TINYINT, MinWinlostdate DATETIME, MaxWinlostdate DATETIME)
	DECLARE @VoidingHistory_tmp AS TABLE (RequestID INT, VoidingHistoryId INT, IssueTypeId TINYINT)
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	CREATE TABLE #inputRequestTransId (TransId BIGINT, RequestID INT, IssueTypeId TINYINT, RequestType TINYINT, DecidedBy NVARCHAR(200), ActionId TINYINT)
	DECLARE @tmpInputTransId_VOID TABLE(TransId BIGINT, RequestID INT, IssueTypeId TINYINT, DecidedBy NVARCHAR(200), Winlostdate DATETIME, StatusId TINYINT)
	DECLARE @tmpInputTransId_ReCalculate TABLE(TransId BIGINT, RequestID INT)
	
	DECLARE @tmpBalanceMember TABLE (CustId INT, Balance MONEY)
	DECLARE @tmpMatch_Eventdate TABLE (MatchId INT, Eventdate DATETIME)
	DECLARE @tmpCustCashOut TABLE (CustId INT)		
	DECLARE @tmpCustCashOut_VOID TABLE (CustId INT)
	DECLARE @tmpCustCashOut_Recalculate TABLE (CustId INT)
						
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	CREATE TABLE #tmpTransId_VOID_RequestID (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,Action				VARCHAR(100)
		,RequestID			INT
		,isFinish			BIT 
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		DATETIME
		,srecommend			INT
		,ruben				TINYINT
	)
	
	CREATE TABLE #tmpTransId_Recalculate (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,balanceType		TINYINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,Action				VARCHAR(100)
		,isFinish			BIT
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		DATETIME
		,ruben				TINYINT
	)
	
	DECLARE @tmpTransIDBatch TABLE (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,balanceType		TINYINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,Action				VARCHAR(100)
		,RequestID			INT
		,isFinish			BIT 
	)
	
	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	
	CREATE TABLE #tmpRefCodeSummary_VOID (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
		 ,RequestID	INT
	)
	
	CREATE TABLE #tmpRefCodeSummary_Recalculate (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
		 ,RequestID	INT
	)
	
	SET @StartTime = GETDATE()
	SET @LogActionId = 90504
	SET @SB_Error = 0
	SET @strRefno = ''

	SET @session = CAST(NEWID() AS NVARCHAR(50))	
	SET @IssueTypeId = 11

	
	--get list VIP Account
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.Dep_CustVIP WITH (NOLOCK)	
								'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
	INSERT INTO @VIPAccount_tmp(CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

	--get list Transid in request
	BEGIN
		INSERT INTO #inputRequestTransId (TransId, RequestID, IssueTypeId, RequestType, DecidedBy, ActionId)
		SELECT  rds.transid, @RequestID, req.IssueTypeId, rd.RequestType, req.DecidedBy, req.ActionId
		FROM dbo.TicketVoiding_Request req WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK) ON rds.RequestId = req.RequestId
		WHERE req.RequestId = @RequestID
	END

	--Check duplicate transid belong multi request--
	IF EXISTS (SELECT TOP (1) 1 FROM #inputRequestTransId GROUP BY TransId HAVING COUNT(1) > 1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = 'Some tickets of this match are being duplicated in multi requests!'	
		RETURN
	END
	
	-- get transid to VOID
	INSERT INTO @tmpInputTransId_VOID (TransId, RequestID, IssueTypeId, DecidedBy, Winlostdate, StatusId)
	SELECT t.TransId, t.RequestID, t.IssueTypeId, t.DecidedBy, b.winlostdate, statusID
	FROM #inputRequestTransId t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
		OUTER APPLY (SELECT TOP (1) ac.CustID 
					 FROM @VIPAccount_tmp ac 
					 WHERE  ac.CustID = b.custid
					 ) AS vip
	WHERE b.matchid = 29 AND b.bettype = 29
		AND 1 = CASE
				WHEN b.statusID = 0 AND t.RequestType = 3 AND t.ActionId = 1 AND b.statuswinlost IN (1,2) THEN 1 --Auto void winning request, void VIP + normal member
				WHEN b.statusID = 0 AND t.RequestType = 3 AND t.ActionId IN (4,8) THEN 1 --Auto void Instant & NoPolicy, void VIP + normal member
				WHEN b.statusID = 0 AND t.RequestType = 1 AND vip.CustID IS NULL THEN 1 -- Void Instant Request
				WHEN b.statusID = 0 AND t.RequestType <> 1 AND b.statuswinlost IN (1,2) AND vip.CustID IS NULL THEN 1 -- Auto void winning request
			ELSE 0 END
		
	SET @Void_cnt = @Void_cnt + @@ROWCOUNT
	
	-- get transid to unmark and resettle
	INSERT INTO @tmpInputTransId_ReCalculate (TransId)
	SELECT DISTINCT t.TransId
	FROM #inputRequestTransId t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
		OUTER APPLY  (SELECT TOP (1) ac.CustID 
					 FROM @VIPAccount_tmp ac 
					 WHERE  ac.CustID = b.custid
					 ) AS vip
	WHERE b.matchid = 29 AND b.bettype = 29
		AND 1 = CASE 
				WHEN b.statusID = 0 AND t.RequestType = 3 AND t.ActionId = 1 AND b.statuswinlost IN (1,2) THEN 0
				WHEN b.statusID = 0 AND t.RequestType = 3 AND t.ActionId IN (4,8) THEN 0 
				WHEN b.statusID = 0 AND b.statuswinlost IN (0,3,4) THEN 1
				WHEN b.statusID = 0 AND vip.CustID IS NOT NULL AND b.statuswinlost IN (1,2) AND t.RequestType <> 3 THEN 1
			  ELSE 0 END
				
	SET @Recalculate_cnt = @@ROWCOUNT
	
	IF @Void_cnt = 0 AND @Recalculate_cnt = 0
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = 'No ticket found.'	

		RETURN
	END
	-------------DATA PREPARATION ------------
	INSERT INTO #tmpTransId_VOID_RequestID(TransId, custid, bettype, KeyId, TicketType, betdaqid, extrainfo, refcode, betid,RequestID, matchid, oddsid, winlostdate, Refno, srecommend, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 1 AND b.bettype NOT IN (911, 912, 913) THEN 3
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			, t.RequestID
			,b.matchid, b.oddsid, t.Winlostdate, b.refno, b.srecommend,b.ruben
	FROM @tmpInputTransId_VOID AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo, refcode, betid, matchid, oddsid, winlostdate, Refno, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
			,1 AS balanceType
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 1 AND b.bettype NOT IN (911, 912, 913) THEN 3
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid, b.matchid, b.oddsid, b.winlostdate, b.refno, b.ruben
	FROM @tmpInputTransId_ReCalculate AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId_VOID_RequestID bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	-- check and not allow attempt to settlement same game while it's still not finish
	SET @isExistParlay	= 1

	INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
	SELECT b.matchid, b.Refno
	FROM 
		(
			SELECT v.matchid, v.Refno
			FROM #tmpTransId_VOID_RequestID v
			WHERE v.matchid IN (9,29) --NOT 2799: Virtual Sport
			UNION ALL
			SELECT r.matchid, r.Refno
			FROM #tmpTransId_Recalculate r
			WHERE r.matchid IN (9,29) --NOT 2799: Virtual Sport
		)b
	
	SET @totalMainParlay = @@ROWCOUNT

	EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	-- Apply new way to lock parlay tickets	
	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold 
	BEGIN
		IF @totalMainParlay > 0 
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				 @IsLockingByRefno	= 1
				,@spName			= @spName
				,@Session			= @Session
				,@avaiableProcess 	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN
				SET @ErrCode = 9999
				RETURN
			END
		END
				
	END
	ELSE IF @totalMainParlay > @ThreadHold
	BEGIN
		--check settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay 				= @isExistParlay
			, @spName					= @spName
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN
			SET @ErrCode = 9999
				
			RETURN
		END
	END	
	
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID) AND @Recalculate_cnt = 0)
	BEGIN
		IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
		BEGIN
			IF @totalMainParlay	> 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1				
			END
		END
		ELSE IF @totalMainParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					, @IsReleased				= 1
		END
		
		SELECT	@ErrCode = 0
				,@ErrMsg = 'No ticket found.'				
		RETURN
	END	
	
	-- Capture request and its void tickets to insert voidingHistory
	INSERT INTO @AutoVoid_ValidRequest (RequestID, IssueTypeId, Transids, MinWinlostdate, MaxWinlostdate)			
	SELECT DISTINCT r.RequestID, r.IssueTypeId, STUFF(tmp.Transids,1,1,'') AS Transids, r.MinWinlostdate, r.MaxWinlostdate
	FROM(
		  SELECT DISTINCT RequestID, IssueTypeId, MIN (Winlostdate) AS MinWinlostdate, MAX( Winlostdate) AS MaxWinlostdate
		  FROM @tmpInputTransId_VOID
		  GROUP BY RequestID, IssueTypeId 
		) AS r
		CROSS APPLY (SELECT ',' + CAST(v.transid AS VARCHAR(50))
					FROM @tmpInputTransId_VOID v
					WHERE v.RequestID = r.RequestID
					FOR XML PATH ('')
					) AS tmp (Transids)
	
	-- Insert more bonus or cash ticket in case only one ticket appears in #tmpTransId	
	INSERT INTO #tmpRefCodeSummary_VOID (RefCode, custid, bettype, transid,requestID)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid, requestID
	FROM	#tmpTransId_VOID_RequestID t
	WHERE	t.refcode IS NOT NULL 
	GROUP BY t.refcode, t.custid, t.bettype, RequestID
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId_VOID_RequestID (TransId, custid, bettype, KeyId, TicketType, refcode, RequestID, betid)
		SELECT b.TransId, b.custid, b.bettype
		,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
		, 1, b.refcode, r.RequestID, b.betid
		FROM #tmpRefCodeSummary_VOID r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = r.bettype
			)f
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID WHERE b.transid = TransId)
	END
	INSERT INTO #tmpRefCodeSummary_Recalculate(RefCode, custid, bettype, transid)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid
	FROM	#tmpTransId_Recalculate t
	WHERE	t.refcode IS NOT NULL 
	GROUP BY t.refcode, t.custid, t.bettype
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, KeyId, balanceType, TicketType, refcode)
		SELECT b.TransId, b.custid, b.bettype
		,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
		, 1, 1, b.refcode
		FROM #tmpRefCodeSummary_Recalculate r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = r.bettype
			)f
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate WHERE b.transid = TransId)
				
	END
	
	----------------- END OF PREPARATION -----------------------------------	
	-----------STARTING FOR VOID AND RE-Calculation-------------------------
	---------- Starting for Voiding Process ------------------------------------

	--Get data before update	
	--capture balance before voiding & recal
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost 
					- CASE 
						WHEN t.TicketType = 5 THEN t.actual_stake -- get actual_stake from translog
						ELSE b.actual_stake 
					END 
					+ b.playercomm AS balance
		FROM #tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost 
					- CASE 
						WHEN t.TicketType = 5 THEN t.actual_stake -- get actual_stake from translog
						ELSE b.actual_stake 
					END 
					+ b.playercomm AS balance
		FROM #tmpTransId_Recalculate  t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914
		
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType
	

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WITH (NOLOCK) WHERE RequestID = @RequestID)
	BEGIN
		SET @VoidDataXML = ( SELECT DISTINCT 
									'starixIT' AS "@CreatorName"
									,a.DecidedBy AS "@DecidedBy"
									,MIN(CONVERT(VARCHAR, a.Winlostdate, 101)) AS "@VoidFromDate"
									,MAX(CONVERT(VARCHAR, a.Winlostdate, 101)) AS "@VoidToDate"
									,MAX (CASE WHEN a.statusID IN (111, 112, 113) THEN 1 ELSE 0 END) AS "@IsHasSettledTicket"
							FROM @tmpInputTransId_VOID a
							WHERE a.IssueTypeId = 13
							GROUP BY a.DecidedBy
							FOR XML PATH('VoidData')
							)
		
		-- Insert Voiding History first
		INSERT INTO dbo.TicketVoiding_VoidingHistory (RequestId, UserId, StatusId, TransIds, VoidData, MinWinlostdate, MaxWinlostdate)
		OUTPUT INSERTED.RequestID
				,INSERTED.VoidingHistoryId
		INTO @VoidingHistory_tmp (RequestID,VoidingHistoryId)	
		SELECT  RequestID
				,@UserId
				, 1
				,CASE WHEN IssueTypeId IN (11,15) THEN TransIds ELSE NULL END
				,@VoidDataXML
				,CASE WHEN IssueTypeId = 13 THEN MinWinlostdate ELSE NULL END
				,CASE WHEN IssueTypeId = 13 THEN MaxWinlostdate ELSE NULL END
		FROM @AutoVoid_ValidRequest

		UPDATE v SET v.IssueTypeId = r.IssueTypeId
		FROM @VoidingHistory_tmp v
			INNER JOIN @AutoVoid_ValidRequest r ON r.RequestID = v.RequestID
	END

	SELECT @VoidingHistoryIds = STUFF((SELECT ',' + CAST(VoidingHistoryId AS VARCHAR(50)) FROM @VoidingHistory_tmp FOR XML PATH('')),1,1,'')

	-- Insert for WEB Auto Service PROCESS
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
						INNER JOIN @VoidingHistory_tmp t ON t.RequestID = s.RequestID AND t.VoidingHistoryId = s.VoidingHistory)
	BEGIN
		DECLARE @sessionID INT = 0
		SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1

		INSERT INTO Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistory,statusID,matchID,SessionID,IsAutoVoid)
		SELECT vh.RequestID, vh.VoidingHistoryId,1,CASE WHEN vh.IssueTypeId <> 13 THEN @MatchId ELSE NULL END,@sessionID,1
		FROM @VoidingHistory_tmp vh
	END
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
		
	INSERT INTO @tmpMatch_Eventdate (MatchId, Eventdate)
	SELECT DISTINCT t.MatchId, t.winlostdate
	FROM (
			SELECT t.matchid, t.winlostdate
			FROM #tmpTransId_VOID_RequestID t
			UNION ALL
			SELECT r.matchid, r.winlostdate
			FROM #tmpTransId_Recalculate r
		 )t
	
	SELECT @MatchId_cnt = COUNT(MatchId)
	FROM @tmpMatch_Eventdate t

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatch_Eventdate WHERE Eventdate <= @Movebetdate)
	BEGIN
		DECLARE @tblMatchProcess_1 TABLE (matchid INT, KeyID TINYINT)
		DECLARE @tblCashOutProcess_1 TABLE (transid BIGINT)

		DELETE 
		FROM #tblMatchProcess
		OUTPUT	DELETED.matchid, DELETED.KeyID
		INTO  @tblMatchProcess_1 (matchid, KeyID)
		WHERE matchid NOT IN (SELECT matchid FROM @tmpMatch_Eventdate WHERE Eventdate <= @Movebetdate)

		------ releasing process
		EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay 				= @isExistParlay
				, @IsReleased				= 1

		DELETE #tblMatchProcess
		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT matchid, KeyID FROM @tblMatchProcess_1

		IF (@MatchId_cnt = 1) OR (NOT EXISTS (SELECT TOP 1 1 FROM @tblMatchProcess_1))
		BEGIN
			SELECT	@ErrCode = 99
					,@ErrMsg = 'Match is under Movebet process, could not void ticket.'

			RETURN
		END	
		ELSE
		BEGIN
			SELECT @MoveBetMatchIds = STUFF((SELECT DISTINCT  ',' + CAST( m.matchid AS VARCHAR(20))
							FROM @tmpMatch_Eventdate m
							WHERE eventdate <= @Movebetdate
							FOR XML PATH ('')
						),1,1,'')

			DELETE t
			FROM #tmpTransId_VOID_RequestID t
				INNER JOIN @tmpMatch_Eventdate m 
			ON t.matchid = m.matchid  AND t.winlostdate <= @Movebetdate
				
			DELETE r
			FROM #tmpTransId_Recalculate r
				INNER JOIN @tmpMatch_Eventdate m 
			ON r.matchid = m.matchid  AND r.winlostdate <= @Movebetdate	 	
					 	 
		END
	END

	BEGIN TRY			  
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT DELETED.TransId,DELETED.custid, DELETED.Refno, DELETED.bettype, DELETED.TicketType, DELETED.isSubTransaction,DELETED.RequestID, DELETED.betid, DELETED.actual_stake
					
			INTO @tmpTransIDBatch(TransId,custid, Refno, bettype, TicketType, isSubTransaction,RequestID,betid,actual_stake)
			FROM #tmpTransId_VOID_RequestID t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
			-- backup into zzzbettrans for void transid
			INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
					,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
					,betteam, creator, refno, winlostdate, betfrom
					,betcheck
					,comstatus
					,checktime, matchid, bettype  
					,VoidingHistoryId
				)  
			SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
				,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
				,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
				,CASE 
					WHEN t.TicketType = 3 THEN @session -- original ticket & cashout bet ticket
					ELSE b.betcheck END AS betcheck 
				,CASE WHEN t.TicketType = 3 AND t.isSubTransaction = 1 THEN 'CO' ELSE b.comstatus END
				,b.checktime, b.matchid, b.bettype  
				,vd.VoidingHistoryId
			FROM @tmpTransIDBatch AS t 
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.TransId
				INNER JOIN @VoidingHistory_tmp vd ON t.RequestID = vd.RequestID
			
			-- Auto Void
			SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									,CASE WHEN t.TicketType = 5 THEN t.Refno ELSE NULL END AS '@translogid'
									,t.betid AS '@betid'
									,CASE WHEN t.TicketType = 5 THEN 1 ELSE NULL END AS '@isMG'
									,CASE WHEN t.TicketType = 5 THEN t.actual_stake ELSE NULL END AS '@actual_stake'
									,t.isSubTransaction AS '@IsCashOutMember'
									FROM	@tmpTransIDBatch t
									FOR XML PATH('r'), ROOT('root')
								)
			EXEC dbo.TicketVoiding_Admin_VoidingTransId 
				@TransIds = @xmlTransId
				,@UserId = @UserId
				,@IssueTypeId = 11
				,@IsAbnormalMixParlay = 1
				
			SET @xmlTransId = ''	 
			
		END
			
		-- Recal for ticket Lose by statuswinlost
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT deleted.transid, deleted.Refno
			INTO @tmpTransIDBatch(TransId, Refno)
			FROM #tmpTransId_Recalculate t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
								
			SET @TransIDList_tmp = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) FROM @tmpTransIDBatch FOR XML PATH('')),1,1,'')
			
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @TransIDList_tmp
				,@UserId = @UserId
				,@Username = @Username
				,@IP = @IP
				,@LogActionId = 90510
				,@IsLockMatch = 0
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT
			
			SELECT	@strRefno = @strRefno + ',' + CONVERT(VARCHAR(20), Refno) + '|' + CONVERT(VARCHAR(20), TransId)
			FROM	@tmpTransIDBatch

			EXEC dbo.NAP_Admin_Calculate_MP_broker   
				@matchdate = ''  
				,@strXML = @strRefno  
				,@mode  = '29'	
			
			SET @TransIDList_tmp = ''
			SET @strRefno = ''
				 
		END
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		INSERT INTO @AfterUpd(
			matchid
			,custid
			,balanceType		
			,walletType
			,bonusId
			,balance
		)
		SELECT	@matchid
				,b.custid
				,b.balanceType
				,b.WalletType
				,b.BonusID			
				,SUM(b.balance) AS balance
		FROM (	
			SELECT	b.custid
					,CASE 
						WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
						WHEN t.sporttype = 162 THEN 3 -- Casino
						ELSE 4  -- Others
					   END AS balanceType
					,CASE 
						WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,CASE
						WHEN t.isSubTransaction = 1 THEN 2
						ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
					
			FROM #tmpTransId_VOID_RequestID t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
			UNION ALL
			SELECT	b.custid
					,t.balanceType
					,CASE 
						WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,CASE
						WHEN t.isSubTransaction = 1 THEN 2
						ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
			FROM	#tmpTransId_Recalculate t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
					
			UNION ALL
			
			SELECT b914.custid
					,1 AS balanceType
					,0 AS BonusId
					,2 AS WalletType
					,b914.winlost - b914.actual_stake + b914.playercomm AS balance
			FROM	@tmpCustCashOut c
				INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
					ON	b914.matchid = @MatchId
						AND b914.custid = c.CustId
						AND b914.bettype = 914
		)b
		GROUP BY b.custid
				,b.balanceType
				,b.BonusID
				,b.WalletType

		--UPDATE balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				@BalanceWalletBefore	= @beforeUpd
				, @BalanceWalletAfter	= @afterUpd
				, @ActionId				= 0	
		
		SELECT    @ErrCode = 1001017 
					,@ErrMsg = ERROR_MESSAGE()
	        
		DELETE tv
		FROM TicketVoiding_VoidingHistory tv WITH (ROWLOCK)
			INNER JOIN @VoidingHistory_tmp  t ON tv.VoidingHistoryId = t.VoidingHistoryId
			
		RETURN 
		 
	END CATCH
	
	--- Capture balance after
	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
				
		FROM #tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		UNION ALL
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId_Recalculate t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--UPDATE balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd
			, @ActionId				= 0	
	
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(a.custid AS VARCHAR(20)) + ','
	FROM	@BeforeUpd b
		INNER JOIN @AfterUpd a
			ON b.custid = a.custid
	WHERE	b.balance > a.balance

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	-- Update BetTradeSellingCancelled information
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_VOID_RequestID t
	WHERE	t.bettype = 911
	GROUP BY t.custid

	EXEC dbo.TicketVoiding_BalanceMember_Select 
		@CustIds = @CustIds
		,@CustBalance = @CustBalance OUTPUT

	INSERT INTO @tmpBalanceMember (CustId, Balance)
	SELECT	T.C.value('./@c', 'int')
			,T.C.value('./@b', 'money')
	FROM	@CustBalance.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustBalance = NULL ))

	;WITH CTE_Source AS
		(
			SELECT	bts.TradeID AS TradeID
					,bts.TicketID AS [TicketID]					
					,'SB void ticket due to ' AS [Remark]
					,sub.awinlost AS [BTBuyBack]
					,0 AS [BTComission]
					,c.Balance AS [AfterBalance]
					,'SB' AS [Owner]
					,1 AS [Cancelled]
					,GETDATE() AS [ChangeDate]
					,GETDATE() AS [CreateDate]
			FROM	#tmpTransId_VOID_RequestID sub						 											 
				 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
						 ON bts.TicketID = sub.refno -- bettrade + cash-out
							AND CASE																				 
									WHEN sub.bettype = 911 -- cash-out													 
											THEN CASE
													WHEN bts.SoldTicketID = sub.transid THEN 1
													ELSE 0
												 END																							
									ELSE 1
								END = 1	
				 INNER JOIN @tmpBalanceMember c
						 ON sub.custid = c.custid						 							
			WHERE sub.BetType = 911
		)
		MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
		USING (SELECT * FROM CTE_Source) AS [Source]
		ON [Target].TradeID = [Source].TradeID
		WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
									,[BTBuyBack] = [Source].[BTBuyBack]
									,[BTComission] = [Source].[BTComission]
									,[AfterBalance] = [Source].[AfterBalance]
									,[Owner] = [Source].[Owner]
									,[Cancelled] = [Source].[Cancelled]
									,[ChangeDate] = [Source].[ChangeDate]										
		WHEN NOT MATCHED THEN INSERT(TradeID
									,[TicketID]										
									,[Remark]
									,[BTBuyBack]
									,[BTComission]
									,[AfterBalance]
									,[Owner]
									,[Cancelled]
									,[ChangeDate]
									,[CreateDate])
							  VALUES([Source].TradeID
									,[Source].[TicketID]										
									,[Source].[Remark]
									,[Source].[BTBuyBack]
									,[Source].[BTComission]
									,[Source].[AfterBalance]
									,[Source].[Owner]
									,[Source].[Cancelled]
									,[Source].[ChangeDate]
									,[Source].[CreateDate]); 

	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
	BEGIN
		IF @totalMainParlay	> 0 
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
				,@Session	= @Session
				,@IsReleased = 1				
		END				
	END
	ELSE IF @totalMainParlay > @ThreadHold
	BEGIN
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					, @IsReleased				= 1
	END
	
	----------------Insert Max Payout Queue----------------
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID WHERE bettype = 29)
	BEGIN
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #tmpTransId_VOID_RequestID t
								GROUP BY custid, ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
	END
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate WHERE bettype = 29)
	BEGIN
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #tmpTransId_Recalculate t
								GROUP BY custid, ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
	END

	-------------------------------------------------------
	--Insert data for TicketVoiding_Queue
	SET @EndTime = GETDATE()
	INSERT INTO dbo.TicketVoiding_Queue (
		RequestId
		,MatchId
		,VoidingHistoryId
		,TransIds
		,StatusId
		,UserId
		,Ip
		,VoidingTypeId
		,TotalTicket
		,Starttime
		,Exectime
		,Duration
	)
	SELECT	vh.RequestID
			,@MatchId
			,vh.VoidingHistoryId
			,vr.Transids
			,2 -- completed
			,@UserId
			,@IP
			,1
			,tmp.TotalTicket
			,@StartTime AS starttime
			,@StartTime AS Exectime
			,DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS Duration
	FROM @VoidingHistory_tmp vh
		INNER JOIN @AutoVoid_ValidRequest vr ON vh.RequestID = vr.RequestID
		CROSS APPLY (SELECT COUNT(1) AS TotalTicket
					FROM #tmpTransId_VOID_RequestID t
					WHERE t.RequestID = vh.RequestID) AS tmp
		
	-- Write Log
	DECLARE @allTransId_Void VARCHAR(MAX) = ''
	DECLARE @allTransId_Recal VARCHAR(MAX) = ''
	
	SELECT	@allTransId_Void = @allTransId_Void + CAST(transid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_VOID_RequestID
	
	SELECT	@allTransId_Recal = @allTransId_Recal + CAST(transid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_Recalculate

	SET @EndTime = GETDATE()
	SET @VoidingHistoryIdList = STUFF((SELECT ',' + CAST(VoidingHistoryId AS VARCHAR(50)) FROM @VoidingHistory_tmp FOR XML PATH('')),1,1,'')
	SET @LogData = CAST((SELECT CASE WHEN @RequestId > 0 THEN @RequestId ELSE 0 END AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,@MatchId AS '@MatchId'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + @VoidingHistoryIdList
								+ ' Auto Void TransId: ' + @allTransId_Void
								+ ' Auto Recalculate TransId: ' + @allTransId_Recal
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))
	
	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #inputRequestTransId
	DROP TABLE #tmpTransId_Recalculate
	DROP TABLE #tmpTransId_VOID_RequestID
	DROP TABLE #tmpRefCodeSummary_Recalculate
	DROP TABLE #tmpRefCodeSummary_VOID
	DROP TABLE #tblMatchParlayProcess

END

GO

