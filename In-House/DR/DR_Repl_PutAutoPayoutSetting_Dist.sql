/*<info serverAlias="IRS_DBPRO-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[DR_Repl_PutAutoPayoutSetting_Dist]
    @tvp_param TVP_ReplAutoPayoutSetting READONLY
AS
/*
	Created: 20241010@Aries.Nguyen	
	Task: In-House
	DB: IRS_DBPRO-bodb02
	
	Revisions:
		- 20241010@Aries.Nguyen: Created [RedmineID: #209415]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
	
	SET IDENTITY_INSERT [dbo].[AutoPayoutSetting] ON;
			
	INSERT INTO [dbo].[AutoPayoutSetting_Del_InHouse]([Id], [RepUpdateTime])
	SELECT [Id], [RepUpdateTime]
	FROM (
		MERGE [dbo].[AutoPayoutSetting] [t]
		USING @tvp_param [tvp] ON [t].[Id] = [tvp].[Id] 
		WHEN MATCHED AND [tvp].[isDeleted] = 0 THEN	
			UPDATE SET 
			    [t].[MatchId] = [tvp].[MatchId]
				,[t].[AutoType] = [tvp].[AutoType]
				,[t].[Enable] = [tvp].[Enable]
				,[t].[WaitingTime] = [tvp].[WaitingTime]
				,[t].[Main_HasTrader] = [tvp].[Main_HasTrader]
				,[t].[Main_NumberProvider] = [tvp].[Main_NumberProvider]
				,[t].[Main_PrimaryProvider] = [tvp].[Main_PrimaryProvider]
				,[t].[Main_TotalPrimaryProvider] = [tvp].[Main_TotalPrimaryProvider]
				,[t].[Main_SecondaryProvider] = [tvp].[Main_SecondaryProvider]
				,[t].[Main_TotalSecondaryProvider] = [tvp].[Main_TotalSecondaryProvider]
				,[t].[Main_InactiveProvider] = [tvp].[Main_InactiveProvider]
				,[t].[EAR_HasTrader] = [tvp].[EAR_HasTrader]
				,[t].[EAR_NumberProvider] = [tvp].[EAR_NumberProvider]
				,[t].[EAR_PrimaryProvider] = [tvp].[EAR_PrimaryProvider]
				,[t].[EAR_TotalPrimaryProvider] = [tvp].[EAR_TotalPrimaryProvider]
				,[t].[EAR_SecondaryProvider] = [tvp].[EAR_SecondaryProvider]
				,[t].[EAR_TotalSecondaryProvider] = [tvp].[EAR_TotalSecondaryProvider]
				,[t].[EAR_WaitingTime] = [tvp].[EAR_WaitingTime]
				,[t].[EAR_InactiveProvider] = [tvp].[EAR_InactiveProvider]
				,[t].[CreatedDate] = [tvp].[CreatedDate]
				,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END
		WHEN MATCHED AND [tvp].isDeleted = 1 THEN
			DELETE
		WHEN NOT MATCHED AND [tvp].[isDeleted] = 0 THEN
			INSERT ([Id]
				,[MatchId]
				,[AutoType]
				,[Enable]
				,[WaitingTime]
				,[Main_HasTrader]
				,[Main_NumberProvider]
				,[Main_PrimaryProvider]
				,[Main_TotalPrimaryProvider]
				,[Main_SecondaryProvider]
				,[Main_TotalSecondaryProvider]
				,[Main_InactiveProvider]
				,[EAR_HasTrader]
				,[EAR_NumberProvider]
				,[EAR_PrimaryProvider]
				,[EAR_TotalPrimaryProvider]
				,[EAR_SecondaryProvider]
				,[EAR_TotalSecondaryProvider]
				,[EAR_WaitingTime]
				,[EAR_InactiveProvider]
				,[CreatedDate]
				,[RepUpdateTime])
			VALUES ([tvp].[Id]
				,[tvp].[MatchId]
				,[tvp].[AutoType]
				,[tvp].[Enable]
				,[tvp].[WaitingTime]
				,[tvp].[Main_HasTrader]
				,[tvp].[Main_NumberProvider]
				,[tvp].[Main_PrimaryProvider]
				,[tvp].[Main_TotalPrimaryProvider]
				,[tvp].[Main_SecondaryProvider]
				,[tvp].[Main_TotalSecondaryProvider]
				,[tvp].[Main_InactiveProvider]
				,[tvp].[EAR_HasTrader]
				,[tvp].[EAR_NumberProvider]
				,[tvp].[EAR_PrimaryProvider]
				,[tvp].[EAR_TotalPrimaryProvider]
				,[tvp].[EAR_SecondaryProvider]
				,[tvp].[EAR_TotalSecondaryProvider]
				,[tvp].[EAR_WaitingTime]
				,[tvp].[EAR_InactiveProvider]
				,[tvp].[CreatedDate]
				,[tvp].[RepUpdateTime])
		OUTPUT $action, [deleted].[Id], [tvp].[RepUpdateTime]
	) AS __deleting([Action], [Id], [RepUpdateTime])
	WHERE [Action] = 'DELETE'; --only capture deleted $action
	
	SET IDENTITY_INSERT [dbo].[AutoPayoutSetting] OFF;	
END	
GO