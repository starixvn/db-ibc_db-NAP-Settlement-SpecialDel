/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_InstantCalculation_UndoChecking]
	@MatchId			INT
	, @InstantCheck		INT = NULL
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			VARCHAR(250) = '' OUTPUT
AS
/*
	Creator: 20161201@Bobby
	Task: #68128 - Implement Uncalculate instant settlement process
	DB: DBPRO/bodb02
	Revisions:
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20180528@Benjamin: Add "SourceID = 100" to filter correct score from Suspender[Redmine:#86964]
		
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @evenstatus		VARCHAR(30)
		,@homeScore			VARCHAR(30)
		,@awayScore			VARCHAR(30)
		,@InstantKey		INT
		,@goalRecord		VARCHAR(30)
		,@isHT				BIT
		,@livehomescore		INT
		,@liveawayscore		INT
		,@hScore			INT
		,@aScore			INT
		,@FirstGoalValue	VARCHAR(1)
		,@betstatus			NVARCHAR(50)
		
	
	SELECT @ErrCode			= 0
		, @ErrMsg			= ''
		
	SELECT TOP(1)
		@evenstatus 			= m.eventstatus
		, @livehomescore		= m.livehomescore
		, @liveawayscore		= m.liveawayscore
		, @betstatus			= m.betstatus
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @MatchId
		--AND m.evenstatus = 'running'
		AND EXISTS (
			SELECT TOP 1 1 
			FROM dbo.AutoPayoutResult rs WITH(NOLOCK)
			WHERE rs.matchid = m.matchid
			AND rs.CalculationType BETWEEN 101 AND 103
			AND rs.StatusId = 2 -- completed
			
		)
	IF(@evenstatus IS NULL)
	BEGIN
		SELECT @ErrCode		= 1001001
			, @ErrMsg		= 'Instant calculation has not been executed on the match.'
		
	END
	
	IF(@ErrCode = 0 AND @evenstatus = 'completed' OR @evenstatus <> 'running')
	BEGIN
		SELECT @ErrCode		= 1001002
			, @ErrMsg		= 'Instant Settlement cannot be uncalculated because the match has already been completed' 
							+ CASE WHEN @evenstatus <> 'completed' THEN ' or not being running match.' ELSE '.' END
		
	END
	
	-- OUTPUT the currenct scores and GoalRecord
	IF(@ErrCode = 0)
	BEGIN
		
		SELECT TOP(1)
			@homeScore 		= rs.HomeValue
			,@awayScore 	= rs.AwayValue
			,@goalRecord 	= ISNULL(fgng.GoalRecord, '')
			,@IsHT  		= CASE WHEN rs.TypeId = 101 THEN 1 ELSE 0 END
			,@InstantKey	= rs.ProviderResultDetailId
			
		FROM dbo.ProviderResultDetail rs WITH(NOLOCK)
			OUTER APPLY (
				SELECT HomeValue AS GoalRecord
				FROM dbo.ProviderResultDetail gr WITH(NOLOCK)
				WHERE gr.matchid 	= @MatchId
					AND TypeId 		= 103 --FGNG
					AND AwayValue 	= CAST(rs.ProviderResultDetailId AS VARCHAR(30))
			) AS fgng
		WHERE rs.matchid = @MatchId
			AND rs.TypeId BETWEEN 101 AND 102 
			AND rs.SourceID = 100 --#86964
			AND rs.ProviderResultDetailId = ISNULL(@InstantCheck, rs.ProviderResultDetailId)
			
		ORDER  BY rs.ProviderResultDetailId DESC
	
		--double checking with latest scores
		;WITH PRD_LatestScore AS (
			SELECT TOP(1)
				rs.HomeValue
				, rs.AwayValue
			FROM dbo.ProviderResultDetail rs WITH(NOLOCK)
			WHERE rs.matchid = @MatchId
				AND rs.TypeId BETWEEN 101 AND 102
				AND rs.SourceID = 100 --#86964
			ORDER BY ProviderResultDetailId DESC
		)
		SELECT @ErrCode		= 1001003
			, @ErrMsg		= 'The current score has just been updated. Please double check the score and try again!' 
		FROM PRD_LatestScore
		WHERE HomeValue 	<> @homeScore
			OR AwayValue 	<> @awayScore
						
		
		IF( @ErrCode = 0 AND @InstantCheck > 0 )
		BEGIN
			SELECT @hScore		= CAST(@homeScore AS INT)
				, @aScore		= CAST(@awayScore AS INT)
			
			IF (
				@hScore 		<> @livehomescore
				OR @aScore 		<> @liveawayscore
			)
			BEGIN
				SELECT @ErrCode		= 1001004
					, @ErrMsg		= 'Instant Settlement cannot be uncalculated due to an error of synchronizing.' 
				
			END
		END
	END
	
	IF @ErrCode = 0
	BEGIN
		SELECT 	@FirstGoalValue = HomeValue
		FROM	dbo.ResultDetail WITH (NOLOCK)
		WHERE	matchid = @MatchId
				AND	1 = CASE 
							WHEN @IsHT = 1 AND ResourceId = '127F' THEN 1
							WHEN @IsHT = 1 AND ResourceId = '14F' THEN 1
							WHEN @IsHT = 0 AND ResourceId = '14F' THEN 1
							ELSE 0
						END
	END
			
	SELECT @homeScore 	AS HomeScore
		,@awayScore 	AS AwayScore
		,@goalRecord 	AS GoalRecord
		,@IsHT  		AS IsHT
		,@InstantKey	AS InstantKey
		,ISNULL(@FirstGoalValue,'') AS FirstGoalValue
		,@betstatus		AS betstatus
	RETURN
END
GO