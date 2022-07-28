/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_Admin_SettleOutright_Trans]
	@matchid INT
	,@status NVARCHAR(10)
	,@deadheat FLOAT = 1
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
	,@eventdate SMALLDATETIME = NULL
	,@adminid int = 5838421
AS
/*
Created:
Task : sp for outright settlement

DB: DBTXN/BODB02
Original:

Revisions:
	- 20120202@Thien: receive @winlostdate param from outside SP, to resolve late replication in DBDW/2
	- 20120430@AllenWu: Apply new credit balance procedure
	- 20120808@Sophia: . Add table TempVariableNumber to check if this match is being calculated then not allow to settle until the on-going process is completed
					   . Add @ErrCode, @ErrMsg to raise error
	- 20130103@Elodie:  Write log for adding a match into TempVariableNumber table or deleting a match from TempVariableNumber table
	- 20130121@Elodie:  Write more log on DBTXN server in case of DBLOG server failure
	- 20130624@Martin: Hotfix(There is already an object named 'pk_C2' in the database.Could not create constraint. See previous errors)
	- 20130624@Jamie: Add BalanceNegative 
	- 20130719@Ava::Add @eventdate when user re-settle
	- 20140219@Elodie: Write settlement log for outright
	- 20150910@Zake(TransDB): Change balance rule
	- 20180702@Helen: Using Bet Publication for outright settlement [Redmine:#97670]
	- 20201211@Louisa: Show Calculate Outright Log, add param @AdminId [Redmine:#146738]
	- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
	- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

Param's Explanation:
	- @deadheat = fraction of deadheat to divide (1,2,3  etc)
*/
BEGIN	
	SET NOCOUNT ON

	-- check and not allow attempt to settlement same game while it's still not finish
	IF EXISTS (SELECT 1 FROM dbo.TempVariableNumber WHERE KeyID = 2 AND KeyValue = @matchid)
	BEGIN
		SELECT  @ErrCode = 101,
				@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

	DECLARE @Remark VARCHAR(500), @ActionID INT, @LeagueID	INT
			,@procName		SYSNAME
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT 
			,@IsCentral		BIT = 0

	SELECT @ActionID = CASE @status 
				WHEN 'Refund' THEN 139 
				WHEN 'Won' THEN 137
				WHEN 'Lose' THEN 137
			END
			,@procName = OBJECT_NAME(@@PROCID)
			,@IsWaiting = 0

	-- Check SP is in deployment
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	IF @IsWaiting = 1
	BEGIN
		WAITFOR DELAY @WaitingTime -- Dot_Admin_SettleOutright_Trans
			
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = @ErrMsg

		RETURN
	END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT	@LeagueID	= LeagueID
	FROM	Outright WITH (NOLOCK)
	WHERE	ORID = @MatchID

	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) VALUES (2, @matchid)
	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			IF @IsCentral = 1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @adminid,--dbaAdmin
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = 'ADD SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @adminid,--dbaAdmin
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 102
			,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

		RETURN
	END

	---------
	DECLARE @winlostdate SMALLDATETIME

	IF (@eventdate IS NULL)
		SET @winlostdate = convert(CHAR(10), getdate(), 111)
	ELSE
		SET @winlostdate = convert(CHAR(10), @eventdate, 111)

	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)

	INSERT INTO #BalanceBefore
    SELECT custid,sum( winlost-actual_stake+playercomm)
    FROM dbo.bettrans with (rowlock)
    WHERE matchid = @matchid and bettype = 10 and statusID NOT IN (101, 102)
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
 	GROUP BY custid

	EXEC NAP_Admin_PreCalculate_10 @matchid, @status, @deadheat, @winlostdate

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (custid int PRIMARY KEY , balance money)

    INSERT INTO #BalanceAfter
    SELECT custid,sum( winlost-actual_stake+playercomm)
    FROM dbo.bettrans with (rowlock)
    WHERE matchid = @matchid and bettype = 10
		AND statusID = case @status when 'won' then 112
			when 'lose' then 113
			when 'Refund' then 103
			else 999 end
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	GROUP BY custid

	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList

	CREATE TABLE #Balance (custid int not null , balance money, Increased bit not null , PRIMARY KEY CLUSTERED(custid, Increased))
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	INSERT INTO #Balance
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM #BalanceBefore b
			INNER JOIN #BalanceAfter a ON b.custid = a.custid
	WHERE b.balance <> a.balance

	--INSERT INTO dbo.BalancePendingDebit (custid, balance)
	--SELECT custid, ABS(balance)
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


	--INSERT INTO dbo.BalancePendingCredit (custid, balance)
	--SELECT custid, balance
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
		,3 ---- Outright Settlement 
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

	---------------------------------------------------
	--add log to outright_log to notify for Apollo
	EXEC bodb02.dbo.[Acc_Set_ConfirmedActionOutright] @matchid = @matchid
		,@actionid = 31
		,@status = @status
		,@deadheat = @deadheat

	----------------------------------------------------
	DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
	WHERE KeyID = 2 AND KeyValue = @matchid

	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			IF @IsCentral = 1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @adminid,--dbaAdmin
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = 'DEL SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @adminid,--dbaAdmin
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END
	ELSE
	BEGIN
		BEGIN TRY
			IF @IsCentral = 1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @adminid,--dbaAdmin
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = 'DEL FAILED'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL FAILED ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @adminid,--dbaAdmin
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END

	-- WRITE LOG
	BEGIN TRY
		SELECT @Remark = CAST(@deadheat AS VARCHAR(5))
		IF @IsCentral = 1
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = @adminid
			,@MatchID = @matchid
			,@ActionID = @ActionID
			,@LeagueID = @LeagueID
			,@EventDate = @winlostdate
			,@Result = @status
			,@Remark = @Remark
	END TRY

	BEGIN CATCH
		SELECT @Remark = CAST(@deadheat AS VARCHAR(5)) + ' ErrMsg=' + left(error_message(), 400)
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = @adminid
			,@MatchID = @matchid
			,@ActionID = @ActionID
			,@LeagueID = @LeagueID
			,@EventDate = @winlostdate
			,@Result = @status
			,@Remark = @Remark
	END CATCH
END