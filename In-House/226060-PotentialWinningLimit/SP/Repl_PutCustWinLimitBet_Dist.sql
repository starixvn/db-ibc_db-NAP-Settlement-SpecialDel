/*<info serverAlias="IRS_DBTP-bodb02,DBCustRepl-ReplDB" executers="repl_ap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_PutCustWinLimitBet_Dist]
    @tvp_param TVP_ReplCustWinLimitBet READONLY
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
			
    MERGE [dbo].[CustWinLimitBet] [t]
    USING @tvp_param [tvp] 
		ON [t].[CustID] = [tvp].[CustID]
		AND [t].[Sporttype] = [tvp].[Sporttype]
		AND [t].[Bettype] = [tvp].[Bettype]
		WHEN MATCHED THEN	
		UPDATE SET
			[t].[AccumToWin] = [tvp].[AccumToWin]
			,[t].[AccumWinLoss] = [tvp].[AccumWinLoss]
			,[t].[CreatedDate] = [tvp].[CreatedDate]
			,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END	
			,[t].[isDeleted]= [tvp].[isDeleted]
    WHEN NOT MATCHED THEN
        INSERT ([CustID]
				,[Sporttype]
				,[Bettype]
				,[AccumToWin]
				,[AccumWinLoss]
				,[CreatedDate]
				,[RepUpdateTime]
		   		,[isDeleted])
		VALUES ([tvp].[CustID]
				,[tvp].[Sporttype]
				,[tvp].[Bettype]
				,[tvp].[AccumToWin]
				,[tvp].[AccumWinLoss]
				,[tvp].[CreatedDate]
				,[tvp].[RepUpdateTime]
				,[tvp].[isDeleted] 
		);
		
END	