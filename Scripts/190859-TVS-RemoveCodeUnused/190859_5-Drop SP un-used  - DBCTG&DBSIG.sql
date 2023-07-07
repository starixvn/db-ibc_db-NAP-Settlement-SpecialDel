/*<info serverAlias="DBCTG-bodb02, DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221207@July
	Task: Drop SP un-used - Special Delete & TVS  [Redmine:#180625]  
	DB: DBCTG-bodb02, DBSIG-bodb02
		   
*/
USE bodb02
GO

DECLARE @SPName VARCHAR(MAX)
DECLARE @tmpSPName TABLE ( SPName VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpSPName (SPName)
SELECT 'DROP PROCEDURE ' +name
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
OR  name LIKE 'TicketVoiding_Queue_Checking%'
OR  name LIKE 'TicketVoiding_CheckingProcess%'
OR  name LIKE 'NAP_BettransSpecialDelBetID_Del%'
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
