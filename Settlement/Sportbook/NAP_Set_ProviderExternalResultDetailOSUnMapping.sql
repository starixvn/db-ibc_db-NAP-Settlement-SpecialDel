/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailOSUnMapping]
	@MatchId3rd		INT
	,@MatchId		INT
	,@SourceId		SMALLINT
	,@EnvFlag		SMALLINT
	,@UserId		INT
AS
/*
	Created by: 20211223@Louisa
	Task: Cancel incorrect mapping between in-house and external match [Redmine:#166449]
	DB: DBPRO/bodb02
	Revisions:
		- 20211223@Louisa: Cancel incorrect mapping between in-house and external match [Redmine:#166449]
		
	Param's Explanation:
		@EnvFlag: -1: UAT, 0:PROD

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @batchNo INT

	DECLARE @tmpId TABLE (ProviderExternalId INT)
	CREATE TABLE #tmpProviderExternalResultDetail (ProviderExternalId INT)
	
	SET @batchNo = 2000

	INSERT INTO #tmpProviderExternalResultDetail(ProviderExternalId)
	SELECT	ProviderExternalId
	FROM	dbo.ProviderExternalResultDetailOS WITH(NOLOCK)
	WHERE	SourceId = @SourceId
			AND MatchId3rd = @MatchId3rd
			AND MatchId = @MatchId

	IF @@ROWCOUNT = 0
		RETURN
	
	WHILE (1=1)
	BEGIN
		DELETE FROM @tmpId

		DELETE TOP (@batchNo)
		FROM	#tmpProviderExternalResultDetail
		OUTPUT DELETED.ProviderExternalId INTO @tmpId (ProviderExternalId)

		UPDATE	p
			SET MatchId = @EnvFlag
				,LastModifyBy = @UserId
				,LastModifyDate = GETDATE()
		FROM	dbo.ProviderExternalResultDetailOS p WITH (UPDLOCK, ROWLOCK)
			INNER JOIN @tmpId t
				ON p.ProviderExternalId = t.ProviderExternalId

		IF @@ROWCOUNT = 0
			BREAK
	END
END
