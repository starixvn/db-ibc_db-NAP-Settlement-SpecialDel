/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231002@Louisa
	Task: New bettype 1H for UpComingSports - sporttype 58 [Redmine: #194661]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	;WITH cte_UpComing (pfID ,BetType ,SportType,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo ,RoundID ,OddsType) AS 
	 (

				  SELECT 10	,7	,58 ,0 ,'01' ,'MNL' ,'HT' ,1 ,0 ,NULL ---1H Handicap
		UNION ALL SELECT 3	,8	,58 ,0 ,'01' ,'MNL' ,'HT' ,1 ,0 ,NULL ---1H Over/Under
		UNION ALL SELECT 2	,12	,58 ,0 ,'01' ,'MNL' ,'HT' ,1 ,0 ,NULL ---1H Odd/Even
		UNION ALL SELECT 20	,21	,58 ,0 ,'01' ,'MNL' ,'HT' ,1 ,0 ,NULL ---1H Moneyline

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
	FROM cte_UpComing  cte
		LEFT JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON cte.BetType =  sp.BetType 
				AND cte.SportType = sp.SportType
				AND sp.BetID = cte.BetID
	WHERE sp.BetType IS NULL

END
GO



