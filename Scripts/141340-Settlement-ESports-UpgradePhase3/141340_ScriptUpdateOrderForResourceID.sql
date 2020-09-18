/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created by: 20200917@Louisa
    Task: Update OrdNo for ESport (dbo.SettlementSpecialBettypeProfile)  [Redmine:#141340]
    DB: DBPRO/BODB02  
    
    Revisions:            
		- 20200917@Louisa: Update OrdNo for ESport (dbo.SettlementSpecialBettypeProfile)  [Redmine:#141340]

	Param's Explanation:
		
*/

----********* STEP1: DEFINE NEW ARRANGEMENT **********
IF OBJECT_ID ('tempdb..#Order_ResourceESports' ) IS NOT NULL
BEGIN DROP TABLE #Order_ResourceESports END

CREATE TABLE #Order_ResourceESports (BetType SMALLINT, ResourceID VARCHAR(25), OrderGroup SMALLINT)

INSERT INTO  #Order_ResourceESports (BetType , ResourceID , OrderGroup )

select 9002 AS BetType	,'9002__' as ResourceID	, 1 AS OrderGroup
union all select 9003	,'9002__'	, 2
union all select 9004	,'9002__'	, 3
union all select 9005	,'9002__'	, 4
union all select 9006	,'9006__'	, 5
union all select 9007	,'9007____'	, 6
union all select 9008	,'9008__'	, 8
union all select 9009	,'9008__'	, 9
union all select 9010	,'9008__'	, 10
union all select 9078	,'9008__'	, 11
union all select 9011	,'9011____'	, 12
union all select 9012	,'9012__'	, 15
union all select 9013	,'9012__'	, 16
union all select 9014	,'9012__'	, 17
union all select 9079	,'9012__'	, 18
union all select 9015	,'9015__'	, 19
union all select 9016	,'9016__'	, 20
union all select 9017	,'9017__'	, 21
union all select 9018	,'9018__'	, 22
union all select 9019	,'9018__'	, 23
union all select 9020	,'9018__'	, 24
union all select 9080	,'9018__'	, 25
union all select 9021	,'9021__'	, 26
union all select 9022	,'9022__'	, 27
union all select 9023	,'9023__'	, 28
union all select 9024	,'9024__'	, 29
union all select 9025	,'9024__'	, 30
union all select 9026	,'9024__'	, 31
union all select 9081	,'9024__'	, 32
union all select 9027	,'9027____'	, 33
union all select 9028	,'9028__'	, 36
union all select 9029	,'9028__'	, 37
union all select 9030	,'9028__'	, 38
union all select 9082	,'9028__'	, 39
union all select 9031	,'9031__'	, 40
union all select 9032	,'9032__'	, 41
union all select 9033	,'9033__'	, 42
union all select 9034	,'9034__'	, 43
union all select 9035	,'9034__'	, 44
union all select 9036	,'9034__'	, 45
union all select 9083	,'9034__'	, 46
union all select 9037	,'9037__'	, 47
union all select 9038	,'9038__'	, 48
union all select 9039	,'9039__'	, 49
union all select 9040	,'9040__'	, 50
union all select 9041	,'9040__'	, 51
union all select 9042	,'9040__'	, 52
union all select 9084	,'9040__'	, 53
union all select 9043	,'9043__'	, 54
union all select 9044	,'9044__'	, 55
union all select 9045	,'9045__'	, 56
union all select 9046	,'9046__'	, 57
union all select 9047	,'9046__'	, 58
union all select 9048	,'9046__'	, 59
union all select 9085	,'9046__'	, 60
union all select 9049	,'9049__'	, 61
union all select 9050	,'9050__'	, 62
union all select 9051	,'9051__'	, 63
union all select 9052	,'9052__'	, 64
union all select 9053	,'9052__'	, 65
union all select 9054	,'9052__'	, 66
union all select 9086	,'9052__'	, 67
union all select 9055	,'9055__'	, 68
union all select 9056	,'9056__'	, 69
union all select 9057	,'9057__'	, 70
union all select 9058	,'9058__'	, 71
union all select 9074	,'9074__'	, 72
union all select 9059	,'9059__'	, 73
union all select 9060	,'9059__'	, 74
union all select 9061	,'9059__'	, 75
union all select 9063	,'9063__'	, 76
union all select 9067	,'9067__'	, 77
union all select 9064	,'9064__'	, 78
union all select 9066	,'9066__'	, 79
union all select 9076	,'9066__'	, 80
union all select 9065	,'9065__'	, 81
union all select 9062	,'9062____'	, 82
union all select 9068	,'9068____'	, 84
union all select 9069	,'9069____'	, 84
union all select 9070	,'9069____'	, 84
union all select 9071	,'9069____'	, 84
union all select 9077	,'9069____'	, 84
union all select 9072	,'9072____'	, 84
union all select 9073	,'9073____'	, 84
union all select 9075	, '9075__'	, 91
union all select 9087	, '9087__'	, 92



----********* STEP2: GENERATE NEW ARRANGEMENT **********
	--Map 01: range 1000~1999
	--Map 02: range 2000~2999
	--....
	--Map 09: range 9000~9999

	--Map and Round not used: Update dbo.SettlementSpecialBettypeProfile.OrdNo = 0

IF OBJECT_ID ('tempdb..#New_Ordered' ) IS NOT NULL
BEGIN DROP TABLE #New_Ordered END

IF OBJECT_ID ('tempdb..#tmpProfile' ) IS NOT NULL
BEGIN DROP TABLE #tmpProfile END

SELECT p.BetType, p.ResourceID 
INTO #tmpProfile 
FROM dbo.SettlementSpecialBettypeProfile p WITH(NOLOCK)
WHERE p.Sporttype =43
	AND p.SettleType  ='EAR'

CREATE TABLE #New_Ordered (BetType SMALLINT, ResourceID VARCHAR(25), NewOrderNo SMALLINT)

INSERT INTO #New_Ordered (BetType,ResourceID, NewOrderNo) ---1287
----MAP 1
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE p.ResourceID LIKE '____[0][1]%'
----MAP 2
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 1999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][2]%'
----MAP 3
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup,substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 2999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][3]%'
----MAP 4
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 3999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][4]%'
----MAP 5
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 4999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][5]%'
----MAP 6
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 5999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][6]%'
----MAP 7
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 6999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][7]%'
----MAP 8
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 7999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][8]%'
----MAP 9
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, substring(p.ResourceId,5,2), RIGHT(p.ResourceId,2), l.Bettype) + 8999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][9]%'

----********* STEP3: UPDATE Column OrdNo for dbo.SettlementSpecialBettypeProfile **********
UPDATE dbo.SettlementSpecialBettypeProfile WITH (ROWLOCK)
SET OrdNo = n.NewOrderNo
FROM dbo.SettlementSpecialBettypeProfile  p
	INNER JOIN #New_Ordered n
		ON p.BetType =n.BetType AND p.ResourceID  = n.ResourceID
WHERE p.SportType  =43
	AND p.SettleType ='EAR'


UPDATE dbo.SettlementSpecialBettypeProfile WITH (ROWLOCK)
SET OrdNo = 0
FROM dbo.SettlementSpecialBettypeProfile p
	LEFT JOIN #New_Ordered n
		ON p.BetType =n.BetType AND p.ResourceID  = n.ResourceID
WHERE p.SportType  =43
	AND p.SettleType ='EAR'
	AND n.BetType IS NULL

