/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240822@Aries
	Task: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
CREATE TABLE [dbo].[AutoPayoutSetting](
    [Id] [int] IDENTITY(1,1) NOT NULL,
	[MatchId] [int] NOT NULL,
	[AutoType] [tinyint] NOT NULL,
	[Enable] [BIT] NULL,

	[WaitingTime] [int] NULL,
	[Main_HasTrader] [bit] NULL,
	[Main_NumberProvider] [tinyint] NULL,
	[Main_PrimaryProvider] [varchar](500) NULL,
	[Main_TotalPrimaryProvider] [tinyint] NULL,
	[Main_SecondaryProvider] [varchar](500) NULL,
	[Main_TotalSecondaryProvider] [tinyint] NULL,
    [Main_InactiveProvider] [varchar](500) NULL,

	[EAR_HasTrader] [bit] NULL,
	[EAR_NumberProvider] [tinyint] NULL,
	[EAR_PrimaryProvider] [varchar](500) NULL,
	[EAR_TotalPrimaryProvider] [tinyint] NULL,
	[EAR_SecondaryProvider] [varchar](500) NULL,
	[EAR_TotalSecondaryProvider] [tinyint] NULL,
	[EAR_WaitingTime] [int] NULL,
	[EAR_InactiveProvider] [varchar](500) NULL,

    [CreatedDate]    DATETIME		NOT NULL,
    [RepUpdateTime]  DATETIME2(7)	NOT NULL,
	[IsDeleted]		 BIT			NOT NULL,
    CONSTRAINT [PK_AutoPayoutSetting_Id] PRIMARY KEY NONCLUSTERED 
    (
	    [Id] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA];
GO
CREATE INDEX IX_AutoPayoutSetting_RepUpdateTime ON dbo.AutoPayoutSetting(RepUpdateTime);
GO
CREATE CLUSTERED INDEX CX_AutoPayoutSetting_MatchId ON dbo.AutoPayoutSetting (MatchId,AutoType);
GO
ALTER TABLE [dbo].[AutoPayoutSetting] ADD  CONSTRAINT [DF_AutoPayoutSetting_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[AutoPayoutSetting] ADD  CONSTRAINT [DF_AutoPayoutSetting_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
GO
ALTER TABLE [dbo].[AutoPayoutSetting] ADD  CONSTRAINT [DF_AutoPayoutSetting_IsDeleted]  DEFAULT ((0)) FOR [IsDeleted]
GO


