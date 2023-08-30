/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230706@Louisa
	Task: Integration -Leap Gaming [Redmine: #189854]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	;WITH cte_VS3 (pfID ,BetType ,SportType,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo	,RoundID ,OddsType) AS 
	 (
				  SELECT 5,   5302, 178, 0, '00', 'MNL', 'FT', 1, 99, NULL ---FT.1X2
		UNION ALL SELECT 5,   5303, 178, 0, '01', 'MNL', 'HT', 1, 0,  NULL ---1H.1X2
		UNION ALL SELECT 3,   5304, 178, 0, '01', 'MNL', 'HT', 1, 0,  NULL ---1H Over/Under
		UNION ALL SELECT 644, 5305, 178, 0, '00', 'MNL', 'FT', 1, 99, NULL ---Correct Score

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
	select cte.pfID, cte.BetType, cte.SportType, cte.BetID, cte.ResourceID, cte.SettleType, cte.GroupType, cte.OrdNo, cte.RoundID, cte.OddsType
	FROM cte_VS3  cte
		LEFT JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON cte.BetType =  sp.BetType 
				AND sp.SportType = 178 
				AND sp.BetID = cte.BetID
	WHERE sp.BetType IS NULL

END
GO