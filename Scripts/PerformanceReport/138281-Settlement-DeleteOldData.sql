/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200818@Kathy
	Task : delete data in table SettlementPerformanceLog [Redmine:#138281]
	DB: DBTXN/bodb02
	
	Revision:
		
*/

USE bodb02
GO

WHILE 1=1
BEGIN
	DELETE TOP (5000)
	FROM dbo.SettlementPerformanceLog WITH(ROWLOCK, UPDLOCK)
	WHERE Starttime >= '20200601'

	IF @@ROWCOUNT = 0
		BREAK
END
GO
