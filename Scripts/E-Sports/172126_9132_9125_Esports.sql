/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220428@Helen
    Task: 20220428@Helen: ESports Phase 4 [Redmine:#172126]
    DB: DBTXN/bodb02
*/

INSERT INTO SettlementSpecialBettypeProfile ([pfID], [BetType], [SportType], [BetID], [ResourceID], [SettleType], [GroupType], [OrdNo], [RoundID])
--9125
SELECT 100, 9125, 43, 806, '912506', 'EAR', '', 6115, '806'
UNION ALL
SELECT 100, 9125, 43, 807, '912507', 'EAR', '', 7115, '807'
----9132
UNION ALL
SELECT 102, 9132, 43, 806, '913206', 'EAR', '', 6079, '806'
UNION ALL
SELECT 102, 9132, 43, 807, '913207', 'EAR', '', 7079, '807'
