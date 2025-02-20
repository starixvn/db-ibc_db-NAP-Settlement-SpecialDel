/* info serverAlias="DBPRO-bodb02" executers="" isFunction="0"  /info */
/*
    Created: 20250213@Hughie
	Task: Integration - Change 6 bet types of Basketball [Redmine: #217571]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Bettype **************************/
WITH cte_exist_bettypes AS (
    SELECT v.Bettypes
    FROM (VALUES (461), (462), (463), (464), (651), (652)) AS v(Bettypes)
    WHERE NOT EXISTS (
        SELECT 1
        FROM SettlementSpecialBettypeProfile
        WHERE BetType = v.Bettypes AND SportType = 2
    )
)

	INSERT INTO [dbo].[SettlementSpecialBettypeProfile]
           ([pfID]
           ,[BetType]
           ,[SportType]
           ,[BetID]
           ,[ResourceID]
           ,[SettleType]
           ,[GroupType]
           ,[OrdNo]
           ,[RoundID]
           ,[OddsType]
           ,[RefResourceId]
           ,[SDTpfId]
           ,[Is3x30]
           ,[SDTResourceId]
           ,[IsSDT]
           ,[DeterminedType]
           ,[SpecialType]
           ,[SDTRefund]
           ,[SDTInstant]
           ,[HasAwayValue]
           ,[APSetting])
    SELECT
    		[pfID]
           ,[BetType] = CASE WHEN A.BetType = 401 THEN 461
							 WHEN A.BetType = 402 THEN 462
							 WHEN A.BetType = 403 THEN 463
							 WHEN A.BetType = 404 THEN 464
							 WHEN A.BetType = 615 THEN 651
							 WHEN A.BetType = 616 THEN 652
							 END 
           ,[SportType]
           ,[BetID]
           ,[ResourceID]
           ,[SettleType]
           ,[GroupType]
           ,[OrdNo]
           ,[RoundID]
           ,1 AS [OddsType]
           ,[RefResourceId]
           ,[SDTpfId]
           ,[Is3x30]
           ,[SDTResourceId]
           ,[IsSDT]
           ,[DeterminedType]
           ,[SpecialType]
           ,[SDTRefund]
           ,[SDTInstant]
           ,[HasAwayValue]
           ,[APSetting]
	FROM SettlementSpecialBettypeProfile A
		CROSS APPLY
			(
				SELECT TOP 1 1 AS OldBettypes 
				FROM SettlementSpecialBettypeProfile X WITH (NOLOCK) 
				WHERE A.BetType = X.BetType
			) AS B
	WHERE A.BetType IN (401, 402, 403, 404, 615, 616) 
	AND A.SportType = 2 
	AND EXISTS (SELECT 1 FROM cte_exist_bettypes M WHERE M.Bettypes = CASE 
                                                       WHEN A.Bettype = 401 THEN 461
                                                       WHEN A.Bettype = 402 THEN 462
                                                       WHEN A.Bettype = 403 THEN 463
                                                       WHEN A.Bettype = 404 THEN 464
                                                       WHEN A.Bettype = 615 THEN 651
                                                       WHEN A.Bettype = 616 THEN 652
                                                   END)

--WAY 2
INSERT INTO [dbo].[SettlementSpecialBettypeProfile]
           ([pfID]
           ,[BetType]
           ,[SportType]
           ,[BetID]
           ,[ResourceID]
           ,[SettleType]
           ,[GroupType]
           ,[OrdNo]
           ,[RoundID]
           ,[OddsType]
           ,[RefResourceId]
           ,[SDTpfId]
           ,[Is3x30]
           ,[SDTResourceId]
           ,[IsSDT]
           ,[DeterminedType]
           ,[SpecialType]
           ,[SDTRefund]
           ,[SDTInstant]
           ,[HasAwayValue]
           ,[APSetting])
SELECT
    		[pfID]
           ,[BetType] = CASE WHEN A.BetType = 401 THEN 461
							 WHEN A.BetType = 402 THEN 462
							 WHEN A.BetType = 403 THEN 463
							 WHEN A.BetType = 404 THEN 464
							 WHEN A.BetType = 615 THEN 651
							 WHEN A.BetType = 616 THEN 652
							 END 
           ,[SportType]
           ,[BetID]
           ,[ResourceID]
           ,[SettleType]
           ,[GroupType]
           ,[OrdNo]
           ,[RoundID]
           ,1 AS [OddsType]
           ,[RefResourceId]
           ,[SDTpfId]
           ,[Is3x30]
           ,[SDTResourceId]
           ,[IsSDT]
           ,[DeterminedType]
           ,[SpecialType]
           ,[SDTRefund]
           ,[SDTInstant]
           ,[HasAwayValue]
           ,[APSetting]
	FROM SettlementSpecialBettypeProfile A
	WHERE A.BetType IN (401, 402, 403, 404, 615, 616) 
	AND A.SportType = 2 
	AND NOT EXISTS (
	    SELECT 1
	    FROM SettlementSpecialBettypeProfile B
	    WHERE B.BetType = CASE 
	                    WHEN A.BETTYPE = 401 THEN 461
	                    WHEN A.BETTYPE = 402 THEN 462
	                    WHEN A.BETTYPE = 403 THEN 463
	                    WHEN A.BETTYPE = 404 THEN 464
	                    WHEN A.BETTYPE = 615 THEN 651
	                    WHEN A.BETTYPE = 616 THEN 652
	                 END
	    AND B.SportType = 2
	)
