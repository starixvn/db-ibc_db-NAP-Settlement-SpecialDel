/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221207@July
	Task: Drop SP un-used - Special Delete & TVS  [Redmine:#180625]  
	DB: DBCTG-bodb02,DBSIG-bodb02
		   
*/
USE bodb02
GO

/****************************************** SPECIAL DELETE ************************************/
--Live Casino
IF OBJECT_ID('NAP_BettransSelSpecialDel_LiveCS', 'P') IS NOT NULL
	DROP PROCEDURE NAP_BettransSelSpecialDel_LiveCS;
GO
IF OBJECT_ID('NAP_BettransDelSpecial_LiveCS', 'P') IS NOT NULL
	DROP PROCEDURE NAP_BettransDelSpecial_LiveCS;
GO
IF OBJECT_ID('NAP_BettransSelRecoverBet_LiveCS', 'P') IS NOT NULL
	DROP PROCEDURE NAP_BettransSelRecoverBet_LiveCS;
GO
IF OBJECT_ID('NAP_BettransRecoverBet_LiveCS', 'P') IS NOT NULL
	DROP PROCEDURE NAP_BettransRecoverBet_LiveCS;
GO
--BetTrade
IF OBJECT_ID('NAP_CheckNegativeBalanceBetTradeTransaction', 'P') IS NOT NULL
	DROP PROCEDURE NAP_CheckNegativeBalanceBetTradeTransaction;
GO
IF OBJECT_ID('NAP_VoidBetTradeTransaction_Sel', 'P') IS NOT NULL
	DROP PROCEDURE NAP_VoidBetTradeTransaction_Sel;
GO
IF OBJECT_ID('NAP_VoidBetTradeTransaction_Del', 'P') IS NOT NULL
	DROP PROCEDURE NAP_VoidBetTradeTransaction_Del;
GO
IF OBJECT_ID('NAP_RecoverBetTradeTransaction_Del', 'P') IS NOT NULL
	DROP PROCEDURE NAP_RecoverBetTradeTransaction_Del;
GO
IF OBJECT_ID('NAP_RecoverBetTradeTransaction_Sel', 'P') IS NOT NULL
	DROP PROCEDURE NAP_RecoverBetTradeTransaction_Sel;
GO
--Outright
IF OBJECT_ID('NAP_BettransDelSpecial_LeagueSelOutright', 'P') IS NOT NULL
	DROP PROCEDURE NAP_BettransDelSpecial_LeagueSelOutright;
GO
IF OBJECT_ID('NAP_BettransDelSpecial_OutrightSel', 'P') IS NOT NULL
	DROP PROCEDURE NAP_BettransDelSpecial_OutrightSel;
GO
IF OBJECT_ID('NAP_SpecialDelete_VoidOutright_Select', 'P') IS NOT NULL
	DROP PROCEDURE NAP_SpecialDelete_VoidOutright_Select;
GO
IF OBJECT_ID('NAP_SpecialDelete_VoidOutright_Update', 'P') IS NOT NULL
	DROP PROCEDURE NAP_SpecialDelete_VoidOutright_Update;
GO
--NumberGame (Recover)
IF OBJECT_ID('dbo.NAP_BettransSelRecoverBet_NumberGame', 'P') IS NOT NULL
	DROP PROCEDURE dbo.NAP_BettransSelRecoverBet_NumberGame;
GO
IF OBJECT_ID('dbo.NAP_BettransRecoverBet_NumberGame', 'P') IS NOT NULL
	DROP PROCEDURE dbo.NAP_BettransRecoverBet_NumberGame;
GO
--MetricGaming
IF OBJECT_ID('NAP_VoidMetricGaming_Sel', 'P') IS NOT NULL
	DROP PROCEDURE NAP_VoidMetricGaming_Sel;
GO
IF OBJECT_ID('NAP_VoidMetricGaming_Del', 'P') IS NOT NULL
	DROP PROCEDURE NAP_VoidMetricGaming_Del;

IF OBJECT_ID('NAP_InvalidGoalScorerTicketVoid', 'P') IS NOT NULL
	DROP PROCEDURE NAP_InvalidGoalScorerTicketVoid;
GO
IF OBJECT_ID('NAP_SpecialDelete_CheckingMarkedTransaction', 'P') IS NOT NULL
	DROP PROCEDURE NAP_SpecialDelete_CheckingMarkedTransaction;
GO

/****************************************** TVS ************************************/

IF OBJECT_ID('TicketVoiding_Request_CheckMatchCal', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_Request_CheckMatchCal;
GO
IF OBJECT_ID('TicketVoiding_BalanceMember_Select', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_BalanceMember_Select;
GO
IF OBJECT_ID('TicketVoiding_AutoVoid_Queue_MP_Job', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoVoid_Queue_MP_Job;
GO
IF OBJECT_ID('TicketVoiding_AutoVoid_Update_MP', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoVoid_Update_MP;
GO
IF OBJECT_ID('TicketVoiding_AutoMarkProblemAccount_Job', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoMarkProblemAccount_Job;
GO
IF OBJECT_ID('TicketVoiding_AutoMarkService_AutoSetting_Sel', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoMarkService_AutoSetting_Sel;
GO
IF OBJECT_ID('TicketVoiding_AutoMarkService_AutoSetting_Upd', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoMarkService_AutoSetting_Upd;
GO
IF OBJECT_ID('TicketVoiding_AutoVoid_Update', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoVoid_Update;
GO
IF OBJECT_ID('TicketVoiding_AutoVoid_Queue_Job', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoVoid_Queue_Job;
GO
IF OBJECT_ID('TicketVoiding_AutoVoidFormulaBets_Single', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoVoidFormulaBets_Single;
GO
IF OBJECT_ID('TicketVoiding_AutoVoidFormulaBets_Single_Update', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_AutoVoidFormulaBets_Single_Update;
GO
IF OBJECT_ID('TicketVoiding_ManageVoidServices_VoidService_Select', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_ManageVoidServices_VoidService_Select;
GO
IF OBJECT_ID('TicketVoiding_Void_Service_Select', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_Void_Service_Select;
GO
IF OBJECT_ID('TicketVoiding_Void_Service_Update', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_Void_Service_Update;
GO
IF OBJECT_ID('TicketVoiding_Request_CheckingProcess', 'P') IS NOT NULL
	DROP PROCEDURE TicketVoiding_Request_CheckingProcess;
GO