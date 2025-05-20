/*<info serverAlias="DBKLC1-bodb02" executers="repl_ap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[DR_Repl_GetCustWinLimitBet_Dist]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20250509@Louisa	
	Task: In-House
	DB: DBKLC1-bodb02
	
	Revisions:
		- 20250509@Louisa: Created [RedmineID: #226060]

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
			FROM [dbo].[CustWinLimitBet] WITH (NOLOCK, INDEX = IX_CustWinLimitBet_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound			
		) t
		ORDER BY [RepUpdateTime]
    )
    SELECT @__time_end = ISNULL(MAX([RepUpdateTime]), @start) FROM CTE_Timestamp;
	
	SET LOCK_TIMEOUT -1;
	
	IF @__time_end > @start
    BEGIN		
        SELECT 
			[CustID]
			,[Sporttype]
			,[Bettype]
			,[AccumToWin]
			,[AccumWinLoss]
			,[CreatedDate]
			,[RepUpdateTime]
			,ISNULL([IsDeleted], 0) AS [IsDeleted]
			,SYSDATETIME() AS [_FetchedTime]
        FROM [dbo].[CustWinLimitBet]  WITH (NOLOCK, INDEX = IX_CustWinLimitBet_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
		ORDER BY [RepUpdateTime]
    END
END