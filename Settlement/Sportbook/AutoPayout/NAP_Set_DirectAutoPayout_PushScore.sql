/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Set_DirectAutopayout_PushScore
(
	@MatchId INT,
	@HomeScore TINYINT,
	@AwayScore TINYINT,
	@IsHTScore BIT
)
AS
/*
	Creator: 20200412@Sol
	Task: insert new score result for direct autopayout
	DB: DBPRO/bodb02
	Revisions:
		- 20200412@Sol: Allow User to Set Timeout for Direct Settlement - [Redmine:#132138]
		
	Param's Explanation:
		- @IsHTScore: [0:2H, 1:1H]

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @TypeId 	TINYINT
		, @SourceId		TINYINT
		, @RefInfo		VARCHAR(50)
		, @CreatedDate	DATETIME
		
	SELECT @TypeId 		=  CASE WHEN @IsHTScore = 1 THEN 1 
								WHEN @IsHTScore = 0 THEN 2
								ELSE 0 
							END
		, @SourceId		= 101 -- Direct auto payout
		, @CreatedDate	= GETDATE()
	
	IF ( 
		NOT EXISTS (
						SELECT TOP 1 1 
						FROM dbo.ProviderResultDetail WITH(NOLOCK) 
						WHERE MatchId = @MatchId AND SourceId = @SourceId AND TypeId = @TypeId
					)
		AND EXISTS (
						SELECT TOP 1 1
						FROM dbo.[match] m WITH (NOLOCK)
						WHERE matchid = @MatchId
					)
		AND @TypeId IN (1, 2)
		AND (ISNULL(@HomeScore, 0) >= 0 AND ISNULL(@AwayScore, 0) >= 0)
	)
	BEGIN
		INSERT INTO dbo.ProviderResultDetail (
			MatchId
			, SourceId
			, TypeId
			, HomeValue
			, AwayValue
			, CreatedDate
			, IsConfirmed
		)
		SELECT
			@MatchId
			, @SourceId
			, @TypeId
			, CAST(@HomeScore AS VARCHAR(50))
			, CAST(@AwayScore AS VARCHAR(50))
			, @CreatedDate
			, 0
	END
	RETURN	
END
GO
