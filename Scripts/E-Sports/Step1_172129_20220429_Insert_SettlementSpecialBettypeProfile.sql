/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220428@Louisa
    Task: 20220429@Louisa: ESports-Support settle more Resource from Map 6 to Map 9 [Redmine:#172129]
    DB: DBTXN/bodb02
*/

USE bodb02
GO

	
	IF OBJECT_ID ('tempdb..#Current' ) IS NOT NULL
	DROP TABLE #Current

	CREATE TABLE #Current (pfID SMALLINT,  BetType SMALLINT, BetID BIGINT, ResourceID VARCHAR(20), RoundID VARCHAR(10), OddsType SMALLINT )

	INSERT INTO  #Current ( pfID,  BetType, BetID, ResourceID, RoundID, OddsType)
	SELECT  pfID,  BetType, MAX(BetID), MAX(ResourceID), MAX(RoundID), OddsType 
	FROM SettlementSpecialBettypeProfile sp (nolock)
	WHERE sp.sporttype = 43 
		AND sp.SettleType = 'EAR'
		AND  sp.bettype IN (9089,9090,9091,9092,9093,9094,9095,9096,9097,9098,9099,9100,9101,9102,9103,9104,9105,9106,9107,9108,9109,9110,9111,9112,9113,9114,9115,9116,9117,9120,9125,9126,9127,9128,9129,9130,9131,9132)
	GROUP BY pfID,  BetType, GroupType, OddsType

	;WITH cte_New  ( pfID,  BetType, BetID, ResourceID, RoundID, OddsType) 
	AS (
		--Bettype Map X
		SELECT c.pfID,  c.BetType, r.BetID
			, LEFT(ResourceID,4) + r.Suffix  AS ResourceID
			, '8' +  r.Suffix AS RoundID
			, OddsType 
		FROM #Current c 
			CROSS APPLY (SELECT * FROM ( VALUES (806, '06'),  (807,'07'), (808,'08'), (809,'09') ) r(BetId, Suffix)) r
		WHERE r.betid > c.betid
				and c.bettype NOT IN ( 9101,9102,9103,9104,9105,9106,9107,9108,9109,9110,9111,9112,9089	)
	
		--Bettype Map X - Y kill
		UNION ALL
		SELECT c.pfID,  c.BetType,  r.BetId AS BetID
			, LEFT(ResourceID,4) + r.Suffix  + CASE WHEN bettype = 9111 THEN '15'
													WHEN bettype = 9112 THEN '20'
													ELSE RIGHT(CAST (bettype AS VARCHAR(4) ),2)
												END	AS ResourceID
			, CAST (r.BetId AS VARCHAR) AS RoundID
			, OddsType 
		FROM #Current c 
			CROSS APPLY (SELECT * FROM ( VALUES (806, '06'),  (807,'07'), (808,'08'), (809,'09') ) r(BetId, Suffix)) r
		WHERE r.betid > c.betid
				AND c.bettype IN ( 9101,9102,9103,9104,9105,9106,9107,9108,9109,9110,9111,9112	)
	
		UNION ALL
		SELECT c.pfID,  c.BetType,  CAST ( '8' +  r.Suffix AS BIGINT) AS  BetID
			, LEFT(ResourceID,4) + r.Suffix  AS ResourceID
			, CAST (r.BetId AS VARCHAR) AS RoundID
			, OddsType 
		FROM #Current c 
			CROSS APPLY (SELECT * FROM ( VALUES (808, '0805'),  (808,'0810'), (809, '0905'),  (809,'0910') ) r(BetId, Suffix)) r
		WHERE   c.bettype = 9089
	)

	--INSERT INTO SettlementSpecialBettypeProfile ( pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType , RoundID, OddsType )
	SELECT cte.pfID, cte.BetType, 43 AS SportType, cte.BetID, cte.ResourceID, 'EAR' AS SettleType, '' AS GroupType, cte.RoundID , cte.OddsType
	FROM cte_New cte
		LEFT JOIN SettlementSpecialBettypeProfile sp (nolock) 
			ON sp.bettype = cte.bettype AND sp.BetId = cte.BetId AND sp.ResourceID = cte.ResourceID
	WHERE sp.bettype IS NULL


