/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230207@Aries
	Task: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO


INSERT INTO SettlementSpecialBettypeProfile( pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
SELECT  pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType
FROM( 
    -- Bet Type 1,3
    SELECT CASE WHEN Sporttype IN (49,51) AND  pfID = 10 THEN 1 ELSE pfID END AS pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(10, 1,		 0,	 '00',	'MNL',	'FT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL),
                (3,	 3,		 0,	 '00',	'MNL',	'FT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL)) 
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(3),(4),(7),(8),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(28),(29),(30),(31),(32),(33),
                          (34),(35),(36),(37),(38),(39),(40),(41),(42),(44),(47),(48),(49),(51),(52),(53),(54),(55),(56),(57),(58),(59),(60),(61),(62),(63),
                          (64),(65),(66),(99)) AS os (Sporttype)
    UNION  
    -- Bet Type 2
    SELECT  pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(2,	 2,		 0,	 '00',	'MNL',	'FT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL)) 
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(3),(4),(7),(8),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(28),(29),(30),(31),(32),(33),
                          (34),(35),(36),(37),(38),(39),(40),(41),(42),(47),(48),(49),(51),(52),(53),(54),(55),(56),(57),(58),(59),(60),(61),(62),(63),
                          (64),(65),(66),(99)) AS os (Sporttype)
    UNION 
    -- Bet Type 5, 15
    SELECT  pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(5, 5,		0,	 '00',	'MNL',	'FT',	NULL,	NULL,	1,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL),
                (5,	15,     0,	 '01',	'MNL',	'HT',	NULL,	NULL,	1,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL)) 
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(8),(7)) AS os (Sporttype)

    UNION 
    -- Bet Type 7, 8
    SELECT pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(10, 7,      0,  '01',  'MNL',  'HT',	NULL,   NULL,   NULL,   NULL,	NULL,   NULL,   NULL,   NULL,   NULL,	NULL),
                (3,	 8,		 0,	 '01',	'MNL',	'HT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL))
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(3),(4),(8),(10),(26),(32),(47),(49),(56)) AS os (Sporttype)

    UNION
    -- Bet Type 12
    SELECT  pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(2,	 12,	 0,	 '01',	'MNL',	'HT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL))
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(3),(8),(26),(32),(47),(49),(56)) AS os (Sporttype)

    UNION
    -- Bet Type 20
    SELECT  pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(20, 20,	 0,	 '00',	'MNL',	'FT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL)) 
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(3),(4),(7),(8),(10),(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23),(24),(25),(26),(28),(29),(30),(31),(33),
                          (34),(35),(36),(37),(38),(39),(40),(41),(42),(47),(48),(49),(51),(52),(53),(54),(55),(56),(57),(58),(59),(60),(61),(62),(63),
                          (64),(65),(66),(99)) AS os (Sporttype)

    UNION
    -- Bet Type 21
    SELECT  pfID,BetType,Sporttype,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType 
    FROM (VALUES(20, 21,	 0,	 '01',	'MNL',	'HT',	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL,	NULL))
    AS st(pfID,BetType,BetID,ResourceID,SettleType,GroupType,OrdNo,RoundID,OddsType,RefResourceId,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType)
        CROSS APPLY(VALUES(3),(7),(8)) AS os (Sporttype)
) AS tbl
ORDER BY Sporttype,BetType;