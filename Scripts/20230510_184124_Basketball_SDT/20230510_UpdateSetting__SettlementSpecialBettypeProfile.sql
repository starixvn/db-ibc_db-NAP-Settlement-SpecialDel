/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230510@Aries
	Task: Apply Settle Determined for Basketball [Redmine: #184124]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
-- Bit 1 - HT
UPDATE SettlementSpecialBettypeProfile
SET DeterminedType = ISNULL(DeterminedType,0) | 1 
WHERE SportType = 2
    AND BetType IN (3,401,402,645,646)
-- Bit 2 - HTDone
/*None*/
-- Bit 3 - FT 
/*None*/
-- Bit 4 - Q1
UPDATE SettlementSpecialBettypeProfile
SET DeterminedType = ISNULL(DeterminedType,0) | 8
WHERE SportType = 2
    AND BetType IN (8,403,404,633,3, 401,402,632,635,638, 639,640,641,642,646)

-- Bit 5 - Q2
UPDATE SettlementSpecialBettypeProfile
SET DeterminedType = ISNULL(DeterminedType,0) | 16
WHERE SportType = 2
    AND BetType IN (8,403,404,633,3, 401,402,632,635,638, 639,640,641,642,643, 645,646)

-- Bit 6 - Q3
UPDATE SettlementSpecialBettypeProfile
SET DeterminedType = ISNULL(DeterminedType,0) | 32 
WHERE SportType = 2
    AND BetType IN (3,401,402,632,634, 635,638,639,640,641, 642,643,646)

-- Bit 7 - Q4
UPDATE SettlementSpecialBettypeProfile
SET DeterminedType = ISNULL(DeterminedType,0) |  64
WHERE SportType = 2
    AND BetType IN (3,401,402,603,632, 634,635,638,639,640, 641,642,643,646)

/************************Add setting Refund SDT**************************/
ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD SDTRefund TINYINT

-- Bit 1 - HT
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 1 
WHERE SportType = 2
    AND BetType IN (3,401,402,8,403,404,646)
-- Bit 2 - HT-Done
/*None*/
-- Bit 3 - FT - None
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 4
WHERE SportType = 2
    AND BetType IN (3,401,402,646,645)

-- Bit 4 - Q1
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 8 
WHERE SportType = 2
    AND (BetType IN (3,401,402,8,403,404,646) OR (BetType IN (610,615,616) AND ResourceID = 'Q1') )

-- Bit 5 - Q2
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 16 
WHERE SportType = 2
    AND (BetType IN (3,401,402,8,403,404,643,646,633,632,635,638,639,640,641,642) OR (BetType IN (610,615,616) AND ResourceID = 'Q2') )

-- Bit 6 - Q3
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 32 
WHERE SportType = 2
    AND (BetType IN (3,401,402,643,646,632,635,638,639,640,641,642,645) OR (BetType IN (610,615,616) AND ResourceID = 'Q3') )

-- Bit 7 - Q4
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 64 
WHERE SportType = 2
    AND (BetType IN (3,401,402,643,646,632,634,635,638,639,640,641,642,645) OR (BetType IN (610,615,616) AND ResourceID = 'Q4') )

-- Bit 8 - OT
UPDATE SettlementSpecialBettypeProfile
SET SDTRefund = ISNULL(SDTRefund,0) | 128 
WHERE SportType = 2
    AND BetType IN (3,401,402,603,632,646,645,634,635,638,639,640,641,642,643)
GO


-- Update SDTResourceId, SDTpfId
UPDATE SettlementSpecialBettypeProfile 
SET SDTResourceId = ResourceId,
    SDTpfId = CASE WHEN bettype IN (632,634,645) THEN 633
                   WHEN bettype IN (638,639,641) THEN 638
                   ELSE IIF(pfId = 424,ResourceId, pfId)
              END
WHERE SportType = 2  
    AND bettype in (3,8,401,402,403,404,603,610,615,616,632,633,634,635,638,639,640,641,642,643,645,646);  
GO

