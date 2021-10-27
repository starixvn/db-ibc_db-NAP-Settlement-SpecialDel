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


--- apply for remaining bettypes

INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (1,17,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (3,18,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (20,20,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (20,21,1,0,'01','MNL','1H',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (24,24,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (25,25,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (26,26,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (27,27,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (28,28,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (30,30,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (121,121,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (122,122,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (123,123,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (1,124,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (1,125,1,0,'01','MNL','1H',0,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,128,1,0,'128','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (129,129,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (130,130,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (131,131,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (132,132,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,133,1,0,'133','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,134,1,0,'134','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (136,136,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (136,137,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (138,138,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (138,139,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,140,1,0,'140','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,141,1,0,'141','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,142,1,0,'142','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (143,143,1,0,'143','MNL','1H',1,'01')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (143,144,1,0,'144','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (145,145,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (145,146,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,147,1,0,'147','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,148,1,0,'148','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,149,1,0,'149','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,150,1,0,'150','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (24,151,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,152,1,0,'152','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,157,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (406,159,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (407,161,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (409,162,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (143,163,1,0,'144','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (165,165,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (165,166,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (5,167,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (170,170,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (171,171,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (5,177,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (3,178,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (179,179,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (407,181,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (409,182,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (1,183,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,184,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (25,185,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (186,186,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (187,187,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (145,188,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,189,1,0,'189','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,190,1,0,'190','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (25,191,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,388,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,389,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (392,392,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,394,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (22,396,1,0,'22','MNL','FT',1,'08')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,397,1,0,'397','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (24,398,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (399,399,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,400,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,401,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,402,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,403,1,0,'01','MNL','1H',0,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,404,1,0,'01','MNL','1H',0,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (409,409,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (24,410,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (25,411,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,417,1,0,'417','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (418,418,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,419,1,0,'419','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,420,1,0,'420','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,421,1,0,'421','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,426,1,0,'426','MNL','1H',1,'01')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (145,427,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,428,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (429,429,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (5,430,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (186,431,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (25,432,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (145,433,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,434,1,0,'189','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,435,1,0,'190','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,436,1,0,'147','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,437,1,0,'148','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,438,1,0,'133','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,439,1,0,'134','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,440,1,0,'149','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,441,1,0,'150','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,442,1,0,'140','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,443,1,0,'141','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,444,1,0,'142','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,445,1,0,'445','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,446,1,0,'446','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,447,1,0,'447','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (449,449,1,0,'449','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (450,450,1,0,'450','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (451,451,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (452,452,1,0,'452','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (28,453,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,456,1,0,'456','MNL','1H',1,'01')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (457,457,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (458,458,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (458,459,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (460,460,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,461,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,462,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,463,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,464,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (1,465,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (1,466,1,0,'01','MNL','1H',0,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,467,1,0,'467','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (468,468,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (469,469,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,470,1,0,'00','MNL','FT',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,471,1,0,'01','MNL','1H',NULL,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (2,472,1,0,'02','MNL','2H',NULL,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (473,473,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (474,474,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (475,475,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (475,476,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (28,477,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (28,478,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,482,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,483,1,0,'00','MNL','FT',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (389,484,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (388,485,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (493,493,1,0,'493','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (494,494,1,0,'01','MNL','1H',1,NULL)
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (494,495,1,0,'02','MNL','2H',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (16,496,1,0,'140','MNL','FT',1,'00')
INSERT INTO dbo.SettlementSpecialBettypeProfile(pfId, Bettype, Sporttype, BetId, ResourceId, SettleType, GroupType, OddsType, RefResourceId) VALUES (497,497,1,0,'140','MNL','FT',1,'00')
