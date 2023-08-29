/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230727@Aries
	Task: Basketball AIO  [Redmine: #191381]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND BetType = 647)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,647 AS BetType, 0 AS BetID
            ,'647' AS ResourceID, '00' AS RefResourceId,'FT' AS GroupType

            , 'MNL' AS SettleType
            ,99 AS OrdNo, 0 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END

IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND BetType = 648)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,648 AS BetType, 0 AS BetID
            ,'648' AS ResourceID, '01' AS RefResourceId,'1H' AS GroupType

            , 'MNL' AS SettleType
            ,3 AS OrdNo, 0 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END

IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND BetType = 649)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,649 AS BetType, 0 AS BetID
            ,'649' AS ResourceID, '00' AS RefResourceId,'2H' AS GroupType

            , 'MNL' AS SettleType
            ,99 AS OrdNo, 0 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END




IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND BetType = 650  AND BetID = 801)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,650 AS BetType, 801 AS BetID
            ,'65001' AS ResourceID, 'Q1' AS RefResourceId,'SP' AS GroupType

            , 'MNL' AS SettleType
            ,1 AS OrdNo, 801 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END

IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND BetType = 650  AND BetID = 802)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,650 AS BetType, 802 AS BetID
            ,'65002' AS ResourceID, 'Q2' AS RefResourceId,'SP' AS GroupType

            , 'MNL' AS SettleType
            ,2 AS OrdNo, 802 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END

IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND BetType = 650  AND BetID = 803)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,650 AS BetType, 803 AS BetID
            ,'65003' AS ResourceID, 'Q3' AS RefResourceId,'SP' AS GroupType

            , 'MNL' AS SettleType
            ,4 AS OrdNo, 803 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END

IF NOT EXISTS (SELECT 1 FROM SettlementSpecialBettypeProfile WITH(NOLOCK) WHERE SportType = 2 AND  BetType = 650  AND BetID = 804)
BEGIN
    INSERT INTO SettlementSpecialBettypeProfile(pfID,SportType,BetType,BetID,ResourceID, RefResourceId,GroupType,SettleType,OrdNo,RoundID,OddsType,SDTpfId,Is3x30,SDTResourceId,IsSDT,DeterminedType,SpecialType,SDTRefund)
    SELECT   9088 AS pfid, 2 AS SportType
            ,650 AS BetType, 804 AS BetID
            ,'65004' AS ResourceID, 'Q4' AS RefResourceId,'SP' AS GroupType

            , 'MNL' AS SettleType
            ,5 AS OrdNo, 804 AS RoundID, 1 AS OddsType
            ,NULL AS SDTpfId,  0 AS Is3x30, NULL AS SDTResourceId
            ,NULL AS IsSDT, NULL AS DeterminedType, NULL AS SpecialType,NULL AS  SDTRefund
END

