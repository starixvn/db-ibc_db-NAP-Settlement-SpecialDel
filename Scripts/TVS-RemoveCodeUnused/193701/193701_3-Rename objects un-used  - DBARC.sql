/*<info serverAlias="DBARC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230921@July
	Task: Rename Objects un-used  [Redmine:#193701]  
	DB: DBARC-bodb02
	Apply for SIT & PROD
*/
USE bodb02
GO

/*TABLES***********************************************************************************************************/
IF OBJECT_ID('TicketVoiding_Action','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_Action','DEL_TicketVoiding_Action';
GO
IF OBJECT_ID('TicketVoiding_IssueType','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_IssueType','DEL_TicketVoiding_IssueType';
GO
IF OBJECT_ID('TicketVoiding_MessageTemplate','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_MessageTemplate','DEL_TicketVoiding_MessageTemplate';
GO
IF OBJECT_ID('TicketVoiding_MessageTemplateSetting','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_MessageTemplateSetting','DEL_TicketVoiding_MessageTemplateSetting';
GO
IF OBJECT_ID('TicketVoiding_OperatorInfo','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_OperatorInfo','DEL_TicketVoiding_OperatorInfo';
GO
IF OBJECT_ID('TicketVoiding_Reason','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_Reason','DEL_TicketVoiding_Reason';
GO
IF OBJECT_ID('TicketVoiding_ReasonTemplate','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_ReasonTemplate','DEL_TicketVoiding_ReasonTemplate';
GO
IF OBJECT_ID('TicketVoiding_RequestDetailTicket_Single','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_RequestDetailTicket_Single','DEL_TicketVoiding_RequestDetailTicket_Single';
GO
IF OBJECT_ID('TicketVoiding_RequestDetailTicket_SubParlay','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_RequestDetailTicket_SubParlay','DEL_TicketVoiding_RequestDetailTicket_SubParlay';
GO
/*SPS***********************************************************************************************************/
DECLARE @command VARCHAR(MAX)
DECLARE @tmpRenameObjectsName TABLE ( command VARCHAR(MAX), IsRename BIT)

INSERT INTO @tmpRenameObjectsName (command)
SELECT 'sp_rename ' + name + ', DEL_' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'TicketVoiding_CTS_ProblemAccountSelect%'
OR  name LIKE 'TicketVoiding_CTS_ProblemAccountSelect_CN88%'
)
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpRenameObjectsName
	SET @command = command, IsRename = 1
	WHERE IsRename IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@command)

END
SELECT * FROM @tmpRenameObjectsName

