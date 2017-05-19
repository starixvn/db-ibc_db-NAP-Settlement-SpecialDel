USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] @MatchId INT
	,@Action	VARCHAR(20)
	,@Results	VARCHAR(MAX)

	,@IsAuto	BIT				= 0
	,@AdminId	INT				= 0
	,@Ip		VARCHAR(20)		= ''

	,@ErrCode	INT				= 0		OUTPUT
	,@ErrMsg	VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20160427@Patrick
	Task: Fast market - Auto/Manual settlement
	DB: DBTXN.BODB02
	Original:
	
	Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]

	Param's Explanation:
		If @IsAuto = 0:
			@ResultList = <r>
							<b Id="221">
								<r p="0" r="36" />
								<r p="1" r="1" />
								<r p="2" r="4" />
							</b>
						</r>
		If @IsAuto = 1:
			@ResultList = <r>
							<b Id="221">
								<r p="0"/>
								<r p="1"/>
								<r p="2"/>
							</b>
						</r>
*/
BEGIN
	SET NOCOUNT ON
	 
	DECLARE		@Start 		DATETIME
				,@Stop 		DATETIME
				,@fth		INT
				,@fta 		INT
				,@hth 		INT
				,@hta 		INT
				,@ActionID	INT
				,@Remark	VARCHAR(MAX)
				,@LogData	NVARCHAR(300)						
				,@LogResult VARCHAR(MAX) = ''	
				,@strFMBettypes	VARCHAR(MAX)
				,@XmlData XML
				,@rowcount	INT
				
	SET @XmlData =  CONVERT(XML, @Results)

	SELECT	@start = CURRENT_TIMESTAMP
	SELECT	@ActionID = CASE 
							WHEN @Action = 'CAL' THEN 165 
							WHEN @Action = 'UNDO' THEN 166 
							WHEN @Action = 'REFUND' THEN 167
							ELSE 0 
						END  
	--Write Log Settle
	SELECT	 @fth = finalhomescore
			,@fta = finalawayscore
			,@hth = hthomescore
			,@hta = htawayscore
	FROM	dbo.match WITH (NOLOCK)
	WHERE	matchid = @matchid

	-- check and not allow attempt to settlement same game while it's still not finish
	IF EXISTS (SELECT 1 
				FROM dbo.TempVariableNumber t WITH(NOLOCK)
				WHERE t.KeyID = 1 AND t.KeyValue = @matchid)
	BEGIN
		SELECT @ErrCode = 1000000
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END

	INSERT INTO dbo.TempVariableNumber (KeyID, KeyValue)
	VALUES (1, @matchid)

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1000000
			, @ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END
	
	CREATE TABLE #tblResultDetail (
		BetType			SMALLINT
		,ResourceId		VARCHAR(20)
		,Position		TINYINT
		,BetOption		TINYINT
	)

	CREATE INDEX IX_ResultDetail_Bettype ON #tblResultDetail (BetType)
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
		FROM @xmlData.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
	)
	INSERT INTO #tblResultDetail (
		BetType
		,ResourceId
		,Position
		,BetOption
	)
	SELECT	BetType
			,CAST(BetType * 100 + 1 AS VARCHAR(20)) AS ResourceId
			,Position
			,ISNULL(BetOption,0)
	FROM TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (custid INT PRIMARY KEY, balance MONEY)
	CREATE TABLE #BalanceAfter (custid INT PRIMARY KEY, balance MONEY)
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList

	INSERT INTO	#BalanceBefore
	SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm)
	FROM	#tblResultDetail r
		INNER JOIN dbo.bettrans b WITH(ROWLOCK)
			ON	b.matchid = @matchid
				AND b.bettype = r.BetType
				AND b.hdp1 = r.Position
	GROUP BY b.custid
	
	SET @rowcount = @@rowcount
	
	BEGIN TRY
		-- update resultstatus
		EXEC DBPRO.bodb02.dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId = @MatchId
			,@Results = @Results
			,@Action = @Action
			,@IsAuto = @IsAuto
			,@AdminId = @AdminId			
		
		IF @rowcount > 0
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@action = 'CAL-FM'
				,@mode = @Action
				,@XmlData = @Results
		END
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement        ---
		---------------------------VVVV------------------------------
		INSERT INTO #BalanceAfter
		SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm)
		FROM	#tblResultDetail r
			INNER JOIN dbo.bettrans b WITH(ROWLOCK)
				ON	b.matchid = @matchid
					AND b.bettype = r.BetType
					AND b.hdp1 = r.Position
		GROUP BY b.custid
		-------------------------------------------------------------
		---                   compare BALANCE                     ---
		---------------------------VVVV------------------------------
		CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

		INSERT INTO #Balance
		SELECT	b.custid, a.balance - b.balance
				,CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM	#BalanceBefore b
			INNER JOIN #BalanceAfter a 
				ON	b.custid = a.custid
		WHERE	b.balance <> a.balance
	
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance
		WHERE	Increased = 0
	
		IF @@ROWCOUNT <> 0
		BEGIN
			EXEC dbo.Dot_BalancePendingDebitIns @BalancePending = @tblDebitPending, @Type = 1 -- Sports
		END

		INSERT INTO @tblCreditPending (custID, balance)
		SELECT	custid, balance
		FROM	#Balance
		WHERE	Increased = 1
	
		IF @@ROWCOUNT <> 0
		BEGIN
			EXEC dbo.Dot_BalancePendingCreditIns @BalancePending = @tblCreditPending, @Type = 1 -- Sports
		END
		----
		-- Add Negative Balance into BalanceNegative table 
		----
		INSERT INTO [dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
		SELECT GETDATE(), @MatchID, @ActionID, 1, CustID, Balance, 0, NULL
		FROM	#Balance WITH(NOLOCK)
		WHERE	Increased = 0

		---------------------------------------------------
		DROP TABLE #Balance
		DROP TABLE #BalanceBefore
		DROP TABLE #BalanceAfter
		
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE()
		
		RETURN

	END CATCH

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	INSERT INTO #BalanceAfter
	SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm)
	FROM	#tblResultDetail r
		INNER JOIN dbo.bettrans b WITH(ROWLOCK)
			ON	b.matchid = @matchid
				AND b.bettype = r.BetType
				AND b.hdp1 = r.Position
	GROUP BY b.custid
	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	INSERT INTO #Balance
	SELECT	b.custid, a.balance - b.balance
			,CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM	#BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	b.custid = a.custid
	WHERE b.balance <> a.balance
	
	INSERT INTO @tblDebitPending (custID, balance)
	SELECT	custid, ABS(balance)
	FROM	#Balance
	WHERE	Increased = 0
	
	IF @@ROWCOUNT <> 0
	BEGIN
		EXEC dbo.Dot_BalancePendingDebitIns @BalancePending = @tblDebitPending, @Type = 1 -- Sports
	END

	INSERT INTO @tblCreditPending (custID, balance)
	SELECT	custid, balance
	FROM	#Balance
	WHERE	Increased = 1
	
	IF @@ROWCOUNT <> 0
	BEGIN
		EXEC dbo.Dot_BalancePendingCreditIns @BalancePending = @tblCreditPending, @Type = 1 -- Sports
	END
	----
	-- Add Negative Balance into BalanceNegative table 
	----
	INSERT INTO [bodb02].[dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
	SELECT	GETDATE(), @MatchID, @ActionID, 1, CustID, Balance, 0, NULL
	FROM	#Balance WITH(NOLOCK)
	WHERE	Increased = 0

	---------------------------------------------------
	DROP TABLE #Balance
	DROP TABLE #BalanceBefore
	DROP TABLE #BalanceAfter
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------

	SELECT @stop = CURRENT_TIMESTAMP

	SELECT @logdata = 'NAP: Fast Market (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ '(' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @logdata
	
	SET @LogResult = CONVERT(VARCHAR(MAX),(SELECT BetType '@Id'
		, STUFF((SELECT ',' + CAST(Position AS VARCHAR(3)) FROM #tblResultDetail WHERE BetType = r.BetType FOR XML PATH ('')),1,1,'') AS 'Item/@Position'
		, CASE WHEN @Action = 'CAL' THEN STUFF((SELECT ',' + CAST(BetOption AS VARCHAR(3)) FROM #tblResultDetail WHERE BetType = r.BetType FOR XML PATH ('')),1,1,'') END AS 'Item/@Result'
	FROM #tblResultDetail r
	GROUP BY BetType
	FOR XML PATH('BetType'), ROOT ('BetTypes'), TYPE))
		
	SELECT @Remark = 'NAP: IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
			+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + 'ms' 
			
	BEGIN TRY
		SELECT @Remark = @Remark + '|'  -- signal for web
						+ @LogResult
	
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @userid = @AdminId
			, @matchid			= @MatchID
			, @actionid			= @ActionID
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= ''
			, @betstatus		= ''
			, @Remark			= @Remark
			, @ip				= @ip
	END TRY

	BEGIN CATCH
		SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250) + '|' -- signal for web
							+ @LogResult

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @MatchID			= @matchid
			, @actionid			= @actionid
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= ''
			, @betstatus		= ''
			, @Remark			= @Remark
			, @IP				= @ip
	END CATCH
	
	DELETE
	FROM	dbo.TempVariableNumber WITH (ROWLOCK, UPDLOCK)
	WHERE	KeyID = 1 
			AND KeyValue = @matchid
	
END


GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] TO [vnteam] AS [dbo]