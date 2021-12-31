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
)
AS
/*	
	Created by: Max
	Date 20211116
	Task: [TVS] Void abnormal bet of parlay
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20211116@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
		- 20211230@July: Remove code CashOut [Redmine: #165097]

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
			,@query				NVARCHAR(MAX) = ''
			,@ExecuteSQL		NVARCHAR(MAX) = ''
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@Movebetdate		DATETIME
			,@ThreadHold		INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
			,@totalMainParlay	INT = 0
			,@strRefno			VARCHAR(MAX) = ''

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL
	
	DECLARE @avaiableProcess BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@IssueTypeId	TINYINT
			,@isExistParlay	BIT = 1
	
	DECLARE @AutoVoid_ValidRequest AS TABLE (RequestID INT, Transids VARCHAR(MAX), IssueTypeId TINYINT, MinWinlostdate DATETIME, MaxWinlostdate DATETIME)
	DECLARE @VoidingHistory_tmp AS TABLE (RequestID INT, VoidingHistoryId INT)
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	CREATE TABLE #inputRequestTransId (TransId BIGINT, RequestID INT, IssueTypeId TINYINT, RequestType TINYINT, DecidedBy NVARCHAR(200), ActionId TINYINT)
	DECLARE @tmpInputTransId_VOID TABLE(TransId BIGINT, RequestID INT, IssueTypeId TINYINT, DecidedBy NVARCHAR(200), Winlostdate DATETIME, StatusId TINYINT)
	DECLARE @tmpInputTransId_ReCalculate TABLE(TransId BIGINT, RequestID INT)
	
	DECLARE @tmpMatch_Eventdate TABLE (MatchId INT, Eventdate DATETIME)	
						
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	CREATE TABLE #tmpTransId_VOID_RequestID (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,Refno				BIGINT
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,actual_stake		MONEY
		,refcode			BIGINT
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
		,Refno				BIGINT
		,balanceType		TINYINT
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,actual_stake		MONEY
		,refcode			BIGINT
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
		,Refno				BIGINT
		,betid				BIGINT
		,actual_stake		MONEY
		,RequestID			INT
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
	INSERT INTO #tmpTransId_VOID_RequestID(TransId, custid, bettype, betdaqid, extrainfo, refcode, betid,RequestID, matchid, oddsid, winlostdate, Refno, srecommend, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			, t.RequestID
			,b.matchid, b.oddsid, t.Winlostdate, b.refno, b.srecommend,b.ruben
	FROM @tmpInputTransId_VOID AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	
	INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, balanceType, betdaqid, extrainfo, refcode, betid, matchid, oddsid, winlostdate, Refno, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,1 AS balanceType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid, b.matchid, b.oddsid, b.winlostdate, b.refno, b.ruben
	FROM @tmpInputTransId_ReCalculate AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	
	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId_VOID_RequestID bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	-- check and not allow attempt to settlement same game while it's still not finish
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
	IF @totalMainParlay <= @ThreadHold 
	BEGIN
		-- checking Refno parlay proccess
		EXEC dbo.NAP_Admin_CheckingProcess
			 @IsLockingByRefno	= 1
			,@spName			= @spName
			,@Session			= @Session
			,@avaiableProcess 	= @avaiableProcess OUTPUT
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END
	ELSE
	BEGIN
		--check settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay 				= @isExistParlay
			, @spName					= @spName
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT
	END	

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SET @ErrCode = 9999
		RETURN
	END

	IF (NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID) AND @Recalculate_cnt = 0)
	BEGIN
		IF @totalMainParlay <= @ThreadHold
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
			   ,@Session	= @Session
			   ,@IsReleased = 1				
		END
		ELSE
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
				 @isExistParlay = @isExistParlay
				,@IsReleased	= 1
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
		INSERT INTO #tmpTransId_VOID_RequestID (TransId, custid, bettype, refcode, RequestID, betid)
		SELECT b.TransId, b.custid, b.bettype
		, b.refcode, r.RequestID, b.betid
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
		INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, balanceType, refcode)
		SELECT b.TransId, b.custid, b.bettype
		, 1, b.refcode
		FROM #tmpRefCodeSummary_Recalculate r
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
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM #tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM #tmpTransId_Recalculate  t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType
	
	
	-- Insert Voiding History first
	INSERT INTO dbo.TicketVoiding_VoidingHistory (RequestId, UserId, StatusId, TransIds)
	OUTPUT INSERTED.RequestID
			,INSERTED.VoidingHistoryId
	INTO @VoidingHistory_tmp (RequestID,VoidingHistoryId)	
	SELECT  RequestID
			,@UserId
			, 1
			,TransIds
	FROM @AutoVoid_ValidRequest

	SELECT @VoidingHistoryIds = STUFF((SELECT ',' + CAST(VoidingHistoryId AS VARCHAR(50)) FROM @VoidingHistory_tmp FOR XML PATH('')),1,1,'')

	-- Insert for WEB Auto Service PROCESS
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
						INNER JOIN @VoidingHistory_tmp t ON t.RequestID = s.RequestID AND t.VoidingHistoryId = s.VoidingHistory)
	BEGIN
		DECLARE @sessionID INT = 0
		SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1

		INSERT INTO Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistory,statusID,matchID,SessionID,IsAutoVoid)
		SELECT vh.RequestID, vh.VoidingHistoryId,1,@MatchId,@sessionID,1
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

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatch_Eventdate WHERE Eventdate <= @Movebetdate)
	BEGIN
		IF @totalMainParlay <= @ThreadHold
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
			   ,@Session	= @Session
			   ,@IsReleased = 1				
		END
		ELSE
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 	= @isExistParlay
					, @IsReleased	= 1
		END
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Match is under Movebet process, could not void ticket.'

		RETURN
	END

	BEGIN TRY			  
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT DELETED.TransId,DELETED.custid, DELETED.Refno, DELETED.bettype,DELETED.RequestID, DELETED.betid, DELETED.actual_stake
					
			INTO @tmpTransIDBatch(TransId,custid, Refno, bettype,RequestID,betid,actual_stake)
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
				,b.betcheck
				,b.comstatus
				,b.checktime, b.matchid, b.bettype  
				,vd.VoidingHistoryId
			FROM @tmpTransIDBatch AS t 
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.TransId
				INNER JOIN @VoidingHistory_tmp vd ON t.RequestID = vd.RequestID
			
			-- Auto Void
			SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									,NULL AS '@translogid'
									,t.betid AS '@betid'
									,NULL AS '@isMG'
									,NULL AS '@actual_stake'
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
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					, ISNULL(b.WalletType, 2) AS WalletType
					,b.winlost - b.actual_stake + b.playercomm AS balance
					
			FROM #tmpTransId_VOID_RequestID t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
			UNION ALL
			SELECT	b.custid
					,t.balanceType
					,CASE 
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,ISNULL(b.WalletType, 2) AS WalletType
					,b.winlost - b.actual_stake + b.playercomm AS balance
			FROM	#tmpTransId_Recalculate t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
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
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType
				,b.winlost - b.actual_stake + b.playercomm AS balance
				
		FROM #tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		UNION ALL
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId_Recalculate t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
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

	IF @totalMainParlay <= @ThreadHold
	BEGIN
		------ releasing Refno parlay proccess
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefno = 1
			,@Session	= @Session
			,@IsReleased = 1				
	END
	ELSE
	BEGIN
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay 	= @isExistParlay
			, @IsReleased	= 1
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
	
	DROP TABLE #inputRequestTransId
	DROP TABLE #tmpTransId_Recalculate
	DROP TABLE #tmpTransId_VOID_RequestID
	DROP TABLE #tmpRefCodeSummary_Recalculate
	DROP TABLE #tmpRefCodeSummary_VOID
	DROP TABLE #tblMatchParlayProcess

END

GO

