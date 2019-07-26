/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_FGLG] 
	@matchid INT
	,@action VARCHAR(10) = 'REFUND' -- REFUND, REFUND-FT, REFUND-HT
	,@adminid INT
	,@LGOnly BIT
	,@IP VARCHAR(15) = ''
	,@IsLoopTempTable BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
	Created: Kathy
	Date: 20140213
	Task : Refund Half-time in case there are HT tickets bet on special matches that have 3 sets
	DB: DBTXN/BODB02
	Original: Admin_Settlement_Refund_FGLG

	Revisions:
		- 20140426@Kathy: Add 1H FGLG (127) [Redmine:#14449]
		- 20140618@Kathy: Correct 1FL, FL string
		- 20150611@Johnson: Add bettrade [Redmine: #35921]
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		
	Param's Explanation:
			+ @matchid: matchid of match to Refund HT
			+ @IsLoopTempTable: 1 : is nested
								0 : Normal

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Remark VARCHAR(500)
		,@ActionID INT
		,@bettype INT

	SELECT @ActionID = 112
		,@bettype = CASE 
			WHEN @action = 'REFUND-HT' THEN 127
			WHEN @action = 'REFUND-FT' THEN 14
			ELSE 0
			END

	IF @IsLoopTempTable = 0
	BEGIN
		-- check and not allow attempt to settlement same game while it's still not finish
		IF EXISTS (
				SELECT 1
				FROM dbo.TempVariableNumber
				WHERE KeyID = 1 AND KeyValue = @matchid
				)
		BEGIN
			SELECT @ErrCode = 1000000
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN
		END

		INSERT INTO dbo.TempVariableNumber (
			KeyID
			,KeyValue
			)
		VALUES (
			1
			,@matchid
			)

		IF (@@Error = 0)
		BEGIN
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking @UserID = @adminID
					,@Matchid = @matchid
					,@KeyID = 1
					,@ActionID = @ActionID
					,@Remark = 'ADD SUCCESS'
			END TRY

			BEGIN CATCH
				SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)

				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking @UserID = @adminID
					,@Matchid = @matchid
					,@KeyID = 1
					,@ActionID = @ActionID
					,@Remark = @Remark
			END CATCH
		END
		ELSE
		BEGIN
			SELECT @ErrCode = 1000000
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN
		END

		CREATE TABLE #BalanceBefore (
			custid INT PRIMARY KEY
			,balance MONEY
			)
		CREATE TABLE #tmpTrans(transid BIGINT)

		DECLARE @TotalAccount INT
			,@TotalAccount_BalanceUpdate INT

		BEGIN
			INSERT INTO #tmpTrans
			SELECT transid
			FROM dbo.bettrans WITH (ROWLOCK)
			WHERE matchid = @matchid 
				AND ((@bettype = 0 AND bettype IN (14, 127)) OR (bettype = @bettype))
				AND betdaqid = 0--bettrade
			INSERT INTO #BalanceBefore
			SELECT custid
				,SUM(winlost - actual_stake + playercomm)
			FROM dbo.bettrans WITH (ROWLOCK)
			WHERE matchid = @matchid 
				AND ((@bettype = 0 AND bettype IN (14, 127,901,902,903)) OR (bettype IN(@bettype,901,902,903)))
				AND 1 = CASE WHEN bettype IN (901,902,903) 
								AND refno IN (SELECT transid FROM #tmpTrans)	
								THEN 1 
							WHEN bettype NOT IN (901,902,903) THEN 1
							ELSE 0 END
			GROUP BY custid

			SET @TotalAccount = @@ROWCOUNT
		END
	END

	------
	DECLARE @finalhomescore INT
		,@finalawayscore INT
		,@hthomescore INT
		,@htawayscore INT
		,@goalrecord VARCHAR(50)
		,@betstatus NVARCHAR(50)
		,@matchdate DATETIME
		,@betstatus1 nvarchar(50)
		,@betstatus2 nvarchar(50)

	SELECT @matchdate = eventdate
		,@betstatus = betstatus
	FROM DBPRO.bodb02.dbo.match WITH (NOLOCK)
	WHERE matchid = @matchid
	
	SELECT @betstatus1 = CASE when CHARINDEX('1FL:',@betstatus) > 0 then SUBSTRING(@betstatus, CHARINDEX('1FL:',@betstatus),8)
							  ELSE ''
						END,
			@betstatus2 = CASE when CHARINDEX('1FL:',@betstatus) > 0 THEN REPLACE(@betstatus,@betstatus1,'')
							   ELSE @betstatus	
						END		
			
	IF @LGOnly = 1 --refund last goal
	BEGIN
		IF @action IN ('REFUND', 'REFUND-HT')
		BEGIN
			SELECT @betstatus1 = CASE WHEN @betstatus1 = '' THEN @betstatus1 -- Ex: 1FL:1-0;
									 ELSE STUFF(@betstatus1,7,1,'0')
								END
		END
		IF @action IN ('REFUND', 'REFUND-FT')
		BEGIN
			select @betstatus2 = CASE when CHARINDEX('FL:',@betstatus2) > 0 THEN STUFF(@betstatus2,CHARINDEX('FL:',@betstatus2)+5,1,'0')
									  ELSE @betstatus2
								 end -- Ex: Refund;FL:1-0;
		END
	END
	ELSE -- refund all FGLG
	BEGIN
		IF @action IN ('REFUND', 'REFUND-HT')
		BEGIN
			select @betstatus1 = '1FL:0-0;'
		END
		IF @action IN ('REFUND', 'REFUND-FT')
		BEGIN
			select @betstatus2 = CASE when CHARINDEX('FL:',@betstatus2) > 0 then STUFF(@betstatus2,CHARINDEX('FL:',@betstatus2),7,'FL:0-0;')
										ELSE @betstatus2 + 'FL:0-0;' -- Ex: Refund;FL:0-0;
								END 
		END
	END

	SELECT @betstatus = @betstatus2 + @betstatus1

								EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_Refund_FGLG'
		,@MatchID = @matchid
		,@BetStatus = @betstatus

	--EXEC dbo.NAP_Admin_Calculate_RefundFGLG @matchid = @matchid, @LGOnly=@LGOnly, @matchdate=@matchdate
				EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
		,@action = 'REFUND-FGLG'
		,@mode = @action
		,@LGOnly = @LGOnly
		,@matchdate = @matchdate

	IF @IsLoopTempTable = 0
	BEGIN
		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement        ---
		---------------------------VVVV------------------------------
		CREATE TABLE #BalanceAfter (
			custid INT PRIMARY KEY
			,balance MONEY
			)

		BEGIN
			INSERT INTO #BalanceAfter
			SELECT custid
				,SUM(winlost - actual_stake + playercomm)
			FROM dbo.bettrans WITH (ROWLOCK)
			WHERE matchid = @matchid 
				AND ((@bettype = 0 AND bettype IN (14, 127,901,902,903)) OR (bettype IN (@bettype,901,902,903)))
				AND 1 = CASE WHEN bettype IN (901,902,903) 
								AND refno IN (SELECT transid FROM #tmpTrans)	
								THEN 1 
							WHEN bettype NOT IN (901,902,903) THEN 1
							ELSE 0 END
			GROUP BY custid
		END --IF @SkipBalanceUpdate = 0

		-------------------------------------------------------------
		---                   compare BALANCE                     ---
		---------------------------VVVV------------------------------
		CREATE TABLE #Balance (
			custid INT PRIMARY KEY
			,balance MONEY
			,Increased BIT
			)
		
		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
	
		CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

		INSERT INTO #Balance
		SELECT b.custid
			,a.balance - b.balance
			,CASE 
				WHEN a.balance > b.balance THEN 1
				ELSE 0
				END
		FROM #BalanceBefore b
			INNER JOIN #BalanceAfter a ON b.custid = a.custid
		WHERE b.balance <> a.balance

		SET @TotalAccount_BalanceUpdate = @@ROWCOUNT

		--INSERT INTO dbo.BalancePendingDebit (
		--	custid
		--	,balance
		--	)
		--SELECT custid
		--	,ABS(balance)
		--FROM #Balance
		--WHERE Increased = 0
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance
		WHERE	Increased = 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 -- Sports


		--INSERT INTO dbo.BalancePendingCredit (
		--	custid
		--	,balance
		--	)
		--SELECT custid
		--	,balance
		--FROM #Balance
		--WHERE Increased = 1
		
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT	custid, balance
		FROM	#Balance
		WHERE	Increased = 1
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
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
			,1 -- Sportsbook Single bet Settlement 
			,CustID
			,Balance
			,0
			,NULL
		FROM #Balance WITH (NOLOCK)
		WHERE Increased = 0

		---------------------------------------------------
		DROP TABLE #Balance

		DROP TABLE #BalanceBefore

		DROP TABLE #BalanceAfter
		
		DROP TABLE #tmpTrans
	END

	DECLARE @LogData NVARCHAR(200)

	SELECT @LogData = 'NAP: Calculate (Refund FGLG) for matchid:' + CAST(@matchid AS NVARCHAR(10)) + 'action: ' + @action + 'LG Only:' + CASE 
			WHEN @LGOnly = 1 THEN ' (LG only)'
			ELSE ' (All)'
			END

	EXEC dbo.WriteLog_UserLog @AdminID
		,@LogData

	--Write Log Settle
	SELECT @finalhomescore = finalhomescore
		,@finalawayscore = finalawayscore
		,@hthomescore = hthomescore
		,@htawayscore = htawayscore
		,@goalrecord = goalrecord
		,@betstatus = betstatus
	FROM DBPRO.bodb02.dbo.match WITH (NOLOCK)
	WHERE matchid = @matchid

	SELECT @Remark = 'NAP: Action=' + @action + ' RefundLGOnly=' + convert(CHAR(1), @LGOnly)

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @adminid
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
		SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @adminid
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

	-----
	IF @IsLoopTempTable = 0
	BEGIN
		DELETE
		FROM dbo.TempVariableNumber WITH (ROWLOCK, UPDLOCK)
		WHERE KeyID = 1 AND KeyValue = @matchid

		IF (@@Error = 0)
		BEGIN
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking @UserID = @adminID
					,@Matchid = @matchid
					,@KeyID = 1
					,@ActionID = @ActionID
					,@Remark = 'DEL SUCCESS'
			END TRY

			BEGIN CATCH
				SELECT @Remark = 'DEL SUCCESS ErrMsg=' + left(error_message(), 400)

				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking @UserID = @adminID
					,@Matchid = @matchid
					,@KeyID = 1
					,@ActionID = @ActionID
					,@Remark = @Remark
			END CATCH
		END
		ELSE
		BEGIN
			BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking @UserID = @adminID
					,@Matchid = @matchid
					,@KeyID = 1
					,@ActionID = @ActionID
					,@Remark = 'DEL FAILED'
			END TRY

			BEGIN CATCH
				SELECT @Remark = 'DEL FAILED ErrMsg=' + left(error_message(), 400)

				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking @UserID = @adminID
					,@Matchid = @matchid
					,@KeyID = 1
					,@ActionID = @ActionID
					,@Remark = @Remark
			END CATCH
		END
	END
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Refund_FGLG] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Refund_FGLG] TO [vnteam] AS [dbo]