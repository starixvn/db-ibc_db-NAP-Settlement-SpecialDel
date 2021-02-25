/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	DB: DBTXN.bodb02
	Task: rollback: update profile of bettype 22 [Redmine:#142425]
*/
USE bodb02
GO

UPDATE dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK,UPDLOCK)
	SET pfID= 0
		,ResourceID = '08'
		,RefResourceId = NULL
WHERE SportType = 1
	AND bettype = 22
GO
