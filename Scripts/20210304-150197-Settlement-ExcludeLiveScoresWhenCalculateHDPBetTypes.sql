/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	DB: DBTXN.bodb02
	Task: Exclude LiveScores When Calculate HDP Bet Types [Redmine:#142425]
*/
USE bodb02
GO

UPDATE	dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK,UPDLOCK)
	SET pfID = 10
WHERE	SportType IN (5,9)
		AND pfID = 1
GO
-- 15 rows affected