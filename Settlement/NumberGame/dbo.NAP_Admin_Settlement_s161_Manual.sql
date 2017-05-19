CREATE PROCEDURE [NAP_Admin_Settlement_s161_Manual]
	@MatchId int,
	@FirstBall tinyint = NULL, --  means N/A
	@SecondBall tinyint = NULL, --  means N/A
	@ThirdBall tinyint = NULL, --  means N/A
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
	
	Param's Explanation:
		
*/
BEGIN	

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
		@FirstBall = @FirstBall,
		@SecondBall = @SecondBall,
		@ThirdBall = @ThirdBall,
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

GRANT EXECUTE ON [NAP_Admin_Settlement_s161_Manual] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Admin_Settlement_s161_Manual] TO [vnteam] AS [dbo]
GO


