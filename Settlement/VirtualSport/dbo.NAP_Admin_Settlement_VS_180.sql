/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_VS_180] 
	@AdminId			INT
	,@MatchId			INT
	,@Fth				SMALLINT		= NULL
	,@Fta				SMALLINT		= NULL
	,@Action			VARCHAR(10)		= 'CAL'
	,@IP				VARCHAR(50)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Kathy
	Date: 20140213
	Task: main SP for VS settlement (VS soccer, VS tennis)
	DB: DBTXN/BODB02
	Original: NAP_Admin_Settlement_1
	
	Revisions:
		- 20161201@Kathy: Company win limit [Redmine:#66599]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		@Action - CAL
				- REFUND
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Start			DATETIME
			,@Stop			DATETIME
			,@LogData		NVARCHAR(200)
			,@Remark		VARCHAR(500)
			,@TicketCount	INT
			,@ActionId		INT
			,@EventStatus	NVARCHAR(50)
			,@IsCentral		BIT
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SET @Start = CURRENT_TIMESTAMP
		
	SELECT @ActionID = CASE @Action
							WHEN 'CAL'		THEN 155
							WHEN 'REFUND'	THEN 156
						END
						
	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue) VALUES (1, @matchid)

	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			IF @IsCentral =1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 1
				,@ActionID	= @ActionID
				,@Remark	= 'ADD SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(error_message(), 400)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 1
				,@ActionID	= @ActionID
				,@Remark	= @Remark
		END CATCH
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 1000000
			,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

		RETURN
	END
	
	SELECT	@TicketCount = COUNT(1)
	FROM	dbo.bettrans WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (
		custid INT
		,balance MONEY
		,winlostdate SMALLDATETIME
		,winlost MONEY
		,gametypeid SMALLINT
		)

	DECLARE @TotalAccount INT
			,@TotalAccount_BalanceUpdate INT

	INSERT INTO #BalanceBefore
	SELECT	custid
			,SUM(winlost - actual_stake + playercomm)
			,winlostdate
			,SUM(CASE
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0
				END) AS winlost
			,bettype
	FROM	dbo.bettrans WITH (ROWLOCK)
	WHERE	matchid = @matchid 
			AND bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	GROUP BY custid, winlostdate, bettype

	SET @TotalAccount = @@ROWCOUNT
	-----------------------------------------------------------
	-----------------------------------------------------------
	
	IF @Action = 'CAL'
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_3_VS 
			@Creator	= @AdminId
			,@MatchId	= @matchid
			,@Mode		= @Action
	END
	ELSE IF @Action = 'REFUND'
	BEGIN
		EXEC dbo.NAP_Admin_Calculate_VS_180_Refund 
			@matchid = @matchid
			,@IsCentral = @IsCentral		
	END
			
	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (
		custid INT
		,balance MONEY
		,winlostdate SMALLDATETIME
		,winlost MONEY
		,gametypeid SMALLINT
		)

	INSERT INTO #BalanceAfter
	SELECT	custid
			,SUM(winlost - actual_stake + playercomm)
			,winlostdate
			,SUM(CASE
					WHEN ruben = 1 THEN winlost - actual_stake
					ELSE 0
				END) AS winlost
			,bettype
	FROM	dbo.bettrans WITH (ROWLOCK)
	WHERE	matchid = @matchid
			AND bettype IN (1201, 1203, 1204, 1205, 1206, 1224, 1220, 1235, 1236)
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	GROUP BY custid, winlostdate, bettype
	
	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	CREATE TABLE #Balance (
		custid INT 
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
		INNER JOIN #BalanceAfter a 
			ON	a.custid = b.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE b.balance <> a.balance

	SET @TotalAccount_BalanceUpdate = @@ROWCOUNT

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
	---------------------------------------------------
	DROP TABLE #Balance

	DROP TABLE #BalanceBefore

	DROP TABLE #BalanceAfter
	
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP

	SELECT @LogData = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
					+ ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
					+ ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.Logfile_V2 
		@UserID = @AdminId
		,@Doing = @LogData
		,@extend = @MatchId
		
	SELECT @Remark = 'Calculate (' + @Action + ')' 
					+ ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
					+ ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
					+ ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
					+ ' Bal:' + CAST(IsNull(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))

	BEGIN TRY
		IF @IsCentral = 1
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
			@UserID				= @AdminId
			,@Matchid			= @matchid
			,@ActionID			= @ActionID
			,@finalhomescore	= @fth
			,@finalawayscore	= @fta
			,@hthomescore		= NULL
			,@htawayscore		= NULL
			,@GoalRecord		= NULL
			,@betstatus			= NULL
			,@Remark			= @Remark
			,@IP				= @IP
	END TRY

	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
			@UserID				= @AdminId
			,@Matchid			= @matchid
			,@ActionID			= @ActionID
			,@finalhomescore	= @fth
			,@finalawayscore	= @fta
			,@hthomescore		= NULL
			,@htawayscore		= NULL
			,@GoalRecord		= NULL
			,@betstatus			= NULL
			,@Remark			= @Remark
			,@IP				= @IP
	END CATCH
	
	DELETE
	FROM dbo.TempVariableNumber WITH (ROWLOCK, UPDLOCK)
	WHERE KeyID = 1 AND KeyValue = @matchid

	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			IF @IsCentral = 1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 1
				,@ActionID	= @ActionID
				,@Remark	= 'DEL SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL SUCCESS  ErrMsg=' + left(error_message(), 400)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 1
				,@ActionID	= @ActionID
				,@Remark	= @Remark
		END CATCH
	END
	ELSE
	BEGIN
		BEGIN TRY
			IF @IsCentral = 1
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 1
				,@ActionID	= @ActionID
				,@Remark	= 'DEL FAILED'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL FAILED  ErrMsg=' + left(error_message(), 400)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 1
				,@ActionID	= @ActionID
				,@Remark	= @Remark
		END CATCH
	END

END

GO