ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_BetDaq]
	@matchid int,
	@creator int, 	
	@IP varchar(15) = '',
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS

/*
	Created: 20140114@Kathy 
	Task : Refund Running BetDaq 
	Original: 
	DB: DBTXN/BODB02

	Revisions: 
		- 20140512@Kathy: Exclude 1H FGLG (127) [Redmine:#14449]
		- 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33),
						 sportting solution (from 1301 -> 1334), keno (1501 -> 1599)
		- 20141030@Jamie: Sportting Solution Tennis Settlement [Redmine:#23034]
		- 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]

	Param's Explanation:
	• @matchid: matchid need to refund
	• @IsExcludeBetdaq: Is Exclude betdaq tickets or not
	• @IsSettleAbandonedMatch: Is Settlement for Abandoned/postponed match or not
	BetDaq account: 
				custid	--- username	-	roleid
				50057	---	BQUS888		-	1
				879241	---	BQUSMLB		-	1
				103873	---	BQUSNBA		-	1
				78761	---	ITibc101	-	1
				1688156	---	MTEST0101	-	2
				851668  --- BDUS01      -   1
				878902  --- BDUS016     -   1
*/
BEGIN
	SET NOCOUNT ON

	-- check and not allow attempt to settlement same game while it's still not finish
	IF EXISTS (SELECT 1 FROM dbo.TempVariableNumber WHERE KeyID = 1 AND KeyValue = @matchid)
	BEGIN
		SELECT  @ErrCode = 1000000,
				@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END
	DECLARE @Remark VARCHAR(500)
			,@ActionID	INT
			
	SELECT	@ActionID = 126
	 
	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) VALUES (1, @matchid)
	
	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @creator, 
				@Matchid = @matchid, 
				@KeyID = 1,
				@ActionID = @ActionID, 
				@Remark = 'ADD SUCCESS'
		END TRY
		BEGIN CATCH	
			SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
			@UserID = @creator, 
			@Matchid = @matchid, 
			@KeyID = 1,
			@ActionID = @ActionID, 
			@Remark = @Remark
		END CATCH
	END
	ELSE 
	BEGIN
		SELECT @ErrCode = 1000000, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END
	---

	DECLARE	@start DATETIME, @stop DATETIME

	SELECT	@start = CURRENT_TIMESTAMP

	CREATE TABLE #BalanceBefore (custid int PRIMARY KEY, balance money)

	CREATE TABLE #BalanceAfter (custid int PRIMARY KEY, balance money)

	CREATE TABLE #Balance (custid int PRIMARY KEY, balance money, Increased bit)
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
	
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)


	INSERT INTO #BalanceBefore
	SELECT	custid, SUM(winlost-actual_stake+playercomm)
	FROM	dbo.bettrans with (rowlock)
	WHERE 
	(	custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
		OR recommend = 1688156	)
	AND matchid = @matchid
	AND bettype NOT IN (14, 127) --Exclude FGLG, 1H FGLG
	AND bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
	AND bettype NOT BETWEEN 1301 AND 1399 -- exclude sporting solution product
	AND bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
	AND bettype NOT BETWEEN 1501 and 1599 -- Keno
	AND bettype NOT IN (135,160,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217) --Auto bets BetRadar 2 


	GROUP BY custid

																EXEC dbo.NAP_Admin_Calculate_Main 
		 @matchid = @matchid
		,@action = 'REFUND'
		,@mode = 'BetDaq'

	--EXEC dbo.NAP_Admin_Calculate_Refund_BetDaq @matchid = @matchid 

	INSERT INTO #BalanceAfter	
	SELECT	custid, SUM(winlost-actual_stake+playercomm)
	FROM	dbo.bettrans with (rowlock)
	WHERE 
	(	custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
		OR recommend = 1688156	)
	AND matchid = @matchid
	AND bettype NOT IN (14, 127) --Exclude FGLG, 1H FGLG
	AND bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
	AND bettype NOT BETWEEN 1301 AND 1399 -- exclude sporting solution product
	AND bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
	AND bettype NOT BETWEEN 1501 and 1599 -- Keno
	AND bettype NOT IN (135,160,164,168,169,173,174,175,176,180,192,193,210,211,212,213,214,215,216,217) --Auto bets BetRadar 2 

	GROUP BY custid


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
	INSERT INTO [bodb02].[dbo].[BalanceNegative]
			   ([ExecDate]
			   ,[MatchID]
			   ,[ActionID]
			   ,[GroupID]
			   ,[CustID]
			   ,[Balance]
			   ,[StatusID]
			   ,[Remark])
	SELECT	 GETDATE()
			,@MatchID
			,@ActionID
			,1			-- Sportsbook Single bet Settlement 
			,CustID
			,Balance
			,0
			,NULL 
	FROM	#Balance WITH (NOLOCK)
	WHERE	Increased = 0
			        
	---------------------------------------------------

	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter

	----------------------------------------------------

	SELECT	@stop = CURRENT_TIMESTAMP

	Declare @LogData nvarchar(200)
	SELECT @LogData = 'NAP: Calculate (Refund Running BetDaq) for matchid:' + CAST(@matchid as nvarchar(10))
	EXEC dbo.WriteLog_UserLog @creator, @LogData

	--Write Log Settle
	DECLARE 
		@finalhomescore INT, @finalawayscore INT,
		@hthomescore INT, @htawayscore INT,
		@goalrecord varchar(50), @betstatus nvarchar(50)
	SELECT 
		@finalhomescore = finalhomescore,
		@finalawayscore = finalawayscore,
		@hthomescore = hthomescore, 
		@htawayscore = htawayscore,
		@goalrecord = goalrecord,
		@betstatus = betstatus
	 FROM dbo.match WITH(NOLOCK) WHERE matchid = @matchid

	SELECT @Remark ='NAP: Duration=' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms;'

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
			@UserID = @creator,
			@Matchid = @matchid,
			@ActionID = @ActionID,
			@finalhomescore = @finalhomescore,
			@finalawayscore = @finalawayscore,  
			@hthomescore = @hthomescore,
			@htawayscore = @htawayscore,
			@GoalRecord =@GoalRecord,
			@betstatus = @betstatus,
			@Remark = @Remark,
			@IP = @IP
	END TRY
	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 350)	
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
			@UserID = @creator,
			@Matchid = @matchid,
			@ActionID = @ActionID,
			@finalhomescore = @finalhomescore,
			@finalawayscore = @finalawayscore,  
			@hthomescore = @hthomescore,
			@htawayscore = @htawayscore,
			@GoalRecord =@GoalRecord,
			@betstatus = @betstatus,
			@Remark = @Remark,
			@IP = @IP
	END CATCH
	    
	  
	-----
	DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
	WHERE KeyID = 1 AND KeyValue = @matchid   
	IF (@@Error = 0)
	BEGIN
		BEGIN TRY	
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @creator,
				@Matchid = @matchid, 
				@KeyID = 1,
				@ActionID = @ActionID, 
				@Remark = 'DEL SUCCESS'
		END TRY
		BEGIN CATCH
			SELECT @Remark = 'DEL SUCCESS ErrMsg=' + left(error_message(), 350)	
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @creator,
				@Matchid = @matchid, 
				@KeyID = 1,
				@ActionID = @ActionID, 
				@Remark = @Remark
		END CATCH
	END
	ELSE
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @creator,
				@Matchid = @matchid, 
				@KeyID = 1,
				@ActionID = @ActionID, 
				@Remark = 'DEL FAILED'
		END TRY
		BEGIN CATCH
			SELECT @Remark = 'DEL FAILED ErrMsg=' + left(error_message(), 350)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @creator,
				@Matchid = @matchid, 
				@KeyID = 1,
				@ActionID = @ActionID, 
				@Remark = @Remark
		END CATCH
	END
END

GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Refund_BetDaq] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Refund_BetDaq] TO [vnteam] AS [dbo]