/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Admin_Settlement_s161_Manual]
	@MatchId int,
	@BallResults VARCHAR(MAX) = '<Balls></Balls>',
	@IP varchar(50),
	@AdminID int, -- Admin user
	@ErrCode int = 0 OUTPUT,
	@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
	Created by:Kathy
	Date:20131212
	Task: Re-calculate for a numbers game match
	DB: DBTXN/BODB02
	Orignal: Admin_Settlement_s161_Manual
	
	Revisions: 
		- 20200218@Sol: : Incorporate Number Game - Color Ball [Redmine:#128203]
		- 20220601@Kathy: Check SP under deployment [Redmine:#172557]
	
	Param's Explanation:
		
*/
BEGIN	
	DECLARE @procName		SYSNAME
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT 

	SELECT @procName = OBJECT_NAME(@@procid)
			,@IsWaiting = 0

	-- Check SP is in deployment
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@WaitingTime = @WaitingTime OUTPUT
		,@IsWaiting = @IsWaiting OUTPUT
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	IF @IsWaiting = 1
	BEGIN
		WAITFOR DELAY @WaitingTime
			
		SELECT	@ErrCode = @ErrCode
				,@ErrMsg = @ErrMsg

		RETURN
	END

	IF EXISTS(SELECT 1 FROM SystemSettings WITH (NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingNGManual')
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Another number game re-calculation is in progress, please wait a few seconds until the ongoing process has finished and try again.'
		RETURN
	END
	ELSE 
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '1'
		WHERE	VName = 'isCalculatingNGManual'
	END

	-- get data from xml
	DECLARE @tblResult TABLE(Seq TINYINT, Number TINYINT, Color VARCHAR(1))
	DECLARE @handle INT,
			@FirstBall TINYINT = NULL, -- 0 means N/A	
			@SecondBall TINYINT = NULL, -- 0 means N/A
			@ThirdBall TINYINT = NULL -- 0 means N/A

	EXEC sp_xml_preparedocument @handle OUTPUT, @BallResults
	INSERT INTO @tblResult(Seq, Number, Color)
	SELECT Seq, Number, Color
	FROM OPENXML(@handle,'Balls/Ball',1) WITH( Seq	TINYINT
												,Number TINYINT
												,Color VARCHAR(1)
										) AS tbl
	EXEC sp_xml_removedocument @handle

	SELECT 
		@FirstBall = CASE WHEN Seq = 1 THEN Number ELSE @FirstBall END,
		@SecondBall = CASE WHEN Seq = 2 THEN Number ELSE @SecondBall END,
		@ThirdBall = CASE WHEN Seq = 3 THEN Number ELSE @ThirdBall END
	FROM @tblResult

	-- step 1: refund all
	EXEC dbo.NAP_Admin_settlement_s161
	@MatchId = @MatchId,
	@IsLive = 0,
	@Action = 'Refund',
	@IP = @IP,
	@AdminID = @AdminID,
	@ErrCode = @ErrCode OUTPUT,
	@ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END
	
	-- step 2: update ball result
	EXEC DBPRO.BODB02.dbo.NAP_UpdateNumberGameBalls 
		@MatchId = @MatchId,
		@BallResults = @BallResults,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode <> 0
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END

	-- step 3: FIRST ball case
	IF @FirstBall is NULL 
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END

	-- calculate first ball (live) [ and HT (dead) ]
	EXEC dbo.NAP_Admin_settlement_s161
	@MatchId = @MatchId,
	@IsLive = 1,
	@DrawSeq = 1,
	@Action = 'CAL',
	@IP = @IP,
	@AdminID = @AdminID,
	@ErrCode = @ErrCode OUTPUT,
	@ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode <> 0 
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END

	-- step 4: SECOND ball case
	IF @SecondBall is NULL
	BEGIN
		EXEC dbo.NAP_Admin_settlement_s161
			@MatchId = @MatchId,
			@IsLive = 0,
			@Action = 'Refund-FT',
			@IP = @IP,
			@AdminID = @AdminID,			
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT
			
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
		
	END

	EXEC dbo.NAP_Admin_settlement_s161
		@MatchId = @MatchId,
		@IsLive = 1,
		@DrawSeq = 2,
		@Action = 'CAL',
		@IP = @IP,
		@AdminID = @AdminID,		
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode <> 0 
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END

	-- step 5: THIRD ball case
	IF @ThirdBall is NULL
	BEGIN
		EXEC dbo.NAP_Admin_settlement_s161
			@MatchId = @MatchId,
			@IsLive = 0,
			@Action = 'Refund-FT',
			@IP = @IP,
			@AdminID = @AdminID,			
			@ErrCode = @ErrCode OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT
	
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END

	-- calculate 3rd ball (live)
	EXEC dbo.NAP_Admin_settlement_s161
		@MatchId = @MatchId,
		@IsLive = 1,
		@DrawSeq = 3,
		@Action = 'CAL',
		@IP = @IP,
		@AdminID = @AdminID,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT
	
	IF @ErrCode <> 0 
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
	END

	-- calculate FT (dead)
	EXEC dbo.NAP_Admin_settlement_s161
		@MatchId = @MatchId,
		@IsLive = 0,	
		@Action = 'CAL',
		@IP = @IP,
		@AdminID = @AdminID,
		@ErrCode = @ErrCode OUTPUT,
		@ErrMsg = @ErrMsg OUTPUT
		

	UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
	SET		VValue = '0'
	WHERE	VName = 'isCalculatingNGManual'
END
GO
