/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231002@Louisa
	Task: Integrate sporttype 58-Bandy [Redmine: #196041]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	UPDATE r
	SET ResultTable = 2
		,IsSettleByProfile  =1
		,IsMergedParlay = 1
		,Setting = ISNULL(Setting,0) |  1  ---bit 1: apply SOP Refund
	FROM dbo.SettlementResultTableSetting r WITH(ROWLOCK, UPDLOCK)
	WHERE r.Sporttype = 58

END
GO