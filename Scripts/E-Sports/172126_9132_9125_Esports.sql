/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220428@Helen
    Task: 20220428@Helen: ESports Phase 4 [Redmine:#172126]
    DB: DBTXN/bodb02
*/

INSERT INTO SettlementSpecialBettypeProfile ([pfID], [BetType], [SportType], [BetID], [ResourceID], [SettleType], [GroupType], [OrdNo], [RoundID], [Is3x30])
--9125
SELECT 100, 9125, 43, 806, '912506', 'EAR', '', 5116, '806', 0
UNION ALL
SELECT 100, 9125, 43, 807, '912507', 'EAR', '', 5117, '807', 0
----9132
UNION ALL
SELECT 102, 9132, 43, 806, '913206', 'EAR', '', 5080, '806', 0
UNION ALL
SELECT 102, 9132, 43, 807, '913207', 'EAR', '', 5081, '807', 0
