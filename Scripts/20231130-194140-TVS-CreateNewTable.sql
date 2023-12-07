/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20231130@Max
	Task: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
	DB: DBCTG/bodb02
		
*/

USE [bodb02]
GO

/****** Object:  Table [dbo].[TicketVoiding_AbnormalAccountVoidAmount]    Script Date: 12/1/2023 8:14:43 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[TicketVoiding_AbnormalAccountVoidAmount](
	[RequestId] [int] NOT NULL,
	[custid] [int] NOT NULL,
	[AdjustLimit] [money] NULL,
	[CurrWinning] [money] NULL,
	[CurrLosing] [money] NULL,
	[EstVoidAmount] [money] NULL,
	[WinlostAfterVoid] [money] NULL,
	[CreatedDate] [datetime] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
	[GivenCredit] [money] NOT NULL
) ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_AbnormalAccountVoidAmount] ADD  CONSTRAINT [DF_CreatedDate_AC]  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[TicketVoiding_AbnormalAccountVoidAmount] ADD  CONSTRAINT [DF_ModifiedDate_AC]  DEFAULT (getdate()) FOR [ModifiedDate]
GO

CREATE CLUSTERED INDEX [CIX_RequestId] ON [dbo].[TicketVoiding_AbnormalAccountVoidAmount]
(
	[RequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO

