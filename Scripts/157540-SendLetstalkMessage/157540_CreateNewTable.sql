/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Louisa
	Date: 20210706
	Task: Create new table to send message to Letstalk [Redmine:#157540]
	DB: DBTXN/bodb02
*/

USE [bodb02]
GO

CREATE TABLE dbo.Settlement_LetstalkMessage
(
	 MessageId			INT IDENTITY(1,1) NOT NULL,
	 MessageGroupId		TINYINT			NOT NULL,
	 MessageType		VARCHAR(100)	NOT NULL,
	 MatchId			INT				NOT NULL,
	 ActionName			VARCHAR(512)	NULL,
	 MessageContent		VARCHAR(MAX)	NULL,
	 MessageDetail		VARCHAR(MAX)	NULL,
	 StatusId			TINYINT			NULL,
	 CreatedDate		DATETIME		NULL,
	 CreatedBy			INT				NULL,
	 LastModifiedDate	DATETIME		NULL,

	CONSTRAINT [PK_Settlement_LetstalkMessage] PRIMARY KEY NONCLUSTERED 
	(
		[MessageId] ASC
	)
) ON [Event_table]

GO

	EXEC sys.sp_addextendedproperty 
	@name=N'MS_Description', 
	@value=N'1:Instant Settlement' ,
	@level0type=N'SCHEMA', 
	@level0name=N'dbo', 
	@level1type=N'TABLE', 
	@level1name=N'Settlement_LetstalkMessage', 
	@level2type=N'COLUMN', 
	@level2name=N'MessageGroupId'

GO

ALTER TABLE [dbo].[Settlement_LetstalkMessage] ADD  CONSTRAINT [DF_Settlement_LetstalkMessage_StatusId]  DEFAULT (0) FOR [StatusId]
GO

ALTER TABLE [dbo].[Settlement_LetstalkMessage] ADD  CONSTRAINT [DF_Settlement_LetstalkMessage_CreateDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[Settlement_LetstalkMessage] ADD  CONSTRAINT [DF_Settlement_LetstalkMessage_LastModifyDate]  DEFAULT (GETDATE()) FOR [LastModifiedDate]
GO

-----CREATE INDEXS

	CREATE NONCLUSTERED INDEX [IX_Settlement_LetstalkMessage_MatchStatus] ON [dbo].[Settlement_LetstalkMessage]
	(
		[MatchId] ASC	
		,[StatusId] ASC
	)
	ON [Event_table]
	GO
