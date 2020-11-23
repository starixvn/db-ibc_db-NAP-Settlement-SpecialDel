/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_Reason_bk](
	[ReasonId] [int] NOT NULL,
	[ReasonEnglish] [nvarchar](150) NULL,
	[ReasonChineseSimplified] [nvarchar](150) NULL,

) ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_Reason_bk] ADD  CONSTRAINT [PK_TicketVoiding_Reason_bk_ReasonId] PRIMARY KEY CLUSTERED 
(
	[ReasonId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


