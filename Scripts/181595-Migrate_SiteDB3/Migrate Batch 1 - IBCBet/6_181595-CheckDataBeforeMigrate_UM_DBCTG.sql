/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230626@Louisa: Checking data before migration [Redmineid:#181595]					
	
	Note: 
		BalCreditCasino ---> not exists data in BalCreditCasinoPending with(nolock)
		BalCreditOthers ---> not exists data in bodb02.dbo.BalCreditOthersPending  with(nolock)
		BalCreditSports ---> not exists data in bodb02.dbo.BalCreditSportsPending  with(nolock)
		BalDebitCasino  ---> not exists data in bodb02.dbo.BalDebitCasinoPending  with(nolock)
		BalDebitOthers  ---> not exists data in bodb02.dbo.BalDebitOthersPending  with(nolock)
		BalDebitSports  ---> not exists data in bodb02.dbo.BalDebitSportsPending  with(nolock)


*/

USE SiteDBtmp
GO
	
	SELECT TOP 1 1 
	FROM bodb02.dbo.BalCreditCasinoPending bl WITH(NOLOCK) --waiting return no data
		INNER JOIN CustSiteDB3_20230626 c WITH(NOLOCK) ON bl.CustId = c.CustID

	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditOthersPending bl WITH(NOLOCK) --waiting return no data
		INNER JOIN CustSiteDB3_20230626 c WITH(NOLOCK) ON bl.CustId = c.CustID
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalCreditSportsPending bl WITH(NOLOCK)--waiting return no data
		INNER JOIN CustSiteDB3_20230626 c WITH(NOLOCK) ON bl.CustId = c.CustID
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitCasinoPending bl WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 c WITH(NOLOCK) ON bl.CustId = c.CustID
	
	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitOthersPending bl WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 c WITH(NOLOCK) ON bl.CustId = c.CustID

	SELECT TOP 1 1 FROM bodb02.dbo.BalDebitSportsPending bl WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 c WITH(NOLOCK) ON bl.CustId = c.CustID

	