/*<info serverAlias="DBACC-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20211110@Max
	Task: [NAP CM] Add Void User when mark PA - [Redmine: #164166]
	DB: DBACC/bodb02

*/

USE [bodb02]
GO
CREATE NONCLUSTERED INDEX [IX_MessageId] ON [dbo].[TicketVoiding_VoidingHistory]
(
	[MessageId] ASC
) WITH (ONLINE = ON) ON [DATA]
GO



