/*<info serverAlias="DBPRO-bodb02" executers="Dot_InfoSite" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ProviderResultDetailIns
	(
		@MatchId		INT
		, @SourceId		TINYINT
		, @TypeId		TINYINT
		, @HomeValue	VARCHAR(50)
		, @AwayValue	VARCHAR(50)
		, @Action		VARCHAR(1) = 'I'
		, @ErrCode		INT = 0 OUTPUT
		, @ErrMsg		NVARCHAR(200) = '' OUTPUT
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
		@Action
				'I' - Insert
				'U' - Update
*/
BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId AND ISNULL(m.ChildMatchType,0) =  204 ) --match corner
	BEGIN
		SELECT  @ErrCode = 1001001 ,@ErrMsg	= 'Match does not exist!'
		RETURN
	END

	IF @Action = 'I' AND EXISTS ( SELECT TOP 1 1 FROM dbo.ProviderResultDetail WITH(NOLOCK) WHERE MatchId = @MatchId AND SourceId = @SourceId AND TypeId = @TypeId )
	BEGIN
		SELECT @ErrCode = 1001021, @ErrMsg = 'Failed to insert result detail (duplicate data).'
		RETURN
	END

	BEGIN TRY

		;WITH cte_Source (MatchId, SourceId, TypeId, HomeValue, AwayValue) AS (
			SELECT @matchId, @SourceId, @TypeId, @HomeValue, @AwayValue
		)

		MERGE dbo.ProviderResultDetail AS TARGET
		USING ( SELECT MatchId, SourceId, TypeId, HomeValue, AwayValue FROM cte_Source ) AS SOURCE
			ON	TARGET.MatchId	= SOURCE.MatchId 
			AND TARGET.SourceId = SOURCE.SourceId 
			AND TARGET.TypeId	= SOURCE.TypeId

		WHEN MATCHED AND @Action = 'U' THEN
			UPDATE SET TARGET.HomeValue = SOURCE.HomeValue
					 , TARGET.AwayValue = SOURCE.AwayValue

		WHEN NOT MATCHED BY TARGET AND @Action = 'I' THEN
			INSERT (MatchId, SourceId, TypeId, HomeValue, AwayValue)
			VALUES (SOURCE.MatchId, SOURCE.SourceId, SOURCE.TypeId, SOURCE.HomeValue,SOURCE. AwayValue);
	
	END TRY

	BEGIN CATCH
		SELECT @ErrCode	= ERROR_NUMBER()
			, @ErrMsg 	= ISNULL(ERROR_MESSAGE(),'')

		RETURN
	END CATCH
		
END
GO