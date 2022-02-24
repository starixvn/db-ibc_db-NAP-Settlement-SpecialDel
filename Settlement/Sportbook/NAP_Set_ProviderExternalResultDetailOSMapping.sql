/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ProviderExternalResultDetailOSMapping]
	@MatchId3rd		INT
	,@MatchId		INT 
	,@SourceId		SMALLINT 
	,@UserId		INT
	,@EnvFlag		SMALLINT
AS
/*
	Created by: 20211223@Louisa
	Task: mapping between in-house and external match [Redmine:#166449]
	DB: DBPRO/bodb02
	Revisions:
		- 20211223@Louisa: mapping between in-house and external match [Redmine:#166449]
		
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
			AND MatchId = @EnvFlag

	IF @@ROWCOUNT = 0
		RETURN

	WHILE (1=1)
	BEGIN
		DELETE FROM @tmpId

		DELETE TOP (@batchNo)
		FROM	#tmpProviderExternalResultDetail
		OUTPUT DELETED.ProviderExternalId INTO @tmpId (ProviderExternalId)

		UPDATE	p
			SET MatchId = @MatchId
				,LastModifyBy = @UserId
				,LastModifyDate = GETDATE()
		FROM	dbo.ProviderExternalResultDetailOS p WITH (UPDLOCK, ROWLOCK)
			INNER JOIN @tmpId t
				ON p.ProviderExternalId = t.ProviderExternalId

		IF @@ROWCOUNT = 0
			BREAK
	END
END
