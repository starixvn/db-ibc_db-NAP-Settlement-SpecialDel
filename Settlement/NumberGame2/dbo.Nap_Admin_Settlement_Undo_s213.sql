/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Undo_s213] 
AS
/*
	Created by:[Johnson]
	Date:[20190109]
	Task: Undo for NG2
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190109@Johnson: create sp [redmine:#107658]
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @start DATETIME, @stop DATETIME
	DECLARE @Remark VARCHAR(500), @ActionID INT	
	DECLARE @matchid INT = 0,
			@seqID INT = 0,
			@GambleID INT = 0

	--Check settlement queue to get available sequence ID
	SELECT TOP 1 @matchid = matchid, @seqID = seqID, @GambleID = GambleID
	FROM settlementNG2_message WITH (NOLOCK)
	WHERE status = 'copied' AND Task = 'Undo'
	ORDER BY seqID ASC
	
	IF @@ROWCOUNT = 0 RETURN
	
	SELECT @start = CURRENT_TIMESTAMP,
			@actionID = 200--Undo action for NG2
			
	UPDATE settlementNG2_message WITH (UPDLOCK,ROWLOCK)
	SET startCalculate_time = GETDATE(),
		status = 'Calculating'
	WHERE seqID = @seqID
	
	--Calculate & update result
	CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY)
	CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY, balance MONEY)	
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	-- CAPTURE value BALANCE before udpate bettrans
	INSERT INTO #BalanceBefore
	SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
	FROM	dbo.bettrans b WITH(ROWLOCK)
	WHERE	matchid = @matchid
	GROUP BY b.custid
	
	--Call execrep sp to undo all tickets
	EXEC dbo.NAP_Admin_Calculate_Undo_s213 @matchid = @matchid, @GambleID = @GambleID
	
	-- CAPTURE value BALANCE after udpate bettrans
	INSERT INTO #BalanceAfter
	SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
	FROM	dbo.bettrans b WITH(ROWLOCK)
	WHERE	matchid = @matchid
	GROUP BY b.custid
	
	INSERT INTO #Balance (custid, balance, Increased)
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM #BalanceBefore b
		INNER JOIN #BalanceAfter a ON b.custid = a.custid
	WHERE b.balance <> a.balance
	
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
	
	--update settlement queue
	UPDATE settlementNG2_message WITH (UPDLOCK,ROWLOCK)
	SET doneCalculate_time = GETDATE(),
		status = 'Completed'
	WHERE seqID = @seqID
	
	--Send email to IT,CSD,3rd party
	EXEC dbo.NAP_Admin_SendNotificationEmail_s213 @action = 'Undo', @seqID = @seqID
	
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP
	
	SET @Remark = 'SeqID: '+ CAST(@SeqID AS NVARCHAR(20)) + ', Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms'
	
	BEGIN TRY		
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = 148-- calculated by system (default)
			,@Matchid = @MatchId
			,@ActionID = @ActionID
			,@finalhomescore = NULL
			,@finalawayscore = NULL
			,@hthomescore = NULL
			,@htawayscore = NULL
			,@GoalRecord = NULL
			,@betstatus = NULL
			,@Remark = @Remark
			,@IP = NULL
	END TRY

	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 350)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = 148-- calculated by system (default)
			,@Matchid = @MatchId
			,@ActionID = @ActionID
			,@finalhomescore = NULL
			,@finalawayscore = NULL
			,@hthomescore = NULL
			,@htawayscore = NULL
			,@GoalRecord = NULL
			,@betstatus = NULL
			,@Remark = @Remark
			,@IP = NULL
	END CATCH
	
	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter
	
	
END	
GO