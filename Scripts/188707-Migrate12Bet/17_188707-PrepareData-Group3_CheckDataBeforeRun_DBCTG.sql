/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 Redmineid:#188707 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230602@Louisa: Checking data before migration - table group 3 [Redmineid:#188707] 					
	
	Note: 
		BalCreditCasino ---> not exists data in BalCreditCasinoPending with(nolock)
                        ---> not exists data in bodb02.dbo.BalCreditCasinoPending_Staging  with(nolock)
		BalCreditOthers ---> not exists data in bodb02.dbo.BalCreditOthersPending  with(nolock)
						---> not exists data in bodb02.dbo.BalCreditOthersPending_Staging  with(nolock)
		BalCreditSports ---> not exists data in bodb02.dbo.BalCreditSportsPending  with(nolock)
						---> not exists data in bodb02.dbo.BalCreditSportsPending_Staging  with(nolock)
		BalDebitCasino  ---> not exists data in bodb02.dbo.BalDebitCasinoPending  with(nolock)
		BalDebitOthers  ---> not exists data in bodb02.dbo.BalDebitOthersPending  with(nolock)
		BalDebitSports  ---> not exists data in bodb02.dbo.BalDebitSportsPending  with(nolock)

		CustLimitBet_LIC, CustLimitBetHistory ---> not exists running data in CustLimitBetQueue


*/

USE SiteDBtmp
GO
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditCasinoPending bl WITH(NOLOCK)
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditCasinoPending_Staging bl WITH(NOLOCK)

	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditOthersPending bl WITH(NOLOCK)
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditOthersPending_Staging bl WITH(NOLOCK)
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditSportsPending bl WITH(NOLOCK)
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditSportsPending_Staging bl WITH(NOLOCK)
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitCasinoPending bl WITH(NOLOCK)
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitOthersPending bl WITH(NOLOCK)

	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitSportsPending bl WITH(NOLOCK)

	SELECT TOP 1 QueueID FROM bodb02.dbo.CustLimitBetQueue q WITH(NOLOCK) where q.statusid  = 0
	