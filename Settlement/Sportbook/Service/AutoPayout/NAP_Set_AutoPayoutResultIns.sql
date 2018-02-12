/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayoutResultIns
	@MatchId 		INT
	, @SourceId 	TINYINT
	, @TypeId 		TINYINT
	, @HomeValue 	VARCHAR(50)
	, @AwayValue 	VARCHAR(50)
	, @StatusId 	TINYINT
	, @InstantKey		INT = NULL
	, @ErrCode 		INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(200) = '' OUTPUT
	
AS
/*
	Creator: 20160315@Patrick
	Task: Auto payout - Insert result
	DB: DBPRO/bodb02
	Revisions:
		- 20160930@Bobby: #65003 - Implement Instant Calculation
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20180208@Benjamin: Implement to determine AutoIntant and ManualInstant [Redmine:#86964]
		
	Param's Explanation:
		@TypeId:
		    + 1: AutoPayout - 1H
		    + 2: AutoPayout - 2H
		    + 101: InstantCalculation - 1H
		    + 102: InstantCalculation - 2H
		@SourceId:
		    + 5: AutoInstant (Soccerway)
		    + 100: Suspender
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StatusIdCheck 		TINYINT
		 , @AutoPayoutResultId 	INT
		 , @InstKeyValue		VARCHAR(50)
	
	SET @InstKeyValue 			= CAST(ISNULL(@InstantKey,0) AS VARCHAR(50))
	
	SELECT TOP 1 @AutoPayoutResultId = AutoPayoutResultId
		, @StatusIdCheck = StatusId 
	FROM dbo.AutoPayoutResult WITH(NOLOCK) 
	WHERE MatchId = @MatchId 
		AND CalculationType = @TypeId
		AND SourceId = @SourceID
		AND 1 = CASE 
				WHEN @TypeId IN (1, 2) THEN 1
				WHEN @TypeId IN (101, 102) THEN 
				    CASE WHEN HomeValue = @HomeValue AND AwayValue = @AwayValue THEN 1 
				    ELSE 0 END
				ELSE 0 
			   END

	IF ( @TypeId IN (1, 2) AND @AutoPayoutResultId > 0 ) --Auto Payout
	BEGIN
		SELECT @ErrCode = 1001021, @ErrMsg = 'Failed to insert result detail (duplicate data).'
		RETURN
	END
	
	--Instant Calculation
	IF (@TypeId IN (101, 102) AND @AutoPayoutResultId > 0 
		AND (
			@StatusIdCheck IN (0,1) -- waiting|running
		)
	)
	BEGIN
		SELECT @ErrCode = 1001022, @ErrMsg = 'Sorry. This score has already existed or being in progress!'
		RETURN
	END
	
	--Instant Calculation update score
	IF (@TypeId IN (101, 102)
		AND (
			@StatusIdCheck = 3 --FAILED to re-confirm
			OR 
			@StatusIdCheck = 2 --abnormal N-case to re-calculate
		)	
	)	
	BEGIN
		UPDATE dbo.AutoPayoutResult WITH(ROWLOCK,UPDLOCK)
		SET StatusId = @StatusId
		WHERE AutoPayoutResultId = @AutoPayoutResultId
	END
	ELSE
	BEGIN
		INSERT INTO dbo.AutoPayoutResult (MatchId, SourceId, CalculationType, HomeValue, AwayValue, StatusId, TryCount, CreatedDate, ModifiedDate)
		VALUES(@MatchId, @SourceId, @TypeId, @HomeValue, @AwayValue, @StatusId, 0, GETDATE(), GETDATE())
	END
	
	IF (@TypeId IN (101, 102) )
	BEGIN
		UPDATE rs
		SET IsConfirmed = 1
		FROM dbo.ProviderResultDetail rs WITH(ROWLOCK,UPDLOCK)
		WHERE rs.ProviderResultDetailId = @InstantKey
			OR (
				MatchId 		= @MatchId 
				AND AwayValue 	= @InstKeyValue
			)
	END
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 1001022, @ErrMsg = 'Failed to insert result detail.'
		RETURN
	END
END
GO