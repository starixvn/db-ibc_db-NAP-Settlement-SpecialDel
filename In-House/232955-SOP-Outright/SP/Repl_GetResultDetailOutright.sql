/*<info serverAlias="DBPRO-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_GetResultDetailOutright]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250819@Hughie.Pham: Scale out DBCUST [RedmineID: #232955]
		- 20250925@Hughie: Apply SOP for Outright phase 2 [Redmine:#233004]

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
			FROM [dbo].[ResultDetailOutright] WITH (NOLOCK, INDEX = IX_ResultDetailOutright_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound
			UNION ALL 
			SELECT [RepUpdateTime]
			FROM [dbo].[ResultDetailOutright_Del_InHouse] WITH (NOLOCK)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound	
		) t
		ORDER BY [RepUpdateTime] ASC
    )
    SELECT @__time_end = ISNULL(MAX([RepUpdateTime]), @start) FROM CTE_Timestamp;
	
	SET LOCK_TIMEOUT -1;
	
	IF @__time_end > @start
    BEGIN
		;WITH CTE AS(
        SELECT 
			[Orid]
			,[leagueid]
			,[Teamid]
			,[Result]
			,[ResultStatusID]
			,[SettlementStatusID]
			,[IsDeadHeat]
			,[SumWon]
			,[CreatedBy]
			,[CreatedDate]
			,[ModifiedBy]
			,[ModifiedDate]
			,[SettledBy]
			,[OtherInfo]
			,[RepUpdateTime]
			,0 AS [isDeleted]
        FROM [dbo].[ResultDetailOutright]  WITH (NOLOCK, INDEX = IX_ResultDetailOutright_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
        )
		SELECT 
			[Orid]
			,[leagueid]
			,[Teamid]
			,[Result]
			,[ResultStatusID]
			,[SettlementStatusID]
			,[IsDeadHeat]
			,[SumWon]
			,[CreatedBy]
			,[CreatedDate]
			,[ModifiedBy]
			,[ModifiedDate]
			,[SettledBy]
			,[OtherInfo]
			,[RepUpdateTime]
			,0 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM CTE
		UNION ALL
		SELECT 
			[del].[Orid]
			,0 AS [leagueid]
			,0 AS [Teamid]
			,'' AS [Result]
			,0 AS [ResultStatusID]
			,0 AS [SettlementStatusID]
			,0 AS [IsDeadHeat]
			,0 AS [SumWon]
			,0 AS [CreatedBy]
			,'' AS [CreatedDate]
			,0 AS [ModifiedBy]
			,'' AS [ModifiedDate]
			,0 AS [SettledBy]
			,'' AS [OtherInfo]
			,MAX(RepUpdateTime) AS [RepUpdateTime]
			,1 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM [dbo].[ResultDetailOutright_Del_InHouse] AS [del] WITH (NOLOCK)
		WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
			AND NOT EXISTS( SELECT TOP 1 1 
							FROM CTE AS [c] 
							WHERE [c].[Orid] = [del].[Orid]
								)
		GROUP BY [Orid] 	
		ORDER BY [RepUpdateTime] ASC
	END
END