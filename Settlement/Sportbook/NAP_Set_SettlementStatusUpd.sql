/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_SettlementStatusUpd]
	@MatchId	INT
	,@Type		TINYINT
	,@IsEnabled BIT
	,@AdminId	INT

AS
/*
	Created: Kathy
	Date: 20180926
	Task : Update settlement status
	DB: DBPRO/bodb02

	Revisions:
		- 20180926@Kathy: Add New Status "Result Pending" and "Under Settlement"  [Redmine:#102028]
		
	Parameters Explanation:    
		@Type: TINYINT
			+ 1: IsPending
			+ 2: IsUndecided
			+ 3: IsUnderSettlement	
	
*/
BEGIN
	SET NOCOUNT ON 

	--write log
	DECLARE @LogData NVARCHAR(200)
	DECLARE @SettlementStatus TINYINT

	UPDATE	mr 
		SET @SettlementStatus = ISNULL(SettlementStatus, 0)
			,SettlementStatus = CASE 
									WHEN @IsEnabled = 1 THEN @SettlementStatus | POWER(2, @Type - 1)
									ELSE @SettlementStatus & (~POWER(2, @Type - 1))
								END
			,isPending = CASE WHEN @Type = 1 THEN @IsEnabled ELSE mr.isPending END
			,isUndecided = CASE WHEN @Type = 2 THEN @IsEnabled ELSE mr.isUndecided END
	FROM	dbo.match_remark mr
	WHERE	mr.matchid = @MatchId
			
	SELECT @LogData = 'Update settlement status of MatchID = ' + CAST(@MatchId AS VARCHAR(20)) + ' with Type = ' + CAST(@Type AS VARCHAR(2))

	EXEC WriteLog_UserLog @UserID = @AdminId, @Doing = @LogData
END
GO
