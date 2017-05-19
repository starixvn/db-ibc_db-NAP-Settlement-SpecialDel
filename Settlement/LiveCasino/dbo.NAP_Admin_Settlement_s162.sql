USE [bodb02]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_s162]
	@MatchId		INT,
	@Action			VARCHAR(10)		= 'CAL',	-- CAL  / Refund 
	@AdminID		INT				= 5067934,	-- Livecasino
	@BetStatus		VARCHAR(50) 	= '',
	@CardsResult	VARCHAR(50) 	= '',
	@IP				VARCHAR(15) 	= '' ,
	@CommRate		MONEY			= 0,
	@ErrCode		INT				= 0			OUTPUT,
	@ErrMsg			NVARCHAR(200)	= ''		OUTPUT
AS
/*
	Created by: Kathy
	Date:20140121
	Task: Settlement 
	DB: DBTXN/BODB02
	Original: Admin_Settlement_s162
	
	Revisions:
		- 20150421@Kathy: Offer New Game Type "No Card Baccarat" (1106) [Redmine:#31630]
		- 20150716@Patrick: Support Gold Deluxe
		- 20150807@Kathy: Using new balance table (BalCreditCasinoPending,BalDebitCasinoPending) [Redmine:#40125]

	Param explanation:
		@CardsResult: 
				1101,1103: the sequence of cards result 'C2,H2,D2,S2,D3,S3'
				1102,1104: not input this parameter
		@betstatus: 
				1101,1103: '2,4,7'
				1102,1104: input result ball number
		@CommRate:
				1101,1103: 0.05 ~ 0.3
				1102,1104: not input this parameter
*/
BEGIN

	SET NOCOUNT ON

	-- check and not allow attempt to settlement same game while it's still not finish
	IF EXISTS (SELECT 1 FROM dbo.TempVariableNumber WHERE KeyID = 1 AND KeyValue = @matchid)
	BEGIN
		SELECT  @ErrCode = 101,
				@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

	DECLARE @start			DATETIME
			,@stop			DATETIME 
			,@LogData		NVARCHAR(200)
			,@ActionID		INT
			,@Remark		VARCHAR(500) 
			,@Bettype		SMALLINT 
			,@Newbetstatus	VARCHAR(100)
			,@BallNo		VARCHAR(10)
			,@eventdate		DATETIME
			
	IF @action = 'CAL'
		SELECT @ActionID = 121
	ELSE IF @action = 'Refund'
		SELECT @ActionID = 122
		
	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) VALUES (1, @matchid)
	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminID, 
				@Matchid	= @matchid, 
				@KeyID		= 1,
				@ActionID	= @ActionID, 
				@Remark		= 'ADD SUCCESS'
		END TRY
		BEGIN CATCH
			SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminID, 
				@Matchid	= @matchid, 
				@KeyID		= 1,
				@ActionID	= @ActionID, 
				@Remark		= @Remark
		END CATCH
	END
	ELSE 
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
				
		RETURN
	END
	---------
		
		SELECT @start = CURRENT_TIMESTAMP
		
		-- match.homeid2 will keep this match is which bettype
		SELECT	@Bettype = homeid2
				,@eventdate = eventdate 
		FROM	DBPRO.BODB02.dbo.Match with (rowlock)
		WHERE	matchid = @matchid 
				AND sporttype = 162
		
		-- for old data not maintain match.homeid2
		IF ISNULL(@bettype,0) = 0 
			SET @bettype = 1101
		
		-------------------------------------------------------------
		---        CAPTURE value BALANCE before settlement        ---
		---------------------------VVVV------------------------------
		CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY, winlost MONEY)
		
		DECLARE @TotalAccount					INT
				,@TotalAccount_BalanceUpdate	INT
			
		INSERT INTO #BalanceBefore
		SELECT	custid, SUM(winlost-actual_stake+playercomm), SUM(CASE WHEN ruben = 1 THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM	dbo.bettrans with (rowlock)
		WHERE	matchid = @matchid 
				--AND bettype = @Bettype
				AND bettype BETWEEN 1101 and 1199
		GROUP BY custid

		SET @TotalAccount = @@ROWCOUNT

		IF @action = 'CAL'
		BEGIN
			--bettye 1101,1102 all use Admin_Calculate_1101G for settle
			IF (@bettype IN (1101, 1103, 1106))
			BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
					@Command	= 'NAP_Admin_Settlement_s162-CAL'
					,@Matchid	= @matchid
					,@creator	= @AdminID
					
								EXEC NAP_Admin_Calculate_1101G
					@matchid	= @matchid  
					,@betteam	= @betstatus 
					,@CommRate	= @CommRate 
					,@Bettype	= @Bettype
					
				EXEC NAP_Admin_Calculate_1101 @matchid = @matchid 

			END
			IF (@bettype IN (1102,1104))
			BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
					@Command	= 'NAP_Admin_Settlement_s162-1102-CAL'
					,@Matchid	= @matchid
					,@creator	= @AdminID
									
				SELECT	@Newbetstatus = StrValue 
				FROM	MappingTable  with (rowlock) 
				WHERE	Ballno = @betstatus
						
								EXEC NAP_Admin_Calculate_1101G
					@matchid	= @matchid  
					,@betteam	= @Newbetstatus 
					,@CommRate	= @CommRate 
					,@Bettype	= @Bettype
					
				EXEC NAP_Admin_Calculate_1101 @matchid = @matchid 

			END	
			SELECT @LogData = 'Calculate for matchid:' + CAST(@matchid AS NVARCHAR(10)) + 'CommRate:' + CAST(@CommRate AS NVARCHAR(10)), @ActionID = 121	
		END
		ELSE IF @action = 'Refund'
		BEGIN

			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
				@Command	= 'NAP_Admin_Settlement_s162-Refund'
				,@Matchid	= @matchid
				,@creator	= @AdminID
			
			EXEC NAP_Admin_Calculate_s162_Refund @matchid = @matchid
							
			SELECT @LogData = 'Refund for matchid:' + CAST(@matchid as nvarchar(10)) + 'CommRate:' + CAST(@CommRate as nvarchar(10)), @ActionID = 122	
		END

		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement        ---
		---------------------------VVVV------------------------------
		CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY
									,balance MONEY
									,winlost MONEY
								)
		
		INSERT INTO #BalanceAfter
		SELECT	custid
				,SUM(winlost-actual_stake+playercomm)
				,SUM(CASE WHEN ruben = 1 THEN winlost-actual_stake+playercomm ELSE 0 END)
		FROM	dbo.bettrans with (rowlock)
		WHERE	matchid = @matchid 
				--AND bettype = @Bettype
				AND bettype BETWEEN 1101 and 1199
		GROUP BY custid
		

		-------------------------------------------------------------
		---                   compare BALANCE                     ---
		---------------------------VVVV------------------------------
		CREATE TABLE #Balance (custid INT PRIMARY KEY
								,balance MONEY
								,Increased BIT)
		
		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
						
		CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

		INSERT INTO #Balance
		SELECT	b.custid
				,a.balance - b.balance
				,CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM	#BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	b.custid = a.custid
		WHERE	b.balance <> a.balance

		SET @TotalAccount_BalanceUpdate = @@ROWCOUNT


		--INSERT INTO dbo.BalancePendingDebit (custid, balance)
		--SELECT	custid, ABS(balance)
		--FROM	#Balance
		--WHERE	Increased = 0
		
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance
		WHERE	Increased = 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 3 -- Casino

		--INSERT INTO dbo.BalancePendingCredit (custid, balance)
		--SELECT	custid, balance
		--FROM	#Balance
		--WHERE	Increased = 1
		
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT	custid, balance
		FROM	#Balance
		WHERE	Increased = 1
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 3 -- Casino

		-------------------------------------------------------------
		---                   compare BALANCE for LCS Balance     ---
		---------------------------VVVV------------------------------

		CREATE TABLE #BalanceGame (custid INT PRIMARY KEY
									,balance MONEY
									,Increased BIT
								)
								
		CREATE INDEX IX_BalanceGame_Increased ON #BalanceGame (Increased)

		INSERT INTO #BalanceGame 
		SELECT	b.custid
				,a.winlost - b.winlost
				,CASE WHEN a.winlost > b.winlost THEN 1 ELSE 0 END
		FROM	#BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	b.custid = a.custid
		WHERE	b.winlost <> a.winlost
		
		
		INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,balance
				,bettype
		)
		SELECT	custid
				,@eventdate
				,ABS(balance)
				,1101
		FROM	#BalanceGame
		WHERE	Increased = 0

		INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,balance
				,bettype
		)
		SELECT	custid
				,@eventdate
				,balance
				,1101
		FROM	#BalanceGame
		WHERE	Increased = 1

		DROP TABLE #Balance
		DROP TABLE #BalanceGame
		DROP TABLE #BalanceBefore
		DROP TABLE #BalanceAfter


		SELECT @stop = CURRENT_TIMESTAMP

		SELECT @LogData = @LogData + '(' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms)'
		EXEC dbo.WriteLog_UserLog @AdminID, @LogData

	IF (@bettype in (1101,1103, 1106))
	BEGIN 
		SELECT @Remark = 'Cards result: ' + @CardsResult + '; '
						+ ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms; '
						+ ' Bal:' + CAST(IsNull(@TotalAccount_BalanceUpdate,0) as varchar(20)) + '/' + CAST(IsNull(@TotalAccount,0) as varchar(20))
		BEGIN TRY			
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@UserID				= @AdminID,
				@Matchid			= @matchid,
				@ActionID			= @ActionID,
				@finalhomescore		= NULL,
				@finalawayscore		= NULL,  
				@hthomescore		= NULL,
				@htawayscore		= NULL,
				@GoalRecord			= NULL,
				@betstatus			= @betstatus,
				@Remark				= @Remark,
				@IP					= @IP
		END TRY
		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@UserID			= @AdminID,
				@Matchid		= @matchid,
				@ActionID		= @ActionID,
				@finalhomescore = NULL,
				@finalawayscore = NULL,  
				@hthomescore	= NULL,
				@htawayscore	= NULL,
				@GoalRecord		= NULL,
				@betstatus		= @betstatus,
				@Remark			= @Remark,
				@IP				= @IP
		END CATCH		
	END
	ELSE 
	BEGIN 
		SET @BallNo = NULL
		
		IF @betstatus <> 'refund'
		BEGIN 	
			SElECT @BallNo = @betstatus
			
			SELECT	@betstatus = betstatus 
			FROM	DBPRO.BODB02.dbo.Match with (rowlock)
			WHERE	matchid = @matchid 
					AND sporttype = 162 
		END 
		
		SELECT @Remark = 'Ball No: ' + ISNULL(@BallNo,'') + '; '
						+ ' Result: ' + @betstatus + '; '
						+ ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) as nvarchar(50)) + ' ms; '
						+ ' Bal:' + CAST(IsNull(@TotalAccount_BalanceUpdate,0) as varchar(20)) + '/' + CAST(IsNull(@TotalAccount,0) as varchar(20))
		BEGIN TRY				
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@UserID			= @AdminID,
				@Matchid		= @matchid,
				@ActionID		= @ActionID,
				@finalhomescore = @BallNo,
				@finalawayscore = NULL,  
				@hthomescore	= NULL,
				@htawayscore	= NULL,
				@GoalRecord		= NULL,
				@betstatus		= @betstatus,
				@Remark			= @Remark,
				@IP				= @IP
		END TRY
		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@UserID			= @AdminID,
				@Matchid		= @matchid,
				@ActionID		= @ActionID,
				@finalhomescore = @BallNo,
				@finalawayscore = NULL,  
				@hthomescore	= NULL,
				@htawayscore	= NULL,
				@GoalRecord		= NULL,
				@betstatus		= @betstatus,
				@Remark			= @Remark,
				@IP				= @IP
		END CATCH		
	END 

	----
	DELETE FROM dbo.TempVariableNumber WITH (ROWLOCK,UPDLOCK)
	WHERE KeyID = 1 AND KeyValue = @matchid
	IF (@@Error = 0)
	BEGIN 
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminID, 
				@Matchid	= @matchid, 
				@KeyID		= 1,
				@ActionID	= @ActionID, 
				@Remark		= 'DEL SUCCESS'
		END TRY
		BEGIN CATCH
			SELECT @Remark = 'DEL SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminID, 
				@Matchid	= @matchid, 
				@KeyID		= 1,
				@ActionID	= @ActionID, 
				@Remark		= @Remark
		END CATCH
	END			
	ELSE
	BEGIN
		BEGIN TRY	
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminID, 
				@Matchid	= @matchid, 
				@KeyID		= 1,
				@ActionID	= @ActionID, 
				@Remark		= 'DEL FAILED'
		END TRY
		BEGIN CATCH
			SELECT @Remark = 'DEL FAILED ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminID, 
				@Matchid	= @matchid, 
				@KeyID		= 1,
				@ActionID	= @ActionID, 
				@Remark		= @Remark
		END CATCH
	END
END
GO


