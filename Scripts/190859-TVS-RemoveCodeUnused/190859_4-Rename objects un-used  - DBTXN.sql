/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230303@July
	Task: Rename Objects un-used  [Redmine:#190859]  
	DB: DBTXN-bodb02
	
*/
USE bodb02
GO

/*TABLES***********************************************************************************************************/

IF OBJECT_ID('TicketVoiding_Void_Service','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_Void_Service','DEL_TicketVoiding_Void_Service';
GO
IF OBJECT_ID('TicketVoiding_RequestDetail_MixParlay','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_RequestDetail_MixParlay','DEL_TicketVoiding_RequestDetail_MixParlay';
GO
IF OBJECT_ID('TicketVoiding_AutoMarkService_AutoSetting','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_AutoMarkService_AutoSetting','DEL_TicketVoiding_AutoMarkService_AutoSetting';
GO
IF OBJECT_ID('TicketVoiding_AutoVoidRequest_Queue','U') IS NOT NULL 
	EXEC sp_rename 'dbo.TicketVoiding_AutoVoidRequest_Queue','DEL_TicketVoiding_AutoVoidRequest_Queue';
GO

/*SPS***********************************************************************************************************/

DECLARE @command VARCHAR(MAX)
DECLARE @tmpRenameObjectsName TABLE ( command VARCHAR(MAX), IsRename BIT)

INSERT INTO @tmpRenameObjectsName (command)
SELECT 'sp_rename ' + name + ', DEL_' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
 --Live Casino
	name LIKE 'NAP_BettransSelSpecialDel_LiveCS%'
OR  name LIKE 'NAP_BettransDelSpecial_LiveCS%'
OR  name LIKE 'NAP_BettransSelRecoverBet_LiveCS%'
OR  name LIKE 'NAP_BettransRecoverBet_LiveCS%'
--BetTrade
OR  name LIKE 'NAP_CheckNegativeBalanceBetTradeTransaction%'
OR  name LIKE 'NAP_VoidBetTradeTransaction_Sel%'
OR  name LIKE 'NAP_VoidBetTradeTransaction_Del%'
OR  name LIKE 'NAP_RecoverBetTradeTransaction_Del%'
OR  name LIKE 'NAP_RecoverBetTradeTransaction_Sel%'
--Outright
OR  name LIKE 'NAP_BettransDelSpecial_LeagueSelOutright%'
OR  name LIKE 'NAP_BettransDelSpecial_OutrightSel%'
OR  name LIKE 'NAP_SpecialDelete_VoidOutright_Select%'
OR  name LIKE 'NAP_SpecialDelete_VoidOutright_Update%'
--NumberGame (Recover)
OR  name LIKE 'NAP_BettransSelRecoverBet_NumberGame%'
OR  name LIKE 'NAP_BettransRecoverBet_NumberGame%'
--MetricGaming
OR  name LIKE 'NAP_VoidMetricGaming_Sel%'
OR  name LIKE 'NAP_VoidMetricGaming_Del%'
OR  name LIKE 'NAP_InvalidGoalScorerTicketVoid%'
OR  name LIKE 'NAP_SpecialDelete_CheckingMarkedTransaction%'
--TVS		  
OR  name LIKE 'TicketVoiding_Request_CheckMatchCal%'
OR  name LIKE 'TicketVoiding_BalanceMember_Select%'
OR  name LIKE 'TicketVoiding_AutoVoid_Update_MP%'
OR  name LIKE 'TicketVoiding_AutoVoid_Queue_MP_Job%'
OR  name LIKE 'TicketVoiding_AutoMarkProblemAccount_Job%'
OR  name LIKE 'TicketVoiding_AutoMarkService_AutoSetting_Sel%'
OR  name LIKE 'TicketVoiding_AutoMarkService_AutoSetting_Upd%'
OR  name LIKE 'TicketVoiding_AutoVoid_Queue_Job%'
OR  name LIKE 'TicketVoiding_AutoVoid_Update%'
OR  name LIKE 'TicketVoiding_VoidBetAutomation_Service_SelectAll%'
OR  name LIKE 'TicketVoiding_AutoVoidFormulaBets_Single%'
OR  name LIKE 'TicketVoiding_AutoVoidFormulaBets_Single_Update%'
OR  name LIKE 'TicketVoiding_Void_Service_Select%'
OR  name LIKE 'TicketVoiding_Void_Service_Update%'
OR  name LIKE 'TicketVoiding_ManageVoidServices_VoidService_Select%'
OR  name LIKE 'TicketVoiding_Request_CheckingProcess%'

--Change config DBTXN -> DBPRO - Remove DBTXN
OR  name LIKE 'TicketVoiding_RelatedEvent_Select%'
OR  name LIKE 'TicketVoiding_SubIssueType_AutoSelect%'

--Remove version --ORG removed
OR  name LIKE 'NAP_Admin_CheckingCashOutProcess%'
OR  name LIKE 'TicketVoiding_RequestDetail_Insert%'
OR  name LIKE 'TicketVoiding_RequestDetail_Update%'
OR  name LIKE 'TicketVoiding_RequestDetailTicket_Single_Insert%'
OR  name LIKE 'TicketVoiding_RequestDetailTicket_SubParlay_Insert%'
OR  name LIKE 'TicketVoiding_VoidTime_Select%'
OR  name LIKE 'NAP_SpecialDelete_CheckNegativeBalanceCashOutTransaction%'
OR  name LIKE 'Nap_SpecialDelete_MarkedTickets_ManualUpdate%'

-----------------------RUN CONTINUTED
OR  name LIKE 'NAP_SpecialDelete_CheckVoidBetPermission%'
OR  name LIKE 'NAP_SpecialDelete_TransInfo_Select%'
OR  name LIKE 'TicketVoiding_MatchInfo_Select%'
OR  name LIKE 'TicketVoiding_ScoreInfo_Select%'
OR  name LIKE 'TicketVoiding_Queue_Checking%'
OR  name LIKE 'TicketVoiding_CheckingProcess%'
OR  name LIKE 'NAP_BettransSpecialDelBetID_Del%'
OR  name LIKE 'DBA_VoidTickets'
OR  name LIKE 'DBA_VoidTickets14'
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
