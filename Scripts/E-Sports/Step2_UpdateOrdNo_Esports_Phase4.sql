/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220111@Louisa
    Task: 20220111@Louisa: ESports Phase 4 [Redmine:#166330]
    DB: DBTXN/bodb02
	 
	Revisions:
		- 20220111@Louisa: Update SettlementSpecialBettypeProfile.OrdNo for ESports Phase 4 ( 54 early bettypes) [Redmine:#166330]
*/

USE bodb02
GO


IF OBJECT_ID ('tempdb..#Order_ResourceESports' ) IS NOT NULL
DROP TABLE #Order_ResourceESports

CREATE TABLE #Order_ResourceESports ( Ord SMALLINT, ResourceID VARCHAR(25) )

IF OBJECT_ID ('tempdb..#tmpProfile' ) IS NOT NULL
BEGIN DROP TABLE #tmpProfile END

CREATE TABLE #tmpProfile (BetType SMALLINT, ResourceID VARCHAR(25)	)


IF OBJECT_ID ('tempdb..#New_Ordered' ) IS NOT NULL
BEGIN DROP TABLE #New_Ordered END

CREATE TABLE #New_Ordered (BetType SMALLINT, ResourceID VARCHAR(25), NewOrderNo SMALLINT)
--------------------------------------------------------------------

INSERT INTO #tmpProfile (BetType, ResourceID)
SELECT p.BetType, p.ResourceID
FROM dbo.SettlementSpecialBettypeProfile p WITH(NOLOCK)
WHERE p.Sporttype = 43
	AND p.SettleType  ='EAR'
	AND ISNULL(p.OrdNo,0) < 8000

INSERT INTO  #Order_ResourceESports (Ord , ResourceID  )	
SELECT
				 1	,'9002__'	
UNION ALL SELECT 2	,'9006__'	
UNION ALL SELECT 3	,'9090__'	
UNION ALL SELECT 4	,'9007____'	
UNION ALL SELECT 5	,'9089____'	
UNION ALL SELECT 6	,'9091__'	
UNION ALL SELECT 7	,'9093__'	
UNION ALL SELECT 8	,'9101____'	
UNION ALL SELECT 9	,'9008__'	
UNION ALL SELECT 10	,'9134__'	
UNION ALL SELECT 11	,'9135__'	
UNION ALL SELECT 12	,'9011____'	
UNION ALL SELECT 13	,'9012__'	
UNION ALL SELECT 14	,'9015__'	
UNION ALL SELECT 15	,'9136__'	
UNION ALL SELECT 16	,'9016__'	
UNION ALL SELECT 17	,'9017__'	
UNION ALL SELECT 18	,'9018__'	
UNION ALL SELECT 19	,'9021__'	
UNION ALL SELECT 20	,'9137__'	
UNION ALL SELECT 21	,'9138__'	
UNION ALL SELECT 22	,'9022__'	
UNION ALL SELECT 23	,'9023__'	
UNION ALL SELECT 24	,'9024__'	
UNION ALL SELECT 25	,'9114__'	
UNION ALL SELECT 26	,'9142__'	
UNION ALL SELECT 27	,'9027____'	
UNION ALL SELECT 28	,'9113__'
UNION ALL SELECT 29	,'9141__'
UNION ALL SELECT 30	,'9028__'	
UNION ALL SELECT 31	,'9031__'	
UNION ALL SELECT 32	,'9131__'	
UNION ALL SELECT 33	,'9032__'	
UNION ALL SELECT 34	,'9033__'	
UNION ALL SELECT 35	,'9124__'	
UNION ALL SELECT 36	,'9132__'	
UNION ALL SELECT 37	,'9034__'	
UNION ALL SELECT 38	,'9037__'	
UNION ALL SELECT 39	,'9127__'	
UNION ALL SELECT 40	,'9128__'	
UNION ALL SELECT 41	,'9038__'	
UNION ALL SELECT 42	,'9039__'	
UNION ALL SELECT 43	,'9040__'	
UNION ALL SELECT 44	,'9043__'	
UNION ALL SELECT 45	,'9129__'	
UNION ALL SELECT 46	,'9130__'	
UNION ALL SELECT 47	,'9044__'	
UNION ALL SELECT 48	,'9045__'	
UNION ALL SELECT 49	,'9046__'	
UNION ALL SELECT 50	,'9049__'	
UNION ALL SELECT 51	,'9121__'	
UNION ALL SELECT 52	,'9050__'	
UNION ALL SELECT 53	,'9051__'	
UNION ALL SELECT 54	,'9122__'	
UNION ALL SELECT 55	,'9052__'	
UNION ALL SELECT 56	,'9055__'	
UNION ALL SELECT 57	,'9123__'	
UNION ALL SELECT 58	,'9056__'	
UNION ALL SELECT 59	,'9057__'	
UNION ALL SELECT 60	,'9125__'	
UNION ALL SELECT 61	,'9126__'	
UNION ALL SELECT 62	,'9133__'	
UNION ALL SELECT 63	,'9115__'	
UNION ALL SELECT 64	,'9074__'	
UNION ALL SELECT 65	,'9059__'	
UNION ALL SELECT 66	,'9062____'	
UNION ALL SELECT 67	,'9068____'	
UNION ALL SELECT 68	,'9063__'	
UNION ALL SELECT 69	,'9067__'	
UNION ALL SELECT 70	,'9064__'	
UNION ALL SELECT 71	,'9066__'	
UNION ALL SELECT 72	,'9073____'	
UNION ALL SELECT 73	,'9075__'	
UNION ALL SELECT 74	,'9065__'	
UNION ALL SELECT 75	,'9069____'	
UNION ALL SELECT 76	,'9072____'	

UNION ALL SELECT 77	,'9139__'	
UNION ALL SELECT 78	,'9140__'	

UNION ALL SELECT 79	,'9058__'	
UNION ALL SELECT 80	,'9087__'	

INSERT INTO #New_Ordered (BetType,ResourceID, NewOrderNo)
----MAP 1
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE p.ResourceID LIKE '____[0][1]%'

----MAP 2
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 1999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE  p.ResourceID LIKE '____[0][2]%'
----MAP 3
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 2999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE  p.ResourceID LIKE '____[0][3]%'
----MAP 4
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 3999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE  p.ResourceID LIKE '____[0][4]%'
----MAP 5
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 4999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE  p.ResourceID LIKE '____[0][5]%'
----MAP 6
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 5999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE  p.ResourceID LIKE '____[0][6]%'
----MAP 7
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.Ord, p.bettype, p.ResourceID) + 6999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID
	WHERE  p.ResourceID LIKE '____[0][7]%'


----********* STEP3: UPDATE Column OrdNo for dbo.SettlementSpecialBettypeProfile **********

UPDATE dbo.SettlementSpecialBettypeProfile WITH (ROWLOCK)
SET OrdNo = n.NewOrderNo
FROM dbo.SettlementSpecialBettypeProfile  p
	INNER JOIN #New_Ordered n
		ON p.BetType =n.BetType AND p.ResourceID  = n.ResourceID
WHERE p.SportType  = 43
	AND p.SettleType ='EAR'
