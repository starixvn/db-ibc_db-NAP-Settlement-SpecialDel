/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite,Dot_Admin" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailSportsUnMapping]
	@MatchId3rd		INT
	,@MatchId		INT
	,@SourceId		SMALLINT
	,@Sporttype		SMALLINT
	,@EnvFlag		SMALLINT
	,@UserId		INT
AS
/*
	Created by: 20211223@Louisa
	Task: Cancel incorrect mapping between in-house and external match [Redmine:#166449]
	DB: DBPRO/bodb02
	Revisions:
		- 20211223@Louisa: Cancel incorrect mapping between in-house and external match [Redmine:#166449]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		
	Param's Explanation:
		@EnvFlag: -1: UAT, 0:PROD

*/
BEGIN
	
	DECLARE @ExternalResultTable TINYINT
	
	SELECT  @ExternalResultTable = CASE WHEN ss.sporttype = 8 THEN 2 ELSE ss.ExternalResultTable END
	FROM dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE ss.Sporttype = @Sporttype

	IF ISNULL(@Sporttype,1) = 1 OR @ExternalResultTable = 0 --exclude soccer and any sports not yet integrated ProviderResult
	RETURN

	IF @ExternalResultTable  = 1
	EXEC NAP_Set_ProviderExternalResultDetailUnMapping
		@MatchId3rd	= @MatchId3rd
		,@MatchId	= @MatchId
		,@SourceId	= @SourceId
		,@UserId	= @UserId
		,@EnvFlag	= @EnvFlag


	ELSE IF @ExternalResultTable  = 2
	EXEC NAP_Set_ProviderExternalResultDetailOSUnMapping		
		@MatchId3rd	= @MatchId3rd
		,@MatchId	= @MatchId
		,@SourceId	= @SourceId
		,@UserId	= @UserId
		,@EnvFlag	= @EnvFlag

	ELSE IF @ExternalResultTable = 3 ---- E-Sports
	EXEC NAP_Set_ProviderExternalResultDetailESUnMapping
		@MatchId3rd	= @MatchId3rd
		,@MatchId	= @MatchId
		,@SourceId	= @SourceId
		,@UserId	= @UserId
		,@EnvFlag	= @EnvFlag

END
