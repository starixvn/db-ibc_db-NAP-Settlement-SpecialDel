/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221207@July
	Task: Drop SP un-used - Special Delete  [Redmine:#180625]  
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
GO
IF OBJECT_ID('NAP_PlayerSelect', 'P') IS NOT NULL
	DROP PROCEDURE NAP_PlayerSelect;
GO
IF OBJECT_ID('NAP_InvalidGoalScorerTicketVoid', 'P') IS NOT NULL
	DROP PROCEDURE NAP_InvalidGoalScorerTicketVoid;
GO
IF OBJECT_ID('NAP_EventSelect', 'P') IS NOT NULL
	DROP PROCEDURE NAP_EventSelect;
GO
IF OBJECT_ID('NAP_SpecialDelete_CheckingMarkedTransaction', 'P') IS NOT NULL
	DROP PROCEDURE NAP_SpecialDelete_CheckingMarkedTransaction;
GO

/****************************************** TVS ************************************/