/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Match_s175_Upd
	@MatchID		INT
	,@IsAuto		BIT = 0
	,@Action		VARCHAR(10)
	,@ResultId		INT
	,@GameResult	VARCHAR(50)		= ''
	,@AdminId		INT
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBPRO/bodb02

	Revisions:		
		- 20201216@Louisa: Update match/reult info Bitcoin [Redmine:#175251]

	Param's explaination: 

*/

BEGIN

	SET NOCOUNT ON

	IF @IsAuto = 0
	RETURN

	EXEC dbo.NAP_Admin_Result3rd_Update 
		@matchid = @matchid
		,@Action = @Action
		,@AdminId = @AdminId
		,@IsAuto = @IsAuto
		,@ResultId = @ResultId
		,@GameResult = @GameResult

	EXEC dbo.NAP_Admin_Match3rd_Update
		@Action	= @Action
		,@MatchID = @matchid

END

GO