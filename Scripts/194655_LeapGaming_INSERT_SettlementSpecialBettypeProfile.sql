/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231002@Louisa
	Task: Integration - Leap Gaming [Redmine: #194655]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	;WITH cte_VS3 (pfID ,BetType ,SportType,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo	,RoundID ,OddsType) AS 
	 (
				  SELECT 5,   5302, 179, 0, '00', 'MNL', 'FT', 99, 0, NULL ---FT.1X2
		UNION ALL SELECT 5,   5303, 179, 0, '01', 'MNL', 'HT', 1,  0, NULL ---1H.1X2
		UNION ALL SELECT 3,   5304, 179, 0, '01', 'MNL', 'HT', 1,  0, NULL ---1H Over/Under
		UNION ALL SELECT 10,  5306,	179, 0, '00', 'MNL', 'FT', 99, 0, 1 ---FT Handicap
		UNION ALL SELECT 3,   5307,	179, 0, '00', 'MNL', 'FT', 99, 0, 1 ---FT Over/Under

		UNION ALL SELECT 10,  5306,	178, 0, '00', 'MNL', 'FT', 99, 0, 1 ---FT Handicap
		UNION ALL SELECT 3,   5307,	178, 0, '00', 'MNL', 'FT', 99, 0, 1 ---FT Over/Under

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
	SELECT cte.pfID, cte.BetType, cte.SportType, cte.BetID, cte.ResourceID, cte.SettleType, cte.GroupType, cte.OrdNo, cte.RoundID, cte.OddsType
	FROM cte_VS3  cte
		LEFT JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON cte.BetType =  sp.BetType 
				AND cte.SportType = sp.SportType
				AND sp.BetID = cte.BetID
	WHERE sp.BetType IS NULL

END
GO