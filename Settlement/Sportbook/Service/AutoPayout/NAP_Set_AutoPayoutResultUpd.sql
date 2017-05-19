/********This is SIT environment*******/
USE bodb02
GO

ALTER PROCEDURE dbo.NAP_Set_AutoPayoutResultUpd 
	@MatchId 					INT
	, @TypeId 					TINYINT
	, @StatusId 				TINYINT
	, @IsIncludedUpdateMatch 	BIT = 0
AS
/*
	Creator: 20160310@Patrick
	Task: Update status of auto payout result
	DB: DBPRO/bodb02
	Revisions:
		- 20160930@Bobby: #65003 - Implement Instant Calculation
		
	Param's Explanation:
		- @StatusId: 0: New
					 1: Waiting
					 2: Completed
					 3: Failed
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @AutoSetting 		TINYINT	
		, @AutoSettingLeague	TINYINT
		, @AutoPayoutResultId	INT
	
	IF(@TypeId IN (101, 102)) --Instant Calculation
	BEGIN
		SELECT @AutoPayoutResultId = MAX(AutoPayoutResultId)
		FROM dbo.AutoPayoutResult rs WITH(NOLOCK)
		WHERE MatchId 			= @MatchId 
			AND CalculationType = @TypeId
			AND StatusId		IN (0, 1) --is waiting/calculating
			
		UPDATE TOP(1) rs
		SET StatusId 				= @StatusId 
			, ModifiedDate 			= GETDATE()
		FROM dbo.AutoPayoutResult rs WITH(ROWLOCK, UPDLOCK)
		WHERE AutoPayoutResultId	= @AutoPayoutResultId
	END
	ELSE --Auto Payout
	BEGIN
		UPDATE dbo.AutoPayoutResult WITH(ROWLOCK, UPDLOCK)
		SET StatusId = @StatusId 
			, ModifiedDate = GETDATE()
		WHERE MatchId = @MatchId 
			AND CalculationType = @TypeId
			AND StatusId <> @StatusId
	END
	
	IF (@IsIncludedUpdateMatch = 1)
	BEGIN
		SELECT TOP 1 
			@AutoSetting 			= m.AutoSetting
			, @AutoSettingLeague	= l.AutoSetting
		FROM dbo.match m WITH(NOLOCK) 
			INNER JOIN dbo.league l WITH(NOLOCK) 
			ON m.leagueid = l.leagueid
			
		WHERE matchid 	= @MatchId 
		
		IF (@AutoSetting IS NULL AND @AutoSettingLeague IS NOT NULL)
		BEGIN
			UPDATE dbo.match WITH(UPDLOCK, ROWLOCK)
			SET AutoSetting =  @AutoSettingLeague
			WHERE matchid = @MatchId
		END
	END
END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_AutoPayoutResultUpd] TO [bodbAdminNet] AS [dbo]
GO