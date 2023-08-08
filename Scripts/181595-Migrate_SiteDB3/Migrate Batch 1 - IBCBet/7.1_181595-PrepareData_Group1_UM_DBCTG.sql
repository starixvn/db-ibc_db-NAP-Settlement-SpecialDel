/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data Batch 1 - during UM Settlement [Redmineid:#181595] 

		8 table balances:
			BalDebitCasino 	,BalDebitOthers  ,BalDebitSports  ,BalDebitTransfer 
			BalCreditCasino ,BalCreditOthers ,BalCreditSports ,BalCreditTransfer 		
*/

/*
	IF OBJECT_ID('BalDebitCasino_UM') IS NOT NULL
	DROP TABLE BalDebitCasino_UM

	IF OBJECT_ID('BalDebitOthers_UM') IS NOT NULL 
	DROP TABLE BalDebitOthers_UM

	IF OBJECT_ID('BalDebitSports_UM') IS NOT NULL 
	DROP TABLE BalDebitSports_UM

	IF OBJECT_ID('BalDebitTransfer_UM') IS NOT NULL 
	DROP TABLE BalDebitTransfer_UM

	IF OBJECT_ID('BalCreditCasino_UM') IS NOT NULL 
	DROP TABLE BalCreditCasino_UM

	IF OBJECT_ID('BalCreditOthers_UM') IS NOT NULL 
	DROP TABLE BalCreditOthers_UM

	IF OBJECT_ID('BalCreditSports_UM') IS NOT NULL 
	DROP TABLE BalCreditSports_UM

	IF OBJECT_ID('BalCreditTransfer_UM') IS NOT NULL 
	DROP TABLE BalCreditTransfer_UM
*/

USE SiteDBtmp
GO

	--copy data bodb02.dbo.BalDebitCasino
	SELECT bal.custid, bal.Balance
	INTO BalDebitCasino_UM
	FROM bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.BalDebitOthers
	SELECT bal.custid, bal.Balance
	INTO BalDebitOthers_UM
	FROM bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.BalDebitSports
	SELECT bal.custid, bal.Balance
	INTO BalDebitSports_UM
	FROM bodb02.dbo.BalDebitSports bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.BalDebitTransfer
	SELECT bal.custid, bal.Balance
	INTO BalDebitTransfer_UM
	FROM bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.BalCreditCasino
	SELECT bal.custid, bal.Balance
	INTO BalCreditCasino_UM
	FROM bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.BalCreditOthers
	SELECT bal.custid, bal.Balance
	INTO BalCreditOthers_UM
	FROM bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalCreditSports
	SELECT bal.custid, bal.Balance
	INTO BalCreditSports_UM
	FROM bodb02.dbo.BalCreditSports bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalCreditTransfer
	SELECT bal.custid, bal.Balance
	INTO BalCreditTransfer_UM
	FROM bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = bal.custid


























