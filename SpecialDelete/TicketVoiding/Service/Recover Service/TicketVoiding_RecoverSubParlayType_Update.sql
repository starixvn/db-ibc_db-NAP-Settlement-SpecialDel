/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RecoverSubParlayType_Update] 
(
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
)
AS
/*	
	Created by:20250609@Lani
	Task: [TVS] Recover Ticket - Support Recover More Products - Sub Parlay [Redmine: #227829]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20250609@Lani: [TVS] Recover Ticket - Support Recover More Products - Sub Parlay - Create new SP [Redmine: #227829]
		- 20250617@July: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @refnos_29				VARCHAR(MAX) = ''
			,@CustIds				VARCHAR(MAX) = ''
			,@MatchDate				DATETIME
			,@EventStatus			NVARCHAR(100) = ''
			,@Sporttype				SMALLINT = NULL
			,@AvailableProcess		BIT
			,@MoveBetDate			DATETIME
			,@SettledMainTranIds	VARCHAR(MAX) = ''
			,@SiteDBGroupId			SMALLINT = 0
			,@StrSetting			VARCHAR(MAX)
			,@SqlOpenqueryCommand	NVARCHAR(MAX) = ''
			,@StartTime				DATETIME
			,@EndTime				DATETIME
			,@LogActionId			INT
			,@LogData				VARCHAR(MAX)
			,@SB_Error				BIT
			,@SpName				VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@MainParlay_MaxPO		VARCHAR(MAX) = NULL
			,@Session				NVARCHAR(50)
			,@ThreadHold			INT --over threadhold, the parlay process will be locked in systemsetting
			,@TotalSubParlay		INT = 0 
			,@RecoverPatchSize		INT = 100
			,@SubTransIds			VARCHAR(MAX) = ''
			,@Transids_29			VARCHAR(MAX) = ''
			,@StartTime_Retry		DATETIME
			,@LimitSecond			INT = 180
			,@ActionID				INT = 90999 --TVS - Agency Cash Service

	CREATE TABLE #tblMatchParlayProcess (MatchId INT, RefNo BIGINT)
	CREATE TABLE #tblRecoverBet (
			TransId			BIGINT
			,MatchId		INT
			,RefNo			BIGINT
			,CustId			INT
			,mRecommend		INT
			,Recommend		INT
			,IsDeposit		BIT
			,Winlostdate	SMALLDATETIME
			,Ruben			TINYINT
			,SiteID			INT
			,Betteam		NVARCHAR(20)
			,Oddspread		MONEY
			,sRecommend		INT
			,IsFinish		BIT
	)
	CREATE TABLE #tblMainTicket
	(
		TransId		BIGINT
		,Refno		BIGINT
		,StatusId	TINYINT
		,CustId		INT
		,Balance	MONEY
		,Ruben		TINYINT
		,MatchId	INT
		,Betteam	NVARCHAR(20)
		,sRecommend INT
		,Oddsspread	MONEY
		,SiteID		INT
		,Bettype	SMALLINT	
	)
	CREATE INDEX IX_RecoverBet ON #tblRecoverBet (refno)
	
	DECLARE @tblTransIds TABLE (Transid BIGINT PRIMARY KEY)
	DECLARE @tblSettledBeforeRecoveredMainTicket TABLE (TransId	BIGINT)
	DECLARE @tmpBoostSite TABLE (SiteId INT, Srecommend INT, IsDeposit BIT DEFAULT(0))
	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)
	DECLARE @tmpTransIdBatch TABLE (TransId BIGINT)
	DECLARE @tmpMatchId TABLE (MatchId INT, MatchDate DATETIME, IsFinish BIT)

	DECLARE @tblBeforeBalance TABLE (CustId INT PRIMARY KEY, balance MONEY)
	DECLARE @tblAfterBalance TABLE (CustId INT PRIMARY KEY, balance MONEY)

	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	SELECT @SiteDBGroupId = dbo.f_Get_SiteDBGroupID()

	SET @Session = CONVERT(NVARCHAR(50),NEWID())
	SET @StartTime = GETDATE()
	SET @LogActionId = 90201
	SET @SB_Error = 0

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MoveBetDate OUTPUT

	SELECT @MatchDate = eventdate
		  ,@EventStatus = eventstatus
		  ,@Sporttype = sporttype
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId

	IF @MatchDate <= @MoveBetDate
	BEGIN
		SELECT @ErrCode = 99, @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try search again.'
		RETURN
	END

	--Parse SubTransId
	INSERT INTO @tblTransIds(Transid)
	SELECT t.value AS TransIds
	FROM STRING_SPLIT(@TransIds,',') AS t
	
	INSERT INTO #tblMatchParlayProcess(MatchId, RefNo)
	SELECT bm.matchid, bm.refno
	FROM @tblTransIds AS t
	INNER JOIN bettransm AS bm ON bm.Transid = t.Transid
	WHERE bm.statusID = 102
		AND bm.SiteDBGroupID = @SiteDBGroupId

	SET @TotalSubParlay = @@ROWCOUNT

	EXEC dbo.NAP_Set_GlobalSettingSel
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	SET @StartTime_Retry = GETDATE()
	WHILE (1=1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = ''

		IF DATEDIFF(SECOND, @StartTime_Retry, getdate()) > @LimitSecond
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN;
		END

		-- Apply new way to lock parlay tickets	
		IF @TotalSubParlay <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= 1
				,@SPName				= @SPName
				,@Session				= @Session
				,@avaiableProcess 		= @AvailableProcess OUTPUT
				,@ErrCode				= @ErrCode OUTPUT
				,@ErrMsg				= @ErrMsg OUTPUT
		END
		ELSE --@totalSubParlay > 10K
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay		= 1  
				,@avaiableProcess	= @AvailableProcess OUTPUT  
				,@ErrCode			= @ErrCode OUTPUT  
				,@ErrMsg			= @ErrMsg OUTPUT  
		END

		IF @AvailableProcess = 0 OR @ErrCode <> 0
			CONTINUE
		ELSE 
			BREAK
	END

	BEGIN TRY
		--Query all sub tickets to recover
		INSERT INTO #tblRecoverBet
		(
			TransId
		   ,MatchId
		   ,RefNo
		   ,CustId
		   ,mRecommend
		   ,Recommend
		   ,IsDeposit
		   ,Winlostdate
		   ,Ruben
		   ,SiteID
		   ,Betteam
		   ,Oddspread
		   ,sRecommend
		)
		SELECT 
			bm.TransId
		   ,bm.matchid
		   ,bm.refno
		   ,b.custid
		   ,b.mrecommend
		   ,b.recommend
		   ,CASE WHEN EXISTS (SELECT TOP 1 1 FROM custDB.dbo.Dep_CustSuper WITH (NOLOCK) WHERE custid = b.srecommend) THEN 1 ELSE 0 END AS IsDeposit
		   ,bm.winlostdate
		   ,b.ruben
		   ,b.BetSiteID
		   ,bm.betteam
		   ,b.oddsspread
		   ,b.srecommend
		FROM @tblTransIds AS t
		INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON t.Transid = bm.TransId AND bm.SiteDBGroupID = @SiteDBGroupId
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno AND bm.SiteDBGroupID = b.SiteDBGroupID
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = bm.matchid
		WHERE b.bettype = 29
			AND (b.betfrom IS NULL OR b.betfrom <> 'p')
			AND bm.statusID = 102
			AND m.sporttype BETWEEN 1 AND 99
		
		IF @@ROWCOUNT = 0
		BEGIN
			IF @TotalSubParlay <= @ThreadHold
			BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session		  = @Session
				   ,@IsReleased		  = 1
			END
			ELSE
			BEGIN
				--Release parlay process
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsExistParlay	= 1
				   ,@IsReleased     = 1
			END

			SELECT @ErrCode = 100, @ErrMsg = 'No ticket found.'

			RETURN 
		END

		--Get list of maintransids
		INSERT INTO #tblMainTicket(TransId, Refno, StatusId, CustId, Balance, Ruben, MatchId, sRecommend, Betteam, Oddsspread, SiteID, Bettype)
		SELECT 
			b.TransId
		   ,b.refno
		   ,b.statusID
		   ,b.custid
		   ,b.winlost - b.actual_stake + b.playercomm AS balance
		   ,b.ruben
		   ,t.matchid
		   ,b.srecommend
		   ,b.betteam
		   ,b.oddsspread
		   ,b.BetSiteID
		   ,b.bettype
		FROM #tblRecoverBet AS t
		INNER JOIN bettransm AS bm WITH (NOLOCK) ON t.TransId = bm.TransId
		INNER JOIN bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
		WHERE b.bettype = 29

		--Capture list of settled main transIds before recover
		INSERT INTO @tblSettledBeforeRecoveredMainTicket(TransId)
		SELECT TransId
		FROM #tblMainTicket
		WHERE StatusId IN (111, 112, 113) -- 'DRAW', 'WON', 'LOSE'

		--Capture @tblBeforeBalance
		INSERT INTO @tblBeforeBalance
		SELECT CustId
			  ,SUM(t.balance) AS Balance
		FROM #tblMainTicket AS t
		GROUP BY t.CustId

		--Prepare for max payout
		SELECT @MainParlay_MaxPO = (
									SELECT CustId AS '@custid'
										  ,Ruben AS '@ruben'
										  ,TransId AS '@transid'
									FROM #tblMainTicket
									GROUP BY CustId, Ruben, TransId
									FOR XML PATH('r'), ROOT('root')
								)

		INSERT INTO @tmpMatchId(MatchId,MatchDate)
		SELECT DISTINCT m.MatchId, m.eventdate
		FROM #tblRecoverBet AS  b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid

		--RECOVER
		--For BettransM
		WHILE ( 1 = 1)
		BEGIN
			UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
			FROM @tmpMatchId p
			WHERE p.IsFinish IS NULL
		
			IF @@ROWCOUNT = 0 BREAK

			SELECT	@matchdate = eventdate
			FROM	dbo.match WITH(NOLOCK)
			WHERE	matchid = @MatchId

			WHILE (1 = 1)
			BEGIN
				DELETE @tmpTransIdBatch
				SET @SubTransIds = ''

				UPDATE TOP (@RecoverPatchSize) t
				SET t.IsFinish = 1
					OUTPUT deleted.TransId
					INTO @tmpTransIdBatch(TransId)
				FROM #tblRecoverBet AS t
				WHERE t.IsFinish IS NULL AND t.MatchId = @MatchId

				IF @@ROWCOUNT = 0 BREAK

				SELECT @SubTransIds = @SubTransIds + CONVERT(VARCHAR(50),TransId) + ','
				FROM @tmpTransIdBatch

				EXEC dbo.NAP_Admin_Calculate_MP_broker
					@matchid = @MatchId
					,@matchdate = @MatchDate
					,@mode = 'RECOVER-RECAL' --Update bettransm + betparlaydetail
					,@VoidTransId = @SubTransIds
			END

			SELECT @Transids_29 = @Transids_29 + CONVERT(VARCHAR(50), transid) + ','
			FROM #tblMainTicket
			WHERE matchid = @MatchId

			DELETE @tmpBoostSite
			INSERT INTO @tmpBoostSite(SiteId, Srecommend)
			SELECT DISTINCT t.SiteID, t.sRecommend
			FROM #tblMainTicket AS t
			WHERE t.Bettype = 29
				AND t.MatchId =  @MatchId
				AND t.Betteam = '1' --mix parlay
				AND t.Oddsspread = 2 --offer parlay bonus
				AND NOT EXISTS (SELECT TOP 1 1
								FROM dbo.bettransm AS bm WITH (NOLOCK)
								WHERE t.refno = bm.refno
									AND ((ISNULL(bm.statuswinlost,0) = 4 AND bm.statusID = 113) OR bm.statusID = 0)
								)--lose/running

			UPDATE si
			SET IsDeposit = 1
			FROM @tmpBoostSite si
			INNER JOIN CustDB.dbo.Dep_CustSuper d WITH (NOLOCK) ON si.Srecommend = d.custid

			SET @SqlOpenqueryCommand = ''
			SET @SqlOpenqueryCommand = 'SELECT SiteId, OverOdds, Boost FROM OPENQUERY(DBPRO,''SELECT SiteId, OverOdds, Boost FROM bodb02.dbo.ParlayOddsBoostSetting p WITH(NOLOCK) WHERE p.SiteId IN ('
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
			EXEC(@SqlOpenqueryCommand)

			SET @StrSetting = ''
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

			--Call pre-cal: betparlaydetail/betparlayresult
			EXEC dbo.NAP_Admin_Calculate_MP_Broker
				@matchid	 = @MatchId
				,@matchdate  = @MatchDate
				,@strXML	 = @Transids_29
				,@mode		 = 'PRECAL-29'
				,@strSetting = @StrSetting
		END

		SELECT @refnos_29 = @refnos_29 + CONVERT(VARCHAR(50),refno) + '|' + CONVERT(VARCHAR(50),transid) + ','
		FROM #tblMainTicket

		--Call cal_29: resettle for main ticket
		EXEC dbo.NAP_Admin_Calculate_MP_broker
			@matchdate = @MatchDate -- main transid + refno: refno|transid,refno|transid...
		   ,@strXML	   = @refnos_29
		   ,@mode	   = '29'

		
		--Insert max payout queue
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId	 = 29
		   ,@TransidList = @MainParlay_MaxPO
		   ,@Mode		 = 'RECOVER'

		--Capture @tblAfterBalance
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT t.CustId
			  ,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM #tblMainTicket AS t
		INNER JOIN bettrans AS b WITH (NOLOCK) ON t.TransId = b.TransId AND b.SiteDBGroupID = @SiteDBGroupId
		GROUP BY t.CustId

		--Update credit balance of cust
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT a.CustId, (a.balance-b.balance) AS balance
		FROM @tblBeforeBalance AS b
		INNER JOIN @tblAfterBalance AS a ON a.CustId = b.CustId
		WHERE (a.balance - b.balance) > 0

		IF @@ROWCOUNT <> 0
			EXEC dbo.Dot_BalancePendingCreditIns
				@BalancePending = @tblCreditPending
			   ,@Type			= 1 --sports

		--Update debit of balance of cust
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT a.CustId, ABS(a.balance - b.balance) AS balance
		FROM @tblBeforeBalance AS b
		INNER JOIN @tblAfterBalance AS a ON a.CustId = b.CustId
		WHERE (a.balance - b.balance) < 0

		IF @@ROWCOUNT <> 0
			EXEC dbo.Dot_BalancePendingDebitIns
				@BalancePending = @tblDebitPending
			   ,@Type			= 1 --sports

		--Build list of changed status main transids that corresponding match needs to re-settle
		IF @EventStatus = 'completed'
		BEGIN
			SELECT @SettledMainTranIds += CASE WHEN @SettledMainTranIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(50), t.transid)
			FROM @tblSettledBeforeRecoveredMainTicket t			 
				 INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid	 
			WHERE b.statusID = 0 AND b.SiteDBGroupID = @SiteDBGroupID
		END

		INSERT INTO #Balance (custid, balance, Increased)
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM @tblBeforeBalance b
			INNER JOIN @tblAfterBalance a ON b.custid = a.custid
		WHERE b.balance <> a.balance

		--Build list of customer name with negative balance
		SELECT @CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20),custid)
		FROM #Balance
		WHERE Increased = 0

		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

		--> Add Agency Cash Service - Negative Balance into BalanceNegative table  [#225390]
		IF OBJECT_ID('BalanceNegative','U') IS NOT NULL AND @SiteDBGroupID = 3 --Credit
		BEGIN
			INSERT INTO [dbo].[BalanceNegative]
						([ExecDate]
						,[MatchID]
						,[ActionID]
						,[GroupID]
						,[CustID]
						,[Balance]
						,[StatusID]
						,[Remark])
			SELECT	 GETDATE()
					,@MatchId
					,@ActionID
					,0		-- For Void/Recover
					,CustID
					,Balance
					,0
					,@spName + ' - RequestId: ' + CAST(@RequestId AS VARCHAR)
			FROM	#Balance
			WHERE	Increased = 0
		END		        
		DROP TABLE #Balance

		IF @TotalSubParlay <= @ThreadHold
		BEGIN 
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
			   ,@Session		  = @Session
			   ,@IsReleased		  = 1
		END
		ELSE
		BEGIN
			--release parlay process
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlay = 1
			   ,@IsReleased    = 1
		END
	END TRY
	BEGIN CATCH
		IF @TotalSubParlay <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefnO = 1
			   ,@Session		  = @Session
			   ,@IsReleased       = 1
		END
		ELSE
		BEGIN
			--release parlay process
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlay = 1
			   ,@IsReleased    = 1
		END

		SELECT @ErrCode = 100, @ErrMsg = 'Unable to recover these parlay bets'

		RETURN
	END CATCH

	--Write useraction log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ ' Sub Parlay ticket with TransId: '+ @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblRecoverBet
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblMainTicket


END