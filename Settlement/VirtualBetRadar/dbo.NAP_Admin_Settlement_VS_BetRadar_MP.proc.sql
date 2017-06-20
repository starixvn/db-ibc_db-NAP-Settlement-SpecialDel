/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Settlement_VS_BetRadar_MP] 
	@AdminId			INT
	,@MatchId			INT
	,@Action			VARCHAR(10)		= 'CAL'
	,@IP				VARCHAR(30)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Creator: 20170106@Bobby
	Task: 77721 - Implement parlay bettype for BetRadar VS
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @sportType			INT 
		, @fth 					INT
		, @fta 					INT
		, @hth 					INT
		, @hta 					INT
		, @matchdate			SMALLDATETIME
		, @strRefnos			VARCHAR(MAX)
		, @TotalAccount			INT
		, @parlayBettype		SMALLINT
		, @ActionID				INT

		, @start				DATETIME
		, @stop					DATETIME
		, @avaiableProcess		BIT
		
	DECLARE @tempRefno			TABLE (refno BIGINT)
	
	--balance tables
	DECLARE @beforeUpd			TVP_BalanceChange
			,@afterUpd			TVP_BalanceChange
	
	SELECT @parlayBettype 		= 2799 
		, @ErrCode				= 0
		, @ErrMsg				= ''
		, @ActionID 			= CASE @Action
									WHEN 'CAL'		THEN 187
									WHEN 'REFUND'	THEN 188
								END
		, @start				= CURRENT_TIMESTAMP

	SELECT TOP(1)
		@fth 					= FinalHomeScore
		, @fta 					= FinalAwayScore
		, @hth 					= HTHomeScore
		, @hta 					= HTAwayScore
		, @matchdate			= CAST(eventdate AS DATE)
		, @sportType			= SportType
	FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
	WHERE matchid = @matchid
	
	--PARLAY checking	
	INSERT INTO @tempRefno (refno)
	SELECT bm.refno 
	FROM dbo.bettransm bm WITH(ROWLOCK)
		OUTER APPLY (
			SELECT TOP 1 refno 
			FROM dbo.bettransm WITH(NOLOCK) 
			WHERE refno = bm.refno 
				AND statusID IN(1, 101)
		) AS chk
	WHERE matchid = @matchid
		AND EXISTS (
					SELECT 1 
					FROM dbo.f_Set_VS_BetRadar_GetBettypes() AS f
					WHERE f.bettype 	= bm.bettype
						AND f.sportType = @sportType
				)
		AND chk.refno IS NULL
		
	IF (@@ROWCOUNT = 0) RETURN
	
	--LOCKING process
	EXEC dbo.NAP_Admin_CheckingProcess
		@IsExistParlayVSBetradar	= 1
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT
	
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	SELECT @strRefnos = CAST((
				SELECT refno AS '@rn'
				FROM @tempRefno AS r
				FOR XML PATH('r'), ROOT('root'), TYPE
		) AS VARCHAR(MAX))
		
		
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------

	INSERT INTO @beforeUpd (custid, balance, balanceType)
	SELECT	b.custid
		, SUM(b.winlost-b.actual_stake+b.playercomm) AS balance
		, 4 AS balanceType
	FROM	dbo.bettrans b with (rowlock)
	WHERE	b.matchid = @parlayBettype
			AND b.bettype = @parlayBettype
			AND EXISTS (SELECT 1 FROM @tempRefno WHERE refno = b.refno)
	GROUP BY b.custid	
	
	
	IF(@Action = 'CAL')
	BEGIN
		EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay] 
			@SportType			= @SportType
			,@MatchId			= @MatchId
			,@Fth				= @fth
			,@Fta				= @fta
			,@Hth				= @hth
			,@Hta				= @hta
			,@strRefnos 		= @strRefnos
			,@matchdate			= @matchdate
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END
	ELSE IF (@Action = 'REFUND')
	BEGIN
		EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Refund] 
			@MatchId			= @MatchId
			,@strRefnos 		= @strRefnos
			,@matchdate			= @matchdate
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END
	
	--CAL mains ticket with refno
	IF(@ErrCode = 0) 
	BEGIN	
		EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Main]
			@MatchId			= @MatchId
			,@strRefnos 		= @strRefnos
			,@matchdate			= @matchdate
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT
	END	
	
	IF(@ErrCode > 0) 
	BEGIN
		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement with ERROR       ---
		---------------------------VVVV------------------------------
		INSERT INTO @afterUpd (custid, balance, balanceType)
		SELECT	b.custid
			, SUM(b.winlost-b.actual_stake+b.playercomm) AS balance
			, 4 AS balanceType
		FROM	dbo.bettrans b with (rowlock)
		WHERE	b.matchid = @parlayBettype
				AND b.bettype = @parlayBettype
				AND EXISTS (SELECT 1 FROM @tempRefno WHERE refno = b.refno)
		GROUP BY b.custid	
		
		-------------------------------------------------------------
		---                   compare BALANCE  with ERROR         ---
		---------------------------VVVV------------------------------
		SELECT @TotalAccount = COUNT(DISTINCT b.custid)
		FROM @beforeUpd b
			INNER JOIN @afterUpd a ON b.custid = a.custid
		WHERE b.balance <> a.balance

		IF(@TotalAccount > 0)
		BEGIN
			EXEC [dbo].[NAP_Admin_BalancePendingIns]
				@BeforeUpd	= @beforeUpd
				,@AfterUpd 	= @afterUpd
		END
	
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
			,7 -- VS BetRadar Parlay Settlement 
			,b.CustID
			, a.balance - b.balance AS Balance
			,0
			,NULL
		FROM @beforeUpd b
			INNER JOIN @afterUpd a 
			ON b.custid = a.custid
		WHERE a.balance < b.balance
		
		RETURN
	END
	
	
	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	INSERT INTO @afterUpd (custid, balance, balanceType)
	SELECT	b.custid
		, SUM(b.winlost-b.actual_stake+b.playercomm) AS balance
		, 4 AS balanceType
	FROM	dbo.bettrans b with (rowlock)
	WHERE	b.matchid = @parlayBettype
			AND b.bettype = @parlayBettype
			AND EXISTS (SELECT 1 FROM @tempRefno WHERE refno = b.refno)
	GROUP BY b.custid	
	
	
	-------------------------------------------------------------
	---                   compare BALANCE  				      ---
	---------------------------VVVV------------------------------
	SELECT @TotalAccount = COUNT(DISTINCT b.custid)
	FROM @beforeUpd b
		INNER JOIN @afterUpd a ON b.custid = a.custid
	WHERE b.balance <> a.balance

	IF(@TotalAccount > 0)
	BEGIN
		EXEC [dbo].[NAP_Admin_BalancePendingIns]
			@BeforeUpd	= @beforeUpd
			,@AfterUpd 	= @afterUpd
	END
	
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
		,7 -- VS BetRadar Parlay Settlement 
		,b.CustID
		, a.balance - b.balance AS Balance
		,0
		,NULL
	FROM @beforeUpd b
		INNER JOIN @afterUpd a 
		ON b.custid = a.custid
	WHERE a.balance < b.balance
	
	
	
	----------------------------------------------------------------------------------------------------------------------------------------
	BEGIN --BEGIN: UPDATE match_remark ----------------------------------	
		IF @Action IN ('CAL', 'REFUND') -- for cal/refund
		BEGIN
			DECLARE @command varchar(5)
			SET @command = CASE WHEN @action = 'CAL' THEN 'M' ELSE 'R' END

			EXEC DBPRO.BODB02.dbo.NAP_UpdateMatch_Remark @matchid = @matchid
				,@command = @command
		END

		--RE-USE old parlay
		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_Parlay'
			,@Matchid = @matchid
			,@creator = @AdminId
			
	END --END: UPDATE match_remark ----------------------------------	

	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
	VALUES (@matchid, NULL, NULL, CURRENT_TIMESTAMP, 'well done, no more to do, end 2799_cal')
	
	--RELEASE process
	EXEC dbo.NAP_Admin_CheckingProcess
		@IsExistParlayVSBetradar	= 1
		,@IsReleased				= 1
		
	----------------------------------------------------------------------------------------------------------------------------------------
	BEGIN --BEGIN: WRITE LOG ----------------------------------		
		DECLARE @Remark VARCHAR(200)
		
		SET @stop = CURRENT_TIMESTAMP

		SELECT @Remark = 'NAP: VS BetRadar - Calculate Multiple (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) + ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
		EXEC dbo.WriteLog_UserLog @AdminId, @Remark

		SELECT @Remark = 'NAP: VS BetRadar - Calculate Multiple (' + @action + '). Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms'

		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
				,@Matchid = @matchid
				,@ActionID = @ActionID
				,@finalhomescore = @fth
				,@finalawayscore = @fta
				,@hthomescore = @hth
				,@htawayscore = @hta
				,@GoalRecord = ''
				,@betstatus = ''
				,@Remark = @Remark
				,@IP = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
				,@Matchid = @matchid
				,@ActionID = @ActionID
				,@finalhomescore = @fth
				,@finalawayscore = @fta
				,@hthomescore = @hth
				,@htawayscore = @hta
				,@GoalRecord = ''
				,@betstatus = ''
				,@Remark = @Remark
				,@IP = @IP
		END CATCH
	END --END: WRITE LOG ----------------------------------
	
	RETURN
END
GO