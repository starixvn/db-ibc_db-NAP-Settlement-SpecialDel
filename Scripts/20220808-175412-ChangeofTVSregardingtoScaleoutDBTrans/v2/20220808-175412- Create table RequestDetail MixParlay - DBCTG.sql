/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@Max
	Task: Create new table TicketVoiding_RequestDetail_MixParlay [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO
CREATE TABLE [dbo].[TicketVoiding_RequestDetail_MixParlay](
	[RequestId] [int] NOT NULL,
	[MatchId] [int] NOT NULL,
	[MainTransId] [bigint] NOT NULL
) ON DATA

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_MixParlay_RequestId] ON [dbo].[TicketVoiding_RequestDetail_MixParlay]
(
	[RequestId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE CLUSTERED INDEX [CIX_TicketVoiding_MixParlay_MatchId] ON [dbo].[TicketVoiding_RequestDetail_MixParlay]
(
	[MatchId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
