/*<info serverAlias="IRS_DBTP-bodb02,DBRepl-ReplDB" executers="repl_ap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_PutResultDetailOutright_Dist]
    @tvp_param TVP_ReplResultDetailOutright READONLY
AS
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBRepl-ReplDB
	
	Revisions:
		- 20250819@Hughie.Pham: Scale out DBCUST [RedmineID: #232955]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
			
    MERGE [dbo].[ResultDetailOutright] [t]
    USING @tvp_param [tvp] 
		ON [t].[Orid] = [tvp].[Orid]
		WHEN MATCHED THEN	
		UPDATE SET
			[t].[leagueid] = [tvp].[leagueid]
			,[t].[Teamid] = [tvp].[Teamid]
			,[t].[Result] = [tvp].[Result]
			,[t].[ResultStatusID] = [tvp].[ResultStatusID]
			,[t].[SettlementStatusID] = [tvp].[SettlementStatusID]
			,[t].[IsDeadHeat] = [tvp].[IsDeadHeat]
			,[t].[CreatedBy] = [tvp].[CreatedBy]
			,[t].[CreatedDate] = [tvp].[CreatedDate]
			,[t].[ModifiedBy] = [tvp].[ModifiedBy]
			,[t].[ModifiedDate] = [tvp].[ModifiedDate]
			,[t].[OtherInfo] = [tvp].[OtherInfo]
			,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END	
			,[t].[isDeleted]= [tvp].[isDeleted]
    WHEN NOT MATCHED THEN
        INSERT ([Orid]
				,[leagueid]
				,[Teamid]
				,[Result]
				,[ResultStatusID]
				,[SettlementStatusID]
				,[IsDeadHeat]
				,[CreatedBy]
				,[CreatedDate]
				,[ModifiedBy]
				,[ModifiedDate]
				,[OtherInfo]
				,[RepUpdateTime]
		   		,[isDeleted])
		VALUES ([tvp].[Orid]
				,[tvp].[leagueid]
				,[tvp].[Teamid]
				,[tvp].[Result]
				,[tvp].[ResultStatusID]
				,[tvp].[SettlementStatusID]
				,[tvp].[IsDeadHeat]
				,[tvp].[CreatedBy]
				,[tvp].[CreatedDate]
				,[tvp].[ModifiedBy]
				,[tvp].[ModifiedDate]
				,[tvp].[OtherInfo]
				,[tvp].[RepUpdateTime]
				,[tvp].[isDeleted] 
		);
		
END	