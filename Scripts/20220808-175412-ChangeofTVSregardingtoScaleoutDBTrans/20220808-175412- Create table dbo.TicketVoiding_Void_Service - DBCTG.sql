/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@July
	Task: Create new table service [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO
CREATE TABLE [dbo].[TicketVoiding_Void_Service](
	Id					INT	IDENTITY (1,1) NOT NULL,
	BroadcastSessionId	VARCHAR(50)	NOT NULL,
	SiteDBGroupID		SMALLINT NOT NULL,
	RequestId			INT	NOT NULL,
	VoidingHistoryId	BIGINT	NOT NULL,
	StatusId			TINYINT	NOT NULL,
	IsAutoVoid			BIT NOT NULL,
	MatchId				INT NOT NULL,
	CreatedDate			DATETIME NOT NULL,
	ModifiedDate		DATETIME NOT NULL
  CONSTRAINT [PK_TicketVoiding_Void_Service] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
	
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
) ON DATA

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_Void_Service_RequestId] ON [dbo].[TicketVoiding_Void_Service]
(
	[RequestId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_Void_Service_BroadcastSessionId] ON [dbo].[TicketVoiding_Void_Service]
(
	[BroadcastSessionId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_Void_Service_StatusId] ON [dbo].[TicketVoiding_Void_Service]
(
	[StatusId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

GO
ALTER TABLE dbo.TicketVoiding_Void_Service ADD CONSTRAINT [DF_TicketVoiding_Void_Service_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO
ALTER TABLE dbo.TicketVoiding_Void_Service ADD CONSTRAINT [DF_TicketVoiding_Void_Service_ModifiedDate]  DEFAULT (GETDATE()) FOR [ModifiedDate]
GO