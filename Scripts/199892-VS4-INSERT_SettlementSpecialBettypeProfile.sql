/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240118@Louisa
	Task: VS4-Cock Fighting [Redmine: #199700]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	;WITH cte_VS4 (pfID ,BetType ,SportType ,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo ,RoundID ,OddsType) AS 
	 (
				  SELECT 20, '10400', 188, 0, '00', 'MNL', 'FT', 99, 0, NULL ---match winner
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
	FROM cte_VS4  cte
		LEFT JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON cte.BetType =  sp.BetType 
				AND cte.SportType = sp.SportType
				AND sp.BetID = cte.BetID
	WHERE sp.BetType IS NULL

END
GO