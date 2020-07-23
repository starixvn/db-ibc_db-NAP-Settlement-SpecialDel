/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: Kathy
    Date: 20200716
    Task : update SettlementSpecialBettypeProfile for basketball [Redmine:#135846]
    DB: DBTXN/bodb02
*/

-- change resourceId of 603
UPDATE	dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET	ResourceID = '603'
		,RefResourceId = '00'
WHERE	SportType = 2
		AND bettype = 603
		AND ResourceID = '00'