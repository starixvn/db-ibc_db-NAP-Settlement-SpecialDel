/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230103@July
	Task: Create new table dbo.TicketVoiding_Letstalk  [Redmine:#180625]  
	DB: DBCTG-bodb02
		
*/
USE bodb02
GO

CREATE TABLE [dbo].[TicketVoiding_Letstalk](
	[Id] INT IDENTITY(1,1) NOT NULL,
	[RequestId] [int] NOT NULL,
	[BroadcastSessionId] [VARCHAR](100) NOT NULL,
	[StatusId] [tinyint] NOT NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedDate] [datetime] NULL
	CONSTRAINT [TicketVoiding_Letstalk_Id] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA]

ALTER TABLE [dbo].[TicketVoiding_Letstalk] ADD  CONSTRAINT [DF_TicketVoiding_Letstalk_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[TicketVoiding_Letstalk] ADD  CONSTRAINT [DF_TicketVoiding_Letstalk_ModifiedDate]  DEFAULT (GETDATE()) FOR [ModifiedDate]
GO
