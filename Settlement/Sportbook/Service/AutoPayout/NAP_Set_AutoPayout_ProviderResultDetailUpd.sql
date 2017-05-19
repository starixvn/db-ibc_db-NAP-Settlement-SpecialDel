USE [bodb02]
GO

ALTER PROCEDURE dbo.NAP_Set_AutoPayout_ProviderResultDetailUpd @MatchId INT
	, @SourceId TINYINT
	, @TypeId TINYINT
	, @HomeValue VARCHAR(50)
	, @AwayValue VARCHAR(50)
	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(200) = '' OUTPUT
	
AS
/*
	Creator: 20160331@Patrick
	Task: Update or insert new score result for AutoPayout.
	DB: DBPRO/bodb02
	Revisions:
	Param's Explanation:
		- @TypeId: 1: HT
				   2: FT
				   3: HT-FGLG
				   4: FT-FGLG

*/
BEGIN
	SET NOCOUNT ON

	IF EXISTS (SELECT TOP 1 1 
				FROM dbo.ProviderResultDetail WITH(NOLOCK) 
				WHERE MatchId = @MatchId AND SourceId = @SourceId AND TypeId = @TypeId)
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM dbo.ProviderResultDetail d WITH(NOLOCK)
					WHERE MatchId = @MatchId 
						AND SourceId = @SourceId
						AND TypeId = @TypeId
						AND (d.HomeValue <> @HomeValue OR d.AwayValue <> @AwayValue)
						AND EXISTS (SELECT TOP 1 1
										FROM dbo.AutoPayoutResult p WITH(NOLOCK) 
										WHERE p.MatchId = d.MatchId AND p.CalculationType = CASE WHEN d.TypeId = 3 THEN 1
																								WHEN  d.TypeId = 4 THEN 2
																								ELSE d.TypeId END AND p.StatusId <> 0))
		BEGIN
			--being processing or already settled
			SELECT @ErrCode = 1001025, @ErrMsg = 'Failed to update result detail. Because this match has already settled.'
			RETURN
		END

		UPDATE dbo.ProviderResultDetail WITH(ROWLOCK, UPDLOCK)
		SET HomeValue = @HomeValue
			, AwayValue = @AwayValue
			, CreatedDate = GETDATE()
		WHERE MatchId = @MatchId AND SourceId = @SourceId AND TypeId = @TypeId
			AND (HomeValue <> @HomeValue OR AwayValue <> @AwayValue)

		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 1001024, @ErrMsg = 'Failed to update result detail.'
			RETURN
		END

	END
	ELSE
	BEGIN
		INSERT INTO dbo.ProviderResultDetail (MatchId, SourceId, TypeId, HomeValue, AwayValue, CreatedDate)
		VALUES(@MatchId, @SourceId, @TypeId, @HomeValue, @AwayValue, GETDATE())
	
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 1001022, @ErrMsg = 'Failed to insert result detail.'
			RETURN
		END
	END
		
END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_AutoPayout_ProviderResultDetailUpd] TO [bodbAdminNet] AS [dbo]
GO
