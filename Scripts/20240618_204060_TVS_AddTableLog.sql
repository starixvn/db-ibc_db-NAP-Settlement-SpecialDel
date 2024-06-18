/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240618@Max
	Task: [TVS] Set logs to check user behavior [Redmine:#204060]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO
CREATE TABLE [dbo].[TicketVoiding_UserActionLog_Tracking](
	LogId				INT	IDENTITY (1,1) NOT NULL,
	UserId				INT	NOT NULL,
	LogDate				SMALLDATETIME NOT NULL,
	FunctionName		VARCHAR(500) NOT NULL,
	ActionCount			INT	NOT NULL,
	LogContent			NVARCHAR(MAX) NULL
  CONSTRAINT [PK_TicketVoiding_UserActionLog_Tracking] PRIMARY KEY NONCLUSTERED 
(
	[LogId] ASC
	
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
) ON DATA

CREATE CLUSTERED INDEX [CIX_UserLog_LogDate] ON [dbo].[TicketVoiding_UserActionLog_Tracking]
(
	[LogDate]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_UserLog_ActionCount] ON [dbo].[TicketVoiding_UserActionLog_Tracking]
(
	[ActionCount]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
