/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230103@July
	Task: Create new table dbo.TicketVoiding_Letstalk  [Redmine:#180625]  
	DB: DBCTG-bodb02
		
*/
USE bodb02
GO

CREATE TABLE [dbo].[TicketVoiding_Letstalk](
	[RequestId] [int] NOT NULL,
	[BroadcastSessionId] [VARCHAR](100) NOT NULL,
	[StatusId] [tinyint] NOT NULL
	CONSTRAINT [TicketVoiding_Letstalk_RequestId] PRIMARY KEY NONCLUSTERED 
(
	[RequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
) ON [DATA]
