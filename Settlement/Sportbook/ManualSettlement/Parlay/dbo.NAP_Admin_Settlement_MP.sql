/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MP]
	@matchid				INT
	,@creator				INT
	,@action				VARCHAR(20)		= 'CAL' -- CAL / UNDO / REFUND-FT / REFUND-HT / REFUND	
	,@SelectedResources 	VARCHAR(MAX)  	= NULL
	,@IsAuto				BIT = 0
	,@IP					VARCHAR(15)		= ''
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Viet
	Date: 20151001
	Task: Main SP for Mix parlay settlement
	Original SP: NAP_Admin_Settlement_Parlay
	DB: DBTXN/BODB02

	Revisions:
		- 20160728@Kathy: Using non clustered index PK_bettrans to settle [Redmine:#61193]
		- 20160804@Kathy: Set @strRefnos = '' in while loop when settle system parlay [Redmine:#61989]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160920@Kathy: Cal mix parlay performance [Redmine:#64328]
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20160825@Bobby: #62926 - Exclude FGLG bet types
		- 20160924@Kathy: Exclude bettype 31,32
		- 20160926@Kathy: Get detail tickets of Sportbook only
		- 20161205@Bobby: #61352 - Apply settle determined for parlay bet types
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Early settlement for BAIO [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20180510@Benjamin: Incorporate new Sports: Sepak Takraw(48)[Redmine:#94608]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190218@Kathy: Wrong member balance when calculating parlay during move bet process [Redmine:#108768]
		- 20190611@Sol: Incorporate PHAIO 4 - Remove bettype 9 [Redmine:#112885]
		- 20190620@Kathy: Remove betradar corner, auto betradar bettypes [Redmine:#109584]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20190924@Sol: Incorporate BMAIO - refactor code - removed sporttype 9 [Redmine:#120324]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20200901@Kathy: Change Calculate Formula for HDP Bet Types of Football [Redmine:#140769]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210921@Max: Apply Max Parlay Payout [Redmine: #161037]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220709@Louisa: Fix select INTO [Redmine:#100002]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		@parentMatchId: identify main match of cricket
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @start		DATETIME
			,@stop		DATETIME
			,@ActionID	INT
			,@strBettypes	VARCHAR(MAX)
      		,@ticketCountTotal INT
			,@IsCentral		BIT = 0

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL
	
	DECLARE @ResourceResult_tmp AS TABLE (ResourceId VARCHAR(20),HomeValue VARCHAR(50),AwayValue VARCHAR(50))		
	DECLARE @GoalBettype_tmp AS TABLE (bettype INT, Voided_cnt INT, ticket_cnt INT)
	
	CREATE TABLE #temp_bettrans_29 ( transid BIGINT, refno BIGINT, IsFinished BIT, ruben TINYINT, custid INT)

	SET @ActionID = CASE @action
						WHEN 'CAL'	THEN 104
						WHEN 'UNDO' THEN 105
						WHEN 'REFUND-FT' THEN 106
						WHEN 'REFUND-HT' THEN 120
						WHEN 'REFUND' THEN 107
					ELSE NULL
					END

	SET @start = CURRENT_TIMESTAMP

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	-- match info
	DECLARE @matchdate			SMALLDATETIME
			,@finalhomescore	SMALLINT
			,@finalawayscore	SMALLINT
			,@hthomescore		SMALLINT
			,@htawayscore		SMALLINT
			,@SportType			SMALLINT
			,@betstatus			NVARCHAR(50)
			,@GoalRecord		VARCHAR(50)
			,@IsRefundHT		BIT
			,@priorAction		VARCHAR(20)
			,@IsSettleBySetting	BIT = 0
			,@IsExistEarlyBettype BIT
			,@ParentMatchId INT

	SELECT	@matchdate = eventdate
			,@finalhomescore = CASE sporttype WHEN 10 THEN finalawayscore ELSE finalhomescore END -- Golf, using Stroke count, so swap the score to make it become normal style
			,@finalawayscore = CASE sporttype WHEN 10 THEN finalhomescore ELSE finalawayscore END -- Golf, using Stroke count, so swap the score to make it become normal style
			,@hthomescore = hthomescore
			,@htawayscore = htawayscore
			,@SportType = SportType
			,@betstatus = betstatus
			,@GoalRecord = GoalRecord
			,@ParentMatchId = CASE WHEN ChildMatchType = 200 AND ParentID IS NOT NULL AND sporttype = 50 THEN ParentID ELSE NULL END
			,@IsRefundHT = CASE WHEN @betstatus LIKE 'Refund HT%' THEN 1 ELSE 0 END
	FROM	DBPRO.BODB02.dbo.Match WITH(ROWLOCK)
	WHERE	matchid = @matchid

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

	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
	BEGIN
	  	SET @IsSettleBySetting = 1
	END
		
	IF @action <> 'UNDO'
	BEGIN
		SELECT	TOP (1) @ErrCode = 1000000
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		FROM	dbo.TempVariableNumber WIHT(NOLOCK)
		WHERE	KeyID = 1
				AND KeyValue = @matchid

		IF @ErrCode > 0
			RETURN

		IF ( @ParentMatchId IS NULL AND ( @finalhomescore IS NULL OR @finalawayscore IS NULL OR @hthomescore IS NULL OR @htawayscore IS NULL)	)
		BEGIN
			SELECT	@ErrCode = 1001011
					,@ErrMsg = 'This match has not been keyed in score yet'
			RETURN
		END
	END
	----------------------------------------------------------------------------------------------------------------------------------------
	BEGIN --BEGIN: handle bettransM ----------------------------------

		INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
		VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'Start handle bettransM')

		-- for VolleyBall/Badminton/Squash
		DECLARE @TennisTotal INT = NULL
		DECLARE @resultDetail_bb VARCHAR(MAX) -- basketball
		DECLARE @resultDetail VARCHAR(MAX)

		SET @strBettypes = CAST((SELECT  BetType '@t'
										,GroupId '@g'
										,GroupName '@n'
										,Is3x30 '@is3x'
										,(SELECT 1 FROM dbo.f_Set_GetEarlyBettypes() WHERE bettype = f.BetType) '@isEarly'
								FROM	dbo.f_Set_GetGroupBettypes() f
								WHERE	f.GroupId <> 8 -- Early Soccer									
								FOR XML PATH ('r'), ROOT('root'), TYPE
							) AS VARCHAR(MAX))

		--correct bettransM.bettype, if any (by the way, this case should not happen nowaday)
		IF EXISTS (
			SELECT TOP (1) bm.transid
			FROM dbo.bettransM bm WITH(NOLOCK)
				INNER JOIN dbo.odds o WITH(NOLOCK) ON bm.oddsID = o.oddsID
			WHERE bm.matchid = @matchid AND bm.bettype <> o.bettype
		)
		BEGIN
			EXEC [dbo].[NAP_Admin_Calculate_MP_broker] @matchid = @matchid
				,@mode = 'm'
				,@action = 'correctBettype'
		END

		IF (@SportType IN (6, 30, 48)) AND @action = 'CAL' AND @betstatus not like 'Refund%' -- Tennis/VolleyBall/Badminton/Squash/Sepak Takraw: get TotalGamesPlayed
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_2 @mode = 'tennis'
				,@betstatus = @betstatus
				,@Total = @TennisTotal OUTPUT
		END
		
		IF @IsSettleBySetting = 1 OR @IsExistEarlyBettype = 1
		BEGIN
    		--Need to cal refund before settle
			IF @Action = 'CAL'
			BEGIN
				EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate_9001
					@matchid = @matchid
					,@matchdate = @matchdate
					,@mode = 'REFUND'
					,@sportType = @SportType
					,@resultDetail = @SelectedResources
					,@IsCentral = @IsCentral
					,@ticketCount = @ticketCountTotal OUTPUT
			END
	       
			IF @Action IN ('CAL','UNDO')
			BEGIN
				EXEC dbo.NAP_Admin_Settlement_Parlay_Calculate_9001
					@matchid = @matchid
					,@matchdate = @matchdate
					,@mode = @Action
					,@sportType = @SportType
					,@resultDetail = @SelectedResources
					,@IsCentral = @IsCentral
					,@ticketCount = @ticketCountTotal OUTPUT
			END
		END
		
		IF @IsSettleBySetting = 0 AND @SelectedResources IS NULL
		BEGIN			
			-- in case refund half event, we do need to calculate whole match first, then refund half event. as no way to get the other half calculate correctly after refund.
			IF @action IN ('REFUND-HT','REFUND-FT') SET @priorAction = 'CAL'
				
			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchid = @matchid,
				@mode = 'm',
				@priorAction = @priorAction,
				@action = @action,
				@IsRefundHT = @IsRefundHT,
				@GoalSequence = @GoalRecord,
				@fth = @finalhomescore ,
				@fta = @finalawayscore,
				@hth = @hthomescore,
				@hta = @htawayscore,
				@matchdate = @matchdate,
				@TennisTotal = @TennisTotal,
				@resultDetail = @resultDetail,
				@strBettypes = @strBettypes,
				@betstatus	= @betstatus,
				@SportType = @SportType
		END
	END --END: handle bettransM ------------------------------------------

	DECLARE @rowCnt29 int
			,@rowCnt int
	DECLARE @strTransIds varchar(MAX) = ''
			,@strRefnos VARCHAR(MAX) = ''

	DECLARE @refnos TABLE (refno BIGINT)
	CREATE TABLE #tempRefno29 (refno BIGINT, transid BIGINT)

	-- for balance table --
	CREATE TABLE #BalanceBefore_29 (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #BalanceAfter_29 (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #Balance_29 (custid int, balance money)

	DECLARE @tblDebitPending_29 TVP_BalanceList
	DECLARE @tblCreditPending_29 TVP_BalanceList

	DECLARE @TotalAccount INT

	SELECT @TotalAccount = 0
	----------------------------------------------------------------------------------------------------------------------------------------
	INSERT INTO @refnos(refno)
	SELECT refno
	FROM dbo.bettransm bm WITH(ROWLOCK)
	WHERE matchid = @matchid
		AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
		AND NOT EXISTS (
			SELECT 1 FROM bettransm WITH(NOLOCK) WHERE refno = bm.refno AND statusID IN(1, 101)
		)
	SET @rowCnt = @@ROWCOUNT --number of tickets of the match

	BEGIN --BEGIN: calculate 29 ----------------------------------
		INSERT INTO #temp_bettrans_29 ( transid, refno, IsFinished, ruben, custid)
		SELECT transid, refno, 0 AS IsFinished, ruben, custid
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
				SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	dbo.bettrans b WITH(ROWLOCK)
				WHERE	b.transid IN (SELECT transid FROM #tempRefno29)

				EXEC dbo.NAP_Admin_Calculate_MP_broker
					@mode = '29'
					,@matchdate = @matchdate
					,@strXML = @strRefnos

				---- CAPTURE value BALANCE after udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
				INSERT INTO #BalanceAfter_29 (transid, custid, balance)
				SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	dbo.bettrans b WITH(ROWLOCK)
				WHERE	b.transid IN (SELECT transid FROM #tempRefno29)

				INSERT INTO #Balance_29 (custid, balance)
				SELECT b.custid, SUM(a.balance - b.balance)
				FROM #BalanceBefore_29 b
					INNER JOIN #BalanceAfter_29 a ON b.transid = a.transid
				GROUP BY b.custid
			END
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
			,t.CustID
			,t.Balance
			,0
			,@matchid
		FROM (	SELECT	custID, SUM(balance) AS balance
				FROM	#Balance_29
				GROUP BY custID) t
		WHERE t.balance < 0

		INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
		VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'END running CAL-29')

	END --END: calculate 29 ----------------------------------

	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
	VALUES (@matchid, NULL, NULL, CURRENT_TIMESTAMP, 'well done, no more to do')

	----------------------------------------------------------------------------------------------------------------------------------------
	BEGIN --BEGIN: WRITE LOG ----------------------------------
		DECLARE @Remark VARCHAR(200)

		SET @stop = CURRENT_TIMESTAMP

		SELECT @Remark = 'NAP: Calculate Multiple (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) + ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
		
		EXEC dbo.Logfile_V2 
			@UserID = @creator
			,@Doing = @Remark
			,@extend = @MatchId
	
		IF @IsCentral = 1
		BEGIN
			SELECT @Remark = CASE WHEN @ParentMatchId IS NOT NULL THEN 'child: '+CAST(@matchid AS VARCHAR) +  '<br/> ' ELSE '' END
							+ 'NAP: Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms'
							+ CASE WHEN @action = 'CAL' OR @IsAuto = 1 THEN ' isAuto: ' + CAST (@IsAuto AS VARCHAR) ELSE '' END

			IF @ParentMatchId IS NOT NULL ---Cricket
			BEGIN
				SELECT  @matchid		= @ParentMatchId
						,@finalhomescore = finalhomescore 
						,@finalawayscore = finalawayscore
						,@betstatus		= betstatus
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
					,@finalhomescore = @finalhomescore
					,@finalawayscore = @finalawayscore
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
					,@finalhomescore = @finalhomescore
					,@finalawayscore = @finalawayscore
					,@hthomescore = @hthomescore
					,@htawayscore = @htawayscore
					,@GoalRecord = @goalrecord
					,@betstatus = @betstatus
					,@Remark = @Remark
					,@IP = @IP
			END CATCH
		END
	END --END: WRITE LOG ----------------------------------

END --end SP
GO


