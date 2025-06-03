/*<info serverAlias="IRS_DBBAH-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_PutCustWinLimitBet_History]
    @tvp_param TVP_ReplCustWinLimitBet_History READONLY
AS
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: IRS_DBBAH-bodb02
	
	Revisions:
		- 20250521@Louisa: Scale out DBCUST [RedmineID: #226060]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
	
	SET IDENTITY_INSERT [dbo].[CustWinLimitBet_History] ON;
		
    MERGE [dbo].[CustWinLimitBet_History] [t]
    USING @tvp_param [tvp] 
		ON [t].[ID] = [tvp].[ID]
		WHEN MATCHED THEN	
		UPDATE SET
			[t].[CustID] = [tvp].[CustID]
			,[t].[Sporttype] = [tvp].[Sporttype]
			,[t].[Bettype] = [tvp].[Bettype]
			,[t].[Transid] = [tvp].[Transid]
			,[t].[AdjToWin] = [tvp].[AdjToWin]
			,[t].[AdjWinLoss] = [tvp].[AdjWinLoss]
			,[t].[ActionType] = [tvp].[ActionType]
			,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END
    WHEN NOT MATCHED THEN
        INSERT ([ID]
				,[CustID]
				,[Sporttype]
				,[Bettype]
				,[Transid]
				,[AdjToWin]
				,[AdjWinLoss]
				,[ActionType]
				,[RepUpdateTime])
		VALUES ([tvp].[ID]
				,[tvp].[CustID]
				,[tvp].[Sporttype]
				,[tvp].[Bettype]
				,[tvp].[Transid]
				,[tvp].[AdjToWin]
				,[tvp].[AdjWinLoss]
				,[tvp].[ActionType]
				,[tvp].[RepUpdateTime]
		);
	
	SET IDENTITY_INSERT [dbo].[CustWinLimitBet_History] OFF;	
END	