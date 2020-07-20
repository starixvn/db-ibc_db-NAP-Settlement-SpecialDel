/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: Kathy
    Date: 20200716
    Task : update SettlementSpecialBettypeProfile for basketball [Redmine:#135846]
    DB: DBTXN/bodb02
*/

USE bodb02
GO

-- insert more resourceId 
IF NOT EXISTS (SELECT * FROM SettlementSpecialBettypeProfile ssbp WITH(NOLOCK) WHERE ssbp.SportType = 2 AND ssbp.BetType = 617 AND ssbp.BetID = 804)
BEGIN
	INSERT INTO dbo.SettlementSpecialBettypeProfile (pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType)
	SELECT	pfID, BetType, SportType, 804, '61704', SettleType, GroupType, 0, 804, OddsType
	FROM	dbo.SettlementSpecialBettypeProfile WITH(NOLOCK)
	WHERE	SportType = 2
			AND bettype = 617
			AND BetID = 803
END

-- correct resourceId
UPDATE	dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET ResourceID = '60630'
WHERE	SportType = 2
		AND bettype = 606
		AND ResourceID = '62630'

-- change resourceId of 603
UPDATE	dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET	ResourceID = '603'
		,RefResourceId = '00'
WHERE	SportType = 2
		AND bettype = 603
		AND ResourceID = '00'

-- update ord
UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET OrdNo = CASE
					WHEN BetID = 801 THEN 1
					WHEN BetID = 802 THEN 2
					WHEN ResourceID = '01' THEN 3
					WHEN BetID = 803 THEN 4
					WHEN BetID = 804 THEN 5
					WHEN ResourceID IN ('00', '605', '603') THEN 99
					ELSE 0
				END
WHERE	SportType = 2
		AND SettleType = 'MNL'

-- update pfid to enable calculating formular				 
UPDATE	dbo.SettlementSpecialBettypeProfile  WITH(ROWLOCK, UPDLOCK)
	SET pfID = CASE 
					WHEN bettype IN (2,12,611) THEN 2
					WHEN bettype IN (3,8,610) THEN 3
					WHEN bettype IN (1,7,609) THEN 10
					WHEN bettype IN (20,21,612) THEN 20
					WHEN bettype IN (603,604,605,606,607,613,617) THEN 100
					WHEN bettype IN (401,403,615) THEN 401
					WHEN bettype IN (402,404,616) THEN 402
					WHEN bettype IN (601) THEN 601
					WHEN bettype IN (602) THEN 602
					WHEN bettype IN (608) THEN 608
					WHEN bettype IN (614) THEN 614
					ELSE 0
				END
WHERE SportType = 2



