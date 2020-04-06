/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoid_Update]
	@MatchId		INT
	,@sporttype		SMALLINT = 1
	,@UserId		INT = 10278938
	,@UserName		VARCHAR(100) = 'starixIT'
	,@Action		VARCHAR(100) = NULL
	,@RequestIdList VARCHAR(MAX) = NULL
	,@IP			VARCHAR(50)		= '125.227.140.97'
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
AS
/*	Created by: Helen
	Date 20200212
	Task: [TVS] Abnormal Void Bets Automation
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Helen:[TVS] Abnormal Void Bets Automation [Redmine:#127398]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis[Redmine:#131516]
	
	Param's explanation:	
		
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT 
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@Void_cnt			INT
			,@Recalculate_cnt	INT
			,@TransIDList_tmp	VARCHAR(MAX)= ''
			,@VoidingHistoryIdList VARCHAR(MAX)= ''
			,@IsTest			BIT = 0
			,@IsMatchCalHT	BIT = 0
			,@IsMatchCalFT_All	BIT = 0
			
			,@RequestId INT
			,@LeagueId			INT
			,@HomeId			INT
			,@AwayId			INT
			,@KickOffTime	DATETIME	
			,@IsCalEarly	BIT = 0
			,@IsCalEarlyQueue BIT = 0
			
			, @query NVARCHAR(MAX) = ''
			, @ExecuteSQL NVARCHAR(MAX) = ''
			, @IsActiveVoidWinning BIT = 0
			
	DECLARE @avaiableProcess BIT
			,@isExistMatch BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@CustBalance XML
			,@IssueTypeId	TINYINT
			,@CustIdsCashOut VARCHAR(MAX)
	
	DECLARE @AutoVoid_InputRequest_tmp AS TABLE (RequestID INT)
	DECLARE @AutoVoid_ValidRequest AS TABLE (RequestID INT, Transids VARCHAR(MAX))
	DECLARE @VoidingHistory_tmp AS TABLE (RequestID INT, VoidingHistoryId INT)
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	CREATE TABLE #inputRequestTransId (TransId BIGINT, RequestID INT, RequestType TINYINT)
	DECLARE @tmpInputTransId_VOID TABLE(TransId BIGINT, RequestID INT)
	DECLARE @tmpInputTransId_ReCalculate TABLE(TransId BIGINT, RequestID INT)
	
	DECLARE @tmpBalanceMember TABLE (CustId INT, Balance MONEY)
	
	DECLARE @tmpCustCashOut TABLE (CustId INT)		
	DECLARE @tmpCustCashOut_VOID TABLE (CustId INT)
	DECLARE @tmpCustCashOut_Recalculate TABLE (CustId INT)
						
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	CREATE TABLE #tmpTransId_VOID_RequestID (
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
	
	DECLARE @tblRequestList AS TABLE (QueueID INT, Matchid INT, RequestID INT)
	DECLARE @tblMatchid_abnormal AS TABLE (matchid INT)
	DECLARE @ProblemAccount_tmp AS TABLE (CustID INT)
	
	CREATE TABLE #Transid_mark_void (transid BIGINT,isFinish BIT )
	CREATE TABLE #Transid_mark_tmp (transid BIGINT, statuswinlost TINYINT)
	
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

	SET @session = CAST(NEWID() AS NVARCHAR(50))	
	
	SELECT @IsMatchCalHT = MAX(CASE WHEN Action = 'CAL-HT' THEN 1 ELSE 0 END)
			, @IsMatchCalFT_All =MAX( CASE WHEN Action IN ('CAL-FT','CAL') THEN 1 ELSE 0 END)
			, @IsCalEarlyQueue = MAX(CASE WHEN Action IN ('CAL-EARLY','CAL_EAR') THEN 1 ELSE 0 END)
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
	WHERE matchid = @MatchId
	
	SELECT  @LeagueId = m.leagueid, @HomeId = homeid, @AwayId = awayid, @KickOffTime = kickofftime, @IsTest = l.isTest
	FROM dbo.match m WITH (NOLOCK)
		INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE matchid = @MatchId		
	
	IF @Action IN ('CAL-EARLY','CAL_EAR')	
		SET @IsCalEarly = 1
			
	IF @RequestIdList IS NOT NULL
	BEGIN
		INSERT INTO @AutoVoid_InputRequest_tmp (RequestID)
		SELECT	val AS RequestID
		FROM	dbo.f_SplitString(@RequestIdList, ',')
		OPTION (maxrecursion 0)
		
		INSERT INTO #inputRequestTransId (TransId,RequestID,RequestType)
		SELECT  tmp.transid,r.RequestID,rd.RequestType
		FROM @AutoVoid_InputRequest_tmp r
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON r.RequestID = rd.RequestId 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (SELECT val AS transid
						 FROM dbo.f_SplitString(rd.TransIds, ',')
						) AS tmp
		WHERE req.IssueTypeId = 11 AND rd.MatchId = @MatchId 
			AND req.ActionId = 1 -- void request only, not for take notes and waiting
		OPTION (maxrecursion 0)
	END
	ELSE
	BEGIN
		SET @IsActiveVoidWinning = (SELECT TOP (1) IsActive 
								FROM DBCUST.CUSTDB.dbo.ProblemAccountAction WITH (NOLOCK) 
								WHERE ActionID = 2)
								
		IF @IsActiveVoidWinning = 1
		BEGIN
			SELECT  @query = N''		
			SELECT	@query = @query + N'SELECT Custid 
										FROM dbo.ProblemAccount WITH (NOLOCK)	
										WHERE Actionid = 2 and SubIssueTypeId = 38'
			SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'

			INSERT INTO @ProblemAccount_tmp (CustID)
			EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query
		
			-- check and create request first for auto mark ticket or marked manually
			IF @@ROWCOUNT > 0
			BEGIN
				INSERT INTO #Transid_mark_tmp (transid,statuswinlost)
				SELECT b.transid, b.statuswinlost
				FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
					INNER LOOP JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = mt.TransId AND b.statusID = 0 
					CROSS APPLY (SELECT TOP (1) custid
								FROM @ProblemAccount_tmp pa
								WHERE pa.CustID = b.CustId ) pa_tmp
					OUTER APPLY (SELECT TOP 1 rd.RequestId
								FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
									INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId
								WHERE mt.MatchId = rd.MatchId AND r.IssueTypeId = 11 
									AND r.ActionId = 1 
									AND CHARINDEX(',' + CAST(mt.TransId AS VARCHAR(50)) + ',', ',' + rd.TransIds + ',') > 0
								) AS tmp
					LEFT JOIN dbo.f_Set_GetEarlyBettypes() eb ON eb.bettype = b.bettype	
				WHERE mt.MatchId = @MatchId 
					AND tmp.RequestId IS NULL
					AND b.statuswinlost IN (0,1,2,3,4)
					AND (@IsCalEarly = 0 OR (@IsCalEarly = 1 AND eb.bettype IS NOT NULL ))
					
				INSERT INTO #Transid_mark_void (transid)
				SELECT transid
				FROM #Transid_mark_tmp
				WHERE statuswinlost IN (1,2)
			END
		END
		
		IF EXISTS (SELECT TOP (1) 1 FROM #Transid_mark_void)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
				
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId
				INTO @tmpTransIDBatch(TransId)
				FROM #Transid_mark_void t 
				WHERE isFinish IS NULL
				
				IF @@ROWCOUNT = 0 BREAK
				
				SET @TransIDList_tmp = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) FROM @tmpTransIDBatch FOR XML PATH('')),1,1,'')
				
				-- Create new request here
				INSERT INTO dbo.TicketVoiding_Request (Sporttype, SubIssueTypeId, ActionId, Provider, Source, DecidedBy, MistakenBy, Remark, UserId, LastModifiedBy, IsTest, IssueTypeId)
				SELECT @Sporttype, 38, 1, NULL, NULL, 'Abnormal Data Investigate', NULL, NULL, @UserId, @UserId, @IsTest, 11

				SET @RequestId = SCOPE_IDENTITY()
			
				INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, KickOffTime, TransIds,RequestType)
				SELECT @RequestId, @MatchId, @LeagueId, @HomeId, @AwayId, @KickOffTime, @TransIDList_tmp, 2
					
				SET @TransIDList_tmp = ''	 
				
			END
		END	
	
		-- get all transid from all requests
		INSERT INTO #inputRequestTransId (RequestID,TransId)
		SELECT  req.RequestID, tmp.transid
		FROM dbo.TicketVoiding_Request req WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (SELECT val AS transid
						 FROM dbo.f_SplitString(rd.TransIds, ',')
						) AS tmp
		WHERE req.IssueTypeId = 11 AND rd.MatchId = @MatchId 
			AND req.ActionId = 1 -- void request only, not for take notes and waiting
		OPTION (maxrecursion 0)
		
	END
	-- get transid to VOID
	INSERT INTO @tmpInputTransId_VOID (TransId, RequestID)
	SELECT t.TransId, t.RequestID
	FROM #inputRequestTransId t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
		INNER JOIN dbo.f_Set_GetGroupBettypes() f ON b.bettype = f.BetType 
		LEFT JOIN  dbo.f_Set_GetEarlyBettypes() eb ON eb.bettype = b.bettype
	WHERE b.matchid = @MatchId 
		AND b.statuswinlost IN (1,2) 
		AND b.statusID = 0
		AND 1 = CASE 
					 WHEN @sporttype IN (2,9,43,5) AND @Action = 'CAL' AND @IsCalEarly = 0 AND f.GroupId IN (1,2,10,11,7) THEN 1
					 WHEN @IsCalEarly = 0 AND @Action IN ('CAL', 'CAL-HT','AddRequest') AND f.GroupId IN (1,3, 7) AND @IsMatchCalHT = 1 THEN 1
					 WHEN @IsCalEarly = 0 AND @Action IN ('CAL', 'CAL-FT','AddRequest') AND f.GroupId IN (2,4,1,3, 7) AND @IsMatchCalFT_All = 1 THEN 1
					 WHEN @IsCalEarlyQueue = 1 AND eb.bettype IS NOT NULL THEN 1
					 ELSE 0
				END
				
	SET @Void_cnt = @@ROWCOUNT
	
	-- get transid to unmark and resettle
	INSERT INTO @tmpInputTransId_ReCalculate (TransId)
	SELECT DISTINCT t.TransId
	FROM (SELECT transid 
		FROM #inputRequestTransId 
		UNION  
		SELECT transid 
		FROM #Transid_mark_tmp
		WHERE statuswinlost IN (0,3,4)
		
		) AS t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid 
		INNER JOIN dbo.f_Set_GetGroupBettypes() f ON b.bettype = f.BetType
		LEFT  JOIN dbo.f_Set_GetEarlyBettypes() eb ON eb.bettype = b.bettype
	WHERE b.matchid = @MatchId AND b.statuswinlost IN (0,3,4) AND b.statusID = 0
		AND 1 = CASE 
					 WHEN @sporttype IN (2,9,43,5) AND @Action = 'CAL' AND @IsCalEarly = 0 AND f.GroupId IN (1,2,10,11,7) THEN 1
					 WHEN @IsCalEarly = 0 AND @Action IN ('CAL', 'CAL-HT','AddRequest') AND f.GroupId IN (1,3,7) AND @IsMatchCalHT = 1 THEN 1
					 WHEN @IsCalEarly = 0 AND @Action IN ('CAL', 'CAL-FT','AddRequest') AND f.GroupId IN (2,4,1,3,7) AND @IsMatchCalFT_All = 1 THEN 1
					 WHEN @IsCalEarlyQueue = 1 AND eb.bettype IS NOT NULL THEN 1
					 ELSE 0
				END
				
	SET @Recalculate_cnt = @@ROWCOUNT
	
	IF @Void_cnt = 0 AND @Recalculate_cnt = 0
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = 'No ticket found.'	
		RETURN
	END
	-------------DATA PREPARATION ------------
	INSERT INTO #tmpTransId_VOID_RequestID(TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo, refcode, betid,RequestID)
	SELECT	b.transid, b.custid, b.bettype
			,1 KeyId
			,1 AS balanceType
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 1 AND b.bettype NOT IN (911, 912, 913) THEN 3
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			, t.RequestID
	FROM @tmpInputTransId_VOID AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	
	INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo, refcode, betid)
	SELECT	b.transid, b.custid, b.bettype
			,1 KeyId
			,1 AS balanceType
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 1 AND b.bettype NOT IN (911, 912, 913) THEN 3
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
	FROM @tmpInputTransId_ReCalculate AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	
	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId
			
	SELECT	@isExistMatch = CASE WHEN KeyID = 1 THEN 1 ELSE 0 END
	FROM	#tblMatchProcess	
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SET @ErrCode = 9999
				
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 
				FROM #tmpTransId_VOID_RequestID t	
				WHERE	t.TicketType = 3)
	BEGIN			
		-- checking cash-out process
		INSERT INTO #tblCashOutProcess(transid)
		SELECT	t.transid
		FROM	#tmpTransId_VOID_RequestID t	
		WHERE	t.TicketType = 3 

		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
			,@Action = 'Void'
			,@IsReleased = 0

		DELETE	t
		FROM	#tmpTransId_VOID_RequestID t
			 INNER JOIN #tblCashOutProcess co
					 ON t.transid = co.transid					
						AND co.IsAvailable = 0
		DELETE	t
		FROM	@tmpInputTransId_VOID t
			 INNER JOIN #tblCashOutProcess co
					 ON t.transid = co.transid					
						AND co.IsAvailable = 0
	END
	
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID))  
	BEGIN
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1 
		
	END
	
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID) AND @Recalculate_cnt = 0)
	BEGIN
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch	= @isExistMatch
			,@IsReleased	= 1
		
		SELECT	@ErrCode = 0
				,@ErrMsg = 'No ticket found.'				
		RETURN
	END	
	
	-- Capture request and its void tickets to insert voidingHistory
	INSERT INTO @AutoVoid_ValidRequest (RequestID, Transids)			
	SELECT DISTINCT RequestID, STUFF(tmp.Transids,1,1,'') AS Transids
	FROM (SELECT DISTINCT RequestID FROM @tmpInputTransId_VOID ) AS r
		CROSS APPLY (SELECT ',' + CAST(v.transid AS VARCHAR(50))
					FROM @tmpInputTransId_VOID v
					WHERE v.RequestID = r.RequestID
					FOR XML PATH ('')
					) AS tmp (Transids)
	
	-- Checking Cashout for VOID
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO #tmpTransId_VOID_RequestID (TransId, custid, Refno, bettype, TicketType, isSubTransaction, balanceType,RequestID)
		SELECT	sub.transid, sub.custid, sub.refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, 1 AS balanceType, main.RequestID
		FROM	#tmpTransId_VOID_RequestID main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)

		-- cashout bet ticket, 912, 913
		INSERT INTO #tmpTransId_VOID_RequestID(TransId,custid, Refno, bettype, TicketType, isSubTransaction, balanceType,RequestID)
		SELECT	sub.TransId,sub.custid, sub.Refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, 1 AS balanceType, sub911.RequestID
		FROM	#tmpTransId_VOID_RequestID sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.statusID NOT IN (101, 102)
				AND sub911.bettype = 911
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID r WHERE r.TransId = sub.transid)	

		INSERT INTO @tmpCustCashOut_VOID(CustId)
		SELECT	t.custid
		FROM	#tmpTransId_VOID_RequestID t
		WHERE	t.TicketType = 3
				AND t.bettype = 912
		GROUP BY t.custid
		
	END
	-- Checking CASHOUT for resettle, used to recal 914 for affect customers
	DECLARE @tmpCustCashOut_Recalculate_tmp AS TABLE(transid BIGINT, custid INT, refno BIGINT, bettype SMALLINT)
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO @tmpCustCashOut_Recalculate_tmp (transid, custid, refno, bettype )
		SELECT	sub.transid, sub.custid, sub.refno, sub.bettype
		FROM	#tmpTransId_Recalculate main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)
		-- cashout bet ticket, 912, 913
		INSERT INTO @tmpCustCashOut_Recalculate_tmp (transid, custid, refno, bettype)
		SELECT	sub.TransId,sub.custid, sub.Refno, sub.bettype
		FROM	@tmpCustCashOut_Recalculate_tmp sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.statusID NOT IN (101, 102)
				AND sub911.bettype = 911

		INSERT INTO @tmpCustCashOut_Recalculate(CustId)
		SELECT	t.custid
		FROM	@tmpCustCashOut_Recalculate_tmp t
		WHERE	t.bettype = 912
		GROUP BY t.custid
		
		INSERT INTO #tmpTransId_Recalculate (TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo, refcode, betid)
		SELECT	DISTINCT cob.transid, cob.custid, cob.bettype
			,1 KeyId
			,1 AS balanceType
			,3 AS TicketType
			,cob.betdaqid, cob.ExtraInfo, cob.RefCode, cob.betid
		FROM @tmpCustCashOut_Recalculate_tmp b
			INNER JOIN dbo.bettrans cob WITH(NOLOCK) 
				ON cob.matchid = @MatchId
				AND cob.custid = b.custid
				AND cob.refno = b.refno 
				AND cob.bettype NOT BETWEEN 912 AND 914 --normal bettype tickets
		WHERE b.bettype = 912
			AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate r WHERE r.TransId = cob.transid)	
		
	END
	
	-- Cashout for all void and resettle
	INSERT INTO @tmpCustCashOut (CustId)
	SELECT custid
	FROM @tmpCustCashOut_VOID
	UNION 
	SELECT custid
	FROM @tmpCustCashOut_Recalculate
	
	-- Insert more bonus or cash ticket in case only one ticket appears in #tmpTransId	
	INSERT INTO #tmpRefCodeSummary_VOID (RefCode, custid, bettype, transid,requestID)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid, requestID
	FROM	#tmpTransId_VOID_RequestID t
	WHERE	t.refcode IS NOT NULL 
	GROUP BY t.refcode, t.custid, t.bettype, RequestID
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId_VOID_RequestID (TransId, custid, bettype, KeyId, balanceType, TicketType, refcode,RequestID,betid)
		SELECT b.TransId, b.custid, b.bettype, 1, 1, 1, b.refcode,r.RequestID,b.betid
		FROM #tmpRefCodeSummary_VOID r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
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
		SELECT b.TransId, b.custid, b.bettype, 1, 1, 1, b.refcode
		FROM #tmpRefCodeSummary_VOID r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate WHERE b.transid = TransId)
				
	END
	
	----------------- END OF PREPARATION -----------------------------------	
	-----------STARTING FOR VOID AND RE-Calculation-------------------------
	---------- Starting for Voiding Process ------------------------------------
	
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
			
	-- Insert Voiding History first
	INSERT INTO dbo.TicketVoiding_VoidingHistory (RequestId,UserId,StatusId,TransIds)
	OUTPUT INSERTED.RequestID
			,INSERTED.VoidingHistoryId
	INTO @VoidingHistory_tmp (RequestID,VoidingHistoryId)	
	SELECT RequestID,@UserId, 1, TransIds
	FROM @AutoVoid_ValidRequest v  
	
	BEGIN TRY
			  
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT DELETED.TransId,DELETED.custid, DELETED.Refno, DELETED.bettype, DELETED.TicketType, DELETED.isSubTransaction, DELETED.balanceType,DELETED.RequestID, DELETED.betid
					
			INTO @tmpTransIDBatch(TransId,custid, Refno, bettype, TicketType, isSubTransaction, balanceType,RequestID,betid)
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
				
			SET @xmlTransId = ''	 
			
		END
			
		-- Recal for ticket Lose by statuswinlost
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT deleted.transid
			INTO @tmpTransIDBatch(TransId)
			FROM #tmpTransId_Recalculate t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
			
			SET @xmlTransId = ''
			
			SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									FROM	@tmpTransIDBatch t
									FOR XML PATH('r'), ROOT('root')
								)
								
			SET @TransIDList_tmp = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) FROM @tmpTransIDBatch FOR XML PATH('')),1,1,'')
			
			EXEC [dbo].[Nap_SpecialDelete_MarkedTickets_Update] @TransIds = @TransIDList_tmp
				,@UserId = @UserId
				,@Username = @Username
				,@IP = @IP
				,@LogActionId = 90510
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT
			
			IF @ErrCode = 0
			BEGIN
				EXEC dbo.TicketVoiding_ReCalculate_Single_Update 
					@TransIds = @xmlTransId
			END	
			
			SET @TransIDList_tmp = ''
			SET @xmlTransId = ''
				 
		END
		-- Pre cal 914
		IF EXISTS (SELECT TOP (1) 1 FROM @tmpCustCashOut)
		BEGIN
			BEGIN TRY				
				SET @CustIdsCashOut = STUFF((SELECT ',' + CAST(c.CustId AS VARCHAR(50))
												FROM (SELECT DISTINCT CustId FROM @tmpCustCashOut) c						    
												FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')	
																						    
				EXEC dbo.NAP_Admin_Calculate_914 
						@MatchId 	= @MatchID
						,@Action 	= 'VOID' -- use this option to limit cust need to update 914 only
						,@CustIds 	= @CustIdsCashOut				
			END TRY 
			BEGIN CATCH
				SELECT @ErrCode = 914
						, @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
			END CATCH
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
					,t.balanceType
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
				,t.balanceType
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
	DECLARE @NegativeBalanceUsers VARCHAR(MAX)
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


	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = @isExistMatch
		,@IsReleased = 1

	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 1  

	-- If void all marked tickets of one match (number of waiting/running marked tickets after voiding = 0), shall notify message to Settlement site
	DECLARE @allTransId_Void VARCHAR(MAX) = ''
	DECLARE @allTransId_Recal VARCHAR(MAX) = ''
	
	SELECT	@allTransId_Void = @allTransId_Void + CAST(transid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_VOID_RequestID
	
	SELECT	@allTransId_Recal = @allTransId_Recal + CAST(transid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_Recalculate

	EXEC dbo.NAP_SpecialDelete_CheckingMarkedTransaction
		@TransId = @allTransId_Recal
		,@Username = @Username
		,@MatchId = @MatchId	

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
	-- Insert for WEB Auto Service PROCESS
	DECLARE @sessionID INT = 0
	SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1
	
	INSERT INTO Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistory,statusID,matchID,SessionID,NegativeBalanceUsers)
	SELECT vh.RequestID, vh.VoidingHistoryId,0,@MatchId,@sessionID,@NegativeBalanceUsers
	FROM @VoidingHistory_tmp vh
		
	-- Write Log
	SET @EndTime = GETDATE()
	SET @VoidingHistoryIdList = STUFF((SELECT ',' + CAST(VoidingHistoryId AS VARCHAR(50)) FROM @VoidingHistory_tmp FOR XML PATH('')),1,1,'')
	SET @LogData = CAST((SELECT	0 AS '@RequestId'
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
	
	DROP TABLE #tblCashOutProcess
	DROP TABLE #tblMatchProcess
	DROP TABLE #inputRequestTransId
	DROP TABLE #tmpTransId_Recalculate
	DROP TABLE #tmpTransId_VOID_RequestID
	DROP TABLE #tmpRefCodeSummary_Recalculate
	DROP TABLE #tmpRefCodeSummary_VOID
	
END

GO

