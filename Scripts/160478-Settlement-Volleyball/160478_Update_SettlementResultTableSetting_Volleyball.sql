/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
    DB: DBPRO-bodb02
	
	Revisions:
		- 20210906@Louisa: Update settlement setting for Volleyball [Redmine:#160478]
*/

USE bodb02
GO

BEGIN

	UPDATE dbo.SettlementResultTableSetting WITH(ROWLOCK, UPDLOCK)
	SET ResultTable = 2
		,IsSettleByProfile = 1
		,IsMergedParlay = 1
	WHERE Sporttype = 6 --Volleyball

END
GO