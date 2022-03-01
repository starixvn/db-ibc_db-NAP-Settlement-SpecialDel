/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderResultDetailSel
	(
		@MatchId		INT
		, @SourceId		TINYINT
		, @TypeId		TINYINT
	)
AS
/*
	Creator: 20220222@Louisa 
	Task: Integrate result for Soccer Corner matches [Redmine:#168854]
	DB: DBPRO/bodb02

	Revisions: 
		- 20220222@Louisa: Initial
	
	Param's Explanation:
		@TypeId:
				1 - HT
				2 - FT
		@SourceId
				1 - SBO
*/
BEGIN
	SET NOCOUNT ON

	SELECT r.MatchId, r.HomeValue, r.AwayValue, r.CreatedDate 
	FROM dbo.ProviderResultDetail r WITH(NOLOCK)
	WHERE r.MatchId = @MatchId
		AND r.SourceId = @SourceId
		AND r.TypeId = @TypeId

END
GO