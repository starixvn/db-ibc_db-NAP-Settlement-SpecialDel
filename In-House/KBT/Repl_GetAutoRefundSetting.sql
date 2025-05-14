/*<info serverAlias="DBPRO-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_GetAutoRefundSetting]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250120@Aries: Scale out DBCUST [RedmineID: #214410]

	Example:
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @__time_start DATETIME2 = DATEADD(MILLISECOND, -@back_fix, @start);
    DECLARE @__time_end DATETIME2;
    DECLARE @__time_upperbound DATETIME2 = DATEADD(MILLISECOND, [dbo].[f_GetUpperBound_BackFix_2](), SYSDATETIME());

    SET LOCK_TIMEOUT 1000;
	
	
   ; WITH CTE_Timestamp ([RepUpdateTime]) AS (
        SELECT TOP (@count) [RepUpdateTime]
		FROM(
			SELECT [RepUpdateTime]
			FROM [dbo].[AutoRefundSetting] WITH (NOLOCK, INDEX = IX_AutoRefundSetting_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound
			UNION ALL 
			SELECT [RepUpdateTime]
			FROM [dbo].[AutoRefundSetting_Del_InHouse] WITH (NOLOCK)
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
			,[Sporttype]
			,[ResourceID]
			,[Trigger]
			,[Conditions]
			,[CreatedDate]
			,[RepUpdateTime]
			,0 AS [isDeleted]
        FROM [dbo].[AutoRefundSetting]  WITH (NOLOCK, INDEX = IX_AutoRefundSetting_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
        )
		SELECT 
			[Id]
			,[Sporttype]
			,[ResourceID]
			,[Trigger]
			,[Conditions]
			,[CreatedDate]
			,[RepUpdateTime]
			,0 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM CTE
		UNION ALL
		SELECT 
			[del].[Id]
			,0 AS [Sporttype]
			,'' AS [ResourceID]
			,'' AS [Trigger]
			,'' AS [Conditions]
			,'' AS [CreatedDate]
			,MAX(RepUpdateTime) AS [RepUpdateTime]
			,1 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM [dbo].[AutoRefundSetting_Del_InHouse] AS [del] WITH (NOLOCK)
		WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
			AND NOT EXISTS( SELECT TOP 1 1 
							FROM CTE AS [c] 
							WHERE [c].[Id] = [del].[Id]
								)
		GROUP BY [Id] 	
		ORDER BY [RepUpdateTime]	
	END
END