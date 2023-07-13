/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 Redmineid:#188707 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230602@Louisa: Checking data before migration - table group 3 [Redmineid:#188707] 					
	
	Note: 
		BalCreditCasino ---> not exists data in BalCreditCasinoPending with(nolock)
							and table BalanceUpdateSetting has PendingLiveCS_State <> 0
		BalCreditOthers ---> not exists data in bodb02.dbo.BalCreditOthersPending  with(nolock)
							and table BalanceUpdateSetting has PendingOS_State <> 0
		BalCreditSports ---> not exists data in bodb02.dbo.BalCreditSportsPending  with(nolock)
							and table BalanceUpdateSetting has PendingCS_State <> 0
		BalDebitCasino  ---> not exists data in bodb02.dbo.BalDebitCasinoPending  with(nolock)
		BalDebitOthers  ---> not exists data in bodb02.dbo.BalDebitOthersPending  with(nolock)
		BalDebitSports  ---> not exists data in bodb02.dbo.BalDebitSportsPending  with(nolock)

		CustLimitBet_LIC, CustLimitBetHistory ---> not exists running data in CustLimitBetQueue


*/

USE SiteDBtmp
GO
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditCasinoPending bl WITH(NOLOCK) --waiting return no data
	SELECT TOP 1 1 FROM bodb02.dbo.BalanceUpdateSetting  WITH(NOLOCK) WHERE VName = 'PendingLiveCS_State' AND VValue <> '0' --waiting return no data

	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditOthersPending bl WITH(NOLOCK) --waiting return no data
	SELECT TOP 1 1 FROM bodb02.dbo.BalanceUpdateSetting  WITH(NOLOCK) WHERE VName = 'PendingOS_State' AND VValue <> '0' --waiting return no data
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditSportsPending bl WITH(NOLOCK)--waiting return no data
	SELECT TOP 1 1 FROM bodb02.dbo.BalanceUpdateSetting  WITH(NOLOCK) WHERE VName = 'PendingCS_State' AND VValue <> '0'--waiting return no data
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitCasinoPending bl WITH(NOLOCK)
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitOthersPending bl WITH(NOLOCK)

	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitSportsPending bl WITH(NOLOCK)

	SELECT TOP 1 QueueID FROM bodb02.dbo.CustLimitBetQueue q WITH(NOLOCK) where q.statusid  = 0
	