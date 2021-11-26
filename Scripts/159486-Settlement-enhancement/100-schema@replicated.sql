/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
go
CREATE TABLE [dbo].[SettlementLock](
	[MatchId] [int] NULL,
	[SessionId] bigint NOT NULL,
	[CreatedTime] [datetime] NULL
) ON [DATA]
GO

ALTER TABLE [dbo].[SettlementLock] ADD  CONSTRAINT [DF_SettlementLock_CreatedTime]  DEFAULT (getdate()) FOR [CreatedTime]
GO
--drop table SettlementProcessing

CREATE TABLE [dbo].[SettlementProcessing](
	Id bigint identity(1,1),
	[SessionId] [bigint] NOT NULL,
	[OddsType] [smallint] NULL,
	[MessageType] [varchar](200) NULL,
	[StatusId] [tinyint] NULL,
	[ActionId] [int] NULL,
	[TransIds] [varchar](max) NULL,
	[modds] [money] NULL,
	[IsMarked] [bit] NULL,
	 CONSTRAINT [PK_SettlementProcessing] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
) ON [DATA]
) ON [DATA]
GO

CREATE CLUSTERED INDEX [CIX_SettlementProcessing] ON [dbo].[SettlementProcessing]
(
	[SessionId] ASC,
	[MessageType] ASC,
	[modds] DESC
) ON [DATA]
GO

ALTER TABLE [dbo].[SettlementProcessing] ADD CONSTRAINT [DF_SettlementProcessing_StatusId]  DEFAULT ((0)) FOR [StatusId]
GO

ALTER TABLE [dbo].[SettlementProcessing] ADD CONSTRAINT [DF_SettlementProcessing_IsMarked] DEFAULT ((0)) FOR [IsMarked]
GO
--alter table dbo.SSB_SettlementLogs add MessageBody nvarchar(max) null


create table dbo.SSB_SettlementLogs
(
	MessageId varchar(128) null,
	MessageType varchar(200) null,
	MessageBody nvarchar(max) null,
	StartTime datetime2 null,
	EndTime datetime2 null,
	MatchId int null,
	SessionId bigint,
	ErrorMessage varchar(1024),
	ConversationHandle varchar(128),
	Resolved bit,
	QueueNo tinyint
)ON [serviceBroker]

create clustered index cix_SSB_SettlementLogs on SSB_SettlementLogs(StartTime) on [serviceBroker]
alter table dbo.SSB_SettlementLogs add constraint DF_SSB_SettlementLogs_StartTime default ((sysdatetime())) for StartTime
alter table dbo.SSB_SettlementLogs add constraint DF_SSB_SettlementLogs_EndTime default ((sysdatetime())) for EndTime
alter table dbo.SSB_SettlementLogs add constraint DF_SSB_SettlementLogs_Resolved default ((0)) for Resolved

