/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_Request_bk](
	[RequestId] [int] NOT NULL,
	[Sporttype] [smallint] NULL,
	[SubIssueTypeId] [smallint] NULL,
	[ActionId] [tinyint] NULL,
	[Provider] [nvarchar](200) NULL,
	[Source] [nvarchar](200) NULL,
	[DecidedBy] [nvarchar](200) NULL,
	[MistakenBy] [nvarchar](200) NULL,
	[Remark] [nvarchar](max) NULL,
	[CheckedBy] [int] NULL,
	[UserId] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[LastModifiedBy] [int] NULL,
	[LastModifiedDate] [datetime] NULL,
	[IsTest] [bit] NULL,
	[IssueTypeId] [tinyint] NULL,

) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_Request_bk] ADD  CONSTRAINT [DF_TicketVoiding_Request_bk_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[TicketVoiding_Request_bk] ADD  CONSTRAINT [DF_TicketVoiding_Request_bk_LastModifiedDate]  DEFAULT (getdate()) FOR [LastModifiedDate]
GO


