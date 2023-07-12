/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230706@July
	Task: [TVS] Drop SP/tables are not needed on sitedb3 and all sitedb  [Redmine:#190859]  
	DB: DBSIG-bodb02
	
*/
USE bodb02
GO

--Drop SP ALL SITEDB
DECLARE @SPName VARCHAR(MAX)
DECLARE @tmpSPName TABLE ( SPName VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpSPName (SPName)
SELECT 'DROP PROCEDURE ' +name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
  /*  File sheet mismatch row 253-277  */
    name LIKE 'TicketVoiding_AutoUnmark_Select%'
OR  name LIKE 'TicketVoiding_AutoUnmark_Ticket_Select%'
OR  name LIKE 'TicketVoiding_AutoUnmarkSetting_Insert%'
OR  name LIKE 'TicketVoiding_AutoVoidRequest_Ticket_Select%'
OR  name LIKE 'TicketVoiding_CheckUserName%'
OR  name = 'TicketVoiding_CheckVoidBetPermission'
OR  name LIKE 'TicketVoiding_Email_CheckITUser%'
OR  name LIKE 'TicketVoiding_GeneralInfo_Select%'
OR	name LIKE 'TicketVoiding_LogInfo_DARC_Select%'
OR  name LIKE 'TicketVoiding_LogInfo_HDP_Select%'
OR  name LIKE 'TicketVoiding_LogInfo_KO_Select%'
OR  name LIKE 'TicketVoiding_LogInfo_OU_Select%'
OR  name LIKE 'TicketVoiding_LogInfo_Select%'
OR  name LIKE 'TicketVoiding_LogInfo_WC_Select%'
OR  name LIKE 'TicketVoiding_LogInfo_WO_Select%' --X
OR  name LIKE 'TicketVoiding_ManageVoidServices_VoidingHistory_Select%'

  /*  File sheet mismatch row 281-306   */
OR name LIKE 'TicketVoiding_MessageTemplate_Settings_Select%'  
OR name LIKE 'TicketVoiding_PoolHouseTicket_Select%'  
OR name LIKE 'TicketVoiding_Request_CheckAbnormalBet%'
OR name LIKE 'TicketVoiding_Request_Insert%'
OR name LIKE 'TicketVoiding_Request_Select%'
OR name LIKE 'TicketVoiding_Request_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_AB_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_ARC_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_DARC_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_HDP_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_KO_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_OU_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_WC_Update%'
OR name LIKE 'TicketVoiding_RequestDetail_WO_Update%' --X
OR name LIKE 'TicketVoiding_RequestInfo_Copy%'
OR name LIKE 'TicketVoiding_RequestList_Select%'
OR name LIKE 'TicketVoiding_TicketRequest_Void_Select%'
OR name LIKE 'TicketVoiding_Void_Select%'

  /*  File sheet mismatch row 311-318  */
OR name LIKE 'TicketVoiding_Void14_Select%'
OR name LIKE 'Ticketvoiding_VoidBetAutomation_Service_Insert%'
OR name LIKE 'TicketVoiding_VoidBetAutomation_Service_Sel%'
OR name LIKE 'TicketVoiding_VoidBetAutomation_Service_SelectAll%'
OR name LIKE 'TicketVoiding_VoidBetAutomation_Service_Upd%'
OR name LIKE 'TicketVoiding_VoidingHistory_Insert%'
OR name LIKE 'TicketVoiding_VoidingHistory_Update%'

--------------------------Other
OR name LIKE 'TicketVoiding_VoidingHistory_Select%'
OR name LIKE 'TicketVoiding_ABWhiteList_CheckUserName%'
OR name LIKE 'TicketVoiding_ABWhiteList_Insert%'
OR name LIKE 'TicketVoiding_ABWhiteList_Select%'
OR name LIKE 'TicketVoiding_ABWhiteList_SubType_Select%'
OR name LIKE 'TicketVoiding_ABWhiteList_Update%'
OR name LIKE 'TicketVoiding_VoidedTransaction_Insert%'
OR name LIKE 'TicketVoiding_VoidedTransaction_Delete%'
OR name LIKE 'TicketVoiding_CheckTickets14%'
OR name LIKE 'TicketVoiding_Reason_Insert%'
OR name LIKE 'TicketVoiding_Reason_Select%'
OR name LIKE 'TicketVoiding_ReasonTemplate_Select%'
OR name LIKE 'TicketVoiding_RequestInfo_Select%'
OR name LIKE 'TicketVoiding_RequestListInfo_Select%'
OR name LIKE 'TicketVoiding_CheckTickets14%'
OR name LIKE 'TicketVoiding_Reason_Insert%'
OR name LIKE 'TicketVoiding_Reason_Select%'
OR name LIKE 'TicketVoiding_ReasonTemplate_Select%'
OR name LIKE 'TicketVoiding_RequestInfo_Select%'
OR name LIKE 'TicketVoiding_RequestListInfo_Select%'
OR name LIKE 'TicketVoiding_MessageTemplate_IssueType_Select%'
OR name LIKE 'TicketVoiding_MessageTemplate_Select%'
OR name LIKE 'TicketVoiding_MessageTemplate_SubIssueType_Select%'
OR name LIKE 'TicketVoiding_MessageTemplate_Settings_Select%'
OR name LIKE 'TicketVoiding_Action_Select%'
OR name LIKE 'TicketVoiding_LastModifiedDate_Select%'
OR name LIKE 'TicketVoiding_BettypesForRequest_Select%'
OR name LIKE 'TicketVoiding_RequestDetail_ACC_Update%'

OR name LIKE 'TicketVoiding_VoidBetAutomation_AfterVoid_Select%'
OR name LIKE 'TicketVoiding_VoidBetAutomation_Letstalk_Select%'
OR name LIKE 'TicketVoiding_Letstalk_Insert%'
OR name LIKE 'TicketVoiding_Letstalk_Update%'
OR name LIKE 'TicketVoiding_TicketProcess_Update%'
OR name LIKE 'Bet_ExecRep_NAP_Admin_01%'
)
SELECT * FROM @tmpSPName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpSPName
	SET @SPName = SPName, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@SPName)

END



