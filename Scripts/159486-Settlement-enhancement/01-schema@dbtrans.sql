/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
USE master
go

ALTER DATABASE bodb02 ADD FILEGROUP serviceBroker 
ALTER DATABASE bodb02 
	ADD FILE (NAME = N'serviceBroker_01', FILENAME = N'D:\IBC_DB\bodb02\serviceBroker\serviceBroker_01.ndf'  
		, SIZE = 512KB, MAXSIZE = UNLIMITED, FILEGROWTH = 32768KB) TO FILEGROUP [serviceBroker]

GO


USE bodb02
GO
CREATE SCHEMA [sb]
GO
CREATE TABLE [sb].[ConfigurationReference](
	[FunctionName] [varchar](50) NULL,
	[MaxReceiveMsg] [int] NULL,
	[MaxReceiveTimeOut] [int] NULL
) ON [serviceBroker]
GO

ALTER TABLE [sb].[ConfigurationReference] ADD  CONSTRAINT [DF_ConfigurationReference_MaxReceiveMsg]  DEFAULT ((1)) FOR [MaxReceiveMsg]
GO

ALTER TABLE [sb].[ConfigurationReference] ADD  CONSTRAINT [DF_ConfigurationReference_MaxReceiveTimeOut]  DEFAULT ((1)) FOR [MaxReceiveTimeOut]
GO

CREATE CLUSTERED INDEX [CIX_ConfigurationReference] ON [sb].[ConfigurationReference]
(
	[FunctionName] ASC
) ON [serviceBroker]
GO


CREATE TABLE [sb].[ConfigurationReferenceDetail](
	[FunctionName] [varchar](50) NULL,
	[ContractName] [varchar](200) NULL,
	[MessageType] [varchar](200) NULL,
	[MinConversation] [int] NULL,
	[MaxConversation] [int] NULL
) ON [serviceBroker]
GO

ALTER TABLE [sb].[ConfigurationReferenceDetail] ADD  CONSTRAINT [DF_ConfigurationReferenceDetail_MinConversation]  DEFAULT ((5)) FOR [MinConversation]
GO

ALTER TABLE [sb].[ConfigurationReferenceDetail] ADD  CONSTRAINT [DF_ConfigurationReferenceDetail_MaxConversation]  DEFAULT ((20)) FOR [MaxConversation]
GO

CREATE CLUSTERED INDEX [CIX_ConfigurationReferenceDetail] ON [sb].[ConfigurationReferenceDetail]
(
	[FunctionName] ASC,
	[MessageType] ASC
) ON [serviceBroker]
GO


CREATE TABLE [sb].[ConversationCount](
	[FunctionName] [varchar](100) NULL,
	[ContractName] [varchar](200) NULL,
	[Cnt] [int] NULL
) ON [serviceBroker]
GO

CREATE CLUSTERED INDEX [CIX_ConversationCount] ON [sb].[ConversationCount]
(
	[FunctionName] ASC,
	[ContractName] ASC
) ON [serviceBroker]
GO

CREATE TABLE [sb].[ConversationManagement](
	[FunctionName] [varchar](50) NULL,
	[ContractName] [varchar](100) NULL,
	[ConversationHandle] [uniqueidentifier] NULL,
	[ConversationNo] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[IsValid] [bit] NULL
) ON [serviceBroker]
GO

CREATE CLUSTERED INDEX [CIX_ConversationManagement] ON [sb].[ConversationManagement]
(
	[FunctionName] ASC,
	[ContractName] ASC,
	[ConversationNo] ASC
) ON [serviceBroker]
GO


select service_broker_guid, is_broker_enabled, * from sys.databases where name = 'bodb02'
ALTER DATABASE bodb02 SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;

go

--alter table dbo.SSB_SettlementLogs add MessageBody nvarchar(max) null
--alter table dbo.SSB_SettlementLogs add QueueNo tinyint null
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


create table Settlement_SettledSession
(
	SessionId bigint identity(1,1),
	MatchId int not null,
	CreatedTime datetime
) on [Data]

ALTER TABLE [dbo].[Settlement_SettledSession] ADD  CONSTRAINT [PK_Settlement_SettledSession] PRIMARY KEY CLUSTERED 
(
	[SessionId] ASC
) ON [DATA]
GO

ALTER TABLE [dbo].[Settlement_SettledSession] ADD  CONSTRAINT [DF_Settlement_SettledSession_CreatedTime]  DEFAULT ((getdate())) FOR [CreatedTime]
GO

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

CREATE CLUSTERED INDEX CIX_SettlementProcessing ON SettlementProcessing(SessionId, MessageType) ON [DATA]

ALTER TABLE [dbo].[SettlementProcessing] ADD CONSTRAINT [DF_SettlementProcessing_StatusId]  DEFAULT ((0)) FOR [StatusId]
GO

ALTER TABLE [dbo].[SettlementProcessing] ADD CONSTRAINT [DF_SettlementProcessing_IsMarked] DEFAULT ((0)) FOR [IsMarked]
GO


CREATE TABLE [dbo].[SettlementBettypeResult](
	[MatchId] [int] NOT NULL,
	[BetType] [smallint] NOT NULL,
	[pfID] [smallint] NULL,
	[HomeValue] [varchar](50) NULL,
	[AwayValue] [varchar](50) NULL,
	[OddsType] [smallint] NULL,
	[SessionId] [bigint] NULL
) ON [DATA]
GO

/****** Object:  Index [CIX_SettlementBettypeResult_MatchId]    Script Date: 10/19/2021 9:30:19 AM ******/
CREATE CLUSTERED INDEX [CIX_SettlementBettypeResult_MatchId] ON [dbo].[SettlementBettypeResult]
(
	[MatchId] ASC
)ON [DATA]
GO


