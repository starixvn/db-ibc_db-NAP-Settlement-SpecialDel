/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250102@Aries
	Task: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
CREATE TABLE [dbo].[AutoRefundSetting](
	[Id] [int] IDENTITY(1,1) NOT NULL,
    [Sporttype] [SMALLINT] NOT NULL,
	[ResourceID] [VARCHAR](20) NOT NULL,
	[Trigger] [VARCHAR](MAX),
	[Conditions] [VARCHAR](MAX),
    [RepUpdateTime]  DATETIME2(7)	NOT NULL,
	[CreatedDate] DATETIME DEFAULT GETDATE()
    CONSTRAINT [PK_AutoRefundSetting_ID] PRIMARY KEY NONCLUSTERED 
    (
	    [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA];
GO
CREATE CLUSTERED INDEX CX_AutoRefundSetting_SporttypeResource ON dbo.AutoRefundSetting (Sporttype,ResourceID);
GO
CREATE INDEX IX_AutoRefundSetting_RepUpdateTime ON dbo.AutoRefundSetting(RepUpdateTime);
GO
ALTER TABLE [dbo].[AutoRefundSetting] ADD  CONSTRAINT [DF_AutoRefundSetting_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
GO


CREATE TABLE [dbo].[AutoRefundSetting_Del_InHouse](
	[Id] [int] NOT NULL,
	[RepUpdateTime] [datetime2](7) NOT NULL ,
	CONSTRAINT [PK_AutoRefundSetting_Del_InHouse_Id] PRIMARY KEY NONCLUSTERED 
	(
		[Id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA]
GO

CREATE INDEX IX_AutoRefundSetting_Del_InHouse_RepUpdateTime ON dbo.AutoRefundSetting_Del_InHouse(RepUpdateTime)
GO
ALTER TABLE [dbo].[AutoRefundSetting_Del_InHouse] ADD  CONSTRAINT [DF_AutoRefundSetting_Del_InHouse_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
GO



