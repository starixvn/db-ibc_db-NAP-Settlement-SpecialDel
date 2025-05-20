/*<info serverAlias="DBSIC-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[DR_Repl_PutCustWinLimitBet_Dist]
    @tvp_param TVP_ReplCustWinLimitBet READONLY
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
			
	INSERT INTO [dbo].[CustWinLimitBet_Del_InHouse]([CustID], [Sporttype], [Bettype], [RepUpdateTime])
	SELECT [CustID], [Sporttype], [Bettype], [RepUpdateTime]
	FROM (
		MERGE [dbo].[CustWinLimitBet] [t]
		USING @tvp_param [tvp] ON [t].[CustID] = [tvp].[CustID] AND [t].[Sporttype] = [tvp].[Sporttype] AND [t].[Bettype] = [tvp].[Bettype] 
		WHEN MATCHED AND [tvp].[isDeleted] = 0 THEN	
			UPDATE SET 
			    [t].[AccumToWin] = [tvp].[AccumToWin]
				,[t].[AccumWinLoss] = [tvp].[AccumWinLoss]
				,[t].[CreatedDate] = [tvp].[CreatedDate]
				,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END
		WHEN MATCHED AND [tvp].isDeleted = 1 THEN
			DELETE
		WHEN NOT MATCHED AND [tvp].[isDeleted] = 0 THEN
			INSERT ([CustID]
				,[Sporttype]
				,[Bettype]
				,[AccumToWin]
				,[AccumWinLoss]
				,[CreatedDate]
				,[RepUpdateTime])
			VALUES ([tvp].[CustID]
				,[tvp].[Sporttype]
				,[tvp].[Bettype]
				,[tvp].[AccumToWin]
				,[tvp].[AccumWinLoss]
				,[tvp].[CreatedDate]
				,[tvp].[RepUpdateTime])
		OUTPUT $action, [deleted].[CustID], [deleted].[Sporttype], [deleted].[Bettype], [tvp].[RepUpdateTime]
	) AS __deleting([Action], [CustID], [Sporttype], [Bettype], [RepUpdateTime])
	WHERE [Action] = 'DELETE'; --only capture deleted $action
		
END	
GO