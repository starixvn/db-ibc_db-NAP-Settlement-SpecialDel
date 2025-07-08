/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverParlayBet_Main] 
	@BetType				VARCHAR(20)		= 'All',
	@TransIds				VARCHAR(MAX)	= '',
	@UserId					INT, 
	@IP						VARCHAR(50)
AS
/*
	Created: 20161017@Elodie
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions: 		
		- 20161104@Kent: Correct logic for GroupName [Redmine:#65531]
		- 20161111@Kent: Correct WinLost when for returned table [Redmine:#65531]
		- 20161221@Kathy: Release lock after recovering tickets [Redmine:#68960]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170727@Kathy: Update statuswinlost, creator when recover [Redmine:#80135]
		- 20171106@Kent: Implement Notifications Center [Redmine:#84330]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210720@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210801@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20211116@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220712@Kathy: Do not using SELECT INTO [Redmine:#175349]
		- 20220906@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20220929@July: Fix recover Rep to central with Statuswinlost=0 [Redmine: #178374]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185238]
		- 20231006@Max: [TVS] Integrate Parlay Boost Bonus [Redmine: #192778]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20250623@Lani: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Param's Explanation:			
		- @BetType: 'all': All
					'Mix Parlay': Mix Parlay
					'System Parlay': System Parlay
*/
BEGIN
	SET NOCOUNT ON
	
	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_BettransRecoverParlayBet_Main '
				+ CASE WHEN @BetType IS NULL THEN '' ELSE '@BetType = ''' + CONVERT(NVARCHAR(20), @BetType) + '''' END
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

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
			,@ErrCode			INT = 0
	        ,@ErrMsg			NVARCHAR(200) = ''
		    ,@SettledMainTranIds VARCHAR(MAX) = '' 
		    ,@NegativeBalanceUsers VARCHAR(MAX) = '' 
		    ,@SiteDBGroupID		SMALLINT = 0
			,@strSetting		VARCHAR(MAX)
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''
			,@ActionID				INT = 90999 --TVS - Agency Cash Service

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MainParlay_MaxPO   VARCHAR(MAX) = NULL

	DECLARE @Session			NVARCHAR(50)
		   ,@ThreadHold			INT -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalMainParlay	INT = 0 
	SET @Session = CONVERT(NVARCHAR(50),NEWID())

	CREATE TABLE #tmpMatch (RowNumber INT, matchId INT, transId BIGINT, refno BIGINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	DECLARE @tblTransIds TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @tblNoResettleTransIds TABLE (transid BIGINT PRIMARY KEY)
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

	DECLARE @matchid INT

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

	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, increased BIT)
	
	DECLARE @tblMatchIds TABLE ( 
		 RowNumber		INT 										
		,matchid		INT
		,transid		BIGINT
		,refno			BIGINT
	)								
											
	DECLARE @tblBeforeBalance	TABLE (custid INT, balance MONEY)
	DECLARE @tblAfterBalance	TABLE (custid INT, balance MONEY)		
	
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
			AND CASE
					WHEN @BetType = 'all' THEN 1
					WHEN @BetType = 'Mix Parlay' THEN CASE WHEN b.betteam = 1 THEN 1 ELSE 0 END
					WHEN @BetType = 'System Parlay' THEN CASE WHEN b.betteam = 1 THEN 0 ELSE 1 END
					ELSE 0
				END	= 1	
		
		SET @totalMainParlay = @@ROWCOUNT
		IF @totalMainParlay = 0
		BEGIN		  			
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'						
			
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

			SELECT @ErrCode = 112, @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'
			
			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
			RETURN		  		
		END

		INSERT INTO @tblNoResettleTransIds (transid)
		SELECT t.transid
		FROM dbo.bettransm b WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet t ON t.refno = b.refno
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid		
		WHERE b.SiteDBGroupID = @SiteDBGroupID
		GROUP BY t.transid
		HAVING COUNT(CASE WHEN m.eventstatus <> 'completed' THEN 1 ELSE NULL END) -- count running subs for each main ticket
			   = COUNT(*) -- count all subs for each main ticket
			  
		-- Get match list
		INSERT INTO #tmpMatch(RowNumber, matchId, transId, refno)
		SELECT	ROW_NUMBER() OVER (PARTITION BY t.transid ORDER BY m.eventdate DESC) AS RowNumber,
				b.matchid, t.transid, t.refno
		FROM	dbo.bettransm b WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet t ON t.refno = b.refno	
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid			
		WHERE NOT EXISTS (SELECT 1 FROM @tblNoResettleTransIds WHERE transid = t.transid)
			AND b.SiteDBGroupID = @SiteDBGroupID

		-- Match list is auto settled
		INSERT INTO @tblMatchIds (RowNumber, matchid, transid, refno)
		SELECT	DENSE_RANK() OVER (ORDER BY t.matchid) AS RowNumber,
				t.matchid, t.transid, t.refno
		FROM	#tmpMatch t
		WHERE RowNumber = 1

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
		
		-- capture after recover
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT	b.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid
		WHERE b.SiteDBGroupID = @SiteDBGroupID
		GROUP BY b.CustID

		INSERT INTO #Balance(custid, balance, increased)
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM @tblBeforeBalance AS b
		INNER JOIN @tblAfterBalance AS a ON b.custid = a.custid
		WHERE b.balance <> a.balance
	
		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
	
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT		custid, balance
		FROM		#Balance 
		WHERE	    increased = 1
	
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 1 -- Sports		

		INSERT INTO @tblDebitPending (custID, balance)
		SELECT		custid, ABS(balance) AS Balance
		FROM		#Balance 
		WHERE	    increased = 0	
	
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 -- Sports
	
		-- end capture

		--> Build list of customer name with negative balance
		SET @NegativeBalanceUsers = ''
		SELECT @CustIds = @CustIds +
						  CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + 
						  CONVERT(VARCHAR(20), custid)
		FROM #Balance 
		WHERE increased = 0				
		
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
						,[SessionId]
						,[Remark])
			SELECT	 GETDATE()
					,0
					,@ActionID
					,0		-- For Void/Recover
					,CustID
					,Balance
					,0
					,CAST(NEWID() AS NVARCHAR(50))
					,@spName
			FROM	#Balance
			WHERE	increased = 0
		END		        
		DROP TABLE #Balance

		DELETE	z
			OUTPUT deleted.matchid, deleted.transid, deleted.transdate, deleted.comstatus
			INTO @tmpTransInfo (matchid, transid, transdate, comstatus)
		FROM dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblRecoverBet t  ON	z.custid = t.custid AND z.matchid = t.matchid AND z.transid = t.transid
		WHERE z.SiteDBGroupID = @SiteDBGroupID

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
						, transdate AS 'td'
						, comstatus AS 'cst'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverMainParlay', 'zzzbettrans', 'D', @MatchId, @TransInfo, 'p'
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo
		END

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
		
		--1. Table return error code/ msg
		SELECT @ErrCode AS ErrorCode
			  ,@ErrMsg AS ErrorMsg
		      ,@SettledMainTranIds AS SettledMainTranIds
			  ,@NegativeBalanceUsers AS NegativeBalanceUsers

		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		
		SELECT	CASE WHEN c.currency <> 20 AND @IsITAdmin = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsITSupport -- Recover real tickets by IT ==> Send mail with recipient list "IT Support"
				,CASE WHEN c.currency <> 20 OR (c.currency = 20 AND @IsITAdmin = 0 )THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCSD --Recover real tickets => send mail to CSD , Recover UUS tickets by CSD: send mail CSD
				,CASE WHEN c.currency = 20 AND @IsITAdmin = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsITQA -- Recover UUS tickets by IT => Send mail with recipient list "IT QA"
				,SUBSTRING(T1.GroupName, 3, 30) AS GroupName
				,b.transid    
				,b.Username
				,TransDate     
				,BetType    
				,b.Refno     
				,Status     
				,WinLost - stake AS WinLost    
				,betid      
				,b.BetTeam    
				,livehomescore    
				,liveawayscore    
				,Stake     
				,Odds     
				,hdp1     
				,hdp2     
				,b.matchid
				,NULL AS homeid      
				,NULL AS awayid      
				,NULL AS sporttype     
				,NULL AS leagueid     
				,betcheck    
				,transdesc   
				,'' AS BetFrom
				,GETDATE() AS [DateTime]
				,b.ExtraInfo
				,b.actual_stake AS ActualStake
				,@SiteDBGroupID AS SiteDBGroupID
				,b.modds AS MasterOdds 
		FROM	#tblRecoverBet t
				INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = t.transid AND b.SiteDBGroupID = @SiteDBGroupID
				INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = b.srecommend
				LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
					   ON t.custid = f.CustID
				CROSS APPLY (SELECT CASE
										WHEN f.CustID IS NULL
											AND b.username <> '12EU'
											AND t.IsDeposit = 0
											AND t.mrecommend NOT IN (105181, 118473, 105183) -- MHC
											AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet, 1E, 8RM
											AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
												THEN '0-Credit' --1. For Normal bets
										WHEN t.recommend = 52466
												THEN '1-8RM' ----2: For 8RM
										WHEN f.CustID IS NULL -- Betdaq
											AND b.username <> '12EU' 
											AND t.IsDeposit = 1	
											AND t.mrecommend NOT IN (105181, 118473, 105183)
											AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466
											AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
												THEN '2-Deposit' ----3. For Deposit bets
										WHEN t.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
												THEN '3-BetFair' ----8: For Betfair
										ELSE NULL
									END AS GroupName) AS T1				
		WHERE T1.GroupName IS NOT NULL
		ORDER BY T1.GroupName, t.transid				
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
		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg 					
		RETURN;
	END CATCH	

	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN     
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, NULL, GETDATE(),@SubmittedDate)
		END      
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #tblRecoverBet
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tmpMatch
END