/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
USE bodb02
GO

-- rollback setting
UPDATE dbo.SettlementResultTableSetting
	SET resulttable = 0
		,isappliedSOP = 0
		,ExternalResultTable=1
		,setting = NULL
WHERE sporttype = 8