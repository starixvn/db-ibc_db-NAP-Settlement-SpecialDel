/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_s213] 
AS
/*
	Created by:[Johnson]
	Date:[20160822]
	Task: Settlement for NG2
	DB: DBTXN/BODB02
	
	Revisions:
		- 20230419@Kathy: Scale Out for Number Game 2 [Redmine:#186722]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @start DATETIME, @stop DATETIME
	DECLARE @seqID INT = 0, @matchid INT
	DECLARE @Remark VARCHAR(500), @ActionID INT	
			,@IsCentral	BIT

	--Check settlement queue to get available sequence ID
	SELECT TOP 1 @seqID = seqID
	FROM settlementNG2_message WITH (NOLOCK)
	WHERE status = 'copied' AND Task = 'Settlement'
	ORDER BY seqID ASC
	
	IF @@ROWCOUNT = 0 RETURN
	
	SELECT @start = CURRENT_TIMESTAMP,
			@actionID = 176--settlement action for NG2
	
	UPDATE settlementNG2_message WITH (UPDLOCK,ROWLOCK)
	SET startCalculate_time = GETDATE(),
		status = 'Calculating'
	WHERE seqID = @seqID

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	--Checking tickets result
	UPDATE s
	SET s.isSkipped = 1
	FROM Bettrans_staging s WITH(UPDLOCK,ROWLOCK)
		INNER JOIN bettrans b WITH(NOLOCK) ON b.transid = s.ObTransId
	WHERE s.seqID = @seqID
		AND (b.Stake <> s.Stake
			OR b.actual_stake <> s.ActualStake
			OR b.odds <> s.odds
			OR b.betdaqid <> s.GambleID 
			OR b.statusid IN (101,102)--'REJECT','VOID'
			)
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	
	CREATE TABLE #Bettrans_staging (transid BIGINT PRIMARY KEY, custID INT, Payout MONEY, isFinished BIT DEFAULT 0)
		
	INSERT INTO #Bettrans_staging (transid, custid, payout)
	SELECT s.ObTransId, s.ObCustID, s.payout
	FROM Bettrans_staging s WITH(NOLOCK)
		INNER JOIN dbo.bettrans b WITH(NOLOCK) 
			ON	b.transid =  s.obTransId
	WHERE s.seqID = @SeqID
		AND s.isSkipped = 0
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	IF @@ROWCOUNT = 0 
	BEGIN
		EXEC dbo.NAP_Admin_SendNotificationEmail_s213 @action = 'Settlement', @seqID = @seqID
		
		UPDATE settlementNG2_message WITH (UPDLOCK,ROWLOCK)
		SET doneCalculate_time = GETDATE(),
			status = 'Completed'
		WHERE seqID = @seqID
		
		DROP TABLE #Bettrans_staging
		
		RETURN;
	END
	
	--Calculate & update result
	CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY)
	CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY, balance MONEY)	
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	CREATE TABLE #tmpTrans (transid BIGINT, Payout MONEY)
	DECLARE @strTransIDs VARCHAR(MAX), 
			@cnt INT-- total transid for one batch update
	
	SELECT @cnt = VValue
	FROM SystemSettings WITH (NOLOCK)
	WHERE VName = 'BatchTicketForSettlementNG2'
	
	-- update tickets result back to bettrans
	WHILE (1=1)
	BEGIN
		TRUNCATE TABLE #tmpTrans
		TRUNCATE TABLE #BalanceBefore
		TRUNCATE TABLE #BalanceAfter
		TRUNCATE TABLE #Balance
		DELETE @tblDebitPending
		DELETE @tblCreditPending
		
		
		SET @strTransIDs = ''
		
		;WITH t AS (
			SELECT TOP (@cnt) transid 
			FROM #Bettrans_staging
			WHERE IsFinished = 0		
			ORDER BY custID ASC
		)
		
		UPDATE #Bettrans_staging 
		SET IsFinished = 1
		OUTPUT INSERTED.transid, INSERTED.payout INTO #tmpTrans (transid, payout)	
		WHERE transid  IN (SELECT transid FROM t)
				
		IF @@rowcount = 0 BREAK;
			
		-- CAPTURE value BALANCE before udpate bettrans
		INSERT INTO #BalanceBefore
		SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM	dbo.bettrans b WITH(ROWLOCK)
		WHERE	transid IN (SELECT transid FROM #tmpTrans) 
		GROUP BY b.custid
		
		SELECT @strTransIDs = @strTransIDs + ',' + CONVERT (VARCHAR(20),transid) + '|' + + CONVERT (VARCHAR(20),payout)
		FROM #tmpTrans
		
		SET @strTransIDs = STUFF(@strTransIDs,1,1,'')
			
		EXEC dbo.NAP_Admin_Calculate_s213
			@strXML = @strTransIDs
		
		-- CAPTURE value BALANCE after update bettrans
		INSERT INTO #BalanceAfter
		SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM	dbo.bettrans b WITH(ROWLOCK)
		WHERE	transid IN (SELECT transid FROM #tmpTrans)					
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
	END
	
		
	--update settlement queue
	UPDATE settlementNG2_message WITH (UPDLOCK,ROWLOCK)
	SET doneCalculate_time = GETDATE(),
		status = 'Completed'
	WHERE seqID = @seqID
	
	--Send email to IT
	EXEC dbo.NAP_Admin_SendNotificationEmail_s213 @action = 'Settlement', @seqID = @seqID
	
	--get matchid from bettrans coz settlementNG2_message dont store this info for settlement case
	select top (1) @matchid = matchid
	FROM #Bettrans_staging s WITH(NOLOCK)
		INNER JOIN bettrans b WITH(NOLOCK) ON b.transid = s.TransId
		
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP
	
	SET @Remark = 'SeqID: ' + CAST(@seqID AS NVARCHAR(10)) + ', Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms'
	
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
	DROP TABLE #Bettrans_staging
	DROP TABLE #tmpTrans
	
	
	
END
GO