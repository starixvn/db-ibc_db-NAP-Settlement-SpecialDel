/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220413@Kathy
	Task	: Add CIX on queue [Redmine:#171446]

*/
USE [bodb02]
GO

ALTER TABLE [dbo].[Single_Calculate_Queue] ADD CONSTRAINT PK_Single_Calculate_Queue PRIMARY KEY CLUSTERED 
(
	[keyid] ASC
) ON [Event_table]
GO



ALTER TABLE [dbo].[Parlay_Calculate_Queue] ADD CONSTRAINT PK_Parlay_Calculate_Queue PRIMARY KEY CLUSTERED 
(
	[keyid] ASC
) ON [Event_table]
GO


