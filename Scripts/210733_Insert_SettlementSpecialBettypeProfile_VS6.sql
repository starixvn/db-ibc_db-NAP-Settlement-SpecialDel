/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241022@Louisa
	Task: VS6-Virtual Basketball [Redmine: #210733]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

 --delete from SettlementSpecialBettypeProfile where sporttype = 134

BEGIN

	;WITH cte_VS6 (pfID ,BetType ,SportType ,BetID ,ResourceID ,SettleType ,GroupType ,OrdNo ,RoundID ,OddsType) AS 
	 (
				SELECT 5	,13000, 134	, 0		,'0100', 'MNL', 'FT', 99, 0, 0 UNION ALL
				SELECT 24	,13001, 134	, 0		,'0100', 'MNL', 'FT', 99, 0, 0 UNION ALL	

				SELECT 501	,13002, 134	, 0		,'00', 'MNL', 'FT', 99, 0, 0 UNION ALL
				SELECT 10	,13003, 134	, 0		,'00', 'MNL', 'FT', 99, 0, 0 UNION ALL
				SELECT 3	,13004, 134	, 0		,'00', 'MNL', 'FT', 99, 0, 0 UNION ALL
				SELECT 401	,13005, 134	, 0	 ,'00', 'MNL', 'FT', 99, 0, 0 UNION ALL
				SELECT 402	,13006, 134	, 0	 ,'00', 'MNL', 'FT', 99, 0, 0 UNION ALL

				SELECT 5	,13007, 134	, 801	,'Q1', 'MNL', 'SP', 1, 0, 0 UNION ALL --630
				SELECT 5	,13007, 134	, 802	,'Q2', 'MNL', 'SP', 2, 0, 0 UNION ALL --630
				SELECT 5	,13007, 134	, 803	,'Q3', 'MNL', 'SP', 3, 0, 0 UNION ALL --630
				SELECT 5	,13007, 134	, 804	,'Q4', 'MNL', 'SP', 5, 0, 0 UNION ALL --630

				SELECT 3	,13008, 134	, 801	,'Q1', 'MNL', 'SP', 1, 0, 0 UNION ALL--610
				SELECT 3	,13008, 134	, 802	,'Q2', 'MNL', 'SP', 2, 0, 0 UNION ALL--610
				SELECT 3	,13008, 134	, 803	,'Q3', 'MNL', 'SP', 3, 0, 0 UNION ALL--610
				SELECT 3	,13008, 134	, 804	,'Q4', 'MNL', 'SP', 5, 0, 0 UNION ALL--610

				SELECT 10	,13009, 134	, 801	,'Q1', 'MNL', 'SP', 1, 0, 0 UNION ALL--609
				SELECT 10	,13009, 134	, 802	,'Q2', 'MNL', 'SP', 2, 0, 0 UNION ALL--609
				SELECT 10	,13009, 134	, 803	,'Q3', 'MNL', 'SP', 3, 0, 0 UNION ALL--609
				SELECT 10	,13009, 134	, 804	,'Q4', 'MNL', 'SP', 5, 0, 0 UNION ALL--609

				SELECT 401	,13010, 134	, 801	,'Q1', 'MNL', 'SP', 1, 0, 0 UNION ALL--615
				SELECT 401	,13010, 134	, 802	,'Q2', 'MNL', 'SP', 2, 0, 0 UNION ALL--615
				SELECT 401	,13010, 134	, 803	,'Q3', 'MNL', 'SP', 3, 0, 0 UNION ALL--615
				SELECT 401	,13010, 134	, 804	,'Q4', 'MNL', 'SP', 5, 0, 0 UNION ALL--615

				SELECT 402	,13011, 134	, 801	,'Q1', 'MNL', 'SP', 1, 0, 0 UNION ALL--616
				SELECT 402	,13011, 134	, 802	,'Q2', 'MNL', 'SP', 2, 0, 0 UNION ALL--616
				SELECT 402	,13011, 134	, 803	,'Q3', 'MNL', 'SP', 3, 0, 0 UNION ALL--616
				SELECT 402	,13011, 134	, 804	,'Q4', 'MNL', 'SP', 5, 0, 0			 --616
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

	UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET RefResourceId = '00'
	WHERE SportType = 134
		AND ResourceID = '0100'

END
GO

 