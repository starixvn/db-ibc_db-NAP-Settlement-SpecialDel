/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230328@Aries
	Task: Support Auto Payout for Main Tennis Matches [Redmine: #182329]
	DB: DBPRO/bodb02
*/


USE bodb02
GO

--Has Auto Payout
UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET Setting = ISNULL(Setting,0) | 2
WHERE Sporttype  IN ( 5, 6, 9, 18 ,50) 

--Has Auto Refund
UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET Setting = ISNULL(Setting,0) | 4
WHERE Sporttype  IN (5,6,9) 

GO
