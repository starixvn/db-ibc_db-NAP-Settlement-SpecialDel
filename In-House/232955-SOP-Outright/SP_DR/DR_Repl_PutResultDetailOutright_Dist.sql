/*<info serverAlias="DBPRO-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[DR_Repl_PutResultDetailOutright_Dist]
    @tvp_param TVP_ReplResultDetailOutright READONLY
AS
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
			
	INSERT INTO [dbo].[ResultDetailOutright_Del_InHouse]([Orid], [RepUpdateTime])
	SELECT [Orid], [RepUpdateTime]
	FROM (
		MERGE [dbo].[ResultDetailOutright] [t]
		USING @tvp_param [tvp] ON [t].[Orid] = [tvp].[Orid] 
		WHEN MATCHED AND [tvp].[isDeleted] = 0 THEN	
			UPDATE SET 
			    [t].[leagueid] = [tvp].[leagueid]
				,[t].[Teamid] = [tvp].[Teamid]
				,[t].[Result] = [tvp].[Result]
				,[t].[ResultStatusID] = [tvp].[ResultStatusID]
				,[t].[SettlementStatusID] = [tvp].[SettlementStatusID]
				,[t].[IsDeadHeat] = [tvp].[IsDeadHeat]
				,[t].[SumWon] = [tvp].[SumWon]
				,[t].[CreatedBy] = [tvp].[CreatedBy]
				,[t].[CreatedDate] = [tvp].[CreatedDate]
				,[t].[ModifiedBy] = [tvp].[ModifiedBy]
				,[t].[ModifiedDate] = [tvp].[ModifiedDate]
				,[t].[OtherInfo] = [tvp].[OtherInfo]
				,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END
		WHEN MATCHED AND [tvp].isDeleted = 1 THEN
			DELETE
		WHEN NOT MATCHED AND [tvp].[isDeleted] = 0 THEN
			INSERT ([Orid]
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
				,[OtherInfo]
				,[RepUpdateTime])
			VALUES ([tvp].[Orid]
				,[tvp].[leagueid]
				,[tvp].[Teamid]
				,[tvp].[Result]
				,[tvp].[ResultStatusID]
				,[tvp].[SettlementStatusID]
				,[tvp].[IsDeadHeat]
				,[tvp].[SumWon]
				,[tvp].[CreatedBy]
				,[tvp].[CreatedDate]
				,[tvp].[ModifiedBy]
				,[tvp].[ModifiedDate]
				,[tvp].[OtherInfo]
				,[tvp].[RepUpdateTime])
		OUTPUT $action, [deleted].[Orid], [tvp].[RepUpdateTime]
	) AS __deleting([Action], [Orid], [RepUpdateTime])
	WHERE [Action] = 'DELETE'; --only capture deleted $action
		
END	
GO