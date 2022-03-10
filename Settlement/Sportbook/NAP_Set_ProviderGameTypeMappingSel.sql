/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderGameTypeMappingSel]
	@SourceId		SMALLINT
	,@Sporttype		SMALLINT = 43
AS
/*
	Creator: 20200713@Kathy
	Task: Get game type list [Redmine:#136931]
	DB: DBPRO/bodb02
	Revisions:
		- 20200713@Kathy: Get game type list [Redmine:#136931]
		- 20220111@Louisa: ESports Phase 4 [Redmine:#166330]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	-- provider info
	SELECT	pi.SourceId
			,pi.SourceName
			,pi.Remark
			,pi.isActive
	FROM	dbo.ProviderInfo pi WITH(NOLOCK)
	WHERE	pi.SourceId = @SourceId

	-- gametype info
	SELECT	pgtm.PGId
			,pgtm.GameType
			,pgtm.Remark
			,pgtm.isActive
	FROM	dbo.ProviderGameTypeMapping pgtm WITH(NOLOCK)
	WHERE	pgtm.SourceId = @SourceId
		AND pgtm.sporttype = @Sporttype
END
GO
