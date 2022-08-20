/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Match_NumberGame_Upd
	 @MatchID	INT
	,@IsAuto	BIT = 0
	,@Resources	VARCHAR(MAX) = NULL
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

	DECLARE @Command VARCHAR(100)

	SET @Command = CASE 
						WHEN @Action = 'CAL' THEN 'NAP_Admin_Settlement_s161-CAL'
						WHEN @Action = 'REFUND' THEN 'NAP_Admin_Settlement_s161-Refund'
						WHEN @Action = 'REFUND-FT' THEN 'NAP_Admin_Settlement_s161-Refund_FT'
						ELSE ''
					END

	EXEC NAP_Admin_Match_Update 
		@Command = @Command 
		,@MatchId = @MatchId
		,@Creator = @AdminID
	
	IF @IsAuto = 0
	BEGIN
		EXEC dbo.NAP_UpdateNumberGameBalls 
			@MatchId = @MatchId
			,@BallResults = @Resources
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END
END
GO