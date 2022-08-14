/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Match_NumberGame_Upd
	@MatchID	INT
	,@IsAuto	BIT = 0
	,@Resources	VARCHAR(MAX)
	,@Action	VARCHAR(10)
	,@AdminId	INT = 0
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	VARCHAR(500) = '' OUTPUT
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBPRO/bodb02

	Revisions:		
		- 20201216@Louisa: Update match/reult info NumberGame [Redmine:#175251]

	Param's explaination:
		@IsAuto:
			1: settle by service
			0: manual 
*/
BEGIN
	SET NOCOUNT ON

	IF @Action = 'Refund' OR @IsAuto = 0
	BEGIN
		EXEC NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_s161-Refund', @MatchId = @MatchId, @Creator = @AdminID
	END

	ELSE IF @Action = 'Refund-FT'
	BEGIN
		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_s161-Refund_FT', @MatchId = @MatchId, @Creator = @AdminID
	END

	ELSE IF @Action = 'CAL'
	BEGIN
		EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_s161-CAL', @Matchid = @MatchId, @Creator = @AdminID
	END

	IF @IsAuto = 0
	BEGIN
		UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
		SET		VValue = '0'
		WHERE	VName = 'isCalculatingNGManual'

		EXEC dbo.NAP_UpdateNumberGameBalls 
			@MatchId = @MatchId
			,@BallResults = @Resources
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			UPDATE	systemSettings WITH (ROWLOCK, UPDLOCK)
			SET		VValue = '0'
			WHERE	VName = 'isCalculatingNGManual'
		
		RETURN
		END

	END

END
GO