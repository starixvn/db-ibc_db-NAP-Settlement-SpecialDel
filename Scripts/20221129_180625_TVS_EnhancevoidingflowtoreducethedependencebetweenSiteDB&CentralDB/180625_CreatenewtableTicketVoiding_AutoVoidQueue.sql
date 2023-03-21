/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Create new table dbo.TicketVoiding_AutoVoidQueue  [Redmine:#180625]  
	DB: DBCTG-bodb02,DBSIG-bodb02
		
*/
USE bodb02
GO

CREATE TABLE [dbo].[TicketVoiding_AutoVoidQueue](
	[QueueId] [int] IDENTITY(1,1) NOT NULL,
	[RequestIds] [VARCHAR](MAX) NOT NULL,
	[MatchId] [int] NOT NULL,
	[Action] [varchar](100) NULL,
	[StatusId] [tinyint] NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedDate] [datetime] NULL,
	[ErrMsg] [varchar](300) NULL,
	[BroadcastSessionId] [VARCHAR](100) NULL
 CONSTRAINT [TicketVoiding_AutoVoidQueue_QueueId] PRIMARY KEY CLUSTERED 
(
	[QueueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA]
GO
ALTER TABLE [dbo].[TicketVoiding_AutoVoidQueue] ADD  CONSTRAINT [DF_TicketVoiding_AutoVoidQueue_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[TicketVoiding_AutoVoidQueue] ADD  CONSTRAINT [DF_TicketVoiding_AutoVoidQueue_ModifiedDate]  DEFAULT (GETDATE()) FOR [ModifiedDate]
GO