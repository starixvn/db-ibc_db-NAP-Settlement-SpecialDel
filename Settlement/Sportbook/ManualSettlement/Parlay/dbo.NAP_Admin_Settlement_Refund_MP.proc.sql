/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_MP] (
	@MatchId 	INT
	,@Creator 	INT
	,@Action 	VARCHAR(20)
	,@IP 		VARCHAR(15) = ''
	,@ErrCode 	INT = 0 OUTPUT
	,@ErrMsg 	NVARCHAR(200) = '' OUTPUT
)
AS
/*	Creator: 20161206@Bobby
	Task: #61352 - Apply settle determined for parlay bet types
	DB: DBTXN/BODB02
	ORIGINAL: 

	Revisions:		
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170901@Kathy: Settle parlay tickets of tennis in case of they have result [Redmine:#82122]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190218@Kathy: Wrong member balance when calculating parlay during move bet process [Redmine:#108768]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto refund ET & PEN match [Redmine:#145597]
		- 20210304@Louisa: Cricket AIO [Redmine:#148870]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210921@Max: Apply Max Parlay Payout [Redmine: #161037]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220709@Louisa: Fix select INTO [Redmine:#100002]
		- 20201216@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:		
		
*/


BEGIN
	SET NOCOUNT ON
	
	DECLARE @start 				DATETIME
		, @stop 				DATETIME
		, @ActionID 			INT
		, @IsDetermined 		BIT
		, @resultDetail_bb		VARCHAR(MAX) -- for basketball
		, @resultDetail			VARCHAR(MAX)

		--ticket count
		, @ticketCountTotal		INT		
		, @ticketCountEarly		INT
		, @ticketCountCAL		INT
		, @ticketCountSDT		INT
		, @ticketCountREFUND	INT
	--------------------------------
		,@minRefno				BIGINT
		,@maxRefno				BIGINT
		,@IsExistEarlyBettype	BIT
		,@IsSettleBySetting 	BIT			= 0
		,@IsCentral				BIT = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	DECLARE @MainParlay_MaxPO	VARCHAR(MAX) = NULL
	
	CREATE TABLE #temp_bettrans_29 ( transid BIGINT, refno BIGINT, IsFinished BIT, ruben TINYINT, custid INT)

	SELECT @ActionID 	= CASE 
						WHEN @action IN ('ABANDONED-2H', 'REFUND-FT') THEN 106
						WHEN @action IN ('ABANDONED-1H', 'REFUND') THEN 107
						WHEN @action IN ('REFUND-HT') THEN 120
						ELSE NULL
					END
		, @IsDetermined = CASE WHEN @action IN ('ABANDONED-1H', 'ABANDONED-2H') THEN 1 ELSE 0 END
		, @start 		= CURRENT_TIMESTAMP
		, @ticketCountTotal		= 0
		, @ticketCountCAL		= 0
		, @ticketCountSDT		= 0
		, @ticketCountREFUND	= 0
	
	-- match info
	DECLARE 
		@matchdate			SMALLDATETIME
		,@fthomescore		SMALLINT
		,@ftawayscore		SMALLINT
		,@hthomescore		SMALLINT
		,@htawayscore		SMALLINT
		,@SportType			SMALLINT
		,@betstatus			NVARCHAR(50)
		,@GoalRecord		VARCHAR(50)		
		,@IsRefundHT		BIT
		,@ParentMatchId		INT
		
		
	SELECT	TOP(1)
		@matchdate 		= eventdate
		,@SportType 	= SportType
		,@fthomescore 	= finalhomescore
		,@ftawayscore 	= finalawayscore
		,@hthomescore 	= hthomescore
		,@htawayscore 	= htawayscore
		,@betstatus 	= ISNULL(betstatus,'')
		,@GoalRecord 	= ISNULL(GoalRecord, '')
		,@IsRefundHT 	= CASE 
							WHEN @action IN ('ABANDONED-2H', 'REFUND-FT') THEN 
								CASE 
									WHEN @betstatus LIKE 'Refund HT%' OR @betstatus LIKE 'Refund;%' THEN 1  --CASE refund 30x30 then refund FT(SDT)
									ELSE 0 
								END
							WHEN @betstatus LIKE 'Refund HT%' THEN 1 
							ELSE 0 
						END
		,@ParentMatchId = CASE WHEN ChildMatchType = 200 AND ParentID IS NOT NULL AND sporttype = 50 THEN ParentID ELSE NULL END
	FROM dbo.Match WITH(ROWLOCK)
	WHERE matchid = @matchid
	
	IF @@ROWCOUNT = 0 
	BEGIN
		SELECT	@ErrCode = 1000001
				,@ErrMsg = 'Match does not exist!'
				
		RETURN -- incorrect matchid? maybe
	END

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	@ErrCode
				,@ErrMsg
	    
	    RETURN
	END
	
	IF @SportType = 1
	BEGIN
		SELECT TOP(1) @IsExistEarlyBettype = 1
		FROM dbo.bettransm bm WITH (NOLOCK)
			CROSS APPLY (
				SELECT TOP 1 1 AS IsExistEarlyBettype, s.SportType, s.SettleType
				FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
				WHERE	s.BetType = bm.bettype 
			) AS f
		WHERE matchid 		= @matchId
			AND f.SportType = @SportType
			AND f.SettleType = 'EAR'
			AND statusID	NOT IN (101, 102)
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
	END

	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
    BEGIN
        SET @IsSettleBySetting = 1
    END
    
	IF @action <> 'UNDO' 
	BEGIN		
		SELECT	TOP (1) @ErrCode = 1000002
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		FROM	dbo.TempVariableNumber WIHT(NOLOCK) 
		WHERE	KeyID = 1 
				AND KeyValue = @matchid
		
		IF @ErrCode > 0
			RETURN
			
		IF (
			(@ParentMatchId IS NULL AND @hthomescore IS NULL AND @htawayscore IS NULL) --HT scores
			AND 
			(@ParentMatchId IS NULL AND @fthomescore IS NULL AND @ftawayscore IS NULL) --FT scores
		)
		BEGIN
			SELECT	@ErrCode = 1000003
					,@ErrMsg = 'This match has not been keyed in score yet'
			RETURN
		END
	END
	
	-- check marked ticket
	EXEC dbo.NAP_Set_CheckingMarkedTransaction
		@MatchID  = @matchid
		,@Action  = 'MP'
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg  = @ErrMsg	OUTPUT
	
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END
	
	DECLARE @IsAutoRefund BIT	= 0	
	IF @Creator = 0
	BEGIN
		SET @IsAutoRefund  =  1 
		EXEC NAP_Set_AutoRefund_MatchChecking_Ticket
			@MatchId		= @matchid
			,@sporttype		= 1
			,@Typeid		= 10
			,@ErrCode 		= @ErrCode OUTPUT
			,@ErrMsg 		= @ErrMsg OUTPUT
	END

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		SELECT @ErrCode, @ErrMsg
		RETURN
	END

	IF @Sporttype = 1
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_2 
			@mode 				= 'all'
			,@matchid 			= @matchID
			,@str_resultDetail 	= @resultDetail OUTPUT
	END
	
	IF @SportType = 2
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_2 
			@mode = 'basketball'
			,@matchid = @matchid
			,@str_resultDetail = @resultDetail_bb OUTPUT
	END
	
	
	BEGIN TRY
		--CHECK for CAL fisrt
		IF @IsSettleBySetting = 1 OR @IsExistEarlyBettype = 1
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate_9001
                @matchid 			= @matchid
                ,@matchdate 		= @matchdate
                ,@mode 				= 'CAL'
                ,@SportType 		= @SportType
                ,@ticketCount		= @ticketCountCAL OUTPUT
		END 

		IF @IsSettleBySetting = 0
		BEGIN
			IF @action IN ('REFUND-HT', 'ABANDONED-2H', 'REFUND-FT') 
				OR (@SportType IN (2) AND @Action = 'REFUND')
			BEGIN
				--DO calculation
				EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate
					@MatchId			= @MatchId
					,@matchdate			= @matchdate
					,@mode				= @Action
					,@hth		 		= @hthomescore
					,@hta		 		= @htawayscore
					,@fth				= @fthomescore
					,@fta				= @ftawayscore
					,@Sporttype			= @Sporttype
					,@betstatus 		= @betstatus
					,@GoalSequence 		= @GoalRecord
					,@resultDetail_bb	= @resultDetail_bb
					,@resultDetail		= @resultDetail
					,@IsRefundHT		= @IsRefundHT
					,@ticketCount		= @ticketCountCAL OUTPUT
				
			END
		END
		
		--CALL settle determinable first
		IF(@IsDetermined = 1)
		BEGIN
			--DO settle determined
			EXEC dbo.NAP_Admin_Settlement_Parlay_SDT
				@MatchId			= @MatchId
				,@matchdate			= @matchdate
				,@mode				= @Action
				,@hthomescore 		= @hthomescore
				,@htawayscore 		= @htawayscore
				,@fthomescore		= @fthomescore
				,@ftawayscore		= @ftawayscore
				,@Sporttype			= @Sporttype
				,@betstatus 		= @betstatus
				,@GoalRecord 		= @GoalRecord
				,@IsRefundHT		= @IsRefundHT
				,@resultDetail		= @resultDetail
				,@ticketCount		= @ticketCountSDT OUTPUT
		END

		--REFUND the REST
		IF @IsSettleBySetting = 1 OR @IsExistEarlyBettype = 1
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate_9001
                @matchid 			= @matchid
                ,@matchdate 		= @matchdate
                ,@mode 				= 'REFUND'
                ,@SportType 		= @SportType
                ,@ticketCount		= @ticketCountREFUND OUTPUT
		END
		
		IF @IsSettleBySetting = 0
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Parlay_Refund
				@MatchId			= @MatchId
				,@matchdate			= @matchdate
				,@mode				= @Action
				,@IsRefundHT		= @IsRefundHT
				,@resultDetail_bb	= @resultDetail_bb
				,@resultDetail		= @resultDetail
				,@ticketCount		= @ticketCountREFUND OUTPUT
		END
		
		SET @ticketCountTotal		= ISNULL(@ticketCountCAL, 0) + ISNULL(@ticketCountSDT, 0) + ISNULL(@ticketCountREFUND, 0)

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 1000004
			,@ErrMsg	= ERROR_MESSAGE()
			
		RETURN
	END CATCH
	
	BEGIN --CAL main tickets by refno
		DECLARE @rowCnt29 int
				,@rowCnt int
		DECLARE @strTransIds varchar(MAX) = ''
				,@strRefnos VARCHAR(MAX) = ''
		
		DECLARE @refnos TABLE (refno BIGINT)		
		CREATE TABLE #tempRefno29 (refno BIGINT, transid BIGINT)	
		
		-- for balance table --	
		DECLARE @tblDebitPending_29 TVP_BalanceList
		DECLARE @tblCreditPending_29 TVP_BalanceList

		CREATE TABLE #BalanceBefore_29 (transid BIGINT PRIMARY KEY, custid INT, balance money)
		CREATE TABLE #BalanceAfter_29 (transid BIGINT PRIMARY KEY, custid INT, balance money)			
		CREATE TABLE #Balance_29 (custid INT, balance MONEY)

		DECLARE @TotalAccount INT
		
		----------------------------------------------------------------------------------------------------------------------------------------
		INSERT INTO @refnos(refno)
		SELECT refno
		FROM dbo.bettransm bm WITH(ROWLOCK)
		WHERE matchid = @matchid
			AND NOT EXISTS (
				SELECT 1 FROM bettransm WITH(NOLOCK) WHERE refno = bm.refno AND statusID IN(1, 101)
			)
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END

		SET @rowCnt = @@ROWCOUNT --number of tickets of the match
		
		BEGIN --BEGIN: calculate 29 ----------------------------------
			
			INSERT INTO #temp_bettrans_29 ( transid, refno, IsFinished, ruben, custid)
			SELECT transid, refno, 0 AS IsFinished, ruben, custid
			FROM bettrans b WITH(NOLOCK)		
			WHERE b.matchid = 29
				AND b.statusID NOT IN (101,102) --('VOID','REJECT')
				AND refno IN (SELECT refno FROM @refnos)
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				
			SET @rowCnt29 = @@ROWCOUNT -- number of system parlay ticket

			INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
			VALUES (@matchid, @rowCnt29, CURRENT_TIMESTAMP, NULL, 'Start running PRECAL-29')

			IF @rowCnt29 > 0 -- got system parlay tickets
			BEGIN	
				SET @strTransIds = STUFF((
					SELECT ',' + cast(transid as varchar(20)) 
					FROM #temp_bettrans_29 
					FOR XML PATH('')
				), 1,1,'')
			
				-- handle betParlayDetail, betParlayResult
				EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchid
					,@mode = 'PRECAL-29'
					,@matchdate = @matchdate
					,@strXML = @strTransIds
			
				INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
				VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'Start running CAL-29')

				--Prepare for Max Payout
				SELECT @MainParlay_MaxPO = (SELECT t.CustId AS '@custid'
											,t.ruben AS '@ruben'
											,t.TransId AS '@transid'
										FROM #temp_bettrans_29 t
										FOR XML PATH('r'), ROOT('root')
									)
				
				-- update summary info back to bettrans
				WHILE (1=1)
				BEGIN
					TRUNCATE TABLE #tempRefno29
					TRUNCATE TABLE #BalanceBefore_29
					TRUNCATE TABLE #BalanceAfter_29

					SET @strRefnos = ''
					
					UPDATE TOP (800) #temp_bettrans_29
						SET IsFinished = 1
					OUTPUT INSERTED.refno, INSERTED.transid INTO #tempRefno29 (refno, transid)
					WHERE IsFinished = 0
					
					IF @@rowcount = 0
						BREAK
						
					SELECT @strRefnos = @strRefnos + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
					FROM	#tempRefno29
					
					SET @strRefnos = STUFF(@strRefnos,1,1,'')
					
					---- CAPTURE value BALANCE before udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
					INSERT INTO #BalanceBefore_29(transid, custid, balance)
					SELECT b.transid
						,b.custid
						,(b.winlost - b.actual_stake + b.playercomm) AS balance
					FROM dbo.bettrans b WITH(ROWLOCK)
					WHERE EXISTS( SELECT 1 FROM #tempRefno29 WHERE transid = b.transid)
					--------------------------------------------------------------	

					EXEC dbo.NAP_Admin_Calculate_MP_broker
						@mode = '29'
						,@matchdate = @matchdate
						,@strXML = @strRefnos

					---- CAPTURE value BALANCE after udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
					INSERT INTO #BalanceAfter_29 (transid, custid, balance)
					SELECT b.transid
						,b.custid
						,(b.winlost - b.actual_stake + b.playercomm) AS balance
					FROM dbo.bettrans b WITH(ROWLOCK)
					WHERE EXISTS( SELECT 1 FROM #tempRefno29 WHERE transid = b.transid)

					INSERT INTO #Balance_29 (custid, balance)
					SELECT b.custid
						,SUM(a.balance - b.balance)
					FROM #BalanceBefore_29 b
						INNER JOIN #BalanceAfter_29 a ON b.transid = a.transid
					GROUP BY b.custid
				END			
				
				--Insert Max Payout Queue
				EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
					@MatchId= 29
					,@TransidList = @MainParlay_MaxPO
				
				INSERT INTO @tblDebitPending_29 (custID, balance)
				SELECT t.custid, ABS(t.balance)
				FROM (
					SELECT	custID, SUM(balance) AS balance
					FROM	#Balance_29
					GROUP BY custID
				) t
				WHERE t.balance < 0

				IF @@ROWCOUNT <> 0
					EXEC dbo.Dot_BalancePendingDebitIns
						@BalancePending = @tblDebitPending_29
						,@Type			= 1 -- Sports

				INSERT INTO @tblCreditPending_29 (custID, balance)
				SELECT t.custid, ABS(t.balance)
				FROM (
					SELECT	custID, SUM(balance) AS balance
					FROM	#Balance_29
					GROUP BY custID
				) t
				WHERE t.balance > 0

				IF @@ROWCOUNT <> 0
					EXEC dbo.Dot_BalancePendingCreditIns
						@BalancePending = @tblCreditPending_29
						,@Type			= 1 -- Sports
			
				----
				-- Add Negative Balance into BalanceNegative table 
				----
				INSERT INTO [bodb02].[dbo].[BalanceNegative] (
					[ExecDate]
					,[MatchID]
					,[ActionID]
					,[GroupID]
					,[CustID]
					,[Balance]
					,[StatusID]
					,[Remark]
					)
				SELECT GETDATE()
					,@MatchID
					,@ActionID
					,2 -- Sportsbook Parlay Settlement 
					,CustID
					,Balance
					,0
					,@matchid
				FROM (	SELECT	custID, SUM(balance) AS balance
						FROM	#Balance_29
						GROUP BY custID) t
				WHERE t.balance < 0

				INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
				VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'END running CAL-29')
			END
		END
	END
	
	----------------------------------------------------------------------------------------------------------------------------------------
	BEGIN --BEGIN: UPDATE match_remark ----------------------------------	
		DECLARE @command varchar(5)
		--SET @command = CASE WHEN @action = 'CAL' THEN 'M' ELSE 'R' END
		SET @command = 'R'

		EXEC DBPRO.BODB02.dbo.NAP_UpdateMatch_Remark @matchid = @matchid
				,@command = @command

		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_Refund_MP'
			,@Matchid = @matchid
			,@creator = @creator		
	END --END: UPDATE match_remark ----------------------------------	

	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
	VALUES (@matchid, NULL, NULL, CURRENT_TIMESTAMP, 'well done, no more to do')

	IF @IsAutoRefund = 1
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefund_ResultUpd
			  @MatchId = @matchid 
			, @TypeId  = 10
			, @StatusId = 2
		END
	----------------------------------------------------------------------------------------------------------------------------------------
	IF @IsCentral = 1 
	BEGIN --BEGIN: WRITE LOG ----------------------------------		
		DECLARE @Remark VARCHAR(200)
		
		SET @stop = CURRENT_TIMESTAMP

		SELECT @Remark = 'NAP: IsAuto: ' + CAST(@IsAutoRefund AS CHAR(1)) + '<br/> '
				+ 'Calculate Multiple (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) + ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

		EXEC dbo.Logfile_V2 
			@UserID = @creator
			,@Doing = @Remark
			,@extend = @MatchId

		SELECT @Remark = CASE WHEN @ParentMatchId IS NOT NULL THEN 'child: '+CAST(@matchid AS VARCHAR) +  '<br/> ' ELSE '' END
						+ 'NAP: Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms;TC:' + CAST(@ticketCountTotal AS NVARCHAR(10)) 
		
		IF @ParentMatchId IS NOT NULL --- Cricket
		BEGIN
			SELECT  @MatchId =  @ParentMatchId
					,@fthomescore = finalhomescore 
					,@ftawayscore = finalawayscore
					,@betstatus	 = ISNULL(betstatus,'')
			FROM	DBPRO.BODB02.dbo.Match WITH(NOLOCK)
			WHERE	matchid = @ParentMatchId
		END

		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_MajorRound(@Sporttype) sd WHERE sd.RoundID = '01' AND sd.GroupType = 'HT')
		BEGIN
			SELECT @hthomescore		= NULL
					,@htawayscore	= NULL
		END

		BEGIN TRY
			
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				,@Matchid = @matchid
				,@ActionID = @ActionID
				,@finalhomescore = @fthomescore
				,@finalawayscore = @ftawayscore
				,@hthomescore = @hthomescore
				,@htawayscore = @htawayscore
				,@GoalRecord = @goalrecord
				,@betstatus = @betstatus
				,@Remark = @Remark
				,@IP = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				,@Matchid = @matchid
				,@ActionID = @ActionID
				,@finalhomescore = @fthomescore
				,@finalawayscore = @ftawayscore
				,@hthomescore = @hthomescore
				,@htawayscore = @htawayscore
				,@GoalRecord = @goalrecord
				,@betstatus = @betstatus
				,@Remark = @Remark
				,@IP = @IP
		END CATCH
	END --END: WRITE LOG ----------------------------------

	RETURN
END	
GO 

