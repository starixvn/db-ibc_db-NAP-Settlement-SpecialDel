/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Outright]
	 @MatchID		INT
	,@Status		NVARCHAR(10)	= NULL 
	,@Action		VARCHAR(10)		='CAL'	
	,@Deadheat		FLOAT			= 1 
	,@isDeadheat	BIT				= 0 
	,@AdminID		INT				= 0 
	,@ErrCode		INT				= 0  OUTPUT
	,@ErrMsg		NVARCHAR(200)	= '' OUTPUT
AS
/*
	Created by: Jamie
	Date: 2014-08-11
	Task: Settlement Outright 
	DB: DBTXN/bodb02 
	Original: Dot_Admin_SettleOutright_Event & Dot_Admin_SettleOutright_Trans
	
	Revision: 
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20180702@Helen: Using Bet Publication for outright settlement [Redmine:#97670]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		+ @Action	= CAL | UNDO | REFUND
		+ @Status	= {WON | LOSE} | UNDO | REFUND 
		+ @Deadheat = fraction of deadheat to divide (1,2,3  etc)	
*/
BEGIN
	SET NOCOUNT ON 
	

	DECLARE  @Remark 	VARCHAR(500)
			,@ActionID 	INT
			,@LogData 	NVARCHAR(300)
			,@LeagueID	INT
			,@EventDate	DATETIME
			,@IsCentral		BIT = 0

	SELECT	@ActionID = CASE @Action WHEN 'UNDO' THEN 145 
									 ELSE 0 END 

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO dbo.TempVariableNumber (KeyID	,KeyValue)
	VALUES (2,@MatchID)

	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			IF @IsCentral =1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminID,
				@Matchid = @Matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = 'ADD SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminID,
				@Matchid = @Matchid,
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
	
	SELECT	@LeagueID	= LeagueID
			,@EventDate	= Eventdate
	FROM	Outright WITH (NOLOCK)
	WHERE	ORID = @MatchID
	
	-- add log to outright_log to notify for Apollo
	EXEC dbo.[Acc_Set_ConfirmedActionOutright] 
		 @matchid = @matchid
		,@actionid = 30
		,@status = @status
		,@deadheat = @isDeadheat
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
 
	CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)
 
	INSERT INTO #BalanceBefore
	SELECT custid, sum(winlost-actual_stake+playercomm)
	FROM dbo.bettrans with (rowlock)
	WHERE matchid = @matchid
		AND bettype = 10
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	GROUP BY custid
	
		EXEC dbo.NAP_Admin_PreCalculate_10 
		 @MatchID = @MatchID
		,@Status = @Status
		,@Action = @Action
		,@Deadheat = @Deadheat
		,@Winlostdate = @EventDate
 
  	---------------------------------------------------
	--add log to outright_log to notify for Apollo
	EXEC dbo.[Acc_Set_ConfirmedActionOutright] 
		 @matchid = @matchid
		,@actionid = 31
		,@status = @status
		,@deadheat = @deadheat
	----------------------------------------------------

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after unsettlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (custid int PRIMARY KEY , balance money)
 
	INSERT INTO #BalanceAfter
	SELECT custid,sum( winlost-actual_stake+playercomm)
	FROM dbo.bettrans with (rowlock)
	WHERE matchid = @matchid and bettype = 10
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	Group by custid
         
	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	CREATE TABLE #Balance (custid int not null , balance money, Increased bit not null , PRIMARY KEY CLUSTERED(custid, Increased))
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	INSERT INTO #Balance
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM #BalanceBefore b
			INNER JOIN #BalanceAfter a ON b.custid = a.custid
	WHERE b.balance <> a.balance
 
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
 
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT	custid, ABS(balance)
	FROM	#Balance
	WHERE	Increased = 0
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 1 -- Sports

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
	INSERT INTO [bodb02].[dbo].[BalanceNegative]
			   ([ExecDate]
			   ,[MatchID]
			   ,[ActionID]
			   ,[GroupID]
			   ,[CustID]
			   ,[Balance]
			   ,[StatusID]
			   ,[Remark])
	SELECT   GETDATE()
			,@MatchID
			,@ActionID --Undo settle
			,3  --outright settlement
			,CustID
			,Balance
			,0
			,NULL
	FROM    #Balance WITH (NOLOCK)
	WHERE   Increased = 0
                 
	---------------------------------------------------
	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter 
	----------------------------------------------------

	DELETE
	FROM dbo.TempVariableNumber WITH (ROWLOCK, UPDLOCK)
	WHERE KeyID = 2
		AND KeyValue = @matchid

	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			IF @IsCentral =1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminID,
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = 'DEL SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminID,
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END
	ELSE
	BEGIN
		BEGIN TRY
			IF @IsCentral =1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminID,
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = 'DEL FAILED'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL FAILED ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminID,
				@Matchid = @matchid,
				@KeyID = 2,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END

	-- WRITE LOG	
	BEGIN TRY
		IF @IsCentral = 1
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = @AdminID
			,@MatchID = @matchid
			,@ActionID = @ActionID
			,@LeagueID = @LeagueID
			,@EventDate = @EventDate
			,@Result = @Status
	END TRY
	BEGIN CATCH
		SELECT @Remark = 'ErrMsg=' + left(error_message(), 400)
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_SettleOutright 
			@UserID = @AdminID
			,@MatchID = @matchid
			,@ActionID = @ActionID
			,@LeagueID = @LeagueID
			,@EventDate = @EventDate
			,@Result = @Status
			,@Remark = @Remark
	END CATCH		
END

GO