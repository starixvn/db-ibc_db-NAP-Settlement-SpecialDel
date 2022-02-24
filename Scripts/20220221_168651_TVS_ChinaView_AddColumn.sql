/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet,Dot_Admin" isFunction="0"></info>*/
/*
	Created: 20210221@Max
	DB: DBMSG.bodb_Message
	Task: Add new column LeagueGroupID into table Msg [Redmine:#168651]
	
*/
USE [bodb_Message]
GO

ALTER TABLE [dbo].[Msg] 
	ADD LeagueGroupID SMALLINT NULL;
GO