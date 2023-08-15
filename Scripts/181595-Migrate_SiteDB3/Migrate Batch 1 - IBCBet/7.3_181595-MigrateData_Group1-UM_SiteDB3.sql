/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - in UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Migrate data for SiteDB3 Batch 1 - Table group 1 [Redmineid:#181595]
		
*/

---- Note: Run on SITEDB03 only
---- Table Group 1: 8 tables balance

USE bodb02
GO

	------------------------------------------------------------------------------------------
	--insert data 8 table balances
	------------------------------------------------------------------------------------------

	-- BalDebitCasino
	INSERT INTO  dbo.BalDebitCasino(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitCasino_UM bal WITH (NOLOCK)

	-- BalDebitOthers
	INSERT INTO dbo.BalDebitOthers(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitOthers_UM bal WITH (NOLOCK)

	-- BalDebitSports
	INSERT INTO dbo.BalDebitSports(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitSports_UM bal WITH (NOLOCK)

	-- BalDebitTransfer
	INSERT INTO dbo.BalDebitTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitTransfer_UM bal WITH (NOLOCK)

	-- BalCreditCasino
	INSERT INTO dbo.BalCreditCasino (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditCasino_UM bal WITH (NOLOCK)

	-- BalCreditOthers
	INSERT INTO dbo.BalCreditOthers (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditOthers_UM bal WITH (NOLOCK)

	-- BalCreditSports
	INSERT INTO dbo.BalCreditSports (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditSports_UM bal WITH (NOLOCK)

	-- BalCreditTransfer
	INSERT INTO  dbo.BalCreditTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditTransfer_UM bal WITH (NOLOCK)












