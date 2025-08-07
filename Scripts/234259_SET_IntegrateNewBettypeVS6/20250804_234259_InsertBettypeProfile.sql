/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250804@Max
	Task: Integrate - Add new bettypes for Virtual Sport 6- Betby [Redmine: #234259]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	;WITH cte_VS6 (pfID ,BetType ,SportType ,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo ,RoundID ,OddsType) AS 
	 (
				SELECT 5	,13012, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL
				SELECT 501	,13013, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL	
				SELECT 10	,13014, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL
				SELECT 3	,13015, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL
				SELECT 401	,13016, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL
				SELECT 402	,13017, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL
				SELECT 2	,13018, 134	, 0	,'01', 'MNL', 'HT', 99, 0, 1 UNION ALL
				SELECT 2	,13019, 134	, 0	,'00', 'MNL', 'FT', 99, 0, 1
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
	SELECT  cte.pfID, cte.BetType, cte.SportType, cte.BetID, cte.ResourceID, cte.SettleType, cte.GroupType, cte.OrdNo, cte.RoundID, cte.OddsType
	FROM cte_VS6  cte
		LEFT JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON cte.BetType =  sp.BetType 
				AND cte.SportType = sp.SportType
				AND sp.BetID = cte.BetID
	WHERE sp.BetType IS NULL
	ORDER BY cte.bettype
END
GO

 