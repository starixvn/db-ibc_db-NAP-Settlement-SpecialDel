/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Louisa
	Date: 20210706
	Task: Create new table to send message to Letstalk [Redmine:#157540]
	DB: DBTXN/bodb02
*/

USE [bodb02]
GO

CREATE TABLE [dbo].[Settlement_LetstalkMessage]
(
	MessageId		INT IDENTITY(1,1) NOT NULL
	,MessageGroupId	TINYINT		NOT NULL
	,MessageTypeId	TINYINT		NOT NULL
	,MatchId		INT			NOT NULL
	,ActionId		INT				NULL
	,ActionName		NVARCHAR(512)	NULL
	,MessageContent	VARCHAR(MAX)	NULL
	,StatusId		TINYINT			NULL
	,CreateDate		DATETIME		NULL
	,CreateBy		INT				NULL
	,LastModifyDate	DATETIME		NULL
	,LastModifyBy	INT				NULL
	,IP				VARCHAR(15)		NULL

	CONSTRAINT [Settlement_LetstalkMessage] PRIMARY KEY NONCLUSTERED 
	(
		[MessageId] ASC
	) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [Event_table]
) ON [Event_table]

GO

ALTER TABLE [dbo].[Settlement_LetstalkMessage] ADD  CONSTRAINT [DF_Settlement_LetstalkMessage_StatusId]  DEFAULT (0) FOR [StatusId]
GO

ALTER TABLE [dbo].[Settlement_LetstalkMessage] ADD  CONSTRAINT [DF_Settlement_LetstalkMessage_CreateDate]  DEFAULT (GETDATE()) FOR [CreateDate]
GO

ALTER TABLE [dbo].[Settlement_LetstalkMessage] ADD  CONSTRAINT [DF_Settlement_LetstalkMessage_LastModifyDate]  DEFAULT (GETDATE()) FOR [LastModifyDate]
GO

-----CREATE INDEXS

	CREATE NONCLUSTERED INDEX [IX_Settlement_LetstalkMessage_MatchStatus] ON [dbo].[Settlement_LetstalkMessage]
	(
		[MatchId] ASC	
		,[StatusId] ASC
	)
	ON [Event_table]
	GO
