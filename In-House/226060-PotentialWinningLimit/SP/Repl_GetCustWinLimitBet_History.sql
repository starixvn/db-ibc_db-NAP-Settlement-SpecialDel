/*<info serverAlias="DBSIC-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_GetCustWinLimitBet_History]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: DBSIC-bodb02
	
	Revisions:
		- 20250521@Louisa: Scale out DBCUST [RedmineID: #226060]

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
			FROM [dbo].[CustWinLimitBet_History] WITH (NOLOCK, INDEX = IX_CustWinLimitBet_History_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound
			UNION ALL 
			SELECT [RepUpdateTime]
			FROM [dbo].[CustWinLimitBet_History_Del_InHouse] WITH (NOLOCK)
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
			[ID]
			,[CustID]
			,[Sporttype]
			,[Bettype]
			,[Transid]
			,[AdjToWin]
			,[AdjWinLoss]
			,[ActionType]
			,[RepUpdateTime]
			,0 AS [isDeleted]
        FROM [dbo].[CustWinLimitBet_History]  WITH (NOLOCK, INDEX = IX_CustWinLimitBet_History_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
        )
		SELECT 
			[ID]
			,[CustID]
			,[Sporttype]
			,[Bettype]
			,[Transid]
			,[AdjToWin]
			,[AdjWinLoss]
			,[ActionType]
			,[RepUpdateTime]
			,0 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM CTE
		UNION ALL
		SELECT 
			[del].[ID]
			,0 AS [CustID]
			,0 AS [Sporttype]
			,0 AS [Bettype]
			,0 AS [Transid]
			,0 AS [AdjToWin]
			,0 AS [AdjWinLoss]
			,0 AS [ActionType]
			,MAX(RepUpdateTime) AS [RepUpdateTime]
			,1 AS [isDeleted]
			,SYSDATETIME() AS [_FetchedTime] 
		FROM [dbo].[CustWinLimitBet_History_Del_InHouse] AS [del] WITH (NOLOCK)
		WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
			AND NOT EXISTS( SELECT TOP 1 1 
							FROM CTE AS [c] 
							WHERE [c].[ID] = [del].[ID]
								)
		GROUP BY [ID] 	
		ORDER BY [RepUpdateTime]	
	END
END