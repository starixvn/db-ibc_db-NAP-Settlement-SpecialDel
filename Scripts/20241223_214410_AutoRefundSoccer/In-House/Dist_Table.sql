/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: 
	
	Revisions:
		- 20250120@Aries: Created [RedmineID: #214410]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'AutoRefundSetting')
BEGIN
	CREATE TABLE [dbo].[AutoRefundSetting]
	(
		 [Id] [INT] IDENTITY(1,1) NOT NULL
		,[Sporttype] [SMALLINT] NOT NULL
		,[ResourceID] [VARCHAR](20) NOT NULL
		,[Trigger] [VARCHAR](MAX) NULL
		,[Conditions] [VARCHAR](MAX) NULL
		,[CreatedDate] DATETIME DEFAULT GETDATE()
		,[RepUpdateTime] [DATETIME2](7) NULL
		,[isDeleted] [BIT] NULL
		,CONSTRAINT [PK_AutoRefundSetting] PRIMARY KEY CLUSTERED ([Id]) ON [DATA]
	) ON [DATA]

	ALTER TABLE [dbo].[AutoRefundSetting] ADD CONSTRAINT [DF_AutoRefundSetting_isDeleted]  DEFAULT ((0)) FOR [isDeleted]
	
	ALTER TABLE [dbo].[AutoRefundSetting] ADD CONSTRAINT [DF_AutoRefundSetting_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
	
	CREATE NONCLUSTERED INDEX [IX_AutoRefundSetting_RepUpdateTime] ON [dbo].[AutoRefundSetting] 
	(
	  [RepUpdateTime] ASC
	)ON [DATA]
END
ELSE 
BEGIN
	SELECT 'Table AutoRefundSetting exists!!!'
END
GO
/***************************************************************************/




