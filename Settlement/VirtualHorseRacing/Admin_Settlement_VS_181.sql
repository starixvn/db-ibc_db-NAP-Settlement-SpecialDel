/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Admin_Settlement_VS_181]
	@matchid int, --VS EventID
	@action varchar(10) = 'CAL', -- CAL  / Refund 
	@IP varchar(50) = NULL ,
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
	Created by:[Victor]
	Date:[20130111]
	Task: Settlement 
	DB: DBTRANS.bodb02
	
	Revisions:
		- 20150807@Kathy: Using new balance table (BalCreditOthersPending,BalDebitOthersPending) [Redmine:#40125]
		- 20161201@Kathy: Company win limit [Redmine:#66599]

*/
BEGIN
SET NOCOUNT ON

DECLARE @ActionID int, @Remark varchar(500) , @SportType tinyint
SELECT @ActionID = CASE @Action 
		WHEN 'CAL' THEN 127 
		WHEN 'Refund' THEN 128		
	END

select @SportType = SportType from DBPRO.bodb02.dbo.VSRaceInfo nolock where EventID= @matchid 


-- check and not allow attempt to settlement same game while it's still not finish
IF EXISTS (SELECT 1 FROM dbo.TempVariableNumber WHERE KeyID = 4 AND KeyValue = @matchid)
BEGIN
	SELECT  @ErrCode = 101,
			@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
	RETURN
END

INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) VALUES (4, @matchid) 
IF (@@Error = 0)
BEGIN
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @SportType, 
			@Matchid = @matchid, 
			@KeyID = 4,
			@ActionID = @ActionID, 
			@Remark = 'ADD SUCCESS'
	END TRY
	BEGIN CATCH	
		SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @SportType, 
			@Matchid = @matchid, 
			@KeyID = 4,
			@ActionID = @ActionID, 
			@Remark = @Remark	
	END CATCH
END
ELSE 
BEGIN
	SELECT @ErrCode = 100, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
	RETURN
END

---------

	Declare @start datetime, @stop datetime , @LogData nvarchar(200) 
	SELECT @start = CURRENT_TIMESTAMP
	

	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (custid int, balance money, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)
	Declare @TotalAccount int, @TotalAccount_BalanceUpdate int
		
	INSERT INTO #BalanceBefore (custid, balance, winlost, winlostdate, gametypeid)
	SELECT custid
		,SUM(winlost-actual_stake+playercomm) AS balance
		,SUM(CASE
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0 
				END) AS winlost
		,winlostdate
		,bettype
	FROM dbo.bettrans with (rowlock)
	WHERE matchid = @matchid AND bettype in (1231,1232,1233)
	GROUP BY custid, winlostdate, bettype

	SET @TotalAccount = @@ROWCOUNT

	IF @action = 'CAL'
	BEGIN

			EXEC DBPRO.bodb02.dbo.Admin_Match_Update @Command = 'Admin_Settlement_VS_181-CAL', @Matchid = @matchid
				
			EXEC Admin_Calculate_181M @matchid =@matchid  
			EXEC Admin_Calculate_181 @matchid =@matchid 

		SELECT @LogData = 'Calculate for matchid:' + CAST(@matchid as nvarchar(10))
	END
	ELSE IF @action = 'Refund'
	BEGIN

		EXEC DBPRO.bodb02.dbo.Admin_Match_Update @Command = 'Admin_Settlement_VS_181-Refund', @Matchid = @matchid
		
		EXEC Admin_Calculate_VS_181_Refund @matchid =@matchid
						
		SELECT @LogData = 'Refund for matchid:' + CAST(@matchid as nvarchar(10))
	END

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (custid int, balance money, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)
	
	INSERT INTO #BalanceAfter (custid, balance, winlost, winlostdate, gametypeid)
	SELECT custid
		,SUM(winlost-actual_stake+playercomm)
		,SUM(CASE 
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0
				END) AS winlost
		,winlostdate
		,bettype
	FROM dbo.bettrans with (rowlock)	
	WHERE matchid = @matchid AND bettype in (1231,1232,1233)
	GROUP BY custid, winlostdate, bettype
	

	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	CREATE TABLE #Balance (custid int, balance money, Increased bit)
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	INSERT INTO #Balance (custid, balance, Increased)
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON b.custid = a.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE b.balance <> a.balance

	--SET @TotalAccount_BalanceUpdate = @@ROWCOUNT
	SELECT @TotalAccount_BalanceUpdate = COUNT(1)
	FROM #Balance
	GROUP BY custid
	
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT	custid, ABS(balance)
	FROM	#Balance
	WHERE	Increased = 0
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 4 -- Others

	INSERT INTO @tblCreditPending (custID, balance)
	SELECT	custid, balance
	FROM	#Balance
	WHERE	Increased = 1
	
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditPending
			,@Type			= 4 -- Others
			
			
		---insert data into pending balance game table 
	INSERT INTO BalancePendingCreditGame (
		custid
		,winlostdate
		,balance
		,bettype
		,GameTypeID
		)
	SELECT a.custid
		,a.winlostdate
		,(a.winlost - b.winlost) AS Balance
		,1201
		,a.gametypeid
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	a.custid = b.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE (a.winlost - b.winlost) > 0

	INSERT INTO BalancePendingDebitGame (
		custid
		,winlostdate
		,balance
		,bettype
		,GameTypeID
		)
	SELECT a.custid
		,a.winlostdate
		,ABS(a.winlost - b.winlost) AS Balance
		,1201
		,a.gametypeid
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	a.custid = b.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE (a.winlost - b.winlost) < 0
	
	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter


	SELECT @stop = CURRENT_TIMESTAMP
	
	DECLARE @betstatus nvarchar(50)
	SELECT @betstatus = CASE @Action WHEN 'Refund' THEN 'Refund' ELSE NULL END

	SELECT @LogData = @LogData + '(' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms)'
	EXEC dbo.WriteLog_UserLog @SportType, @LogData


	SELECT @Remark = ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms; '
			+ ' Bal:' + CAST(IsNull(@TotalAccount_BalanceUpdate,0) as varchar(20)) + '/' + CAST(IsNull(@TotalAccount,0) as varchar(20))
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
			@UserID = @SportType, --a user is dedicted for bettype 181 to write log
			@Matchid = @matchid,
			@ActionID = @ActionID,
			@finalhomescore = NULL,
			@finalawayscore = NULL,  
			@hthomescore = NULL,
			@htawayscore = NULL,
			@GoalRecord = NULL,
			@betstatus = @betstatus,
			@Remark = @Remark,
			@IP = @IP
	END TRY  
	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)	
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
			@UserID = @SportType, --a user is dedicted for bettype 181 to write log
			@Matchid = @matchid,
			@ActionID = @ActionID,
			@finalhomescore = NULL,
			@finalawayscore = NULL,  
			@hthomescore = NULL,
			@htawayscore = NULL,
			@GoalRecord = NULL,
			@betstatus = @betstatus,
			@Remark = @Remark,
			@IP = @IP	
	END CATCH
----
DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
WHERE KeyID = 4 AND KeyValue = @matchid

IF (@@Error = 0)
BEGIN
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @SportType, 
			@Matchid = @matchid, 
			@KeyID = 4,
			@ActionID = @ActionID, 
			@Remark = 'DEL SUCCESS'
	END TRY
	BEGIN CATCH		
		SELECT @Remark = 'DEL SUCCESS  ErrMsg=' + left(error_message(), 400)		
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @SportType, 
			@Matchid = @matchid, 
			@KeyID = 4,
			@ActionID = @ActionID, 
			@Remark = @Remark		
	END CATCH
END
ELSE
BEGIN
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @SportType, 
			@Matchid = @matchid, 
			@KeyID = 4,
			@ActionID = @ActionID, 
			@Remark = 'DEL FAILED'
	END TRY
	BEGIN CATCH		
		SELECT @Remark = 'DEL FAILED  ErrMsg=' + left(error_message(), 400)		
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @SportType, 
			@Matchid = @matchid, 
			@KeyID = 4,
			@ActionID = @ActionID, 
			@Remark = @Remark		
	END CATCH
END

END

GO