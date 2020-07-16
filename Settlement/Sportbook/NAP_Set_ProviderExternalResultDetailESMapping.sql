/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite,Dot_Admin" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailESMapping]
	@MatchId3rd		INT
	,@MatchId		INT 
	,@SourceId		SMALLINT
	,@UserId		INT
AS
/*
	Creator: 20200713@Kathy
	Task: Mapping between in-house and external match
	DB: DBPRO/bodb02
	Revisions:
		- 20200713@Kathy: Mapping between in-house and external match [Redmine:#136931]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @batchNo INT

	DECLARE @tmpId TABLE (ProviderExternalId INT)
	CREATE TABLE #tmpProviderExternalResultDetail (ProviderExternalId INT)
	
	SET @batchNo = 2000

	INSERT INTO #tmpProviderExternalResultDetail(ProviderExternalId)
	SELECT	ProviderExternalId
	FROM	dbo.ProviderExternalResultDetailES WITH(NOLOCK)
	WHERE	SourceId = @SourceId
			AND MatchId3rd = @MatchId3rd
			AND MatchId <> @MatchId

	IF @@ROWCOUNT = 0
		RETURN

	WHILE (1=1)
	BEGIN
		DELETE TOP (@batchNo)
		FROM	#tmpProviderExternalResultDetail
		OUTPUT DELETED.ProviderExternalId INTO @tmpId (ProviderExternalId)

		UPDATE	p
			SET MatchId = @MatchId
				,LastModifyBy = @UserId
				,LastModifyDate = GETDATE()
		FROM	dbo.ProviderExternalResultDetailES p WITH (UPDLOCK, ROWLOCK)
			INNER JOIN @tmpId t
				ON p.ProviderExternalId = t.ProviderExternalId

		IF @@ROWCOUNT = 0
			BREAK
	END
END
GO
