/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200818@Kathy
	Task : Add 2 new columns [Redmine:#138281]
	DB: DBTXN/bodb02
	
	Revision:
		
*/
USE bodb02
GO

ALTER TABLE dbo.SettlementPerformanceLog ADD Sporttype SMALLINT
GO

ALTER TABLE dbo.SettlementPerformanceLog ADD IsHold BIT
GO

