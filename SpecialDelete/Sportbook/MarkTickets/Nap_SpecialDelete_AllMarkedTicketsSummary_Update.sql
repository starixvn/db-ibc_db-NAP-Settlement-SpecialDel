/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Update] 
(
	@Matches  XML           = NULL,
    @UserId   INT           = 0,
    @IP       VARCHAR(15)   = NULL
)
AS
/*
    Created by: 20190325@Alan
	Task: Mark Ticket for Settlement Exclusion
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20201604@Charles: Implement parlay tickets for Mark ticket [131670]
		- 20200609@Charles: Remove notify when mark/unmark tickets [131865]
		- 20210709@Max: [TVS] Tuning SP mark/unmark tickets [Redmine: #157930]
		- 20210720@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20251028@July: [TVS] Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241502]

	Explanation's Param:
		@Matches: <Matches><Match MatchId="1" UserId="1" CreatedDate="2019-03-04 04:11:33.240"/></Matches>
*/
BEGIN
	SET NOCOUNT ON;

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN		
			SET @sqlCommand = 'EXEC dbo.Nap_SpecialDelete_AllMarkedTicketsSummary_Update '
				+ CASE WHEN @Matches IS NULL THEN '' ELSE '@Matches = ''' + CONVERT(NVARCHAR(4000), @Matches) + '''' END
				+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH

	DECLARE @Session			NVARCHAR(50)
		   ,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalParlay		INT = 0
		   ,@Row_SD				INT = 0
		   ,@Row_Refno			INT = 0
		   ,@ErrMsg				NVARCHAR(200) = ''
		   ,@ErrCode			INT = 0 
		   ,@SubTransIds		VARCHAR(MAX) = ''
		   ,@MatchDate			DATETIME
		   ,@refnos_29			VARCHAR(MAX) = ''
		   ,@Transids_29		VARCHAR(MAX) = ''
		   ,@MainParlay_MaxPO	VARCHAR(MAX) = NULL
		   ,@ActionID			INT = 90999 --TVS - Agency Cash Service
		   ,@SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SET @Session = CONVERT(NVARCHAR(50),NEWID())

	CREATE TABLE #Match (
		MatchId INT
		,UserId INT
		,CreatedDate DATETIME
		, HomeId INT, AwayId INT, SportType SMALLINT, IsNeutral BIT
		);

	CREATE TABLE #MarkedTransactionDeleted (
		TransId BIGINT
		,MatchId INT
		,IsParlay BIT DEFAULT(0)
		,IsHybrid BIT DEFAULT(0)
		,statuswinlost TINYINT
	);
	DECLARE @tmpMatchId TABLE (MatchId INT, MatchDate DATETIME, IsFinish BIT)
	DECLARE @tmpTransIdBatch TABLE (TransId BIGINT)
	DECLARE @tmpTransIdHybridParlay TABLE (TransId BIGINT, MatchId INT, IsFinish BIT)
	DECLARE @tblBeforeBalance TABLE (CustId INT PRIMARY KEY, balance MONEY)
	DECLARE @tblAfterBalance TABLE (CustId INT PRIMARY KEY, balance MONEY)
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList

	CREATE TABLE #Tickets (
		TransId   BIGINT,
		MatchId   INT,
		BetType   SMALLINT,
		IsParlay  BIT DEFAULT(0),
		Refno	   BIGINT,
		IsHybrid BIT DEFAULT(0),
		SubTransId BIGINT,
		statuswinlost TINYINT,
		IsFinish  BIT
	);
	CREATE TABLE #tblMainTicket
	(
		TransId		BIGINT
		,Refno		BIGINT
		,StatusId	TINYINT
		,CustId		INT
		,Balance	MONEY
		,Ruben		TINYINT
		,MatchId	INT
	)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT);
	CREATE TABLE #tblMatchProcess_tmp(matchid INT, KeyID TINYINT, IsFinish BIT);
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT);
	CREATE TABLE #tblMatchParlayProcess_tmp (matchId INT, IsFinish BIT);

	INSERT INTO #Match (
		MatchId
		,UserId
		,CreatedDate
		)
	SELECT x.value('@MatchId', 'INT') AS MatchId
		  ,x.value('@UserId', 'INT') AS UserId
		  ,x.value('@CreatedDate', 'DATETIME') AS CreatedDate
	FROM @Matches.nodes('Matches/Match') XmlData(x)
	OPTION (OPTIMIZE FOR (@Matches = NULL));

	-- Get tickets insert into transaction
	INSERT INTO #Tickets (
		TransId
		,MatchId
		,BetType
		,IsParlay
		,Refno
		,SubTransId
		,statuswinlost
		,IsHybrid
		)
	SELECT m.TransId
		,m.MatchId
		,m.BetType
		,CASE WHEN b.bettype = 29 THEN 1 ELSE 0 END
		,b.refno
		,m.TransId AS SubTransId
		,b.statuswinlost
		,CASE WHEN b.oddsspread = 3 THEN 1 ELSE 0 END AS IsHybrid
	FROM dbo.MarkedTransaction m WITH (NOLOCK)
		INNER JOIN #Match t ON t.MatchId = m.MatchId
								AND t.UserId = m.UserId
								AND m.CreatedDate = t.CreatedDate
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = m.transid AND b.SiteDBGroupID = @SiteDBGroupID
	WHERE m.MarkType IN (0,1)

	-- Get tickets insert into transaction
	INSERT INTO #Tickets (
		TransId
		,MatchId
		,BetType
		,IsParlay
		,Refno
		,SubTransId
		,statuswinlost
		,IsHybrid
		)
	SELECT m.TransId
		,m.MatchId
		,bm.BetType
		,1 AS IsParlay
		,bm.refno
		,bm.transid AS SubTransId
		,bm.statuswinlost
		,CASE WHEN b.oddsspread = 3 THEN 1 ELSE 0 END AS IsHybrid
	FROM dbo.MarkedTransaction m WITH (NOLOCK)
		INNER JOIN #Match t ON t.MatchId = m.MatchId
								AND t.UserId = m.UserId
								AND m.CreatedDate = t.CreatedDate
		INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = m.transid AND bm.SiteDBGroupID = @SiteDBGroupID
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON bm.refno = b.refno 
	WHERE m.MarkType IN (2,3)

	-- Check Lock Match
	DECLARE @avaiableProcess BIT
		   ,@IsExistSingle BIT = 0
		   ,@IsExistParlay BIT = 0
		   ,@IsExistFM BIT = 0
		   ,@IsExistFM2 BIT = 0

	SELECT @IsExistSingle = MAX(CASE WHEN f.GroupId IS NULL THEN 1 ELSE 0 END)
		  ,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
		  ,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM #Tickets AS t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f
	WHERE t.IsParlay = 0;

	--Lock Refno process - SportBook
	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT  0 AS MatchId, t.Refno --Many matches with same Refno
	FROM #Tickets AS t
	WHERE t.IsParlay = 1
	GROUP BY t.Refno  
	HAVING COUNT(*) > 1
	SET @totalParlay = @@ROWCOUNT

	INSERT INTO #tblMatchParlayProcess (MatchId, RefNo)
	SELECT  t.MatchId, t.RefNo
	FROM #Tickets t
	WHERE NOT EXISTS (SELECT 1 FROM #tblMatchParlayProcess m WHERE m.RefNo = t.refno) 
		AND t.IsParlay = 1
	SET @totalParlay = @totalParlay + @@ROWCOUNT

	IF @totalParlay > 0 
		SET @isExistParlay = 1

	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchProcess (MatchId, KeyID)
	SELECT DISTINCT MatchId
		,CASE 
			WHEN f.GroupId IS NULL THEN 1 --SB
			WHEN f.GroupId = 1 THEN 6 -- Fast Market
			WHEN f.GroupId = 2 THEN 7 -- Fast market 228
			ELSE 0
			END AS KeyID
	FROM #Tickets t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f
	WHERE 1 = CASE WHEN @totalParlay <= @ThreadHold AND t.IsParlay <> 1 THEN 1
				   WHEN @totalParlay > @ThreadHold THEN 1
				   ELSE 0 END

	-- Apply new way to lock parlay tickets
	IF @totalParlay = 0 OR @totalParlay <= @ThreadHold
	BEGIN
		DELETE FROM #tblMatchProcess WHERE KeyID = 0
		IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess 
				 @isExistMatch = @IsExistSingle
				,@IsExistFM = @IsExistFM
				,@IsExistFM2 = @IsExistFM2
				,@spName = @spName
				,@avaiableProcess = @avaiableProcess OUTPUT
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT;	

			IF (@ErrCode <> 0 OR @avaiableProcess = 0)
			BEGIN
				SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
				RETURN;
			END;
		END

		IF @totalParlay > 0
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				 @IsLockingByRefno	= 1
				,@spName			= @spName
				,@Session			= @Session
				,@avaiableProcess 	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT	
			
			IF (@ErrCode <> 0 OR @avaiableProcess = 0)
			BEGIN
				SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg

				-- releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistMatch = @IsExistSingle,
					@IsExistFM = @IsExistFM,
					@IsExistFM2 = @IsExistFM2,
					@IsReleased = 1;
				RETURN;	
			END;
				
		END	

	END
	ELSE IF @totalParlay > @ThreadHold
	BEGIN
		-- checking SD proccess
		EXEC dbo.NAP_Admin_CheckingProcess 
			 @isExistMatch = @IsExistSingle
			,@isExistParlay = @IsExistParlay
			,@IsExistFM = @IsExistFM
			,@IsExistFM2 = @IsExistFM2
			,@spName = @spName
			,@avaiableProcess = @avaiableProcess OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT;

		IF (@ErrCode <> 0 OR @avaiableProcess = 0)
		BEGIN
			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg
			RETURN;
		END;
	END
	
	-- Delete Transaction
	DECLARE @TransIds_SB VARCHAR(MAX), @MatchId INT, @MatchId_RefNo INT

	INSERT INTO #tblMatchProcess_tmp (KeyID, matchid)
	SELECT KeyID, matchid
	FROM #tblMatchProcess

	IF @totalParlay <= @ThreadHold
	BEGIN
		INSERT INTO #tblMatchParlayProcess_tmp (matchId)
		SELECT DISTINCT MatchId
		FROM #Tickets 
		WHERE IsParlay = 1
	END

	WHILE(1=1)
	BEGIN TRY
		TRUNCATE TABLE #tblMatchProcess

		SELECT @MatchId = NULL, @MatchId_RefNo = NULL, @Row_SD = 0, @Row_Refno = 0

		UPDATE TOP (1) m SET m.IsFinish = 1, @MatchId = m.MatchId
		FROM #tblMatchProcess_tmp m 
		WHERE m.IsFinish IS NULL
		SET @Row_SD = @@ROWCOUNT
		
		IF @totalParlay <= @ThreadHold
		BEGIN
			UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId_RefNo = p.MatchId
			FROM #tblMatchParlayProcess_tmp p
			WHERE p.IsFinish IS NULL
			SET @Row_Refno = @@ROWCOUNT
		END

		IF @Row_SD = 0 AND @Row_Refno = 0
			  BREAK

		WHILE (0=0)
		BEGIN
			DELETE #MarkedTransactionDeleted

			UPDATE TOP (2000) t
				SET t.IsFinish = 1
			OUTPUT DELETED.TransId
				  ,DELETED.MatchId
				  ,DELETED.IsParlay
				  ,DELETED.IsHybrid
			      ,DELETED.statuswinlost
			INTO #MarkedTransactionDeleted (TransId, MatchId, IsParlay, IsHybrid, statuswinlost)
			FROM #Tickets t
			WHERE t.IsFinish IS NULL
				AND (t.MatchId = @MatchId OR t.MatchId = @MatchId_RefNo)

			IF @@ROWCOUNT = 0 BREAK	

			SELECT @TransIds_SB = CAST((
										SELECT m.TransId AS '@id'
											,m.MatchId AS '@match'
											,m.IsParlay AS '@p'
										FROM #MarkedTransactionDeleted m
										FOR XML PATH('r')
											,ROOT('root')
											,TYPE
									) AS VARCHAR(MAX));

			EXEC dbo.TicketVoiding_Admin_VoidingTransId
				@TransIds = @TransIds_SB,
				@UserId = @UserId,
				@CalledByBrokerService = 0,
				@IsUseServiceBroker = 1,
				@ActionType = 2
		
			SET @TransIds_SB = '' 
			
			IF EXISTS (SELECT TOP 1 1 FROM #MarkedTransactionDeleted WHERE IsHybrid = 1 AND statuswinlost IS NOT NULL)
			BEGIN
				DELETE FROM #tblMainTicket
				DELETE FROM @tmpMatchId
				DELETE FROM @tmpTransIdHybridParlay
				DELETE FROM @tblBeforeBalance
				DELETE FROM @tblAfterBalance
				DELETE FROM @tblDebitPending
				DELETE FROM @tblCreditPending
				SET @MainParlay_MaxPO = ''
				SET @refnos_29 = ''
				SET @SubTransIds = ''
				SET @Transids_29 = ''

				--Get list of maintransids
				INSERT INTO #tblMainTicket(TransId, Refno, StatusId, CustId, Balance, Ruben, MatchId)
				SELECT DISTINCT
					b.TransId
				   ,b.refno
				   ,b.statusID
				   ,b.custid
				   ,b.winlost - b.actual_stake + b.playercomm AS balance
				   ,b.ruben
				   ,t.matchid
				FROM #MarkedTransactionDeleted AS t
					INNER JOIN bettransm AS bm WITH (NOLOCK) ON t.TransId = bm.TransId
					INNER JOIN bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
				WHERE b.bettype = 29 AND t.IsHybrid = 1 AND t.statuswinlost IS NOT NULL
				UNION ALL 
				SELECT DISTINCT
					b.TransId
				   ,b.refno
				   ,b.statusID
				   ,b.custid
				   ,b.winlost - b.actual_stake + b.playercomm AS balance
				   ,b.ruben
				   ,t.matchid
				FROM #MarkedTransactionDeleted AS t
					INNER JOIN bettrans AS b WITH (NOLOCK) ON t.TransId = b.TransId
				WHERE b.bettype = 29 AND t.IsHybrid = 1 AND b.statuswinlost IS NOT NULL

				--Capture @tblBeforeBalance
				INSERT INTO @tblBeforeBalance(custid, balance)
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
			
				INSERT INTO @tmpTransIdHybridParlay (TransId, MatchId)
				SELECT b.TransId, b.MatchId
				FROM #MarkedTransactionDeleted AS b
				WHERE IsHybrid = 1 AND statuswinlost IS NOT NULL AND b.MatchId <> 29

				INSERT INTO @tmpMatchId(MatchId, MatchDate)
				SELECT DISTINCT m.MatchId, m.eventdate
				FROM @tmpTransIdHybridParlay AS  b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			
				--For BettransM
				WHILE ( 1 = 1)
				BEGIN
					UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId, @MatchDate = MatchDate
					FROM @tmpMatchId p
					WHERE p.IsFinish IS NULL
		
					IF @@ROWCOUNT = 0 BREAK

					WHILE (1 = 1)
					BEGIN
						DELETE @tmpTransIdBatch
						SET @SubTransIds = ''

						UPDATE TOP (2000) t
						SET t.IsFinish = 1
							OUTPUT deleted.TransId
							INTO @tmpTransIdBatch(TransId)
						FROM @tmpTransIdHybridParlay AS t
						WHERE t.IsFinish IS NULL AND t.MatchId = @MatchId

						IF @@ROWCOUNT = 0 BREAK

						SELECT @SubTransIds = @SubTransIds + CONVERT(VARCHAR(50),TransId) + ','
						FROM @tmpTransIdBatch

						EXEC dbo.NAP_Admin_Calculate_MP_broker
							@matchid = @MatchId
							,@matchdate = @MatchDate
							,@mode = 'Hybrid_m' --Update bettransm + betparlaydetail
							,@strTransIds = @SubTransIds
					END

					SELECT @Transids_29 = @Transids_29 + CONVERT(VARCHAR(50), TransId) + ','
					FROM #tblMainTicket
					WHERE matchid = @MatchId

					--Call pre-cal: betparlaydetail/betparlayresult
					EXEC dbo.NAP_Admin_Calculate_MP_Broker
						@matchid	 = @MatchId
						,@matchdate  = @MatchDate
						,@strXML	 = @Transids_29
						,@mode		 = 'PRECAL-29'
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
			
				INSERT INTO #Balance (custid, balance, Increased)
				SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
				FROM @tblBeforeBalance b
					INNER JOIN @tblAfterBalance a ON b.custid = a.custid
				WHERE b.balance <> a.balance

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
							,@spName 
					FROM	#Balance
					WHERE	Increased = 0
				END		        
			END
		END

		INSERT INTO #tblMatchProcess (KeyID, matchid)
		SELECT KeyID, matchid
		FROM #tblMatchProcess_tmp t
		WHERE t.matchid = @MatchId

		IF @totalParlay = 0 OR @totalParlay <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				-- releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistMatch = @IsExistSingle,
					@IsExistFM = @IsExistFM,
					@IsExistFM2 = @IsExistFM2,
					@IsReleased = 1;
			END

			IF @totalParlay > 0 AND EXISTS (SELECT 1 FROM #tblMatchParlayProcess)
			BEGIN
				-- releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1

				TRUNCATE TABLE #tblMatchParlayProcess
				SET @totalParlay = 0
			END
		END
		ELSE IF @totalParlay > @ThreadHold
		BEGIN
			--Release Match
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch = @IsExistSingle,
				@isExistParlay = @IsExistParlay,
				@IsExistFM = @IsExistFM,
				@IsExistFM2 = @IsExistFM2,
				@IsReleased = 1;
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
	END CATCH 

	TRUNCATE TABLE #Match
	INSERT INTO #Match (MatchId, HomeId, AwayId, SportType, IsNeutral)
	SELECT DISTINCT CASE WHEN sporttype IN (50,8) AND ChildMatchType = 200 THEN m.ParentID ELSE t.MatchId END
		, HomeId
		, AwayId
		, SportType
		, IsNeutral
	FROM #Tickets t
		INNER JOIN dbo.match m WITH (NOLOCK) ON t.MatchId = m.MatchId

	IF EXISTS ( SELECT TOP 1 1 FROM #Match WHERE SportType IN (50,8))
	BEGIN
		UPDATE d
		SET d.matchid = m.ParentID
		FROM #Tickets d
			INNER JOIN dbo.match m WITH (NOLOCK) ON d.matchid = m.matchid AND m.sporttype IN (50,8) AND m.ChildMatchType = 200
	END

	------------------------------------------------------------------------------
	--1. Table return error code/ msg
	SELECT @ErrCode AS ErrorCode
		 , @ErrMsg AS ErrorMsg
 
	--2. Table get match info
	SELECT MatchId, HomeId, AwayId, SportType, IsNeutral
	FROM #Match

	-- Write Log
	DECLARE @xmlLog VARCHAR(MAX);
	SELECT @xmlLog = CAST((
				SELECT 90502 AS '@LogActionId' -- 90502: Action Unmark All
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,m.MatchId AS '@MatchId'
					,STUFF((
							SELECT ',' + CAST(d.TransId AS NVARCHAR(100))
							FROM #Tickets AS d
							WHERE d.MatchId = m.MatchId
							FOR XML PATH('')
							), 1, 1, '') AS '@LogData'
				FROM #Match AS m
				FOR XML PATH('r')
					,ROOT('root')
					,TYPE
				) AS VARCHAR(MAX));

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log';

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

	DROP TABLE #Match;
	DROP TABLE #MarkedTransactionDeleted;
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblMatchProcess_tmp
	DROP TABLE #Tickets
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblMatchParlayProcess_tmp
	DROP TABLE #tblMainTicket
	DROP TABLE #Balance

	SET NOCOUNT OFF;
END