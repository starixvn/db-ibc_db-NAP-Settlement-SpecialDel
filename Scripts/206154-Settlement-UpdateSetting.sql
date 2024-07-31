/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
USE bodb02
GO


UPDATE dbo.SettlementResultTableSetting
	SET resulttable = 2
		,isappliedSOP = 1
		,ExternalResultTable=2
		,setting = 1
WHERE sporttype = 8