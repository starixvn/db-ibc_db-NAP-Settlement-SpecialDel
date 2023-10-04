/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : Max
	Task	: [TVS] Edit description of subtypes by each user [Redmine:#185498]
	DB: DBCTG-bodb02
*/

USE [bodb02]
GO

/****** Object:  Table [dbo].[TicketVoiding_SubIssueType_Note]    Script Date: 9/28/2023 9:16:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[TicketVoiding_SubIssueType_Note](
	[IssueTypeId] [tinyint] NOT NULL,
	[GroupId] [smallint] NOT NULL,
	[UserId] [int] NOT NULL,
	[Note] [nvarchar](max) NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_TicketVoiding_SubIssueType_Note] PRIMARY KEY CLUSTERED 
(
	[GroupId] ASC,
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_SubIssueType_Note] ADD  CONSTRAINT [DF_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[TicketVoiding_SubIssueType_Note] ADD  CONSTRAINT [DF_ModifiedDate]  DEFAULT (getdate()) FOR [ModifiedDate]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_SubIssueType_Note] ON [dbo].[TicketVoiding_SubIssueType_Note]
(
	[IssueTypeId] ASC,
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO


