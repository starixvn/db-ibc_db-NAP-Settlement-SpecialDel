/*<info serverAlias="IRS_DBTP-bodb02" executers="repl_ap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Repl_PutAutoRefundSetting_Dist]
    @tvp_param TVP_ReplAutoRefundSetting READONLY
AS
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: IRS_DBTP-bodb02
	
	Revisions:
		- 20250120@Aries: Scale out DBCUST [RedmineID: #214410]

	Example:			
*/
BEGIN
    SET NOCOUNT ON;
	
	SET IDENTITY_INSERT [dbo].[AutoRefundSetting] ON;
			
    MERGE [dbo].[AutoRefundSetting] [t]
    USING @tvp_param [tvp] 
		ON [t].[Id] = [tvp].[Id]
		WHEN MATCHED THEN	
		UPDATE SET
			[t].[Sporttype] = [tvp].[Sporttype]
			,[t].[ResourceID] = [tvp].[ResourceID]
			,[t].[Trigger] = [tvp].[Trigger]
			,[t].[Conditions] = [tvp].[Conditions]
			,[t].[CreatedDate] = [tvp].[CreatedDate]
			,[t].[RepUpdateTime] = CASE WHEN [tvp].[RepUpdateTime] > ISNULL([t].[RepUpdateTime],'') THEN [tvp].[RepUpdateTime] ELSE [t].[RepUpdateTime] END	
			,[t].[isDeleted]= [tvp].[isDeleted]
    WHEN NOT MATCHED THEN
        INSERT ([Id]
				,[Sporttype]
				,[ResourceID]
				,[Trigger]
				,[Conditions]
				,[CreatedDate]
				,[RepUpdateTime]
		   		,[isDeleted])
		VALUES ([tvp].[Id]
				,[tvp].[Sporttype]
				,[tvp].[ResourceID]
				,[tvp].[Trigger]
				,[tvp].[Conditions]
				,[tvp].[CreatedDate]
				,[tvp].[RepUpdateTime]
				,[tvp].[isDeleted] 
		);
	
	SET IDENTITY_INSERT [dbo].[AutoRefundSetting] OFF;	
END	