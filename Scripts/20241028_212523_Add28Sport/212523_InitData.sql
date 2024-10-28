/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241028@Aries
	Task:  Support Adding 28 New Sport Types [Redmine:#212523]
	DB: DBPRO-bodb02

	Revision:
		- 20241028@Aries: Support Adding 28 New Sport Types [Redmine:#212523]

*/
USE bodb02

;WITH CTE_Sport AS (
    SELECT 67 AS SportType
    UNION ALL
    SELECT SportType + 1 FROM CTE_Sport WHERE SportType+1<=94
)
INSERT INTO dbo.SettlementSpecialBettypeProfile(SportType,pfId, Bettype, BetId, ResourceId, SettleType, GroupType,OrdNo,RoundID, OddsType) 
SELECT s.SportType,bt.pfId, bt.Bettype,0 AS BetID, '00' AS ResourceID, 'MNL' AS SettleType, 'FT' AS GroupType, 99 AS OrdNo, 0 AS RoundID,bt.OddsType
FROM CTE_Sport AS s
    CROSS APPLY (VALUES(1,1,NULL),(2,2,NULL) ,(3,3,NULL) ,(5,4,1),(20,20,NULL)) AS bt(Bettype,pfId,OddsType)
    OUTER APPLY (
        SELECT TOP 1 1 AS IsExist
        FROM SettlementSpecialBettypeProfile AS sp WITH(NOLOCK)
        WHERE s.SportType = sp.SportType
            AND bt.Bettype = sp.Bettype
    ) AS tbl
WHERE ISNULL(tbl.IsExist,0) != 1; 