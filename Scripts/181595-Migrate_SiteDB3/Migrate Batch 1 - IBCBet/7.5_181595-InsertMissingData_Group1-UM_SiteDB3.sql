/*<info serverAlias="DBSIC-bodb02" EXECuters="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Insert missing data for 8 table balance - UM - Group 1  [Redmineid:#181595]

		8 tables: 
			BalDebitCasino 	,BalDebitOthers  ,BalDebitSports  ,BalDebitTransfer 
			BalCreditCasino ,BalCreditOthers ,BalCreditSports ,BalCreditTransfer 	

*/

USE bodb02
GO

DECLARE @TableName NVARCHAR(50) = 'BalCreditSports' --input table name
		,@__sqlCmd NVARCHAR(max) = ''


DROP TABLE IF exists #t1

CREATE TABLE #t1 (custid INT PRIMARY KEY) 

SET @__sqlCmd = N'
	SELECT b.custid
	FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
	INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
	LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_UM t WITH(NOLOCK)  ON b.custid = t.custid
	WHERE t.custid IS NULL '

SELECT @__sqlCmd

INSERT INTO #t1(custid)
EXEC DBCTG.bodb02.sys.sp_EXECutesql @__sqlCmd

SELECT * FROM #t1

IF @@ROWCOUNT = 0
RETURN
------------------------------------------------------------------------------------------
--insert data 8 table balances
------------------------------------------------------------------------------------------

	-- BalDebitCasino
	IF @TableName = 'BalDebitCasino'
		INSERT INTO  dbo.BalDebitCasino(custid, Balance)
		SELECT bal.custid, bal.Balance
		FROM DBCTG.bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)
			INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalDebitOthers
	ELSE IF @TableName = 'BalDebitOthers'
		INSERT INTO dbo.BalDebitOthers(custid, Balance)
		SELECT bal.custid, bal.Balance
		FROM DBCTG.bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)
			INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalDebitSports
	ELSE  IF @TableName = 'BalDebitSports'
	INSERT INTO dbo.BalDebitSports(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.bodb02.dbo.BalDebitSports bal WITH (NOLOCK)
		INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalDebitTransfer
	ELSE  IF @TableName = 'BalDebitTransfer'
	INSERT INTO dbo.BalDebitTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)
		INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalCreditCasino
	ELSE  IF @TableName = 'BalCreditCasino'
	INSERT INTO dbo.BalCreditCasino (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)
		INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalCreditOthers
	ELSE  IF @TableName = 'BalCreditOthers'
	INSERT INTO dbo.BalCreditOthers (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)
		INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalCreditSports
	ELSE  IF @TableName = 'BalCreditSports'
	INSERT INTO dbo.BalCreditSports (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.bodb02.dbo.BalCreditSports bal WITH (NOLOCK)
		INNER JOIN #t1 t ON bal.custid = t.custid

	-- BalCreditTransfer
	ELSE  IF @TableName = 'BalCreditTransfer'
	INSERT INTO  dbo.BalCreditTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)
		INNER JOIN #t1 t ON bal.custid = t.custid





