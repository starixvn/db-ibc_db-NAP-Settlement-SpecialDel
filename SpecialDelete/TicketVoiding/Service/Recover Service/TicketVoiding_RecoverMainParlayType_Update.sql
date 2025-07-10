/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RecoverMainParlayType_Update] 
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
	,@ResettledTransIds   VARCHAR(MAX)	= NULL	OUTPUT
)
AS
/*	
	Created by:20231227@Max
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20231227@Max: Create new SP [Redmine: #196020]
		- 20240304@Max: Set LogActionId [Redmine: #196020]
		- 20241218@July: Modify ErrCode [Redmine: #213398]
		- 20250617@July: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowNumber			INT	= 1
			,@tmp_TransIds		VARCHAR(MAX)
			,@refnos_29			VARCHAR(MAX)
			,@CustIds			VARCHAR(MAX) = ''
			,@tmp_MatchId		INT
			,@MatchDate			DATETIME
			,@IsITAdmin			BIT = 0
			,@AvaiableProcess	BIT
			,@Movebetdate		DATETIME
			,@TransInfo			VARBINARY(MAX) = NULL
		    ,@SettledMainTranIds VARCHAR(MAX) = '' 
		    ,@SiteDBGroupID		SMALLINT = 0
			,@strSetting		VARCHAR(MAX)
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''
			,@StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@xmlTransId			VARCHAR(MAX) = ''
			,@SB_Error			BIT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@ActionID			INT = 90999 --TVS - Agency Cash Service

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MainParlay_MaxPO   VARCHAR(MAX) = NULL

	DECLARE @Session			NVARCHAR(50)
		   ,@ThreadHold			INT -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalMainParlay	INT = 0 
	SET @Session = CONVERT(NVARCHAR(50),NEWID())

	CREATE TABLE #tmpMatch (RowNumber INT, matchId INT, transId BIGINT, refno BIGINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	DECLARE @tblTransIds TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10) , statusID TINYINT, ruben TINYINT, modds SMALLMONEY
			, winlost MONEY, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, statuswinlost TINYINT, creator INT, ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, transdate DATETIME, comstatus NVARCHAR(40)
			)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
	DECLARE @tmpBoostSite TABLE(SiteId INT, srecommend INT, IsDeposit BIT DEFAULT(0))
	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)

	CREATE TABLE #tblRecoverBet( 
		 transid		BIGINT
		,matchid		INT
		,refno			BIGINT 
		,custid			INT
		,mrecommend		INT
		,recommend		INT
		,isdeposit		BIT
		,winlostdate    SMALLDATETIME
		,ruben			TINYINT
		,SiteID			INT
		,betteam		NVARCHAR(20)
		,oddsspread		MONEY
		,srecommend		INT
	)
	CREATE INDEX IX_RecoverBet ON #tblRecoverBet (refno)
	
	DECLARE @tblMatchIds TABLE ( 
		 RowNumber		INT 										
		,matchid		INT
		,transid		BIGINT
		,refno			BIGINT
	)								
											
	DECLARE @tblBeforeBalance	TABLE (custid INT, balance MONEY)
	DECLARE @tblAfterBalance	TABLE (custid INT, balance MONEY)	
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90201
	SET @SB_Error = 0
	
	BEGIN TRY
		INSERT INTO @tblTransIds (transid)
		SELECT value
		FROM STRING_SPLIT(@TransIds, ',')

		--Transid list is recovered
		INSERT INTO #tblRecoverBet (
					transid
					,matchid
					,refno
					,custid
					,mrecommend
					,recommend
					,isdeposit
					,winlostdate
					,ruben
					,SiteID
					,betteam
					,oddsspread
					,srecommend
		)
		SELECT	b.transid
				,b.matchid
				,b.refno
				,b.custid
				,b.mrecommend
				,b.recommend
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end AS isdeposit
				,b.winlostdate
				,b.ruben
				,b.BetSiteID
				,b.betteam
				,b.oddsspread
				,b.srecommend
		FROM	@tblTransIds s 
			INNER JOIN bettrans b WITH(NOLOCK) ON s.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
		WHERE b.matchid = 29 AND b.bettype = 29
			AND b.statusid = 102
		
		SET @totalMainParlay = @@ROWCOUNT
		IF @totalMainParlay = 0
		BEGIN		  			
			SELECT @ErrCode = 100, @ErrMsg = 'No ticket found.'						
			
			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
			RETURN
		END
		ELSE
		BEGIN
			-- Apply new way to lock parlay tickets	
			EXEC dbo.NAP_Set_GlobalSettingSel 
				 @LockName = 'ParlayRefno'
				,@ThreadHold = @ThreadHold OUTPUT

			IF @totalMainParlay <= @ThreadHold
			BEGIN
				INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
				SELECT matchid, refno
				FROM #tblRecoverBet	

				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno		= 1
					,@SPName				= @SPName
					,@Session				= @Session
					,@avaiableProcess 		= @avaiableProcess OUTPUT
					,@ErrCode				= @ErrCode OUTPUT
					,@ErrMsg				= @ErrMsg OUTPUT
			END
			ELSE --@totalMainParlay > 10K
			BEGIN
				EXEC [dbo].[NAP_Admin_CheckingProcess]
						@IsExistParlay = 1			
					  , @IsReleased	= 0
					  , @AvaiableProcess = @AvaiableProcess OUTPUT
					  , @ErrCode = @ErrCode OUTPUT
					  , @ErrMsg	= @ErrMsg OUTPUT
			END
			IF (@ErrCode <> 0 OR @avaiableProcess = 0)
			BEGIN
				SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
				RETURN		
			END
		END

		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

		IF EXISTS (SELECT TOP 1 1 FROM #tblRecoverBet WHERE winlostdate <= @Movebetdate)
		BEGIN
			------ release Parlay procesee	
			EXEC [dbo].[NAP_Admin_CheckingProcess]
					@IsExistParlay = 1			
				  , @IsReleased	= 1	

			SELECT @ErrCode = 99, @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'
			
			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
			RETURN		  		
		END
			  
		-- Get match list
		INSERT INTO #tmpMatch(RowNumber, matchId, transId, refno)
		SELECT	ROW_NUMBER() OVER (PARTITION BY t.transid ORDER BY m.eventdate DESC) AS RowNumber,
				b.matchid, t.transid, t.refno
		FROM	dbo.bettransm b WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet t ON t.refno = b.refno	
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid			
		WHERE b.SiteDBGroupID = @SiteDBGroupID

		-- Match list is auto settled
		INSERT INTO @tblMatchIds (RowNumber, matchid, transid, refno)
		SELECT	DENSE_RANK() OVER (ORDER BY t.matchid) AS RowNumber,
				t.matchid, t.transid, t.refno
		FROM	#tmpMatch t
			INNER JOIN dbo.bettrans b with (nolock) ON b.TransId = t.transId
		WHERE RowNumber = 1
			AND b.SiteDBGroupID = @SiteDBGroupID

		--Just need re-cal for refno exists in BetParlayResults & all combine completed
		DELETE t
		FROM @tblMatchIds t
			OUTER APPLY (
					SELECT TOP 1 1 refno
					FROM dbo.BetParlayResult b WITH (NOLOCK)
					WHERE b.RefNo = t.refno
				)rs
		WHERE rs.refno IS NULL

		DELETE t
		FROM @tblMatchIds t
			CROSS APPLY (
					SELECT TOP 1 1 refno
					FROM dbo.BetParlayResult b WITH (NOLOCK)
					WHERE b.RefNo = t.refno
						AND b.statusid = 0
				)rs

		---- capture balance before recover
		INSERT INTO @tblBeforeBalance (custid, balance)
		SELECT	b.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid
		WHERE b.SiteDBGroupID = @SiteDBGroupID
		GROUP BY b.CustID
		---- end capture
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.CustId AS '@custid'
									,t.ruben AS '@ruben'
									,t.TransId AS '@transid'
								FROM #tblRecoverBet t
								FOR XML PATH('r'), ROOT('root')
							)
		
		UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = 'running'
			,statusID = 0
			,ruben = 0
			--,modds = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0		
			,statuswinlost = NULL
			,creator = b.custid
			,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(2,'recover',b.ExtraInfo,NULL, b.bettype)
			,FcUpdateTime = SYSDATETIME()
		OUTPUT deleted.matchid, deleted.TransId, inserted.status, inserted.statusID, inserted.ruben
			, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost
			, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
			, inserted.statuswinlost, inserted.creator, inserted.ExtraInfo, inserted.FcUpdateTime
		INTO @tmpTransInfo(matchid, transid, status, statusID, ruben, winlost, aWinLost, mWinLost, sWinLost
							,PlayerComm, Comm, aComm, sComm, statuswinlost, creator, ExtraInfo, FcUpdateTime)
		FROM dbo.bettrans b
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid
		WHERE b.SiteDBGroupID = @SiteDBGroupID

		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			INSERT INTO @tmpMatchidInfo (MatchId)
			SELECT DISTINCT MatchId FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId 
				FROM @tmpMatchidInfo m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;
				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
					    , STATUS AS 's'
						, statusID AS 'sid'
						, ruben AS 'r'
					    , winlost AS 'w'
						, awinlost AS 'aw'
						, mwinlost AS 'mw'
						, swinlost AS 'sw'
						, playercomm AS 'pc'
						, comm AS 'c'
						, acomm AS 'ac'
						, scomm AS 'sc'
					    , CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					    , creator AS 'cr'
					    , ExtraInfo AS 'ex'
					    , FcUpdateTime AS 'rut'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverMainParlay', 'bettrans', 'U', @MatchId, @TransInfo, 'p'
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo
		END

		WHILE (1 = 1)
		BEGIN
			SELECT	TOP 1 @tmp_MatchId = matchid
			FROM	@tblMatchIds
			WHERE	RowNumber = @RowNumber
		
			IF @@rowcount = 0
				BREAK		
		
			SET @RowNumber = @RowNumber + 1
		
			SELECT  @MatchDate = eventdate
			FROM	dbo.match WITH(NOLOCK)
			WHERE	matchid = @tmp_MatchId

			SELECT @tmp_TransIds = ''
			SELECT  @tmp_TransIds = @tmp_TransIds + CONVERT(VARCHAR(50), transid) + ','
			FROM	@tblMatchIds
			WHERE	matchid = @tmp_MatchId

			SELECT @refnos_29 = ''
			SELECT 	@refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(50), refno) + '|' + CONVERT(VARCHAR(50), transid)
			FROM	@tblMatchIds
			WHERE	matchid = @tmp_MatchId

			SET @refnos_29 = STUFF(@refnos_29,1,1,'')

			DELETE @tmpBoostSite
			INSERT INTO @tmpBoostSite(SiteId, srecommend )
			SELECT DISTINCT SiteID, srecommend
			FROM	@tblMatchIds t
				INNER JOIN #tblRecoverBet r ON r.transid = t.transid
			WHERE	t.matchid = @tmp_MatchId
				AND r.betteam = '1' -- mix parlay
				AND r.oddsspread = 2 -- offer parlay bonus
				AND NOT EXISTS (SELECT 	TOP 1 1 
									FROM 	dbo.bettransm bm WITH(NOLOCK) 
									WHERE 	t.refno = bm.refno 
											AND ((ISNULL(bm.statuswinlost,0) = 4 AND bm.statusID = 113)
												OR bm.statusId = 0
											)
							) -- lose/running

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
				@matchid = @tmp_MatchId
				,@mode = 'PRECAL-29'
				,@matchdate = @matchdate
				,@strXML = @tmp_TransIds
				,@strSetting = @strSetting
			
			EXEC dbo.NAP_Admin_Calculate_MP_broker
					@matchdate = @MatchDate
					,@strXML	= @refnos_29
					,@mode		= '29' 
		END

		--Insert Max Payout Queue
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
			,@Mode = 'RECOVER'
		
		--Return ResettledTransIds
		SET @ResettledTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( t.TransId AS VARCHAR(20))
									FROM #tblRecoverBet t
										INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.transid
									WHERE b.statusID NOT IN (0,1,102)
									FOR XML PATH ('')
								),1,1,''))
		
		-- capture after recover
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT	b.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid
		WHERE b.SiteDBGroupID = @SiteDBGroupID
		GROUP BY b.CustID
	
		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
	
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT		a.custid, (a.balance - b.balance) AS Balance
		FROM		@tblBeforeBalance b
		INNER JOIN	@tblAfterBalance a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) > 0
	
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 1 -- Sports		

		INSERT INTO @tblDebitPending (custID, balance)
		SELECT		a.custid, ABS(a.balance - b.balance) AS Balance
		FROM		@tblBeforeBalance b
		INNER JOIN	@tblAfterBalance a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) < 0	
	
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 -- Sports
	
		-- end capture

		INSERT INTO #Balance (custid, balance, Increased)
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM @tblBeforeBalance b
			INNER JOIN @tblAfterBalance a ON b.custid = a.custid
		WHERE b.balance <> a.balance

		--> Build list of customer name with negative balance
		SET @NegativeBalanceUsers = ''
		SELECT @CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), custid)
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

		IF @totalMainParlay <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
					,@Session	= @Session
					,@IsReleased = 1
		END
		ELSE
		BEGIN
			------ release Parlay procesee	
			EXEC [dbo].[NAP_Admin_CheckingProcess]
					@IsExistParlay = 1			
				  , @IsReleased	= 1	
		END

		--transid is auto settled
		SELECT @SettledMainTranIds = ''
		SELECT  @SettledMainTranIds = @SettledMainTranIds + ',' + CONVERT(VARCHAR(50), b.transid) 
		FROM	bettrans b WITH (NOLOCK)
				INNER JOIN #tblRecoverBet t
						ON b.transid = t.transid
		WHERE b.statusID IN (111, 112, 113, 103)						
			AND b.SiteDBGroupID = @SiteDBGroupID

		SET @SettledMainTranIds = STUFF(@SettledMainTranIds,1,1,'')
	
	END TRY
	BEGIN CATCH
		IF @totalMainParlay <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
					,@Session	= @Session
					,@IsReleased = 1
		END
		ELSE
		BEGIN
			------ release Parlay procesee	
			EXEC [dbo].[NAP_Admin_CheckingProcess]
					@IsExistParlay = 1			
				  , @IsReleased	= 1	
		END	  
	
		SELECT @ErrCode = 100, @ErrMsg = 'Unable to recover these parlay bets'						
					
		RETURN;
	END CATCH	

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ CASE WHEN @MatchId = 29 THEN  ' Main Parlay ticket with TransId: ' ELSE ' Single ticket with TransId: '  END + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblRecoverBet
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tmpMatch
END