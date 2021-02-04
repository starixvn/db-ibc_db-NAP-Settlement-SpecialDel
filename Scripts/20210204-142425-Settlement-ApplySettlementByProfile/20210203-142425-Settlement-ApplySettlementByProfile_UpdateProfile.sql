/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	DB: DBTXN.bodb02
	Task: update profile [Redmine:#142425]
*/
USE bodb02
GO

UPDATE dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK,UPDLOCK)
	SET pfID= 22
		,ResourceID = '22'
		,RefResourceId = '08'
WHERE SportType = 1
	AND bettype = 22
GO
