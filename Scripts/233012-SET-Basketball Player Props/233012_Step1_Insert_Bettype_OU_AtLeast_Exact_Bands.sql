/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250822@Max
	Task: [Settlement] - Integration - Player Props AIO for Basketball [Redmine: #233012]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN
	;WITH BetTypes AS (
		SELECT 3 AS pfId, BetType, 0 AS OddsType --Over/Under bettypes
		FROM (VALUES (654), (657), (660), (663), (666), (668), (670), (672), (673), (674)) AS t(BetType)

		UNION ALL
		SELECT 9665 AS pfId, BetType, 1 AS OddsType --At least/Exact bettypes
		FROM (VALUES (653), (655), (656), (658), (659), (661), (662), (664), (665), (667), (669), (671)) AS t(BetType)

		UNION ALL --Bands bettypes
		SELECT 9666 AS pfId, BetType, 1 AS OddsType
		FROM (VALUES (685), (686), (687), (688)) AS t(BetType)
		
	),BetIDRange AS (
		SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum,
				number + 800 AS BetID
		FROM master.dbo.spt_values 
		WHERE type = 'P' AND number BETWEEN 1 AND 20
	)
	INSERT INTO SettlementSpecialBettypeProfile
	(	pfID	
		,BetType	
		,SportType	
		,BetID	
		,ResourceID	
		,SettleType	
		,GroupType	
		,OrdNo	
		,RoundID	
		,OddsType
	)  
	SELECT bt.pfId,
		bt.BetType,
		2 AS SportType, -- Basketball
		br.BetID,
		CAST(CASE 
				WHEN bt.BetType IN (653,654,655,685) THEN 653
				WHEN bt.BetType IN (656,657,658,686) THEN 656
				WHEN bt.BetType IN (659,660,661,687) THEN 659
				WHEN bt.BetType IN (662,663,664,688) THEN 662
				WHEN bt.BetType IN (665,666) THEN 665
				WHEN bt.BetType IN (667,668) THEN 667
				WHEN bt.BetType IN (669,670) THEN 669
				WHEN bt.BetType IN (671,672) THEN 671
				WHEN bt.BetType IN (673) THEN 673
				WHEN bt.BetType IN (674) THEN 674 END
			AS VARCHAR) + RIGHT('0' + CAST(br.RowNum AS VARCHAR), 2) AS ResourceID,
		'EAR' AS SettleType,
		'SP' AS GroupType,
		99 AS OrdNo,
		br.BetID AS RoundID,
		bt.OddsType AS OddsType
	FROM BetTypes bt
		CROSS APPLY (SELECT br.BetId, br.RowNum FROM BetIDRange br)br
		LEFT JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON sp.SportType = 2
				AND sp.BetType  = bt.BetType
				AND sp.pfID		= bt.pfID
	WHERE sp.BetType IS NULL
	ORDER BY bt.BetType, br.BetID
END
GO

 