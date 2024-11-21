/*<info serverAlias="DBKLC1-bodb02" executers="repl_ap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[DR_Repl_GetAutoPayoutSetting_Dist]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20241010@Aries.Nguyen	
	Task: In-House
	DB: DBKLC1-bodb02
	
	Revisions:
		- 20241010@Aries.Nguyen: Created [RedmineID: #209415]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @__time_start DATETIME2 = DATEADD(MILLISECOND, -@back_fix, @start);
    DECLARE @__time_end DATETIME2;
    DECLARE @__time_upperbound DATETIME2 = DATEADD(MILLISECOND, dbo.f_GetUpperBound_BackFix(), SYSDATETIME());

    SET LOCK_TIMEOUT 1000;
	
	
   ; WITH CTE_Timestamp ([RepUpdateTime]) AS (
        SELECT TOP (@count) [RepUpdateTime]
		FROM(
			SELECT [RepUpdateTime]
			FROM [dbo].[AutoPayoutSetting] WITH (NOLOCK, INDEX = IX_AutoPayoutSetting_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound			
		) t
		ORDER BY [RepUpdateTime]
    )
    SELECT @__time_end = ISNULL(MAX([RepUpdateTime]), @start) FROM CTE_Timestamp;
	
	SET LOCK_TIMEOUT -1;
	
	IF @__time_end > @start
    BEGIN		
        SELECT 
			[Id]
			,[MatchId]
			,[AutoType]
			,[Enable]
			,[WaitingTime]
			,[Main_HasTrader]
			,[Main_NumberProvider]
			,[Main_PrimaryProvider]
			,[Main_TotalPrimaryProvider]
			,[Main_SecondaryProvider]
			,[Main_TotalSecondaryProvider]
			,[Main_InactiveProvider]
			,[EAR_HasTrader]
			,[EAR_NumberProvider]
			,[EAR_PrimaryProvider]
			,[EAR_TotalPrimaryProvider]
			,[EAR_SecondaryProvider]
			,[EAR_TotalSecondaryProvider]
			,[EAR_WaitingTime]
			,[EAR_InactiveProvider]
			,[CreatedDate]
			,[RepUpdateTime]
			,ISNULL([IsDeleted], 0) AS [IsDeleted]
			,SYSDATETIME() AS [_FetchedTime]
        FROM [dbo].[AutoPayoutSetting]  WITH (NOLOCK, INDEX = IX_AutoPayoutSetting_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
		ORDER BY [RepUpdateTime]
    END
END