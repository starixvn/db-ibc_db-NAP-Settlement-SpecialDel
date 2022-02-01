/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: Kathy
    Date: 20220201
    Task : Update resultdetail
    DB: DBPRO/bodb02
*/
USE bodb02
GO

UPDATE dbo.resultdetail with(rowlock, updlock)
	SET ResultSetting = 2
WHERE matchid = 50221104
	AND ResourceId = '00'