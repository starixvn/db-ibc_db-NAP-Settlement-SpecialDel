/*<info serverAlias="IRS_DBTP-bodb02,DBCustRepl-ReplDB" executers="repl_ap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_GetCustWinLimitBet_History_Dist]
    @start DATETIME2,
    @count INT,
    @back_fix INT = 0
AS
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBCustRepl-ReplCustDB
	
	Revisions:
		- 20250521@Louisa: Scale out DBCUST [RedmineID: #226060]

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
			FROM [dbo].[CustWinLimitBet_History] WITH (NOLOCK, INDEX = IDX_CustWinLimitBet_History_RepUpdateTime)
			WHERE [RepUpdateTime] > @start AND [RepUpdateTime] < @__time_upperbound			
		) t
		ORDER BY [RepUpdateTime]
    )
    SELECT @__time_end = ISNULL(MAX([RepUpdateTime]), @start) FROM CTE_Timestamp;
	
	SET LOCK_TIMEOUT -1;
	
	IF @__time_end > @start
    BEGIN		
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
			,ISNULL([isDeleted],0) AS [IsDeleted]
			,SYSDATETIME() AS [_FetchedTime]
        FROM [dbo].[CustWinLimitBet_History]  WITH (NOLOCK, INDEX = IDX_CustWinLimitBet_History_RepUpdateTime)
        WHERE [RepUpdateTime] > @__time_start AND [RepUpdateTime] <= @__time_end
		ORDER BY [RepUpdateTime]
    END
END