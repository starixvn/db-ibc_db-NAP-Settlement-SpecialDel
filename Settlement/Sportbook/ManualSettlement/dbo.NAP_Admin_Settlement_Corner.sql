/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Settlement_Corner] @AdminId INT
	, @Matchid				INT
	, @fthCorners			SMALLINT		= NULL
	, @ftaCorners			SMALLINT		= NULL
	, @hthCorners			SMALLINT		= NULL
	, @htaCorners			SMALLINT		= NULL 
	, @FTFCorner			VARCHAR(1)		= NULL
	, @FTLCorner			VARCHAR(1)		= NULL
	, @HTFCorner			VARCHAR(1)		= NULL
	, @HTLCorner			VARCHAR(1)		= NULL 	
	, @Action				VARCHAR(10)		= 'CAL'
	, @IP					VARCHAR(15)		= ''
	, @ErrCode				INT				= 0		OUTPUT
	, @ErrMsg				NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: Jamie
	Date: 20150618
	Task: Settlement Corner bets ONLY 
	DB: DBTXN/BODB02

	Revisions:		
		- 20150807@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20160311@Kathy: Exclude Fast Market [Redmine:#56367]
		- 20170427@Bobby: 72789 - Implement bonus system into NAP Settlement
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON 
	DECLARE @start DATETIME
		, @stop DATETIME
		, @eventstatus NVARCHAR(50)
		, @fth INT
		, @fta INT
		, @hth INT
		, @hta INT
		, @goalrecord VARCHAR(50)
		, @betstatus VARCHAR(50)
		, @ActionID INT
		, @Remark VARCHAR(500)
		, @LogData NVARCHAR(300)
		, @strBettypes VARCHAR(MAX)
		, @strAutoBettypes VARCHAR(MAX)
		, @avaiableProcess BIT

	
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	

	SELECT @start = CURRENT_TIMESTAMP
	SELECT @ActionID = CASE WHEN @Action = 'CAL' THEN 151 
							 WHEN @Action = 'CAL-HT' THEN 162
							 WHEN @Action = 'CAL-FT' THEN 161 
						ELSE 0 END
	
	SELECT	@strBettypes = COALESCE(@strBettypes + ',' + CAST(BetType AS VARCHAR),CAST(BetType AS VARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	1 = CASE 
					WHEN @Action = 'CAL' AND GroupId IN (5,6) THEN 1
					WHEN @Action = 'CAL-FT' AND GroupId = 6 THEN 1
					WHEN @Action = 'CAL-HT' AND GroupId = 5 THEN 1
					ELSE 0
				END
						
			
	
	SELECT	@strAutoBettypes = COALESCE(@strAutoBettypes + ',' + CAST(BetType AS VARCHAR),CAST(BetType AS VARCHAR))
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	IsAuto = 1
	
	SELECT @fth = finalhomescore
		, @fta = finalawayscore
		, @hth = hthomescore
		, @hta = htawayscore
		, @goalrecord = goalrecord 
		, @betstatus = betstatus 
	FROM DBPRO.BODB02.dbo.match WITH (NOLOCK)
	WHERE matchid = @matchid
		
	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchId AS matchid
		, 1 AS KeyID
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	
	--CHECK avaiable process
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletBefore (
			matchid
			, custid
			, balanceType
			, BonusID
			, WalletType
			, balance
		)
		SELECT matchid
			, custid
			, balanceType
			, BonusID
			, WalletType
			, balance 
		FROM dbo.f_NAP_Set_1_GetBalance (
			@MatchId
			, @Action
			, 5 --@Mode corner
		)

	--===
	--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	IF @Action IN ('CAL', 'CAL-FT', 'CAL-HT')
	BEGIN

		DECLARE @Status TABLE(CornerBet TINYINT, BetCount INT, InRunning INT)

		INSERT INTO @Status(CornerBet, BetCount, InRunning)
		SELECT	CASE WHEN CHARINDEX(',' + CAST(bettype AS VARCHAR) + ',', ',' + @strBettypes + ',') > 0 THEN 1
					ELSE 0 
				END --others
				, SUM(CASE WHEN statusID BETWEEN 101 AND 102 THEN 0 ELSE 1 END)
				, SUM(CASE WHEN statusID = 0 THEN 1 ELSE 0 END)
		FROM	dbo.Bettrans WITH (NOLOCK)
		WHERE	matchID = @MatchID 
				AND bettype NOT IN (10, 31, 32, 33, 1231, 1232, 1233, 1237, 1238) -- Outright, VSRacing
				AND bettype NOT BETWEEN 1501 AND 1599 -- Keno
				AND bettype NOT BETWEEN 801 AND 899 --Metric Gaming 
				AND 1 = CASE 
							WHEN CHARINDEX(',' + CAST(bettype AS VARCHAR) + ',', ',' + @strAutoBettypes + ',') > 0 THEN 0 
							ELSE 1 
						END
		GROUP BY CASE WHEN CHARINDEX(',' + CAST(bettype AS VARCHAR) + ',', ',' + @strBettypes + ',') > 0 THEN 1
					ELSE 0 
				END

		IF NOT EXISTS(SELECT TOP 1 1 FROM @Status WHERE CornerBet = 0)
			INSERT INTO @Status(CornerBet, BetCount, InRunning) VALUES(0, 0, 0)

		DECLARE @NoneCornerBetDone BIT

		SELECT @NoneCornerBetDone = CASE InRunning WHEN 0 THEN 1 ELSE 0 END
		FROM @Status
		WHERE CornerBet = 0
		
		SELECT @eventstatus = CASE WHEN @NoneCornerBetDone = 1 THEN N'completed' ELSE eventstatus END
		FROM DBPRO.BODB02.dbo.Match m WITH(NOLOCK)
		WHERE m.matchid = @matchid

		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
			@Command			= 'NAP_Admin_Settlement_Corner-CAL'
			,@MatchID			= @matchid
			,@NoneCornerBetDone = @NoneCornerBetDone
			,@Action			= @action
			,@creator			= @AdminID

		EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_1s
				@Command = 'NAP_Admin_Settlement_Corner-CAL',
				@MatchID = @MatchID,
				@fthCorners = @fthCorners,
				@ftaCorners = @ftaCorners,
				@hthCorners = @hthCorners,
				@htaCorners = @htaCorners,
				@ftFCorner = @ftFCorner,
				@ftLCorner = @ftLCorner,
				@htFCorner = @htFCorner,
				@htLCorner = @htLCorner,
				@Action = @Action,
				@IsAuto = 0,
				@creator = @AdminID		

		EXEC dbo.[NAP_Admin_Settlement_3_Corner] @matchid = @matchid, @mode = @action	
			
		IF 	@eventstatus='completed'			
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark @matchid = @matchid, @command	= 'C'
		END

	END

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletAfter (
			matchid
			, custid
			, balanceType
			, BonusID
			, WalletType
			, balance
		)
		SELECT matchid
			, custid
			, balanceType
			, BonusID
			, WalletType
			, balance 
		FROM dbo.f_NAP_Set_1_GetBalance (
			@MatchId
			, @Action
			, 5 --@Mode corner
		)
	
	-- Compare Balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID
		, @IsCheckNegative		= 1
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------

	SELECT @stop = CURRENT_TIMESTAMP

	SELECT @logdata = 'NAP: Calculate Corner (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
														   + ' FT:' + CASE WHEN @fthCorners IS NULL THEN '' ELSE CAST(@fthCorners AS VARCHAR(20)) END 
														   + '-'  + CASE WHEN @ftaCorners IS NULL THEN '' ELSE CAST(@ftaCorners AS VARCHAR(20)) END 
														   + ' HT:'  + CASE WHEN @hthCorners IS NULL THEN '' ELSE CAST(@hthCorners AS VARCHAR(20)) END 
														   + '-'  + CASE WHEN @htaCorners IS NULL THEN '' ELSE CAST(@htaCorners AS VARCHAR(20)) END 
														   + ' FTF:' + CASE WHEN @FTFCorner IS NULL THEN '' ELSE @FTFCorner END
														   + ' FTL:' + CASE WHEN @FTLCorner IS NULL THEN '' ELSE @FTLCorner END
														   + ' HTF:' + CASE WHEN @HTFCorner IS NULL THEN '' ELSE @HTFCorner END
														   + ' HTL ' + CASE WHEN @HTLCorner IS NULL THEN '' ELSE @HTLCorner END 
	EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @logdata

	SELECT @Remark = 'NAP: '
						+ CASE WHEN @fthCorners IS NULL THEN '' ELSE 'fthCorners:' + CAST(@fthCorners AS VARCHAR(50))  + ' ' END 
						+ CASE WHEN @ftaCorners IS NULL THEN '' ELSE 'ftaCorners:' + CAST(@ftaCorners AS VARCHAR(50))  + '<br/> ' END
						+ CASE WHEN @hthCorners IS NULL THEN '' ELSE 'hthCorners:' + CAST(@hthCorners AS VARCHAR(50))  + ' ' END
						+ CASE WHEN @htaCorners IS NULL THEN '' ELSE 'htaCorners:' + CAST(@htaCorners AS VARCHAR(50))  + '<br/> ' END
						+ CASE WHEN @ftFCorner IS NULL THEN '' ELSE 'ftFCorner:' + @ftFCorner + '<br/> ' END
						+ CASE WHEN @ftLCorner IS NULL THEN '' ELSE 'ftLCorner:' + @ftLCorner + '<br/> ' END
						+ CASE WHEN @htFCorner IS NULL THEN '' ELSE 'htFCorner:' + @htFCorner + '<br/> ' END
						+ CASE WHEN @htLCorner IS NULL THEN '' ELSE 'htLCorner:' + @htLCorner + '<br/> ' END
						+ ' Duration:' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + 'ms' 
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @userid = @AdminId
			, @matchid			= @MatchID
			, @actionid			= @ActionID
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= @goalrecord
			, @betstatus		= @betstatus
			, @Remark			= @Remark
			, @ip				= @ip
	END TRY

	BEGIN CATCH
		SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @MatchID			= @matchid
			, @actionid			= @actionid
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= @goalrecord
			, @betstatus		= @betstatus
			, @Remark			= @Remark
			, @IP				= @ip
	END CATCH

	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
	RETURN	
	
END
GO