/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Casino" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_s161] 
	@MatchId INT
	,@IsLive BIT			= 0
	,@DrawSeq TINYINT		= 0
	,@Action VARCHAR(10)	= 'CAL'		-- CAL / CAL-HT / Refund / Refund-FT
	,@IP VARCHAR(50)		= NULL
	,@AdminID INT			= 148		-- calculated by system (default)
	,@IsLoop BIT			= 0
	,@IsLoopTempTable BIT	= 0
	,@ErrCode INT			= 0 OUTPUT
	,@ErrMsg NVARCHAR(200)	= '' OUTPUT
AS
/*
	Created by: Kathy
	Date: 20131212
	Task: Settlement 
	DB: DBTXN/BODB02
	Orignal: Admin_Settlement_s161
	
	Revisions:
		- 20140910@Kathy: Include range of NG bettypes ( 81-> 120)
		- 20150807@Kathy: Using new balance table (BalCreditOthersPending,BalDebitOthersPending) [Redmine:#40125]
		- 20161201@Kathy: Company win limit [Redmine:#66599]
		- 20171031@Patrick: Reduce balance correction [Redmine: #85841]
		- 20200218@Sol: : Incorporate Number Game - Color Ball [Redmine:#128203]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		+ @IsLoop (used for Balance):
			 1 : is recalled  
			 0 : normal						   
		+ @IsLoopTempTable (used for check temp table TempVariableNumber):			
			 1 : is recalled  
			 0 : normal		   
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @start DATETIME
			,@stop DATETIME
			,@LogData		NVARCHAR(200)
			,@Remark		VARCHAR(500)
			,@ActionID		INT
			,@IsCentral	BIT = 0
			,@avaiableProcess	BIT

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @IsLive = 1					SET @ActionID = 116
	ELSE IF @Action = 'CAL-HT'		SET @ActionID = 118
	ELSE IF @Action = 'CAL'			SET @ActionID = 115
	ELSE IF @Action = 'Refund'		SET @ActionID = 117
	ELSE IF @Action = 'Refund-FT'	SET @ActionID = 119

	IF @IsLoopTempTable = 0
	BEGIN
		-- check and not allow attempt to settlement same game while it's still not finish
		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT	@matchid AS matchid
				,1 AS KeyId
		
		--check settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsExistMatch		= 1
			,@avaiableProcess 	= @avaiableProcess OUTPUT
			,@ErrCode			= @ErrCode OUTPUT
			,@ErrMsg			= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN
			SELECT  @ErrCode 
					,@ErrMsg  

			RETURN
		END
	END

	---------
	SELECT @start = CURRENT_TIMESTAMP

	DECLARE @MaxTransID BIGINT
	

	--//MB is running?
	IF EXISTS (
		SELECT 1 FROM dbo.SystemSettings WITH(NOLOCK)
		WHERE VName = 'isMovingBet' AND VValue = '1'
	)
	BEGIN
		-- waiting for releasing lock on bettrans table
		SELECT @MaxTransID = MAX(b.transid)
		FROM dbo.bettrans b WITH(ROWLOCK)
		WHERE b.matchid = @MatchId
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		
		WAITFOR DELAY '00:00:02:000'
	END

	SELECT @MaxTransID = MAX(b.transid)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.matchid = @MatchId
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceBefore (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)

	IF @IsLoop = 0
	BEGIN
		--===
		INSERT INTO #BalanceBefore(custid, balance, winlost, winlostdate, gametypeid)
		SELECT custid
			,SUM(winlost - actual_stake + playercomm)
			,SUM(CASE
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0 
				END) AS winlost
			,winlostdate
			,bettype
		FROM dbo.bettrans WITH(ROWLOCK)
		WHERE matchid = @MatchId AND transid <= @MaxTransID
			AND bettype BETWEEN 81 AND 120
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		GROUP BY custid, winlostdate, bettype

	END

	IF @IsLive = 1
	BEGIN
		DECLARE @Number TINYINT,
				@Color VARCHAR(1)

		SELECT @Number = Number, @Color = Color
		FROM DBPRO.BODB02.dbo.BingoBall WITH(NOLOCK)
		WHERE matchid = @MatchId AND seq = @DrawSeq

		EXEC dbo.NAP_Admin_PreCalculate_s161_Live @MatchId = @MatchId, @DrawSeq = @DrawSeq, @Number = @Number, @Color = @Color

		SET @LogData = 'Calculate Number Game for matchid:' + CAST(@MatchId AS NVARCHAR(10)) + '- [LIVE] - Sequence number: (' + CAST(@DrawSeq AS NVARCHAR(2)) + ') '
		SET @ActionID = 116
		SET @Remark = 'Sequence number: (' + CAST(@DrawSeq AS NVARCHAR(2)) + ') <br />'

		IF @DrawSeq = 1 -- Cal-HT
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_s161 @MatchId = @MatchId
				,@Action = 'CAL-HT'
				,@IP = @IP
				,@AdminID = @AdminID
				,@IsLoop = 1 -- Use for recall (loop balance)
				,@IsLoopTempTable = 1 --- Use for recall (loop TempTable)
		END
	END
	ELSE IF @Action = 'Refund'
	BEGIN

		EXEC dbo.NAP_Admin_PreCalculate_s161_Refund @MatchId = @MatchId, @Action = @Action
		
		SET @LogData = 'REFUND Number Game for matchid:' + CAST(@MatchId AS NVARCHAR(10))
		SET @ActionID = 117

	END
	ELSE IF @Action = 'Refund-FT'
	BEGIN

		EXEC dbo.NAP_Admin_PreCalculate_s161_Refund @MatchId = @MatchId, @Action = @Action

		SET @LogData = 'REFUND FT Number Game for matchid:' + CAST(@MatchId AS NVARCHAR(10))
		SET @ActionID = 119

	END
	ELSE IF @Action = 'CAL-HT'
	BEGIN
		-- gather information for settlement
		DECLARE @1st_Ball TINYINT, @Result81 NVARCHAR(1), @Result83 NVARCHAR(1)		

		SELECT @1st_Ball = Number
		FROM DBPRO.BODB02.dbo.BingoBall WITH(NOLOCK)
		WHERE matchid = @MatchId AND seq = 1

		-- PreGame winning result
		SET @Result81 = CASE WHEN @1st_Ball >= 38 THEN 'h' ELSE 'a' END
		SET @Result83 = CASE @1st_Ball % 2 WHEN 1 THEN 'h' ELSE 'a' END

		-- settle PreGame
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 81, @BetTeam = @Result81, @FirstBallNo = @1st_Ball
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 83, @BetTeam = @Result83, @FirstBallNo = @1st_Ball

		SELECT @LogData = 'Calculate HT Number Game for matchid:' + CAST(@MatchId AS NVARCHAR(10))

		SELECT @ActionID = 118
	END
	ELSE IF @Action = 'CAL'
	BEGIN
		-- gather information for settlement
		DECLARE @MaxSeq TINYINT
		DECLARE @LastBall TINYINT, @SecondBall TINYINT, @ThirdBall TINYINT
		DECLARE @OverBallCount TINYINT, @UnderBallCount TINYINT, @BingoBallSum INT
		DECLARE @Result82 NVARCHAR(1), @Result84 NVARCHAR(1)
		DECLARE @Result85 NVARCHAR(1), @Result86 NVARCHAR(1)
		DECLARE @Result88 NVARCHAR(1)

		-- get count of ball when bingo hit
		SELECT @MaxSeq = MAX(seq)
		FROM DBPRO.BODB02.dbo.BingoBall WITH(NOLOCK)
		WHERE matchid = @MatchId

		-- first & last ball's number & SUM of ball
		SELECT @LastBall = SUM(CASE seq WHEN @MaxSeq THEN Number ELSE 0 END)
			,@OverBallCount = SUM(CASE WHEN Number >= 38 THEN 1 ELSE 0 END)
			,@UnderBallCount = SUM(CASE WHEN Number >= 38 THEN 0 ELSE 1 END)
			,@BingoBallSum = SUM(Number)
			,@SecondBall = SUM(CASE seq WHEN 2 THEN Number ELSE 0 END)
			,@ThirdBall = SUM(CASE seq WHEN 3 THEN Number ELSE 0 END)
		FROM DBPRO.BODB02.dbo.BingoBall WITH(NOLOCK)
		WHERE matchid = @MatchId

		-- PreGame winning result
		SET @Result82 = CASE WHEN @LastBall >= 38 THEN 'h' ELSE 'a' END
		SET @Result84 = CASE @LastBall % 2 WHEN 1 THEN 'h' ELSE 'a' END
		SET @Result85 = CASE 
				WHEN @OverBallCount > @UnderBallCount THEN 'h' 
				WHEN @OverBallCount < @UnderBallCount THEN 'a'
				ELSE 'x' END
		SET @Result86 = CASE @BingoBallSum % 2 WHEN 1 THEN 'h' ELSE 'a' END
		SET @Result88 = CASE WHEN @SecondBall > @ThirdBall THEN 'h' ELSE 'a' END

		-- settle PreGame
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 82, @BetTeam = @Result82, @FirstBallNo = 0
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 84, @BetTeam = @Result84, @FirstBallNo = 0
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 85, @BetTeam = @Result85, @FirstBallNo = 0
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 86, @BetTeam = @Result86, @FirstBallNo = 0
		EXEC dbo.NAP_Admin_PreCalculate_s161_Pregame @MatchId = @MatchId, @BetType = 88, @BetTeam = @Result88, @FirstBallNo = 0		

		SELECT @LogData = 'Calculate Number Game for matchid:' + CAST(@matchid AS NVARCHAR(10))

		SELECT @ActionID = 115

	END

	SELECT @stop = CURRENT_TIMESTAMP

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	CREATE TABLE #BalanceAfter (custid INT, balance MONEY, winlost MONEY, winlostdate SMALLDATETIME, gametypeid SMALLINT)

	IF @IsLoop = 0
	BEGIN
		INSERT INTO #BalanceAfter(custid, balance, winlost, winlostdate, gametypeid)
		SELECT custid
			,SUM(winlost - actual_stake + playercomm)
			,SUM(CASE 
					WHEN ruben = 1 THEN winlost - actual_stake 
					ELSE 0
				END) AS winlost
			,winlostdate
			,bettype
		FROM dbo.bettrans WITH(ROWLOCK)
		WHERE matchid = @matchid AND transid <= @MaxTransID
			AND bettype BETWEEN 81 AND 120
			AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		GROUP BY custid, winlostdate, bettype

	END

	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
	CREATE TABLE #Balance (custid INT, balance MONEY, Increased BIT)

	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
		
	CREATE INDEX IX_Balance_Increased ON #Balance (Increased)

	INSERT INTO #Balance
	SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
	FROM	#BalanceBefore b
		INNER JOIN #BalanceAfter a 
			ON	b.custid = a.custid
				AND a.winlostdate = b.winlostdate
				AND a.gametypeid = b.gametypeid
	WHERE	b.balance <> a.balance

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
		,81
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
		,81
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

	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	-- LOG
	
	SET @LogData = @LogData + '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)' + ' MaxTransID: ' + CONVERT(VARCHAR(20), @MaxTransID)

	EXEC dbo.Logfile_V2 
		@UserID = @AdminId
		,@Doing = @LogData
		,@extend = @MatchId
	
	IF @IsCentral = 1
	BEGIN
		SET @Remark = @Remark + 'Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms - MaxTransID: ' + CONVERT(VARCHAR(20), @MaxTransID)
		BEGIN TRY	
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminID
				,@Matchid = @MatchId
				,@ActionID = @ActionID
				,@finalhomescore = NULL
				,@finalawayscore = NULL
				,@hthomescore = NULL
				,@htawayscore = NULL
				,@GoalRecord = NULL
				,@betstatus = NULL
				,@Remark = @Remark
				,@IP = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 350)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminID
				,@Matchid = @MatchId
				,@ActionID = @ActionID
				,@finalhomescore = NULL
				,@finalawayscore = NULL
				,@hthomescore = NULL
				,@htawayscore = NULL
				,@GoalRecord = NULL
				,@betstatus = NULL
				,@Remark = @Remark
				,@IP = @IP
		END CATCH
	END
	----
	IF @IsLoopTempTable = 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsExistMatch	= 1
			,@IsReleased	= 1
	END
END
GO