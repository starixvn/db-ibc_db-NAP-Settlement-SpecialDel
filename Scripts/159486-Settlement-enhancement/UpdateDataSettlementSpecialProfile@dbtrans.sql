/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20211027@Kathy 
	Task: Init data for table SettlementSpecialBettypeProfile [Redmine:#158477]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

-- current bettype
UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = '14'
		,RefResourceId = '08'
		,pfID = 14
WHERE bettype = 14

IF @@ROWCOUNT = 2
	DELETE TOP (1) dbo.SettlementSpecialBettypeProfile
	WHERE bettype = 14

UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = '127'
		,RefResourceId = '09'
		,pfID = 14
		,GroupType = 'HT'
WHERE bettype = 127

IF @@ROWCOUNT = 2
	DELETE TOP (1) dbo.SettlementSpecialBettypeProfile
	WHERE bettype = 127

UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = bettype
		,RefResourceId = case when bettype in (486,488,490,491) then '00' else '01' end
		,pfID = CASE WHEN bettype in (486,487) THEN 486 ELSE 488 END
WHERE bettype BETWEEN 486 AND 492

UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = bettype
		,RefResourceId = '00'
		,pfID = 454
WHERE bettype = 454

UPDATE dbo.SettlementSpecialBettypeProfile
	SET ResourceID = bettype
		,RefResourceId = '08'
		,pfID = 16
WHERE bettype = 448

update dbo.SettlementSpecialBettypeProfile
	SET pfID = 16
		,ResourceID = '172'
		,RefResourceId = '00'
WHERE bettype = 172
AND SportType = 1
AND SettleType = 'MNL'


update dbo.SettlementSpecialBettypeProfile
	SET pfID = 16
		,ResourceID = CASE WHEN bettype = 415 THEN '172' ELSE CAST(bettype AS VARCHAR) END
		,RefResourceId = CASE WHEN bettype in (415) THEN '00' ELSE '08' END
WHERE bettype IN (415,422,423,425)
AND SportType = 1
AND SettleType = 'MNL'
