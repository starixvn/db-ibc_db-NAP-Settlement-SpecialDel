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
			SELECT BetType FROM (VALUES (654), (657), (660), (663), (666), (668), (670), (672), (673), (674)) AS t(BetType)
	),
	BetIDRange AS (
		SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum,
				number + 800 AS BetID
		FROM master.dbo.spt_values 
		WHERE type = 'P' AND number BETWEEN 1 AND 99
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
	SELECT 3,
		bt.BetType,
		2 AS SportType, -- Basketball
		br.BetID,
		CAST(bt.BetType AS VARCHAR) + RIGHT('0' + CAST(br.RowNum AS VARCHAR), 2) AS ResourceID,
		'MNL' AS SettleType,
		'SP' AS GroupType,
		99 AS OrdNo,
		br.BetID AS RoundID,
		0 AS OddsType
	FROM BetTypes bt
		CROSS APPLY (SELECT br.BetId, br.RowNum FROM BetIDRange br)br
	WHERE NOT EXISTS (
		SELECT 1 FROM SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		WHERE sp.BetType = bt.BetType 
			AND sp.SportType = 2
			AND sp.BetID = br.BetID
	)
	ORDER BY bt.BetType, br.BetID
END
GO

 