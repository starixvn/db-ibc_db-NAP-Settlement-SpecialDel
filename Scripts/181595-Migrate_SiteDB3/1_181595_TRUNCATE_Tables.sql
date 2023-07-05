/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: TRUNCATE TABLE [Redmineid:#181595] 

*/

----Note: Run on SITEDB03 only

USE bodb02
GO


	TRUNCATE TABLE dbo.balanceTable
	GO 
	TRUNCATE TABLE dbo.balanceTable_tmp
	GO 
	TRUNCATE TABLE dbo.BalanceTable_tmp_cal
	GO 
	TRUNCATE TABLE dbo.BalCreditCasino
	GO 
	TRUNCATE TABLE dbo.BalCreditOthers
	GO 
	TRUNCATE TABLE dbo.BalCreditSports
	GO 
	TRUNCATE TABLE dbo.BalCreditTransfer
	GO 
	TRUNCATE TABLE dbo.BalDebitCasino
	GO 
	TRUNCATE TABLE dbo.BalDebitOthers
	GO 
	TRUNCATE TABLE dbo.BalDebitSports
	GO 
	TRUNCATE TABLE dbo.BalDebitTransfer
	GO 
	TRUNCATE TABLE dbo.BalNetPosition
	GO 
	TRUNCATE TABLE dbo.BetParlayDetail
	GO 
	TRUNCATE TABLE dbo.BetParlayResult
	GO 
	TRUNCATE TABLE dbo.bettrans
	GO 
	TRUNCATE TABLE dbo.bettrans14
	GO 
	TRUNCATE TABLE dbo.bettransG
	GO 
	TRUNCATE TABLE dbo.bettransG14
	GO 
	TRUNCATE TABLE dbo.BettransInfo
	GO 
	TRUNCATE TABLE dbo.BettransInfo14
	GO 
	TRUNCATE TABLE dbo.bettransLC
	GO 
	TRUNCATE TABLE dbo.bettransLC14
	GO 
	TRUNCATE TABLE dbo.bettransm
	GO 
	TRUNCATE TABLE dbo.bettransm14
	GO 
	TRUNCATE TABLE dbo.bettransRnG
	GO 
	TRUNCATE TABLE dbo.bettransRnG14
	GO 
	TRUNCATE TABLE dbo.bettranssum
	GO 
	TRUNCATE TABLE dbo.CashOutSelling
	GO 
	TRUNCATE TABLE dbo.CustLimitBet_789
	GO 
	TRUNCATE TABLE dbo.CustLimitBet_MBC
	GO 
	TRUNCATE TABLE dbo.CustLimitBetHistory_789
	GO 
	TRUNCATE TABLE dbo.CustLimitBetHistory_MBC
	GO 
	TRUNCATE TABLE dbo.MarkedTransaction
	GO 
	TRUNCATE TABLE dbo.NetPositionCalculationLog
	GO 
	TRUNCATE TABLE dbo.NetPositionTrans
	GO 
	TRUNCATE TABLE dbo.ProcessingCustList
	GO 
	TRUNCATE TABLE dbo.Task_bettrans14_IP2Country
	GO 
	TRUNCATE TABLE dbo.Task_bettransLC14_IP2Country
	GO 
	TRUNCATE TABLE dbo.Task_bettransRNG14_IP2Country
	GO 
	TRUNCATE TABLE dbo.Task_Cust_BalanceProblem
	GO 
	TRUNCATE TABLE dbo.Task_Cust_BalanceProblem1
	GO 
	TRUNCATE TABLE dbo.Task_Cust_BalanceProblem1_Manually
	GO 
	TRUNCATE TABLE dbo.Task_Cust_CheckBalance_Exception
	GO 
	TRUNCATE TABLE dbo.Transfer
	GO 
	TRUNCATE TABLE dbo.Transfer_Coll
	GO 
	TRUNCATE TABLE dbo.TransferInfo
	GO 
	TRUNCATE TABLE dbo.translog
	GO 
	TRUNCATE TABLE dbo.translog14
	GO 
	TRUNCATE TABLE dbo.zzzbettrans
	GO 
	TRUNCATE TABLE dbo.zzzbettransm
	GO
	TRUNCATE TABLE dbo.sum_winloss

