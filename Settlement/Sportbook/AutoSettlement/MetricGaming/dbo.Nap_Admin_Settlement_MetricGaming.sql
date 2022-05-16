/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MetricGaming] 
	@MatchId					INT
	,@Bettype					INT
	,@ResultID					INT	
	,@BettypeTime				VARCHAR(100)	= ''
	,@newBettypeTime			VARCHAR(100)	= ''
	,@Result					VARCHAR(4000)	= ''
	,@Action					VARCHAR(10)		= 'CAL'
	,@AdminId					INT	
	,@IsSettleDetermined		BIT				= 0
	,@SuspendedTime				TINYINT			= 0
	,@IP						VARCHAR(50)		= ''
	,@ErrCode					INT				= 0		OUTPUT
	,@ErrMsg					NVARCHAR(200)	= ''	OUTPUT
AS
	/*
		Created: Johnson
		Date: 2015-07-01
		Task: Main sp settle Metric Gaming
		DB: DBTXN/bodb02
		
		Revisions:
			- 20151210@Johnson: allow update bettype time when settle bettype Goal within 60s of kick (801) [Redmine: #49016]
			- 20180327@Helen:  Add deployment info in the first of SP [Redmine: #92810]
			
		Parameter's Explantion:
			-@Result = <Result>
							<Row GameResult="7" OtherInfo="6:10"/>
							<Row GameResult="8" OtherInfo="6:20"/>
						</Result>: Every Single Minute
			-@Result = <Result>
							<Row GameResult="15"/>
						</Result>: NONE
			-@Result = <Result>
							<Row GameResult="9" OtherInfo="62"/>
						</Result>: Time of Posession
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ActionID		INT
			,@start			DATETIME
			,@stop			DATETIME
			,@Remark		VARCHAR(500)
			,@LogData		NVARCHAR(300)
			,@ticketCount	INT = 0
	
	SELECT @ActionID = CASE WHEN @Action = 'CAL'	THEN 152--MG-calculate
							WHEN @Action = 'UNDO'	THEN 153
							WHEN @Action = 'REFUND' THEN 154
							END
			,@start = CURRENT_TIMESTAMP
			
	SET @BettypeTime = ISNULL(@BettypeTime,'')
	SET @Result = ISNULL(@Result,'')
			
	-- check and not allow attempt to settlement same game while it's still not finish
	IF EXISTS (
			SELECT 1 
			FROM dbo.TempVariableNumber t WITH(NOLOCK)
			WHERE t.KeyID = 3
			AND t.KeyValue = @matchid
			)
	BEGIN
		SELECT @ErrCode = 1000000
			,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		
		select @Errcode as Errcode , @ErrMsg as ErrMsg
		RETURN
	END
	
	IF @Bettype = 801 AND @newBettypeTime <>  '' 
			AND EXISTS (SELECT 1
						FROM DBPRO.bodb02.dbo.ResultDetail3rd WITH(NOLOCK)
						WHERE MatchID = @matchID
							AND GameID = @bettype
							AND ResultID <> @ResultID
							AND custom1 = @newBettypeTime
						)
	BEGIN
		SELECT @ErrCode = 9999999
			,@ErrMsg	= 'The Event Time already existed in this match.'
		
		select @Errcode as Errcode , @ErrMsg as ErrMsg
		RETURN
	END						

	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue)
	VALUES (3, @matchid)

	IF (@@ERROR = 0)
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 3
				,@ActionID	= @ActionID
				,@Remark	= 'ADD SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'ADD SUCCESS ErrMsg=' + left(ERROR_MESSAGE(), 400)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID		= @AdminId
				,@Matchid	= @matchid
				,@KeyID		= 3
				,@ActionID	= @ActionID
				,@Remark	= @Remark
		END CATCH
	END
	ELSE
	BEGIN
		SELECT @ErrCode = 1000000
			,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		
		select @Errcode as Errcode , @ErrMsg as ErrMsg
		RETURN
	END
	
	SELECT	@ticketCount = COUNT(1)
	FROM	dbo.translog WITH(NOLOCK)
	WHERE	eventID = @MatchId
			AND gameID = @Bettype
			AND @bettypeTime = CASE WHEN gameId <> 806 THEN SUBSTRING(transdesc,CHARINDEX('bettypetime',transdesc)+12,CHARINDEX(';time',transdesc)-CHARINDEX('bettypetime',transdesc)-12)
										ELSE @bettypeTime
										END
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (
		custid		INT PRIMARY KEY
		,balance	MONEY
		)
	
	CREATE TABLE #tmpRef (refno BIGINT, isRunning BIT)
	
	CREATE INDEX IX_Balance_IsRunning ON #tmpRef (isRunning)
	
	DECLARE @TotalAccount				INT = 0
		,@TotalAccount_BalanceUpdate	INT = 0
	
	INSERT INTO #tmpRef (refno, isRunning)
	SELECT	translogid
			,CASE WHEN statusID IN (0,1) THEN 1 ELSE 0 END AS isRunning
	FROM Translog WITH(NOLOCK)
	WHERE GameID = @bettype
		AND EventID = @matchid
		AND @bettypeTime = CASE WHEN gameId <> 806 THEN SUBSTRING(transdesc,CHARINDEX('bettypetime',transdesc)+12,CHARINDEX(';time',transdesc)-CHARINDEX('bettypetime',transdesc)-12)
										ELSE @bettypeTime
										END
	
	INSERT INTO #BalanceBefore
	SELECT custid,SUM(balance)
	FROM 
	(
		SELECT	b.custid
				,SUM(b.winlost - b.actual_stake + b.playercomm) as balance
		FROM	dbo.bettrans b WITH (ROWLOCK)
		WHERE	b.matchid = @matchid 
				AND b.bettype = @Bettype
				AND b.refno IN (SELECT refno FROM #tmpRef WHERE isRunning = 0)
		GROUP BY b.custid
		UNION ALL
		SELECT	custid, SUM(-actual_stake) as balance
		FROM	translog WITH(NOLOCK)
		WHERE	translogid IN (SELECT refno FROM #tmpRef WHERE isRunning = 1)				
		GROUP BY custid
	)t
	GROUP BY custid

	SET @TotalAccount = @@ROWCOUNT
	
		EXEC DBPRO.BODB02.dbo.NAP_Admin_MetricGamingResult_Update
		@ResultID				= @ResultID
		,@Action				= @Action
		,@Result				= @Result
		,@AdminId				= @AdminId
		,@newBettypeTime		= @newBettypeTime
		,@isSettleDetermined	= @isSettleDetermined
		
		--hard code to ruturn dataset
		select 0 as Errcode , '' as ErrMsg
		
		EXEC NAP_Admin_Calculate_801
		@matchid				= @matchid
		,@bettype				= @bettype
		,@bettypeTime			= @bettypeTime
		,@newBettypeTime		= @newBettypeTime
		,@SuspendedTime			= @SuspendedTime
		,@Action				= @Action
		,@ResultID				= @ResultID
		,@Result				= @Result
		,@isSettleDetermined	= @isSettleDetermined
	
	-------------------------------------------------------------
	---         CAPTURE value BALANCE after unsettlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (custid int PRIMARY KEY , balance money)
	
	UPDATE t
	SET t.isRunning = CASE WHEN tl.statusid IN (0,1) THEN 1 ELSE 0 END
	FROM #tmpRef t
		INNER JOIN Translog tl WITH(NOLOCK) ON t.refno = tl.translogid
	
	INSERT INTO #BalanceAfter
	SELECT custid,SUM(balance)
	FROM 
	(
		SELECT	b.custid
				,SUM(b.winlost - b.actual_stake + b.playercomm) as balance
		FROM	dbo.bettrans b WITH (ROWLOCK)
		WHERE	b.matchid = @matchid 
				AND b.bettype = @Bettype
				AND b.refno IN (SELECT refno FROM #tmpRef WHERE isRunning = 0)
		GROUP BY b.custid
		UNION ALL
		SELECT	custid, SUM(-actual_stake) as balance
		FROM	translog WITH(NOLOCK)
		WHERE	translogid IN (SELECT refno FROM #tmpRef WHERE isRunning = 1)				
		GROUP BY custid
	)t
	GROUP BY custid
	
	    
    -------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)
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
			,@Type			= 4 --Other Sports
	

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
			,@Type			= 4 --Other Sports
			
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
	FROM #Balance WITH(NOLOCK)
	WHERE Increased = 0

	---------------------------------------------------
	DROP TABLE #Balance

	DROP TABLE #BalanceBefore

	DROP TABLE #BalanceAfter	
	
	DROP TABLE #tmpRef
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------     
	SELECT @stop = CURRENT_TIMESTAMP
	
	SELECT @LogData = 'Calculate (' + @Action + ') for matchid:' + CAST(@MatchId AS VARCHAR(10))
							+ ' Bettype:' + CAST(@Bettype AS VARCHAR(10)) 
							+ ' ResultID:' + CAST (@ResultId AS VARCHAR(10))
							+ ' BettypeTime:' + @BettypeTime
							+ CASE WHEN @bettype = 801 AND @newBettypeTime <> '' THEN ' newBettypeTime:' + @newBettypeTime ELSE '' END
							+ ' Result:' + @Result
							+ ' IsSettleDetermined:' + CAST (@IsSettleDetermined AS VARCHAR(1))
							+ ' SuspendedTime' + CAST(@SuspendedTime AS VARCHAR(2))
	
	EXEC dbo.WriteLog_UserLog 
		@UserID = @AdminId
		,@Doing = @LogData
		
	-- WRITE LOG	
	/* Format
		<Log>
			<Event IsSettleDetermined="" Duration="" TC="" Bal="" NewAttribute=""/>
				<Result>
					<Row GameResult="7" OtherInfo="6:10"/>
                    <Row GameResult="8" OtherInfo="6:20"/>
				</Result>
			</Event>
		</Log>
	*/
	SELECT @Remark = '<Log><Event IsSettleDetermined ="' + CAST(@IsSettleDetermined AS varchar(10)) + '"'
											+ ' Duration="'+ CAST(DATEDIFF(MILLISECOND, @start, @stop) AS VARCHAR(20)) + ' ms"'
											+ ' TC="' + CAST(@ticketCount AS VARCHAR(20)) + '"'
											+ ' Bal="' + CAST(@TotalAccount_BalanceUpdate AS VARCHAR(20)) + '/' + CAST(@TotalAccount AS VARCHAR(20)) + '"' +											
											+ CASE WHEN @newBettypeTime <> '' THEN  ' NewEventTime="' +  @newBettypeTime + '"' ELSE '' END + ' >'
								+ @Result
						  +	'</Event>'
					+ '</Log>'
			
	BEGIN TRY
				EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_SettleMetricGaming
			@UserID			= @AdminId
			,@MatchID		= @matchid			
			,@ActionID		= @ActionID	
			,@VendorID		= 5--MG		
			,@ResultID		= @ResultID
			,@Remark		= @Remark
			,@IP			= @IP
	END TRY
	BEGIN CATCH
		SELECT @Remark = '<Log><Event IsSettleDetermined ="' + CAST(@IsSettleDetermined AS varchar(10)) + '"'
											+ ' Duration="'+ CAST(DATEDIFF(MILLISECOND, @start, @stop) AS VARCHAR(20)) + ' ms"'
											+ ' TC="' + CAST(@ticketCount AS VARCHAR(20)) + '"'
											+ ' Bal="' + CAST(@TotalAccount_BalanceUpdate AS VARCHAR(20)) + '/' + CAST(@TotalAccount AS VARCHAR(20)) + '"' +
											+ CASE WHEN @newBettypeTime <> '' THEN  ' NewEventTime="' +  @newBettypeTime + '"' ELSE '' END + ' >'											
								+ @Result
								+ '<Error>
									<Row Msg="'+ left(error_message(), 400)+'"/>'
								+ '</Error>'	
						  +	'</Event>'
					+ '</Log>'
		--SELECT @Remark = 'ErrMsg=' + left(error_message(), 400)
				EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_SettleMetricGaming
			@UserID			= @AdminId
			,@MatchID		= @matchid			
			,@ActionID		= @ActionID	
			,@VendorID		= 5--MG		
			,@ResultID		= @ResultID
			,@Remark		= @Remark
			,@IP			= @IP
	END CATCH		
		
	DELETE
	FROM dbo.TempVariableNumber WITH (ROWLOCK, UPDLOCK)
	WHERE KeyID = 3
		AND KeyValue = @matchid	
		
	IF (@@Error = 0)
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminId,
				@Matchid = @matchid,
				@KeyID = 3,
				@ActionID = @ActionID,
				@Remark = 'DEL SUCCESS'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL SUCCESS ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminId,
				@Matchid = @matchid,
				@KeyID = 3,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END
	ELSE
	BEGIN
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminId,
				@Matchid = @matchid,
				@KeyID = 3,
				@ActionID = @ActionID,
				@Remark = 'DEL FAILED'
		END TRY

		BEGIN CATCH
			SELECT @Remark = 'DEL FAILED ErrMsg=' + left(error_message(), 400)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle_Checking 
				@UserID = @AdminId,
				@Matchid = @matchid,
				@KeyID = 3,
				@ActionID = @ActionID,
				@Remark = @Remark
		END CATCH
	END

END

GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_MetricGaming] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_MetricGaming] TO [vnteam] AS [dbo]
GO