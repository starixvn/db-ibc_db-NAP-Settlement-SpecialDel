/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220927@Victoria
    Task: Data Migration for SiteDB - Truncate table for Existing Licensees
    DB: DBSIG-bodb02

	 Revisions:
		- 20220927@Victoria: TRUNCATE for the tables [Redmineid:#178145]								
*/

	USE bodb02
	GO

	--Bet Ticket tables
	TRUNCATE TABLE dbo.bettrans			
	TRUNCATE TABLE dbo.bettrans14
	TRUNCATE TABLE dbo.bettransG			
	TRUNCATE TABLE dbo.bettransG14
	TRUNCATE TABLE dbo.BettransInfo		
	TRUNCATE TABLE dbo.BettransInfo14
	TRUNCATE TABLE dbo.bettransLC			
	TRUNCATE TABLE dbo.bettransLC14
	TRUNCATE TABLE dbo.bettransm			
	TRUNCATE TABLE dbo.bettransm14
	TRUNCATE TABLE dbo.bettransRnG			
	TRUNCATE TABLE dbo.bettransRnG14
	TRUNCATE TABLE dbo.translog			
	TRUNCATE TABLE dbo.translog14
	TRUNCATE TABLE dbo.zzzbettrans			
	TRUNCATE TABLE dbo.zzzbettransm
	TRUNCATE TABLE dbo.Transfer			
	TRUNCATE TABLE dbo.Transfer_Coll		
	TRUNCATE TABLE dbo.TransferInfo
	TRUNCATE TABLE dbo.BetParlayDetail		
	TRUNCATE TABLE dbo.BetParlayResult

	--Balance tables
	TRUNCATE TABLE dbo.BalCreditCasino
	TRUNCATE TABLE dbo.BalCreditOthers
	TRUNCATE TABLE dbo.BalCreditSports
	TRUNCATE TABLE dbo.BalCreditTransfer
	TRUNCATE TABLE dbo.BalDebitCasino
	TRUNCATE TABLE dbo.BalDebitOthers
	TRUNCATE TABLE dbo.BalDebitSports
	TRUNCATE TABLE dbo.BalDebitTransfer
	TRUNCATE TABLE dbo.BalNetPosition
	TRUNCATE TABLE dbo.balanceTable
	TRUNCATE TABLE dbo.balanceTable_tmp
	TRUNCATE TABLE dbo.BalanceTable_tmp_cal

	--Other Tables
	TRUNCATE TABLE  dbo.Bonus_sum_winloss
	TRUNCATE TABLE  dbo.BonusAdjustmentTransfer
	TRUNCATE TABLE  dbo.BonusTrans
	TRUNCATE TABLE  dbo.BonusWalletCredit
	TRUNCATE TABLE  dbo.BonusWalletDebit
	TRUNCATE TABLE  dbo.BonusWalletPending
	TRUNCATE TABLE  dbo.CashOutSelling
	TRUNCATE TABLE  dbo.CustLimitBet_LIC
	TRUNCATE TABLE  dbo.CustLimitBetHistory_LIC
	TRUNCATE TABLE  dbo.Task_bettrans14_IP2Country
	TRUNCATE TABLE  dbo.Task_bettransLC14_IP2Country
	TRUNCATE TABLE  dbo.Task_bettransRNG14_IP2Country

	--List Table Truncate
	TRUNCATE TABLE [dbo].[BalancePendingProcessed]
	TRUNCATE TABLE [dbo].[BalCasinoPendingProcessed]
	TRUNCATE TABLE [dbo].[BalOthersPendingProcessed]
	TRUNCATE TABLE [dbo].[BalSportsPendingProcessed]
	TRUNCATE TABLE [dbo].[bettranssum]
	TRUNCATE TABLE [dbo].[CustLimitBet_789]
	TRUNCATE TABLE [dbo].[CustLimitBet_MBC]
	TRUNCATE TABLE [dbo].[CustLimitBetHistory_789]
	TRUNCATE TABLE [dbo].[CustLimitBetHistory_MBC]
	TRUNCATE TABLE [dbo].[sum_winloss]
	TRUNCATE TABLE [dbo].[TicketVoiding_AutoVoidRequest_Queue]
	TRUNCATE TABLE [dbo].[TicketVoiding_Queue]

	--TW List Tables
	TRUNCATE TABLE [dbo].[BalancePendingCreditGame]
	TRUNCATE TABLE [dbo].[BalancePendingDebitGame]
	TRUNCATE TABLE [dbo].[BalCreditCasinoPending]
	TRUNCATE TABLE [dbo].[BalCreditOthersPending]
	TRUNCATE TABLE [dbo].[BalCreditSportsPending]
	TRUNCATE TABLE [dbo].[BalDebitCasinoPending]
	TRUNCATE TABLE [dbo].[BalDebitOthersPending]
	TRUNCATE TABLE [dbo].[BalDebitSportsPending]
	TRUNCATE TABLE [dbo].[Intg_GameRoundBetStake]
	TRUNCATE TABLE [dbo].[LastBetTime]
	TRUNCATE TABLE [dbo].[LastBetTime_Agent]
	TRUNCATE TABLE [dbo].[MarkedTransaction]
	TRUNCATE TABLE [dbo].[NetPositionCalculationLog]
	TRUNCATE TABLE [dbo].[NetPositionTrans]
	TRUNCATE TABLE [dbo].[Task_Cust_CheckBalance_Exception]
	TRUNCATE TABLE [dbo].[Task_Cust_BalanceProblem1]

	TRUNCATE TABLE [dbo].[Task_Cust_CheckBalanceVerify1]
	TRUNCATE TABLE [dbo].[NetPositionTrans_UAT]
	TRUNCATE TABLE [dbo].[RejectTicketLog]
	TRUNCATE TABLE [dbo].[NetPositionCalculationLog_UAT]
	TRUNCATE TABLE [dbo].[NetPositionQueue_UAT]
	TRUNCATE TABLE [dbo].[CS_CustSuper]
	TRUNCATE TABLE [dbo].[AcceptTicketLog]
	TRUNCATE TABLE [dbo].[BalanceErr]
	TRUNCATE TABLE [dbo].[CustLimitBet_QueueRetry]
	TRUNCATE TABLE [dbo].[IntgUserLog]