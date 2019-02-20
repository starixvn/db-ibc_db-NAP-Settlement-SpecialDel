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


	Param's Explanation:		
		
*/


BEGIN
	SET NOCOUNT ON

	DECLARE @start 				DATETIME
		, @stop 				DATETIME
		, @ActionID 			INT
		, @IsDetermined 		BIT
		, @resultDetail_cb 		VARCHAR(MAX) = NULL -- for corners bets
		, @resultDetail_ss 		VARCHAR(MAX)
		, @resultDetail_bb		VARCHAR(MAX) -- for basketball
		, @resultDetail			VARCHAR(MAX)
		, @SelectedSetCAL 		VARCHAR(50)
		, @SelectedSetREFUND 	VARCHAR(50)
		--ticket count
		, @ticketCountTotal		INT		
		, @ticketCountBetRadar	INT
		, @ticketCountCAL		INT
		, @ticketCountSDT		INT
		, @ticketCountREFUND	INT
	--------------------------------
		,@minRefno				BIGINT
		,@maxRefno				BIGINT
		,@IsBetRadar			BIT
		,@IsSettleBySetting 	BIT			= 0
	
	DECLARE @TennisTotal INT = NULL, @TotalGameHomeMatch INT = NULL, @TotalGameAwayMatch INT = NULL

	SELECT @ActionID 	= CASE 
						WHEN @action IN ('ABANDONED-2H', 'REFUND-FT') THEN 106
						WHEN @action IN ('ABANDONED-1H', 'REFUND') THEN 107
						WHEN @action IN ('REFUND-HT') THEN 120
						ELSE NULL
					END
		, @IsDetermined = CASE WHEN @action IN ('ABANDONED-1H', 'ABANDONED-2H') THEN 1 ELSE 0 END
		, @start 		= CURRENT_TIMESTAMP
		, @ticketCountTotal		= 0
		, @ticketCountBetRadar	= 0
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
		
	FROM dbo.Match WITH(ROWLOCK)
	WHERE matchid = @matchid
	
	IF @@ROWCOUNT = 0 
	BEGIN
		SELECT	@ErrCode = 1000001
				,@ErrMsg = 'Match does not exist!'
				
		RETURN -- incorrect matchid? maybe
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
			(@hthomescore IS NULL AND @htawayscore IS NULL) --HT scores
			AND 
			(@fthomescore IS NULL AND @ftawayscore IS NULL) --FT scores
		)
		BEGIN
			SELECT	@ErrCode = 1000003
					,@ErrMsg = 'This match has not been keyed in score yet'
			RETURN
		END
	END 
	
	
	IF @Sporttype = 1
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_2 
			@mode 				= 'cornersBets'
			,@matchid 			= @matchID
			,@str_resultDetail 	= @resultDetail_cb OUTPUT
		
		EXEC dbo.NAP_Admin_Settlement_2 
			@mode 				= 'all'
			,@matchid 			= @matchID
			,@str_resultDetail 	= @resultDetail OUTPUT
	END
	
	IF @Sporttype = 5
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_2 @mode = 'sporttingSolution'
			,@matchid = @matchID
			,@Total = @TennisTotal OUTPUT
			,@TotalHome = @TotalGameHomeMatch OUTPUT
			,@TotalAway = @TotalGameAwayMatch OUTPUT
			,@str_resultDetail = @resultDetail_ss OUTPUT	
	END
	IF @SportType = 2
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_2 
			@mode = 'basketball'
			,@matchid = @matchid
			,@str_resultDetail = @resultDetail_bb OUTPUT
	END
	
	
	BEGIN TRY
	
		SELECT TOP(1) @IsBetRadar = 1
		FROM dbo.bettransm bm WITH (NOLOCK)
			CROSS APPLY (
				SELECT TOP 1 1 AS IsBetRadar
				FROM dbo.f_Set_GetGroupBettypes() AS f 
				WHERE BetType = bm.bettype AND f.GroupId = 8
			) AS f
		WHERE matchid 		= @matchId
			AND statusID	NOT IN (101, 102)

		--CHECK Auto-Bettype first if any
		IF (@IsBetRadar = 1)
		BEGIN		
			EXEC dbo.NAP_Admin_Settlement_Parlay_BetRadar -- Early 22, 455
				@MatchId			= @MatchId
				,@matchdate			= @matchdate
				,@Mode				= @Action
				,@ticketCount		= @ticketCountBetRadar OUTPUT
		END	
		
		--CHECK for CAL fisrt
		IF @IsSettleBySetting = 1
		BEGIN
			
			EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate_9001
                @matchid 			= @matchid
                ,@matchdate 		= @matchdate
                ,@mode 				= 'CAL'
                ,@SportType 		= @SportType
                ,@ticketCount		= @ticketCountCAL OUTPUT
		END 
		ELSE IF(
			@action IN ('REFUND-HT', 'ABANDONED-2H','REFUND-FT')
		) OR (@SportType IN (2,5) AND @Action = 'REFUND')
		BEGIN
			/*IF(@action IN ('REFUND-HT')) --REFUND Is3x30 AND CAL the REST
			BEGIN
				TODO
			END
			IF(@action IN ('ABANDONED-2H', 'REFUND-FT')) --CAL-HT and REFUND/ABANDONED the REST
			BEGIN
				TODO
			END*/
			
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
				,@resultDetail_cb	= @resultDetail_cb
				,@resultDetail_ss	= @resultDetail_ss
				,@resultDetail_bb	= @resultDetail_bb
				,@resultDetail		= @resultDetail
				,@IsRefundHT		= @IsRefundHT
				,@ticketCount		= @ticketCountCAL OUTPUT
				
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
		IF @IsSettleBySetting = 1
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate_9001
                @matchid 			= @matchid
                ,@matchdate 		= @matchdate
                ,@mode 				= 'REFUND'
                ,@SportType 		= @SportType
                ,@ticketCount		= @ticketCountREFUND OUTPUT
		END
		ELSE
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Parlay_Refund
				@MatchId			= @MatchId
				,@matchdate			= @matchdate
				,@mode				= @Action
				,@IsRefundHT		= @IsRefundHT
				,@resultDetail_bb	= @resultDetail_bb
				,@resultDetail_ss	= @resultDetail_ss
				,@ticketCount		= @ticketCountREFUND OUTPUT
		END
		
		/*
		SELECT @ticketCountBetRadar	AS TC_BetRadar
			, @ticketCountCAL		AS TC_CAL
			, @ticketCountSDT		AS TC_SDT
			, @ticketCountREFUND	AS TC_REFUND
		*/
		
		SET @ticketCountTotal		= ISNULL(@ticketCountBetRadar, 0) + ISNULL(@ticketCountCAL, 0) + ISNULL(@ticketCountSDT, 0) + ISNULL(@ticketCountREFUND, 0)
	
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
		SET @rowCnt = @@ROWCOUNT --number of tickets of the match
		
		BEGIN --BEGIN: calculate 29 ----------------------------------
		
			SELECT transid, refno, 0 AS IsFinished
			INTO #temp_bettrans_29
			FROM bettrans b WITH(NOLOCK)		
			WHERE b.matchid = 29
				AND b.statusID NOT IN (101,102) --('VOID','REJECT')
				AND refno IN (SELECT refno FROM @refnos)
				
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

	----------------------------------------------------------------------------------------------------------------------------------------
	BEGIN --BEGIN: WRITE LOG ----------------------------------		
		DECLARE @Remark VARCHAR(200)
		
		SET @stop = CURRENT_TIMESTAMP

		SELECT @Remark = 'NAP: Calculate Multiple (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) + ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
		EXEC dbo.WriteLog_UserLog @creator, @Remark

		SELECT @Remark = 'NAP: Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms;TC:' + CAST(@ticketCountTotal AS NVARCHAR(10)) 

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

