/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20211027@Kathy 
	Task: Init data for table SettlementSpecialBettypeProfile [Redmine:#158477]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

DELETE 
FROM	dbo.SettlementSpecialBettypeProfile
WHERE	sporttype = 1
		AND bettype IN (14,127)

INSERT INTO dbo.SettlementSpecialBettypeProfile (pfId, bettype, sporttype, betid, resourceId, settletype, grouptype, ordno, roundid, oddstype, refresourceid)
values (0,14,1,0,'14F','MNL','FT',NULL,NULL,1,NULL)
	,(0,14,1,0,'14L','MNL','FT',NULL,NULL,1,NULL)
	,(0,127,1,0,'127F','MNL','1H',NULL,NULL,1,NULL)
	,(0,127,1,0,'127L','MNL','1H',NULL,NULL,1,NULL)

UPDATE dbo.SettlementSpecialBettypeProfile
SET ResourceID = CASE WHEN bettype in (486,488,490,491) THEN '08' ELSE '09' END
	,RefResourceId = NULL
	,pfID = 0
WHERE bettype BETWEEN 486 AND 492

UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = '14F'
		,RefResourceId = NULL
		,pfID = 0
WHERE bettype = 454

UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = '14L'
		,RefResourceId = NULL
		,pfID = 0
WHERE bettype = 448

update dbo.SettlementSpecialBettypeProfile
	SET pfID = 0
		,ResourceID = '14F'
		,RefResourceId = NULL
WHERE bettype = 172
AND SportType = 1
AND SettleType = 'MNL'


update dbo.SettlementSpecialBettypeProfile
	SET pfID = 0
		,ResourceID = CASE WHEN bettype = 415 THEN '14F' ELSE '08' END
		,RefResourceId = NULL
WHERE bettype IN (415,422,423,425)
AND SportType = 1
AND SettleType = 'MNL'
