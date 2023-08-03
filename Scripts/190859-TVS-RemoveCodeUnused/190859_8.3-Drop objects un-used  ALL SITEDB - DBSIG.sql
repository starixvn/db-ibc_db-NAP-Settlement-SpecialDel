/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230303@July
	Task: Drop Objects un-used  [Redmine:#190859]  
	DB: DBSIG-bodb02
	
*/
USE bodb02
GO

/*TABLES***********************************************************************************************************/

IF OBJECT_ID('DEL_TicketVoiding_Request','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Request
GO
IF OBJECT_ID('DEL_TicketVoiding_RequestDetail','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_RequestDetail
GO
IF OBJECT_ID('DEL_TicketVoiding_RequestDetailTicket_Single','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_RequestDetailTicket_Single
GO
IF OBJECT_ID('DEL_TicketVoiding_RequestDetailTicket_SubParlay','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_RequestDetailTicket_SubParlay
GO
IF OBJECT_ID('DEL_Ticketvoiding_VoidBetAutomation_Service','U') IS NOT NULL 
	DROP TABLE DEL_Ticketvoiding_VoidBetAutomation_Service
GO
IF OBJECT_ID('DEL_TicketVoiding_VoidedTransaction','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_VoidedTransaction
GO
IF OBJECT_ID('DEL_TicketVoiding_VoidingHistory','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_VoidingHistory
GO
IF OBJECT_ID('DEL_TicketVoiding_AutoUnmarkSetting','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_AutoUnmarkSetting
GO
IF OBJECT_ID('DEL_TicketVoiding_ABWhiteList','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_ABWhiteList
GO
IF OBJECT_ID('DEL_TicketVoiding_Action','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Action
GO
IF OBJECT_ID('DEL_TicketVoiding_IssueType','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_IssueType
GO
IF OBJECT_ID('DEL_TicketVoiding_SubIssueType','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_SubIssueType
GO
IF OBJECT_ID('DEL_TicketVoiding_MessageTemplate','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_MessageTemplate
GO
IF OBJECT_ID('DEL_TicketVoiding_MessageTemplateSetting','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_MessageTemplateSetting
GO
IF OBJECT_ID('DEL_TicketVoiding_Reason','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Reason
GO
IF OBJECT_ID('DEL_TicketVoiding_ReasonTemplate','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_ReasonTemplate
GO
IF OBJECT_ID('DEL_TicketVoiding_OperatorInfo','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_OperatorInfo
GO
IF OBJECT_ID('DEL_TicketVoiding_Letstalk','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Letstalk
GO

/*FUNCTIONS***********************************************************************************************************/

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP FUNCTION ' + name
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
 AND (
    name LIKE 'DEL_f_TVS_CheckingIssueTypePHBettypes%'
OR  name LIKE 'DEL_f_TVS_CheckingSubIssueTypeIdExcludeBettypes%'
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

/*SPS***********************************************************************************************************/

SET @command = ''
DELETE FROM @tmpDropObjectsName

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
  /*  File sheet mismatch row 253-277  */
    name LIKE 'DEL_TicketVoiding_AutoUnmark_Select%'
OR  name LIKE 'DEL_TicketVoiding_AutoUnmark_Ticket_Select%'
OR  name LIKE 'DEL_TicketVoiding_AutoUnmarkSetting_Insert%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoidRequest_Ticket_Select%'
OR  name LIKE 'DEL_TicketVoiding_CheckUserName%'
OR  name = 'DEL_TicketVoiding_CheckVoidBetPermission'
OR  name LIKE 'DEL_TicketVoiding_Email_CheckITUser%'
OR  name LIKE 'DEL_TicketVoiding_GeneralInfo_Select%'
OR	name LIKE 'DEL_TicketVoiding_LogInfo_DARC_Select%'
OR  name LIKE 'DEL_TicketVoiding_LogInfo_HDP_Select%'
OR  name LIKE 'DEL_TicketVoiding_LogInfo_KO_Select%'
OR  name LIKE 'DEL_TicketVoiding_LogInfo_OU_Select%'
OR  name LIKE 'DEL_TicketVoiding_LogInfo_Select%'
OR  name LIKE 'DEL_TicketVoiding_LogInfo_WC_Select%'
OR  name LIKE 'DEL_TicketVoiding_LogInfo_WO_Select%' --X
OR  name LIKE 'DEL_TicketVoiding_ManageVoidServices_VoidingHistory_Select%'

  /*  File sheet mismatch row 281-306   */
OR name LIKE 'DEL_TicketVoiding_MessageTemplate_Settings_Select%'  
OR name LIKE 'DEL_TicketVoiding_PoolHouseTicket_Select%'  
OR name LIKE 'DEL_TicketVoiding_Request_CheckAbnormalBet%'
OR name LIKE 'DEL_TicketVoiding_Request_Insert%'
OR name LIKE 'DEL_TicketVoiding_Request_Select%'
OR name LIKE 'DEL_TicketVoiding_Request_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_AB_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_ARC_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_DARC_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_HDP_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_KO_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_OU_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_WC_Update%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_WO_Update%' --X
OR name LIKE 'DEL_TicketVoiding_RequestInfo_Copy%'
OR name LIKE 'DEL_TicketVoiding_RequestList_Select%'
OR name LIKE 'DEL_TicketVoiding_TicketRequest_Void_Select%'
OR name LIKE 'DEL_TicketVoiding_Void_Select%'

  /*  File sheet mismatch row 311-318  */
OR name LIKE 'DEL_TicketVoiding_Void14_Select%'
OR name LIKE 'DEL_Ticketvoiding_VoidBetAutomation_Service_Insert%'
OR name LIKE 'DEL_TicketVoiding_VoidBetAutomation_Service_Sel%'
OR name LIKE 'DEL_TicketVoiding_VoidBetAutomation_Service_SelectAll%'
OR name LIKE 'DEL_TicketVoiding_VoidBetAutomation_Service_Upd%'
OR name LIKE 'DEL_TicketVoiding_VoidingHistory_Insert%'
OR name LIKE 'DEL_TicketVoiding_VoidingHistory_Update%'

--------------------------Other
OR name LIKE 'DEL_TicketVoiding_VoidingHistory_Select%'
OR name LIKE 'DEL_TicketVoiding_ABWhiteList_CheckUserName%'
OR name LIKE 'DEL_TicketVoiding_ABWhiteList_Insert%'
OR name LIKE 'DEL_TicketVoiding_ABWhiteList_Select%'
OR name LIKE 'DEL_TicketVoiding_ABWhiteList_SubType_Select%'
OR name LIKE 'DEL_TicketVoiding_ABWhiteList_Update%'
OR name LIKE 'DEL_TicketVoiding_VoidedTransaction_Insert%'
OR name LIKE 'DEL_TicketVoiding_VoidedTransaction_Delete%'
OR name LIKE 'DEL_TicketVoiding_CheckTickets14%'
OR name LIKE 'DEL_TicketVoiding_Reason_Insert%'
OR name LIKE 'DEL_TicketVoiding_Reason_Select%'
OR name LIKE 'DEL_TicketVoiding_ReasonTemplate_Select%'
OR name LIKE 'DEL_TicketVoiding_RequestInfo_Select%'
OR name LIKE 'DEL_TicketVoiding_RequestListInfo_Select%'
OR name LIKE 'DEL_TicketVoiding_CheckTickets14%'
OR name LIKE 'DEL_TicketVoiding_Reason_Insert%'
OR name LIKE 'DEL_TicketVoiding_Reason_Select%'
OR name LIKE 'DEL_TicketVoiding_ReasonTemplate_Select%'
OR name LIKE 'DEL_TicketVoiding_RequestInfo_Select%'
OR name LIKE 'DEL_TicketVoiding_RequestListInfo_Select%'
OR name LIKE 'DEL_TicketVoiding_MessageTemplate_IssueType_Select%'
OR name LIKE 'DEL_TicketVoiding_MessageTemplate_Select%'
OR name LIKE 'DEL_TicketVoiding_MessageTemplate_SubIssueType_Select%'
OR name LIKE 'DEL_TicketVoiding_MessageTemplate_Settings_Select%'
OR name LIKE 'DEL_TicketVoiding_Action_Select%'
OR name LIKE 'DEL_TicketVoiding_LastModifiedDate_Select%'
OR name LIKE 'DEL_TicketVoiding_BettypesForRequest_Select%'
OR name LIKE 'DEL_TicketVoiding_RequestDetail_ACC_Update%'

OR name LIKE 'DEL_TicketVoiding_VoidBetAutomation_AfterVoid_Select%'
OR name LIKE 'DEL_TicketVoiding_VoidBetAutomation_Letstalk_Select%'
OR name LIKE 'DEL_TicketVoiding_Letstalk_Insert%'
OR name LIKE 'DEL_TicketVoiding_Letstalk_Update%'
OR name LIKE 'DEL_TicketVoiding_TicketProcess_Update%'
OR name LIKE 'DEL_Bet_ExecRep_NAP_Admin_01%'
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

