/*<info serverAlias="IRS_DBPRO-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_GetAutoPayoutSetting]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20241010@Aries.Nguyen	
	Task: In-House
	DB: IRS_DBPRO-bodb02
	
	Revisions:
		- 20241010@Aries.Nguyen: Scale out DBCUST [RedmineID: #209415]

	Example:
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @__time_start DATETIME2 = DATEADD(MILLISECOND, -@back_fix, @start);
    DECLARE @__time_end DATETIME2;
    DECLARE @__time_upperbound DATETIME2 = DATEADD(MILLISECOND, [dbo].[f_GetUpperBound_BackFix](), SYSDATETIME());

    SET LOCK_TIMEOUT 1000;
	
	
   ; WITH CTE_Timestamp ([RepUpdateTime]) AS (
        SELECT TOP (@count) [RepUpdateTime]
		FROM(
			SELECT [RepUpdateTime]
			FROM [dbo].[AutoPayoutSetting] WITH (NOLOCK, INDEX = IX_AutoPayoutSetting_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound
			UNION ALL 
			SELECT [RepUpdateTime]
			FROM [dbo].[AutoPayoutSetting_Del_InHouse] WITH (NOLOCK)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound	
		) t
		ORDER BY [RepUpdateTime]
    )
    SELECT @__time_end = ISNULL(MAX([RepUpdateTime]), @start) FROM CTE_Timestamp;
	
	SET LOCK_TIMEOUT -1;
	
	IF @__time_end > @start
    BEGIN
		;WITH CTE AS(
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
			,0 AS [isDeleted]
        FROM [dbo].[AutoPayoutSetting]  WITH (NOLOCK, INDEX = IX_AutoPayoutSetting_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
        )
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
			,0 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM CTE
		UNION ALL
		SELECT 
			[del].[Id]
			,0 AS [MatchId]
			,0 AS [AutoType]
			,0 AS [Enable]
			,0 AS [WaitingTime]
			,0 AS [Main_HasTrader]
			,0 AS [Main_NumberProvider]
			,'' AS [Main_PrimaryProvider]
			,0 AS [Main_TotalPrimaryProvider]
			,'' AS [Main_SecondaryProvider]
			,0 AS [Main_TotalSecondaryProvider]
			,'' AS [Main_InactiveProvider]
			,0 AS [EAR_HasTrader]
			,0 AS [EAR_NumberProvider]
			,'' AS [EAR_PrimaryProvider]
			,0 AS [EAR_TotalPrimaryProvider]
			,'' AS [EAR_SecondaryProvider]
			,0 AS [EAR_TotalSecondaryProvider]
			,0 AS [EAR_WaitingTime]
			,'' AS [EAR_InactiveProvider]
			,'' AS [CreatedDate]
			,MAX(RepUpdateTime) AS [RepUpdateTime]
			,1 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM [dbo].[AutoPayoutSetting_Del_InHouse] AS [del] WITH (NOLOCK)
		WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
			AND NOT EXISTS( SELECT TOP 1 1 
							FROM CTE AS [c] 
							WHERE [c].[Id] = [del].[Id]
								)
		GROUP BY [Id] 	
		ORDER BY [RepUpdateTime]	
	END
END