/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230214@Louisa
	Task: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
	DB: DBPRO/bodb02
*/


USE bodb02
GO

ALTER TABLE dbo.SettlementResultTableSetting ADD Setting TINYINT
GO

--Apply SOP Refund
UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET Setting = ISNULL(Setting,0) | 1
WHERE Sporttype  IN (2, 5, 6, 43, 45, 9, 50) 

GO
