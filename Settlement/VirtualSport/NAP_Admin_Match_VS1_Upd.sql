/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Match_VS1_Upd
	 @MatchID	INT
	,@Fth		SMALLINT	
	,@Fta		SMALLINT	
	,@Action	VARCHAR(10)
	,@AdminId	INT = 0
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBPRO/bodb02

	Revisions:		
		- 20201216@Louisa: Update match/reult info Virtuak sport [Redmine:#175251]

	Param's explaination: 

*/
BEGIN
	SET NOCOUNT ON

	IF @Action = 'CAL'
	BEGIN
		EXEC dbo.NAP_Admin_Match_Update 
			@Command	= 'NAP_Admin_Settlement_VS_180-CAL'
			,@MatchID	= @matchid
			,@FTHome	= @Fth
			,@FTAway	= @Fta
			,@creator	= @AdminId

		EXEC dbo.NAP_updateMatch_remark 
			@MatchId	= @MatchId
			,@Command	= 'C' -- completed
	END

	ELSE IF @Action = 'REFUND'
	BEGIN
		EXEC dbo.NAP_Admin_Match_Update 
			@Command	= 'NAP_Admin_Settlement_VS_180-REFUND'
			,@MatchID	= @matchid
			,@creator	= @AdminId
		
		EXEC dbo.NAP_updateMatch_remark 
			@MatchId	= @MatchId
			,@Command	= 'F' -- refund
	END


END
GO