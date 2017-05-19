/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE bodb02
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE dbo.NAP_Settlement_InstantCalculation_PushScore
	@MatchId 		INT
	, @HomeScore 	TINYINT
	, @AwayScore 	TINYINT
	, @GoalRecord	VARCHAR(50) = NULL
	, @IsHTScore 	BIT
AS
/*
	Creator: 20160930@Bobby
	Task: Update or insert new score result for Instant Calculation.
	DB: DBPRO/bodb02
	Revisions:
		- 20160930@Bobby: #65001 - Integrate with admin site to gather score value once being confirmed.
		- 20161031@Bobby: #66484 - Allow score [0-0] to do Inst.Calc
		- 20161124@Bobby: #67760 - Implement Instant Settlement for FGLG bet types
		
	Param's Explanation:
		- @IsHTScore: [0:2H, 1:1H]
		- @GoalRecord: Store the value of match.GoalRecord at the same time

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @TypeId 	TINYINT
		, @SourceId		TINYINT
		, @RefInfo		VARCHAR(50)
		, @InstantKey	INT
		, @CreatedDate	DATETIME
		
	SELECT @TypeId 		=  CASE WHEN @IsHTScore = 1 THEN 101 
								WHEN @IsHTScore = 0 THEN 102
								ELSE 0 
							END
		, @SourceId		= 100 -- internal source type
		, @GoalRecord	= ISNULL(@GoalRecord,'')
		, @CreatedDate	= GETDATE()
	
	IF ( 
		EXISTS (
			SELECT TOP 1 1
			FROM dbo.[match] m WITH (NOLOCK)
			WHERE matchid = @MatchId
		)
		AND @TypeId IN (101, 102)
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
		
		-- SET Instant Key Information
		SET @InstantKey = SCOPE_IDENTITY()
		
		IF(@InstantKey> 0 AND @GoalRecord <> '')
		BEGIN
			SET @RefInfo = CAST(@InstantKey AS VARCHAR(20))
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
				, 103 --FGLG
				, @GoalRecord
				, @RefInfo
				, @CreatedDate
				, 0
		END
	END
	RETURN	
END
GO
GRANT EXECUTE ON [dbo].[NAP_Settlement_InstantCalculation_PushScore] TO [Dot_Admin] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Settlement_InstantCalculation_PushScore] TO [vnteam] AS [dbo]
GO