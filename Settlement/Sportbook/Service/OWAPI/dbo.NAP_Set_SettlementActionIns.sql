/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SettlementActionIns
	@MatchId		INT
	,@LeagueId		INT
	,@ActionType	TINYINT
	,@HTHomeScore 	INT 			= NULL
	,@HTAwayScore 	INT 			= NULL
	,@FTHomeScore 	INT 			= NULL
	,@FTAwayScore 	INT 			= NULL
	,@OtherInfo		VARCHAR(8000)	= NULL
	,@IsAutoPayout	BIT				= 0
	
	,@ErrCode		INT 			= 0		OUTPUT
	,@ErrMsg		VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created: 20170809@Kathy
	DB: DBPRO/bodb02
	Task: Insert result into Intg_OddsFeed_SettlementAction to log Settlement Action [Redmine:#80704]
	
	Revisions:
		-20170809@Kathy: Create new SP [Redmine:#80704]

	Param's Explanation:
		* @OtherInfo: <Results>
						<Resource Id="08" Value="HAHA">
					  <Results>
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @maxTstamp TIMESTAMP
	
	SELECT	@maxTstamp = MAX(TStamp)
	FROM	dbo.Intg_OddsFeed_SettlementAction WITH (NOLOCK)
	WHERE	MatchId = @MatchId
	
	IF EXISTS (SELECT TOP 1 1
				FROM	dbo.Intg_OddsFeed_SettlementAction WITH (ROWLOCK)
				WHERE	matchId = @Matchid
						AND ActionType = @ActionType
						AND 1 = CASE 
									WHEN HTHomeScore IS NULL AND @HTHomeScore IS NULL THEN 1
									WHEN HTHomeScore = @HTHomeScore THEN 1
									ELSE 0
								END
						AND 1 = CASE 
									WHEN HTAwayScore IS NULL AND @HTAwayScore IS NULL THEN 1
									WHEN HTAwayScore = @HTAwayScore THEN 1
									ELSE 0
								END
						AND 1 = CASE 
									WHEN FTHomeScore IS NULL AND @FTHomeScore IS NULL THEN 1
									WHEN FTHomeScore = @FTHomeScore THEN 1
									ELSE 0
								END
						AND 1 = CASE 
									WHEN FTAwayScore IS NULL AND @FTAwayScore IS NULL THEN 1
									WHEN FTAwayScore = @FTAwayScore THEN 1
									ELSE 0
								END
						AND TStamp = @maxTstamp
						AND OtherInfo = @OtherInfo
					)
	BEGIN
		SELECT @ErrCode = 100
				,@ErrMsg = 'The new action is not inserted due to duplicating with previous record.'
		RETURN
	END				
	
	IF @IsAutoPayout = 1 AND @ActionType = 3
		SELECT 	@HTHomeScore = hthomescore
				,@HTAwayScore = htawayscore
		FROM	dbo.match WITH(ROWLOCK)
		WHERE	matchId = @MatchId
	
	BEGIN TRY
		INSERT INTO dbo.Intg_OddsFeed_SettlementAction(LeagueId, MatchId, ActionType, HTHomeScore, HTAwayScore, FTHomeScore, FTAwayScore, CreateTime, OtherInfo)
			VALUES (@LeagueId, @MatchId, @ActionType, @HTHomeScore, @HTAwayScore, @FTHomeScore, @FTAwayScore, GETDATE(), @OtherInfo)
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH
END
GO