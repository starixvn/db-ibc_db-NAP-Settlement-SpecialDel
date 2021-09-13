/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
    DB: DBTXN/bodb02, DBPRO-bodb02
	
	Revisions:
		- 20210906@Louisa: Update settlement setting for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
*/

USE bodb02
GO

BEGIN

	UPDATE dbo.SettlementResultTableSetting WITH(ROWLOCK, UPDLOCK)
	SET ResultTable = 2
		,IsSettleByProfile = 1
		,IsMergedParlay = 1
	WHERE Sporttype IN ( 6, 30, 48 ) --Volleyball, Squash, Sepak Takraw

END
GO