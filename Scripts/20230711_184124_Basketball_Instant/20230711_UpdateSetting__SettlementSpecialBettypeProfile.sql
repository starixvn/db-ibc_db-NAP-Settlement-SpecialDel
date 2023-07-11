/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230711@Aries
	Task: Apply Settle Determined for Basketball [Redmine: #184124]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
IF NOT EXISTS (SELECT * FROM   sys.columns  WHERE  object_id = OBJECT_ID(N'[dbo].[SettlementSpecialBettypeProfile]') AND name = 'SDTInstant')
BEGIN
	ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD SDTInstant TINYINT
END

GO
-- Bit 4 - Q1
UPDATE SettlementSpecialBettypeProfile
SET SDTInstant = ISNULL(SDTInstant,0) | 8
WHERE SportType = 2
    AND (BetType IN (3,8,401,402,403,404,646)  OR (BetType IN (610,615,616) AND ResourceID = 'Q1'))

-- Bit 5 - Q2
UPDATE SettlementSpecialBettypeProfile
SET SDTInstant = ISNULL(SDTInstant,0) | 16
WHERE SportType = 2
    AND (BetType IN (3,8,401,402,403,404,646)  OR (BetType IN (610,615,616) AND ResourceID = 'Q2'))

-- Bit 6 - Q3
UPDATE SettlementSpecialBettypeProfile
SET SDTInstant = ISNULL(SDTInstant,0) | 32 
WHERE SportType = 2
    AND (BetType IN (3,401,402,646)  OR (BetType IN (610,615,616) AND ResourceID = 'Q3'))

-- Bit 7 - Q4
UPDATE SettlementSpecialBettypeProfile
SET SDTInstant = ISNULL(SDTInstant,0) |  64
WHERE SportType = 2
    AND (BetType IN (3,401,402,646)  OR (BetType IN (610,615,616) AND ResourceID = 'Q4'))


-- Bit 8 - OT
UPDATE SettlementSpecialBettypeProfile
SET SDTInstant = ISNULL(SDTInstant,0) |  128
WHERE SportType = 2
    AND BetType IN (3,401,402,646)



