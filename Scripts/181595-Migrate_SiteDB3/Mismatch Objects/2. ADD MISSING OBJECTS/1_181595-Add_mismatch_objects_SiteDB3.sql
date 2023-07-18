/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Copy structure from SiteDB1 [Redmineid:#181595]

*/

--- run on SiteDB3  only

USE bodb02
GO

---- 1. table SiteDB_SettlementService_CalculationLog
	CREATE TABLE [dbo].[SiteDB_SettlementService_CalculationLog](
		[LogId] [bigint] IDENTITY(1,1) NOT NULL,
		[SystemName] [varchar](50) NULL,
		[FunctionName] [varchar](50) NULL,
		[TableName] [varchar](128) NULL,
		[Action] [varchar](1) NULL,
		[SettlementAction] [varchar](20) NULL,
		[TicketType] [varchar](1) NULL,
		[MatchId] [int] NULL,
		[TransInfo] [xml] NULL,
		[LogDate] [datetime2](7) NULL,
		[TransInfoJson_delete] [varchar](max) NULL,
		[SessionId] [bigint] NULL,
		[IsParallel] [bit] NULL,
		[TransInfoJson] [varbinary](max) NULL
	) ON [DATA] TEXTIMAGE_ON [DATA]
	GO
	----------------------------------------------------------------------------------------------------------
	CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_CalculationLog] ON [dbo].[SiteDB_SettlementService_CalculationLog]
	(
		[LogId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]

	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_Action]  DEFAULT ('U') FOR [Action]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_MatchId]  DEFAULT ((0)) FOR [MatchId]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_LogDate]  DEFAULT (sysdatetime()) FOR [LogDate]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_SessionId]  DEFAULT ((0)) FOR [SessionId]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_IsParallel]  DEFAULT ((0)) FOR [IsParallel]
	GO


---- 2. table SiteDB_SettlementService_CalculationLog_3rd
	 CREATE TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd](
		[LogId] [bigint] IDENTITY(1,1) NOT NULL,
		[SystemName] [varchar](50) NULL,
		[FunctionName] [varchar](50) NULL,
		[TableName] [varchar](128) NULL,
		[Action] [varchar](1) NULL,
		[MatchId] [int] NULL,
		[TransInfoJson] [varbinary](max) NULL,
		[LogDate] [datetime2](7) NULL,
		[SettlementAction] [varchar](20) NULL,
		[TicketType] [varchar](1) NULL,
		[EventTable] [tinyint] NULL
	) ON [DATA] TEXTIMAGE_ON [DATA]
	GO
	----------------------------------------------------------------------------------------------------------
	CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_CalculationLog_3rd] ON [dbo].[SiteDB_SettlementService_CalculationLog_3rd]
	(
		[LogId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
	GO
	----------------------------------------------------------------------------------------------------------	 
	CREATE NONCLUSTERED INDEX [IX_SiteDB_SettlementService_CalculationLog_3rd_LogDate] ON [dbo].[SiteDB_SettlementService_CalculationLog_3rd]
	(
		[LogDate] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_Action]  DEFAULT ('U') FOR [Action]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_MatchId]  DEFAULT ((0)) FOR [MatchId]
	GO
	----------------------------------------------------------------------------------------------------------
	ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_LogDate]  DEFAULT (sysdatetime()) FOR [LogDate]
	GO


---- 3. table 	SiteDB_SettlementService_LastLog
	 CREATE TABLE [dbo].[SiteDB_SettlementService_LastLog](
		[LogId] [bigint] NULL,
		[StatusId] [tinyint] NULL,
		[StarttimeValidation] [datetime2](7) NULL,
		[Starttime] [datetime2](7) NULL,
		[EndTime] [datetime2](7) NULL,
		[ErrMsg] [varchar](300) NULL
	) ON [DATA]
	GO
	----------------------------------------------------------------------------------------------------------
	CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_LastLog] ON [dbo].[SiteDB_SettlementService_LastLog]
	(
		[LogId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
	GO


---- 4. table SiteDB_SettlementService_LastLog_3rd
	 CREATE TABLE [dbo].[SiteDB_SettlementService_LastLog_3rd](
		[LogId] [bigint] NULL,
		[StatusId] [tinyint] NULL,
		[Starttime] [datetime2](7) NULL,
		[Endtime] [datetime2](7) NULL
	) ON [DATA]
	GO
	----------------------------------------------------------------------------------------------------------
	CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_LastLog_3rd] ON [dbo].[SiteDB_SettlementService_LastLog_3rd]
	(
		[LogId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
	GO


---- Add index
	
	--bettrans.IX_refno
	CREATE NONCLUSTERED INDEX [IX_refno] ON [dbo].[bettrans]
	(
		[refno] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	--bettrans.IX_RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettrans]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----BettransInfo.RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[BettransInfo]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----bettransLC.RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettransLC]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----bettransm.RepUpdateTime
	CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettransm]
	(
		[RepUpdateTime] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO

	----bettransRnG.IX_tstamp
	CREATE NONCLUSTERED INDEX [IX_tstamp] ON [dbo].[bettransRnG]
	(
		[tstamp] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO
	
	----CashOutSelling.IX_tstamp
	CREATE NONCLUSTERED INDEX [IX_tstamp] ON [dbo].[CashOutSelling]
	(
		[tstamp] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO
	
	----translog.IX_tstamp
	CREATE NONCLUSTERED INDEX [IX_tstamp] ON [dbo].[translog]
	(
		[tstamp] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
	GO
