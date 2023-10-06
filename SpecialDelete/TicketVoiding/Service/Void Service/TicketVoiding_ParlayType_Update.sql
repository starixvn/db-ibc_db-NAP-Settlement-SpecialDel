/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ParlayType_Update]
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)
	,@IssueTypeId		TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210401@Kathy:  Enhance Auto Void Retry process [Redmine:#152581]
		- 20210622@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210722@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230426@July: [TVS] Support void Cricket tickets on TVS Early Kick Off/Wrong Kick Off Time [Redmine: #187051]
		- 20230523@Max: Hotfix - [TVS] Void Sub Parlay not return balance [Redmine: #188610]
		- 20230712@Max: Scale out credit - Fix issue child match cricket [Redmine: #181595]
		- 20231006@Max: [TVS] Integrate Parlay Boost Bonus [Redmine: #192778]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@Movebetdate		DATETIME
			,@Session			NVARCHAR(50)
		    ,@ThreadHold		INT = 0 -- over threadhold, the parlay process will be locked in systemsetting 
		    ,@SPName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@limitsecond		INT	= 180
			,@StartTime_Retry	DATETIME
			,@MainParlay_MaxPO	VARCHAR(MAX) = NULL
			,@avaiableProcess	BIT
			,@MatchDate			DATETIME
			,@RowCount			INT = 0
			,@strSubTransId		VARCHAR(MAX) =''
			,@strMainTransId	VARCHAR(MAX) =''
			,@strRefno			VARCHAR(MAX) =''
			,@CustIds			VARCHAR(MAX)
			,@strSetting		VARCHAR(MAX)
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''

	SET @Session = CONVERT(NVARCHAR(50),NEWID())

	DECLARE @tblDebitPending TVP_BalanceList  
	DECLARE @tblCreditPending TVP_BalanceList  
	DECLARE @tmpMatchId TABLE (MatchId INT, isFinish INT)
	DECLARE @tmpTransIDBatch TABLE (transid BIGINT)
	DECLARE @tmpInputTransId TABLE(TransId BIGINT, MainTransId BIGINT, MainStatusId TINYINT, SubStatusId TINYINT, Refno BIGINT, Eventdate DATETIME, MatchId INT)
	DECLARE @tmpBoostSite TABLE(SiteId INT, srecommend INT, IsDeposit BIT DEFAULT(0))
	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)

	CREATE TABLE #BeforeUpd (custid INT, balance MONEY)  
	CREATE TABLE #AfterUpd(custid INT, balance MONEY)  
	CREATE TABLE #tmpSubTransId (TransId BIGINT, Refno BIGINT, MatchId INT, isFinish INT)
	CREATE TABLE #tmpMainTransId (TransId BIGINT, Refno BIGINT, ruben TINYINT, CustId INT, MatchId INT
		, srecommend INT, betteam NVARCHAR(10), oddsspread MONEY, SiteID INT
	)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90101
	SET @SB_Error = 0

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	value AS TransId
	FROM	STRING_SPLIT(@TransIds, ',')
	
	UPDATE t 
		SET MainTransId = b.transid
			,MainStatusId = b.statusID
			,SubStatusId = bm.statusID
			,refno = b.refno
			,Eventdate = bm.winlostdate
			,MatchId = bm.matchid
	FROM	@tmpInputTransId t 
		INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK)
			ON t.TransId = bm.transid
		INNER HASH JOIN dbo.bettrans b WITH(NOLOCK)
			ON	bm.refno = b.refno
				AND b.matchid = 29
				AND b.bettype = 29

	INSERT INTO #tmpSubTransId(TransId, Refno, MatchId)
	SELECT	TransId, Refno, MatchId
	FROM	@tmpInputTransId
	WHERE	MainTransId IS NOT NULL 	
			AND SubStatusId NOT IN (101, 102)

	SET @RowCount = @@ROWCOUNT
	
	SELECT @FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(ISNULL(MainTransId, TransId) AS VARCHAR(30)), CAST(ISNULL(MainTransId, TransId) AS VARCHAR(30)))
	FROM	@tmpInputTransId
	WHERE	MainTransId IS NULL
			OR SubStatusId IN (101, 102)
			OR Eventdate <= @Movebetdate --movebet

	IF @RowCount = 0
	BEGIN
		SELECT @ErrCode = 100  
				,@ErrMsg = 'No parlay ticket found.'  

		RETURN
	END

	IF EXISTS(SELECT TOP 1 1 FROM @tmpInputTransId WHERE Eventdate <= @Movebetdate)
	BEGIN
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Match is under Movebet process, could not void ticket.'

		RETURN
	END	

	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
	   ,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT MatchId, refno
	FROM #tmpSubTransId

	SET @StartTime_Retry = GETDATE()
	WHILE (1=1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = ''

		IF DATEDIFF(SECOND, @StartTime_Retry, getdate()) > @limitsecond
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN;
		END

		-- Apply new way to lock parlay tickets	
		IF @RowCount <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= 1
				,@SPName				= @SPName
				,@Session				= @Session
				,@avaiableProcess 		= @avaiableProcess OUTPUT
				,@ErrCode				= @ErrCode OUTPUT
				,@ErrMsg				= @ErrMsg OUTPUT
		END
		ELSE --@totalSubParlay > 10K
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay		= 1  
				,@avaiableProcess	= @avaiableProcess OUTPUT  
				,@ErrCode			= @ErrCode OUTPUT  
				,@ErrMsg			= @ErrMsg OUTPUT  
		END

		IF @avaiableProcess = 0 OR @ErrCode <> 0
			CONTINUE
		ELSE 
			BREAK
	END

	SET @FailedTransIds = NULL

	-- BackUp bettransm tickets into zzzbettrans  
	INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
			winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
			winlostdate, betfrom, betcheck, checktime, matchid, bettype, SiteDBGroupID, RepUpdateTime
	)  
	SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
			b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, b.SiteDBGroupID, SYSDATETIME()
	FROM	#tmpSubTransId t
		INNER JOIN dbo.bettransm AS b WITH (NOLOCK)  
			ON	b.transid = t.TransId

	-- BackUp tickets of bettransm  
	INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype, VoidingHistoryId, SiteDBGroupID, RepUpdateTime)  
	SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
			b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, @VoidingHistoryId, b.SiteDBGroupID, SYSDATETIME()
	FROM	#tmpSubTransId t
		INNER JOIN dbo.bettransm AS b WITH (NOLOCK)  
			ON	t.transid = b.transid   
	
	INSERT INTO @tmpMatchId(MatchId)
	SELECT DISTINCT MatchId
	FROM #tmpSubTransId
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
		FROM @tmpMatchId p
		WHERE p.IsFinish IS NULL
		
		IF @@ROWCOUNT = 0 BREAK

		SELECT	@matchdate = eventdate
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @MatchId

		WHILE (0=0)
		BEGIN
			DELETE @tmpTransIDBatch
			SET @strSubTransId = ''
		
			UPDATE TOP(100) t
			SET isFinish = 1
				OUTPUT deleted.transid
				INTO @tmpTransIDBatch(transid)
			FROM #tmpSubTransId t
			WHERE isFinish IS NULL AND t.MatchId = @MatchId

			IF @@ROWCOUNT = 0 BREAK

			SELECT	@strSubTransId = @strSubTransId + CONVERT(VARCHAR(50), TransId) + ','
			FROM	@tmpTransIDBatch

			EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchId  
				,@fth = 0  
				,@fta = 0  
				,@hth = 0  
				,@hta = 0  
				,@matchdate = @matchdate  
				,@mode = 'VOID'  
				,@VoidTransID = @strSubTransId  
				,@UserId = @UserId
		END
	
		INSERT INTO #tmpMainTransId(TransId, Refno, CustId, ruben, MatchId, srecommend, betteam, oddsspread, SiteID)
		SELECT	DISTINCT b.transid, b.refno, b.custid, b.ruben, t.MatchId, b.srecommend, b.betteam, b.oddsspread, b.BetSiteID
		FROM	#tmpSubTransId t
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON t.Refno = b.refno
		WHERE	b.matchid = 29
				AND b.statusID NOT IN (101, 102)
				AND t.MatchId = @MatchId

		SELECT	@strMainTransId = @strMainTransId + CONVERT(VARCHAR(20), TransId) + ','
		FROM #tmpMainTransId
		WHERE MatchId = @MatchId

		DELETE @tmpBoostSite
		INSERT INTO @tmpBoostSite(SiteId, srecommend )
		SELECT DISTINCT SiteID, srecommend
		FROM	#tmpMainTransId t
		WHERE	matchid = @MatchId
			AND t.betteam = '1' -- mix parlay
			AND t.oddsspread = 2 -- offer parlay bonus
			AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.bettransm bm WITH(NOLOCK) WHERE t.refno = bm.refno AND ISNULL(bm.statuswinlost,0) IN (4,0)) -- lose/running

		UPDATE si 
		SET IsDeposit = 1
		FROM	@tmpBoostSite si
			INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK)
				ON si.srecommend = d.custid

		SET @sqlOpenqueryCommand = ''
		SET @sqlOpenqueryCommand = 'SELECT SiteId, OverOdds, Boost FROM OPENQUERY(DBPRO,''SELECT SiteId, OverOdds, Boost FROM bodb02.dbo.ParlayOddsBoostSetting p WITH(NOLOCK) WHERE p.SiteId IN ('
								+ (SELECT  STRING_AGG(CAST(s.SiteID AS VARCHAR(MAX)),',') 
									FROM (
										SELECT SiteId
										FROM (
											SELECT SiteId
											FROM @tmpBoostSite t
											UNION
											SELECT -1
											UNION 
											SELECT -2
										) t
										GROUP BY t.SiteID
									) s 
								)
						+ ')'')'

		DELETE @tmpBoostSetting
		INSERT INTO @tmpBoostSetting(SiteId, OverOdds, Boost)							
		EXEC (@sqlOpenqueryCommand)

		SET @strSetting = ''
		SELECT @strSetting = CAST((
			SELECT	si.SiteId AS 's'
					,(SELECT t.OverOdds AS 'o', t.Boost AS 'b' -- get its own settings
						FROM (SELECT se.SiteId, se.OverOdds, se.Boost
							FROM	@tmpBoostSetting se
							WHERE	EXISTS (SELECT TOP 1 1 FROM	@tmpBoostSite si WHERE se.SiteId = si.SiteId)
							UNION
							SELECT	si.SiteId, se.OverOdds, se.Boost -- If the site ID does not have its own settings, the default value will be taken on default SiteId (-1 if it's credit, -2 if it's licensee)
							FROM	@tmpBoostSite si
								CROSS APPLY (
									SELECT	se.OverOdds, se.Boost
									FROM	@tmpBoostSetting se
									WHERE	se.SiteId = CASE WHEN si.IsDeposit = 1 THEN -2 ELSE -1 END
								) se
							WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpBoostSetting se WHERE si.SiteId = se.SiteId)
						) t
					WHERE si.SiteId = t.SiteId
					FOR JSON AUTO
					) AS v
			FROM	@tmpBoostSite si
			FOR JSON AUTO
		) AS VARCHAR(MAX))

		EXEC dbo.NAP_Admin_Calculate_MP_broker   
			@matchid = @matchid  
			,@matchdate = @matchdate  
			,@strXML = @strMainTransId  
			,@mode  = 'PRECAL-29'
			,@strSetting = @strSetting
	END

	INSERT INTO #BeforeUpd(custid, balance)
	SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM	#tmpMainTransId t
		INNER JOIN dbo.bettrans b WITH(ROWLOCK)
			ON t.TransId = b.transid
	GROUP BY b.custid

	/*Calculate main parlay ticket*/
	SELECT	@strRefno = @strRefno + ',' + CONVERT(VARCHAR(20), Refno) + '|' + CONVERT(VARCHAR(20), TransId)
	FROM #tmpMainTransId

	EXEC dbo.NAP_Admin_Calculate_MP_broker   
			@matchdate = @matchdate  
			,@strXML = @strRefno  
			,@mode  = '29' 
	-----------------------------------------
	
	INSERT INTO #AfterUpd(custid, balance)
	SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM	#tmpMainTransId t
		INNER JOIN dbo.bettrans b WITH(ROWLOCK)
			ON t.TransId = b.transid
	GROUP BY b.custid

	INSERT INTO @tblCreditPending (custID, balance)  
	SELECT	a.custid  
			,(a.balance - b.balance) AS Balance  
	FROM	#BeforeUpd b  
		INNER JOIN #AfterUpd a 
			ON	a.custid = b.custid  
	WHERE	(a.balance - b.balance) > 0  
		 
	IF @@rowcount <> 0  
		EXEC dbo.Dot_BalancePendingCreditIns   
			@BalancePending = @tblCreditPending  
			,@Type   = 1 -- Sports  

	INSERT INTO @tblDebitPending (custID, balance)  
	SELECT	a.custid  
			,ABS(a.balance - b.balance) AS Balance  
	FROM	#BeforeUpd b  
		INNER JOIN #AfterUpd a 
			ON	a.custid = b.custid  
	WHERE	(a.balance - b.balance) < 0  
		 
	IF @@rowcount <> 0  
		EXEC dbo.Dot_BalancePendingDebitIns   
			@BalancePending = @tblDebitPending  
			,@Type   = 1 -- Sports  

	--Prepare for Max Payout
	SELECT @MainParlay_MaxPO = (SELECT t.CustId AS '@custid'
								,t.ruben AS '@ruben'
								,t.TransId AS '@transid'
							FROM #tmpMainTransId t
							GROUP BY CustId, ruben, TransId
							FOR XML PATH('r'), ROOT('root')
						)
	
	IF @MainParlay_MaxPO IS NOT NULL
	BEGIN
		--Insert Max Payout Queue
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
	END
	--------------------------------------

	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(a.custid AS VARCHAR(20)) + ','
	FROM	#BeforeUpd b
		INNER JOIN #AfterUpd a
			ON b.custid = a.custid
	WHERE	b.balance > a.balance

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	IF @RowCount <= @ThreadHold
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
	END
	ELSE 
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay  = 1  
				,@IsReleased  = 1 
	END
	
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ ' Parlay ticket with TransId: ' + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #tmpMainTransId
	DROP TABLE #tmpSubTransId
	DROP TABLE #BeforeUpd
	DROP TABLE #AfterUpd
	DROP TABLE #tblMatchParlayProcess

END
GO

