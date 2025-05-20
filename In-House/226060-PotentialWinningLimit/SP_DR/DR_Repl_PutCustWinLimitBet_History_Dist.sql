/*<info serverAlias="DBSIC-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[DR_Repl_PutCustWinLimitBet_History_Dist]
    @tvp_param TVP_ReplCustWinLimitBet_History READONLY
AS
/*
	Created: 20250509@Louisa	
	Task: In-House
	DB: DBSIC-bodb02
	
	Revisions:
		- 20250509@Louisa: Created [RedmineID: #226060]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
	
	SET IDENTITY_INSERT [dbo].[CustWinLimitBet_History] ON;
			
	INSERT INTO [dbo].[CustWinLimitBet_History_Del_InHouse]([ID], [RepUpdateTime])
	SELECT [ID], [RepUpdateTime]
	FROM (
		MERGE [dbo].[CustWinLimitBet_History] [t]
		USING @tvp_param [tvp] ON [t].[ID] = [tvp].[ID] 
		WHEN MATCHED AND [tvp].[isDeleted] = 0 THEN	
			UPDATE SET 
			    [t].[CustID] = [tvp].[CustID]
				,[t].[Sporttype] = [tvp].[Sporttype]
				,[t].[Bettype] = [tvp].[Bettype]
				,[t].[Transid] = [tvp].[Transid]
				,[t].[AdjToWin] = [tvp].[AdjToWin]
				,[t].[AdjWinLoss] = [tvp].[AdjWinLoss]
				,[t].[ActionType] = [tvp].[ActionType]
				,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END
		WHEN MATCHED AND [tvp].isDeleted = 1 THEN
			DELETE
		WHEN NOT MATCHED AND [tvp].[isDeleted] = 0 THEN
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
				,[tvp].[RepUpdateTime])
		OUTPUT $action, [deleted].[ID], [tvp].[RepUpdateTime]
	) AS __deleting([Action], [ID], [RepUpdateTime])
	WHERE [Action] = 'DELETE'; --only capture deleted $action
	
	SET IDENTITY_INSERT [dbo].[CustWinLimitBet_History] OFF;	
END	
GO