/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_FGLG] @creator INT
	, @matchid INT
	, @action VARCHAR(10) = 'CAL-FT'
	, @betstatus NVARCHAR(50)
	, @IncludeLG BIT = 1
	, @IP VARCHAR(15) = ''
	, @goalrecord VARCHAR(50) = ''
	, @IsLoopTempTable BIT = 0
	, @IsAutoCalculatePage BIT = 0
	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*	Creator: Kathy
	Date: 20140213 
	Task: SP for settle FGLG
	DB: DBTXN/BODB02
	Original: Admin_Settlement_FGLG

	Revisions:
		- 20140426@Kathy: Add @action param (1H FGLG (bettype 127) ) [Redmine:#14449]
		- 20140618@Kathy: Correct betstatus
		- 20150422@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212] - GoalRecord
		- 20150610@Johnson: Add bettrade [Redmine: #35921]
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20170119@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20160905@Bobby: #63553 - Include FGLG (14,127) bet types
		
	Param's Explanation:
		+ @betstatus: FGLG status
		+ @IsLoopTempTable: 1 : is nested
							0 : Normal
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ActionID INT
			, @bettype INT
			,@strFTBettypes VARCHAR(MAX)
			,@strAutoBettypes VARCHAR(MAX)

	SELECT 	@strFTBettypes = COALESCE(@strFTBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes() f 
	WHERE  	f.IsUsedGoalRecordValue = 1
			AND f.GroupId = 2 AND @IsAutoCalculatePage = 1

	SELECT 	@strAutoBettypes = COALESCE(@strAutoBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes() f 
	WHERE  	f.IsAuto = 1

	SET @strAutoBettypes = ',' + @strAutoBettypes + ','

	CREATE TABLE #tmpTrans (transid BIGINT)
	
	SELECT @ActionID = CASE WHEN @action = 'CAL' THEN 108
							WHEN @action = 'CAL-FT' THEN 163
							WHEN @action = 'CAL-HT' THEN 164
						ELSE -1 END --not supported
		, @bettype = CASE WHEN @action = 'CAL-HT' THEN 127 ELSE 14 END

	IF @IsLoopTempTable = 0
	BEGIN
		-- check and not allow attempt to settlement same game while it's still not finish
		IF EXISTS (SELECT 1
					FROM dbo.TempVariableNumber
					WHERE KeyID = 1 AND KeyValue = @matchid)
		BEGIN
			SELECT @ErrCode = 1000000
				, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN
		END

		INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue)
		VALUES (1, @matchid)

		IF @@ERROR > 0
		BEGIN
			SELECT @ErrCode = 1000000
				, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
								+ 'ErrMsg=' + LEFT(ERROR_MESSAGE(), 400)

			RETURN
		END
	END

	---
	DECLARE @eventstatus VARCHAR(50)
	IF @IsAutoCalculatePage = 1 AND @Action IN ('CAL-FT')
	BEGIN
		DECLARE @Status TABLE(FTFGLGBet BIT, InRunning INT)

		INSERT INTO @Status(FTFGLGBet, InRunning)
		SELECT	CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strFTBettypes + ',') > 0 OR b.bettype IN (14, 127) THEN 1 ELSE 0 END AS FTFGLGBet
				,SUM(CASE WHEN statusID = 0 THEN 1 ELSE 0 END)
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	matchid = @matchid
				AND b.bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
				AND b.bettype NOT BETWEEN 1501 AND 1599 -- Keno
				AND b.bettype NOT BETWEEN 801 AND 899 --Metric Gaming 
				AND 1 = CASE 
							WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', @strAutoBettypes) > 0 THEN 0 
							ELSE 1 
						END   --Auto settle Betradar
		GROUP BY CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strFTBettypes + ',') > 0 OR b.bettype IN (14, 127) THEN 1 ELSE 0 END

		IF NOT EXISTS(SELECT TOP 1 1 FROM @Status WHERE FTFGLGBet = 0)
			INSERT INTO @Status(FTFGLGBet, InRunning) VALUES(0, 0)

		DECLARE @AllDoneExceptFTFGLGBet BIT -- HTDone & FTDone & CornerDone & HTFGLGDone

		SELECT @AllDoneExceptFTFGLGBet = CASE InRunning WHEN 0 THEN 1 ELSE 0 END 
		FROM @Status
		WHERE FTFGLGBet = 0
		
		SELECT @eventstatus = CASE WHEN @Action IN ('CAL-FT') AND @AllDoneExceptFTFGLGBet = 1 THEN N'completed' ELSE eventstatus END
		FROM DBPRO.BODB02.dbo.Match m WITH(NOLOCK)
		WHERE m.matchid = @matchid
	END

	EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_FGLG'
		, @MatchID = @matchid
		, @Action = @action
		, @BetStatus = @betstatus
		, @GoalRecord = @goalrecord
		, @creator = @creator
		, @FTDone = @AllDoneExceptFTFGLGBet

				EXEC DBPRO.BODB02.dbo.[NAP_Admin_Result_Update_1s] @Command = 'NAP_Admin_Settlement_FGLG'
		, @MatchID = @matchid
		, @creator = @creator

	-------------------------
	--First Goal, Last Goal 
	DECLARE @FGLG1 VARCHAR(10)
		, @FGLG2 VARCHAR(10)
		, @FLString VARCHAR(10)
		, @HT_FGLG1 VARCHAR(10)
		, @HT_FGLG2 VARCHAR(10)
		, @HT_FLString VARCHAR(10)
		, @temp_betstatus nvarchar(50)

	SELECT @FGLG1 = '', @FGLG2 = '', @HT_FGLG1 = '', @HT_FGLG2 = '', @temp_betstatus = @betstatus

	IF CHARINDEX('1FL:', @temp_betstatus) > 0 
	BEGIN
		SELECT @HT_FLString = SUBSTRING(@temp_betstatus, CHARINDEX('1FL:',@temp_betstatus) + 4, 3)
			, @temp_betstatus = REPLACE(@temp_betstatus, SUBSTRING(@temp_betstatus, CHARINDEX('1FL:', @temp_betstatus), 7),'')
			, @HT_FGLG1 = CASE @HT_FLString WHEN '0-0' THEN '0:0'
							ELSE LEFT(@HT_FLString, 1) + ':1' END
			, @HT_FGLG2 = CASE @HT_FLString WHEN '0-0' THEN ''
							ELSE RIGHT(@HT_FLString, 1) + ':2' END
	END
	IF CHARINDEX('FL:', @temp_betstatus) > 0
	BEGIN
		SELECT @FLString = SUBSTRING(@temp_betstatus, CHARINDEX('FL:',@temp_betstatus) + 3, 3)
			, @FGLG1 = CASE @FLString WHEN '0-0' THEN '0:0'
							ELSE LEFT(@FLString,1) + ':1' END
			, @FGLG2 = CASE @FLString WHEN '0-0' THEN ''
							ELSE RIGHT(@FLString,1) + ':2' END
	END
	
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY)
	DECLARE @TotalAccount INT, @TotalAccount_BalanceUpdate INT

	INSERT INTO #tmpTrans(transid)
	SELECT	transid
	FROM	dbo.bettrans b WITH (NOLOCK)
	WHERE	matchid = @matchid 
			AND betdaqid = 0--bettrade tickets
			AND 1 = CASE 
						WHEN b.bettype = @bettype THEN 1
						WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strFTBettypes + ',') > 0 AND @IsAutoCalculatePage = 1 AND @Action = 'CAL-FT' THEN 1
						ELSE 0
					END
						

	INSERT INTO #BalanceBefore
	SELECT	custid, SUM(winlost - actual_stake + playercomm)
	FROM	dbo.bettrans b WITH (ROWLOCK)
	WHERE	matchid = @matchid 
			AND 1 = CASE 
						WHEN b.bettype IN (901,902,903) AND refno IN (SELECT transid FROM #tmpTrans) THEN 1 
						WHEN b.bettype NOT IN (901,902,903) THEN 1
						ELSE 0 
					END
			AND 1 = CASE 
						WHEN b.bettype IN (@bettype, 901, 902, 903) THEN 1
						WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strFTBettypes + ',') > 0 AND @IsAutoCalculatePage = 1 AND @Action = 'CAL-FT' THEN 1
						ELSE 0
					END
	GROUP BY custid

	SET @TotalAccount = @@ROWCOUNT

	-- bettype 14 : First Goal Last Goal - re-use the SP of Correct Score, so we have to call it twice		
	DECLARE		@betcount_14	INT
			,@betcount_127		INT
			,@goaldiff			SMALLMONEY
			,@fth				INT
			,@fta				INT
			,@WinFromBehind		NVARCHAR(1)

	SELECT @betcount_14 = ISNULL(SUM(CASE WHEN bettype = 14 THEN 1 ELSE 0 END), 0)
		, @betcount_127 = ISNULL(SUM(CASE WHEN bettype = 127 THEN 1 ELSE 0 END), 0)
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE matchid = @matchid 
		AND bettype IN (14, 127)
		
	IF @IsAutoCalculatePage = 1
	BEGIN
		SELECT @fth = m.finalhomescore, @fta = m.finalawayscore
		FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK)
		WHERE m.matchid = @matchid
				
		-- Win from behind
		DECLARE @curHome INT = 0
				,@curAway INT = 0
				,@index INT = 1
				
		IF (@fth <> @fta) AND (@fth + @fta) > 2
		BEGIN
			WHILE (@index <= LEN(REPLACE(@GoalRecord,';','')))
			BEGIN
				IF SUBSTRING(REPLACE(@GoalRecord,';',''),@index, 1) = 'H'
					SET @curHome = @curHome + 1
					
				IF SUBSTRING(REPLACE(@GoalRecord,';',''),@index, 1) = 'A' 
					SET @curAway = @curAway + 1				
				
				IF @fth > @fta AND @curHome < @curAway 
				BEGIN
					SET @WinFromBehind = 'H' 
					BREAK
				END
				IF @fta > @fth AND @curAway < @curHome
				BEGIN
					SET @WinFromBehind = 'A'
					BREAK
				END
				
				SET @index = @index + 1
			END
		END		
	END

	IF @betcount_14 = 0 OR @betcount_127 = 0
	BEGIN
		SELECT @betcount_14 = CASE WHEN @betcount_14 = 0 THEN ISNULL(SUM(CASE WHEN bettype = 14 THEN 1 ELSE 0 END), 0)
								ELSE @betcount_14 END
			,@betcount_127 = CASE WHEN @betcount_127 = 0 THEN ISNULL(SUM(CASE WHEN bettype = 127 THEN 1 ELSE 0 END), 0)
								ELSE @betcount_127 END
		FROM dbo.bettransm WITH (NOLOCK)
		WHERE matchid = @matchid
	END

	SET @goaldiff = 0

	IF @action = 'CAL-HT'
	BEGIN
		-- cal HT
		EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
			, @action = 'CAL-FGLG'
			, @mode = 'CAL-HT'
			, @HT_FGLG1 = @HT_FGLG1
			, @goaldiff = @goaldiff
			, @HT_FGLG2 = @HT_FGLG2
			, @betcount_127 = @betcount_127

		IF @IncludeLG = 0
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				, @action = 'CAL-FGLG'
				, @mode = 'CAL-FT'
				, @FGLG1 = @FGLG1
				, @goaldiff = @goaldiff
				, @FGLG2 = @FGLG2
				, @betcount_14 = @betcount_14

			--refund  all LG
			EXEC dbo.NAP_Admin_Settlement_Refund_FGLG @matchid = @matchid
				, @adminid = @creator
				, @action = 'REFUND'
				, @LGOnly = 1
				, @IP = @IP
				, @IsLoopTempTable = 1 ---Not check concurrency by TempVariableNumber table
		END
	END

	IF @action = 'CAL-FT'
	BEGIN
		--cal FT
		EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
			, @action = 'CAL-FGLG'
			, @mode = 'CAL-FT'
			, @FGLG1 = @FGLG1
			, @goaldiff = @goaldiff
			, @FGLG2 = @FGLG2
			, @fth = @fth
            , @fta = @fta
			, @GoalRecord = @goalrecord
			, @WinFromBehind = @WinFromBehind
			, @betcount_14 = @betcount_14
			, @strBettypes = @strFTBettypes

		IF @IncludeLG = 0
		BEGIN
			 --refund FT LG
			EXEC dbo.NAP_Admin_Settlement_Refund_FGLG @matchid = @matchid
				, @adminid = @creator
				, @action = 'REFUND-FT'
				, @LGOnly = 1
				, @IP = @IP
				, @IsLoopTempTable = 1 ---Not check concurrency by TempVariableNumber table
		END

		IF @IsAutoCalculatePage = 1 AND @eventstatus = 'completed'
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark @matchid = @matchid, @command = 'C'
		END
	END
	
	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY, balance MONEY)

	BEGIN
		--===
		INSERT INTO #BalanceAfter
		SELECT	custid, SUM(winlost - actual_stake + playercomm)
		FROM	dbo.bettrans b WITH (ROWLOCK)
		WHERE	matchid = @matchid 
				AND 1 = CASE 
							WHEN b.bettype IN (901, 902, 903) AND refno IN (SELECT transid FROM #tmpTrans) THEN 1
							WHEN b.bettype NOT IN (901,902,903) THEN 1
							ELSE 0 
						END
				AND 1 = CASE 
						WHEN b.bettype IN (@bettype, 901, 902, 903) THEN 1
						WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strFTBettypes + ',') > 0 AND @IsAutoCalculatePage = 1 AND @Action = 'CAL-FT' THEN 1
						ELSE 0
					END
		GROUP BY custid
		--===
	END

	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)
		
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList

	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	INSERT INTO #Balance
	SELECT b.custid, a.balance - b.balance
		, CASE WHEN a.balance > b.balance THEN 1	ELSE 0 END
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a ON b.custid = a.custid
	WHERE b.balance <> a.balance

	SET @TotalAccount_BalanceUpdate = @@ROWCOUNT
	
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT custid, ABS(balance)
	FROM #Balance
	WHERE Increased = 0
	
	IF @@ROWCOUNT <> 0
	BEGIN
		EXEC dbo.Dot_BalancePendingDebitIns @BalancePending = @tblDebitPending, @Type = 1 -- Sports
	END
	
	INSERT INTO @tblCreditPending (custID, balance)
	SELECT custid, balance
	FROM #Balance
	WHERE Increased = 1
	
	IF @@ROWCOUNT <> 0
	BEGIN
		EXEC dbo.Dot_BalancePendingCreditIns @BalancePending = @tblCreditPending, @Type	= 1 -- Sports
	END

	----
	-- Add Negative Balance into BalanceNegative table 
	----
	INSERT INTO [bodb02].[dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
	SELECT GETDATE(), @MatchID, @ActionID, 1 /*Sportsbook Single bet Settlement*/, CustID, Balance, 0, NULL
	FROM #Balance WITH (NOLOCK)
	WHERE Increased = 0

	---------------------------------------------------
	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter
	DROP TABLE #tmpTrans
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	--Write Log Settle
	DECLARE @finalhomescore INT
		, @finalawayscore INT
		, @hthomescore INT
		, @htawayscore INT
		, @Remark VARCHAR(500)

	SELECT @finalhomescore = finalhomescore
		, @finalawayscore = finalawayscore
		, @hthomescore = hthomescore
		, @htawayscore = htawayscore
	FROM DBPRO.BODB02.dbo.match WITH (NOLOCK)
	WHERE matchid = @matchid

	DECLARE @LogData VARCHAR(200)

	SELECT @LogData = 'NAP: Calculate FGLG for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ ' score:' + CAST(ISNULL(@finalhomescore, 0) AS NVARCHAR(10)) + '-' + CAST(ISNULL(@finalawayscore, 0) AS NVARCHAR(10)) 
		+ ' HT:' + CAST(@hthomescore AS NVARCHAR(10)) + '-' + CAST(@htawayscore AS NVARCHAR(10)) 
		+ ' GoalRecord:' + ISNULL(@goalrecord, '') 
		+ ') Remark(BetStatus=' + @betstatus + ', IncludeLG=' + CONVERT(CHAR(1), @IncludeLG) + ', Action=' + @action + ')'

	EXEC dbo.WriteLog_UserLog @creator, @LogData

	SELECT @Remark = 'NAP: IncludeLG=' + CONVERT(CHAR(1), @IncludeLG) + 'Action=' + @action

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
			, @Matchid = @matchid
			, @ActionID = @ActionID
			, @finalhomescore = @finalhomescore
			, @finalawayscore = @finalawayscore
			, @hthomescore = @hthomescore
			, @htawayscore = @htawayscore
			, @GoalRecord = @goalrecord
			, @betstatus = @betstatus
			, @Remark = @Remark
			, @IP = @IP
	END TRY

	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
			, @Matchid = @matchid
			, @ActionID = @ActionID
			, @finalhomescore = @finalhomescore
			, @finalawayscore = @finalawayscore
			, @hthomescore = @hthomescore
			, @htawayscore = @htawayscore
			, @GoalRecord = @goalrecord
			, @betstatus = @betstatus
			, @Remark = @Remark
			, @IP = @IP
	END CATCH

	-----
	IF @IsLoopTempTable = 0
	BEGIN
		DELETE
		FROM dbo.TempVariableNumber WITH (ROWLOCK, UPDLOCK)
		WHERE KeyID = 1 AND KeyValue = @matchid
		
	END
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_FGLG] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_FGLG] TO [vnteam] AS [dbo]