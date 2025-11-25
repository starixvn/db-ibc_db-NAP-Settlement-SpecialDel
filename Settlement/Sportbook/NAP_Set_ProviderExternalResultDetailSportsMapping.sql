/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite,Dot_Admin" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailSportsMapping]
	@MatchId3rd		INT
	,@MatchId		INT 
	,@SourceId		SMALLINT
	,@Sporttype		SMALLINT
	,@UserId		INT
	,@EnvFlag		SMALLINT
AS
/*
	Created by: 20211223@Louisa
	Task: mapping between in-house and external match [Redmine:#166449]
	DB: DBPRO/bodb02
	Revisions:
		- 20211223@Louisa: mapping between in-house and external match [Redmine:#166449]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20251107@Louisa: check @ExternalTable by setting [Redmine:#243860]
		
	Param's Explanation:
		@EnvFlag: -1: UAT, 0:PROD

*/
BEGIN
	
	DECLARE @ExternalResultTable TINYINT
	
	SELECT  @ExternalResultTable = ss.ExternalResultTable
	FROM dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE ss.Sporttype = @Sporttype

	IF @ExternalResultTable = 1
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailMapping
			@MatchId3rd	= @MatchId3rd	
			,@MatchId	= @MatchId	
			,@SourceId	= @SourceId
			,@UserId	= @UserId	
			,@EnvFlag	= @EnvFlag	
	END

	ELSE IF @ExternalResultTable = 2
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailOSMapping
			@MatchId3rd	= @MatchId3rd	
			,@MatchId	= @MatchId	
			,@SourceId	= @SourceId
			,@UserId	= @UserId	
			,@EnvFlag	= @EnvFlag	
	END

	ELSE IF @ExternalResultTable = 3 --E-Sports
	BEGIN
		EXEC dbo.NAP_Set_ProviderExternalResultDetailESMapping
			@MatchId3rd	= @MatchId3rd
			,@MatchId	= @MatchId	
			,@SourceId	= @SourceId
			,@UserId	= @UserId	
			,@EnvFlag	= @EnvFlag	
	END

END
