/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog_Archive
GO

DECLARE @batchNo INT = 5000

WHILE (1=1)
BEGIN
	UPDATE TOP (@batchNo) s
		SET ActionId = 101
	FROM dbo.SettlementPerformanceLog s with(rowlock,updlock)
	WHERE Sporttype = 18
			AND ResourceId = '0101'
			AND ActionId = 1
	
	IF @@ROWCOUNT <> @batchNo
		BREAK
END
GO