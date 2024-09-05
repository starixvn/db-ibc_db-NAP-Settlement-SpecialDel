/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO
DELETE FROM dbo.SettlementProcessing WITH(ROWLOCK, UPDLOCK)
WHERE StatusID = 3
