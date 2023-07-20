/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230303@July
	Task: Drop Objects un-used  [Redmine:#190859]  
	DB: DBTXN-bodb02
	
*/
USE bodb02
GO

/*TABLES***********************************************************************************************************/

IF OBJECT_ID('DEL_TicketVoiding_Void_Service','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_Void_Service
GO
IF OBJECT_ID('DEL_TicketVoiding_RequestDetail_MixParlay','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_RequestDetail_MixParlay
GO
IF OBJECT_ID('DEL_TicketVoiding_AutoMarkService_AutoSetting','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_AutoMarkService_AutoSetting
GO
IF OBJECT_ID('DEL_TicketVoiding_AutoVoidRequest_Queue','U') IS NOT NULL 
	DROP TABLE DEL_TicketVoiding_AutoVoidRequest_Queue
GO

/*SPS***********************************************************************************************************/

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
 --Live Casino
	name LIKE 'DEL_NAP_BettransSelSpecialDel_LiveCS%'
OR  name LIKE 'DEL_NAP_BettransDelSpecial_LiveCS%'
OR  name LIKE 'DEL_NAP_BettransSelRecoverBet_LiveCS%'
OR  name LIKE 'DEL_NAP_BettransRecoverBet_LiveCS%'
--BetTrade
OR  name LIKE 'DEL_NAP_CheckNegativeBalanceBetTradeTransaction%'
OR  name LIKE 'DEL_NAP_VoidBetTradeTransaction_Sel%'
OR  name LIKE 'DEL_NAP_VoidBetTradeTransaction_Del%'
OR  name LIKE 'DEL_NAP_RecoverBetTradeTransaction_Del%'
OR  name LIKE 'DEL_NAP_RecoverBetTradeTransaction_Sel%'
--Outright
OR  name LIKE 'DEL_NAP_BettransDelSpecial_LeagueSelOutright%'
OR  name LIKE 'DEL_NAP_BettransDelSpecial_OutrightSel%'
OR  name LIKE 'DEL_NAP_SpecialDelete_VoidOutright_Select%'
OR  name LIKE 'DEL_NAP_SpecialDelete_VoidOutright_Update%'
--NumberGame (Recover)
OR  name LIKE 'DEL_NAP_BettransSelRecoverBet_NumberGame%'
OR  name LIKE 'DEL_NAP_BettransRecoverBet_NumberGame%'
--MetricGaming
OR  name LIKE 'DEL_NAP_VoidMetricGaming_Sel%'
OR  name LIKE 'DEL_NAP_VoidMetricGaming_Del%'
OR  name LIKE 'DEL_NAP_InvalidGoalScorerTicketVoid%'
OR  name LIKE 'DEL_NAP_SpecialDelete_CheckingMarkedTransaction%'
--TVS		  
OR  name LIKE 'DEL_TicketVoiding_Request_CheckMatchCal%'
OR  name LIKE 'DEL_TicketVoiding_BalanceMember_Select%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoid_Update_MP%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoid_Queue_MP_Job%'
OR  name LIKE 'DEL_TicketVoiding_AutoMarkProblemAccount_Job%'
OR  name LIKE 'DEL_TicketVoiding_AutoMarkService_AutoSetting_Sel%'
OR  name LIKE 'DEL_TicketVoiding_AutoMarkService_AutoSetting_Upd%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoid_Queue_Job%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoid_Update%'
OR  name LIKE 'DEL_TicketVoiding_VoidBetAutomation_Service_SelectAll%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoidFormulaBets_Single%'
OR  name LIKE 'DEL_TicketVoiding_AutoVoidFormulaBets_Single_Update%'
OR  name LIKE 'DEL_TicketVoiding_Void_Service_Select%'
OR  name LIKE 'DEL_TicketVoiding_Void_Service_Update%'
OR  name LIKE 'DEL_TicketVoiding_ManageVoidServices_VoidService_Select%'
OR  name LIKE 'DEL_TicketVoiding_Request_CheckingProcess%'

--Change config DBTXN -> DBPRO - Remove DBTXN
OR  name LIKE 'DEL_TicketVoiding_RelatedEvent_Select%'
OR  name LIKE 'DEL_TicketVoiding_SubIssueType_AutoSelect%'

--Remove version --ORG removed
OR  name LIKE 'DEL_NAP_Admin_CheckingCashOutProcess%'
OR  name LIKE 'DEL_TicketVoiding_RequestDetail_Insert%'
OR  name LIKE 'DEL_TicketVoiding_RequestDetail_Update%'
OR  name LIKE 'DEL_TicketVoiding_RequestDetailTicket_Single_Insert%'
OR  name LIKE 'DEL_TicketVoiding_RequestDetailTicket_SubParlay_Insert%'
OR  name LIKE 'DEL_TicketVoiding_VoidTime_Select%'
OR  name LIKE 'DEL_NAP_SpecialDelete_CheckNegativeBalanceCashOutTransaction%'
OR  name LIKE 'DEL_Nap_SpecialDelete_MarkedTickets_ManualUpdate%'

-----------------------RUN CONTINUTED
OR  name LIKE 'DEL_NAP_SpecialDelete_CheckVoidBetPermission%'
OR  name LIKE 'DEL_NAP_SpecialDelete_TransInfo_Select%'
OR  name LIKE 'DEL_TicketVoiding_MatchInfo_Select%'
OR  name LIKE 'DEL_TicketVoiding_ScoreInfo_Select%'
OR  name LIKE 'DEL_TicketVoiding_Queue_Checking%'
OR  name LIKE 'DEL_TicketVoiding_CheckingProcess%'
OR  name LIKE 'DEL_NAP_BettransSpecialDelBetID_Del%'
OR  name LIKE 'DEL_DBA_VoidTickets'
OR  name LIKE 'DEL_DBA_VoidTickets14'
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


