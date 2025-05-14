/*<info serverAlias="DBPRO-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[DR_Repl_PutAutoRefundSetting_Dist]
    @tvp_param TVP_ReplAutoRefundSetting READONLY
AS
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250120@Aries: Created [RedmineID: #214410]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
	
	SET IDENTITY_INSERT [dbo].[AutoRefundSetting] ON;
			
	INSERT INTO [dbo].[AutoRefundSetting_Del_InHouse]([Id], [RepUpdateTime])
	SELECT [Id], [RepUpdateTime]
	FROM (
		MERGE [dbo].[AutoRefundSetting] [t]
		USING @tvp_param [tvp] ON [t].[Id] = [tvp].[Id] 
		WHEN MATCHED AND [tvp].[isDeleted] = 0 THEN	
			UPDATE SET 
			    [t].[Sporttype] = [tvp].[Sporttype]
				,[t].[ResourceID] = [tvp].[ResourceID]
				,[t].[Trigger] = [tvp].[Trigger]
				,[t].[Conditions] = [tvp].[Conditions]
				,[t].[CreatedDate] = [tvp].[CreatedDate]
				,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END
		WHEN MATCHED AND [tvp].isDeleted = 1 THEN
			DELETE
		WHEN NOT MATCHED AND [tvp].[isDeleted] = 0 THEN
			INSERT ([Id]
				,[Sporttype]
				,[ResourceID]
				,[Trigger]
				,[Conditions]
				,[CreatedDate]
				,[RepUpdateTime])
			VALUES ([tvp].[Id]
				,[tvp].[Sporttype]
				,[tvp].[ResourceID]
				,[tvp].[Trigger]
				,[tvp].[Conditions]
				,[tvp].[CreatedDate]
				,[tvp].[RepUpdateTime])
		OUTPUT $action, [deleted].[Id], [tvp].[RepUpdateTime]
	) AS __deleting([Action], [Id], [RepUpdateTime])
	WHERE [Action] = 'DELETE'; --only capture deleted $action
	
	SET IDENTITY_INSERT [dbo].[AutoRefundSetting] OFF;	
END	
GO