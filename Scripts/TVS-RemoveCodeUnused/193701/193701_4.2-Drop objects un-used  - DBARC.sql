/*<info serverAlias="DBARC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230921@July
	Task: Drop Objects un-used  [Redmine:#193701]  
	DB: DBARC-bodb02
	
*/
USE bodb02
GO
/*TABLES - Apply only PROD***********************************************************************************************************/
IF OBJECT_ID('DEL_TicketVoiding_Action','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Action
GO
IF OBJECT_ID('DEL_TicketVoiding_IssueType','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_IssueType
GO
IF OBJECT_ID('DEL_TicketVoiding_MessageTemplate','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_MessageTemplate
GO
IF OBJECT_ID('DEL_TicketVoiding_MessageTemplateSetting','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_MessageTemplateSetting
GO
IF OBJECT_ID('DEL_TicketVoiding_OperatorInfo','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_OperatorInfo
GO
IF OBJECT_ID('DEL_TicketVoiding_Reason','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Reason
GO
IF OBJECT_ID('DEL_TicketVoiding_ReasonTemplate','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_ReasonTemplate
GO
IF OBJECT_ID('DEL_TicketVoiding_RequestDetailTicket_Single','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_RequestDetailTicket_Single
GO
IF OBJECT_ID('DEL_TicketVoiding_RequestDetailTicket_SubParlay','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_RequestDetailTicket_SubParlay
GO

/*SPS***********************************************************************************************************/
DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'DEL_TicketVoiding_CTS_ProblemAccountSelect%'
OR  name LIKE 'DEL_TicketVoiding_CTS_ProblemAccountSelect_CN88%'
)

SELECT * FROM @tmpDropObjectsName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpDropObjectsName
	SET @command = command, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@command)

END
