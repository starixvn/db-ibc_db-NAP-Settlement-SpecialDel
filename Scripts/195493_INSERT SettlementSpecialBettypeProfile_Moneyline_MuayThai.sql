/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231101@Louisa
	Task: Implement Moneyline for MuayThai [Redmine: #195493]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	;WITH cte_NewBettype (pfID ,BetType ,SportType,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo ,RoundID ,OddsType) AS 
	 (
	 	SELECT 20, 20, 44, 0, '00', 'MNL', 'FT', 99, '0', NULL

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
	FROM cte_NewBettype  cte
		LEFT JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON cte.BetType =  sp.BetType 
				AND cte.SportType = sp.SportType
				AND sp.BetID = cte.BetID
	WHERE sp.BetType IS NULL

END
GO