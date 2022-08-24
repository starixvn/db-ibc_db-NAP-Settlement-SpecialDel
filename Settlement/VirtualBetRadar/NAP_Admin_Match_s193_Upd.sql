/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Match_s193_Upd
	@MatchId	INT
	,@IsAuto	BIT = 0
	,@Fth		SMALLINT		= NULL
	,@Fta		SMALLINT		= NULL
	,@Hth		SMALLINT		= NULL
	,@Hta		SMALLINT		= NULL
	,@Resources	VARCHAR(MAX)
	,@Action	VARCHAR(10)
	,@AdminId	INT = 0
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBPRO/bodb02

	Revisions:		
		- 20201216@Louisa: Update match/reult info Happy5 [Redmine:#175251]

	Param's explaination: 
		@Resources:   '<Results>
                            <Resource ResourceId="00" Custom1="100" Custom2="106" />
                            <Resource ResourceId="01" Custom1="60" Custom2="41" />
                            <Resource ResourceId="280920" Custom1="H" Custom2="" />
                            <Resource ResourceId="280940" Custom1="A" Custom2="" />
                            <Resource ResourceId="280960" Custom1="N" Custom2="" />
                    </Results>'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sporttype SMALLINT

	SELECT	@sportType 	= sportType
	FROM	dbo.match m WITH(NOLOCK) 
	WHERE	m.matchid = @MatchId

	IF @Action = 'CAL'
	BEGIN
		EXEC dbo.NAP_Admin_Match_Update 
			@Command	= 'completed'
			,@MatchID	= @matchid
			,@FTHome	= @fth
			,@FTAway	= @fta
			,@HTHome	= @hth
			,@HTAway	= @hta
			,@creator	= @AdminId
		
		EXEC dbo.NAP_updateMatch_remark 
			@MatchId	= @MatchId
			,@Command	= 'VSC'

		IF @sportType = 193
		BEGIN
			EXEC dbo.NAP_Admin_VS_Betradar_Result_Update 
				@Command	= 'NAP_Admin_Settlement_VS_BetRadar-CAL'
				,@MatchID	= @matchid
				,@ResourceResult = @Resources
				,@creator	= @AdminId
				,@IsAuto = @IsAuto
		END

	END
	ELSE IF @Action = 'REFUND'
	BEGIN
		EXEC dbo.NAP_Admin_Match_Update 
			@Command	= 'completed'
			,@MatchID	= @matchid
			,@creator	= @AdminId
		
		EXEC dbo.NAP_updateMatch_remark 
			@MatchId	= @MatchId
			,@Command	= 'VSR' -- refund

		IF @sportType = 193
		BEGIN
			EXEC dbo.NAP_Admin_VS_Betradar_Result_Update 
				@Command	= 'NAP_Admin_Settlement_VS_BetRadar-REFUND'
				,@MatchID	= @matchid
				,@ResourceResult = @Resources
				,@creator	= @AdminId
				,@IsAuto = @IsAuto
		END
	END

END
GO