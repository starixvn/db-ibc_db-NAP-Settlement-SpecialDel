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
 SELECT 9002 AS BetType		,'9002__' AS ResourceID	,	1 AS OrderGroup
UNION ALL SELECT 9003		,'9002__'		,2
UNION ALL SELECT 9004		,'9002__'		,3
UNION ALL SELECT 9005		,'9002__'		,4
UNION ALL SELECT 9006		,'9006__'		,5
UNION ALL SELECT 9007		,'9007__05'		,6
UNION ALL SELECT 9007		,'9007__10'		,7
UNION ALL SELECT 9008		,'9008__'		,8
UNION ALL SELECT 9009		,'9008__'		,9
UNION ALL SELECT 9010		,'9008__'		,10
UNION ALL SELECT 9078		,'9008__'		,11
UNION ALL SELECT 9011		,'9011__01'		,12
UNION ALL SELECT 9011		,'9011__02'		,13
UNION ALL SELECT 9011		,'9011__03'		,14
UNION ALL SELECT 9012		,'9012__'		,15
UNION ALL SELECT 9013		,'9012__'		,16
UNION ALL SELECT 9014		,'9012__'		,17
UNION ALL SELECT 9079		,'9012__'		,18
UNION ALL SELECT 9015		,'9015__'		,19
UNION ALL SELECT 9016		,'9016__'		,20
UNION ALL SELECT 9017		,'9017__'		,21
UNION ALL SELECT 9018		,'9018__'		,22
UNION ALL SELECT 9019		,'9018__'		,23
UNION ALL SELECT 9020		,'9018__'		,24
UNION ALL SELECT 9080		,'9018__'		,25
UNION ALL SELECT 9021		,'9021__'		,26
UNION ALL SELECT 9022		,'9022__'		,27
UNION ALL SELECT 9023		,'9023__'		,28
UNION ALL SELECT 9024		,'9024__'		,29
UNION ALL SELECT 9025		,'9024__'		,30
UNION ALL SELECT 9026		,'9024__'		,31
UNION ALL SELECT 9081		,'9024__'		,32
UNION ALL SELECT 9027		,'9027__01'		,33
UNION ALL SELECT 9027		,'9027__02'		,34
UNION ALL SELECT 9027		,'9027__03'		,35
UNION ALL SELECT 9028		,'9028__'		,36
UNION ALL SELECT 9029		,'9028__'		,37
UNION ALL SELECT 9030		,'9028__'		,38
UNION ALL SELECT 9082		,'9028__'		,39
UNION ALL SELECT 9031		,'9031__'		,40
UNION ALL SELECT 9032		,'9032__'		,41
UNION ALL SELECT 9033		,'9033__'		,42
UNION ALL SELECT 9034		,'9034__'		,43
UNION ALL SELECT 9035		,'9034__'		,44
UNION ALL SELECT 9036		,'9034__'		,45
UNION ALL SELECT 9083		,'9034__'		,46
UNION ALL SELECT 9037		,'9037__'		,47
UNION ALL SELECT 9038		,'9038__'		,48
UNION ALL SELECT 9039		,'9039__'		,49
UNION ALL SELECT 9040		,'9040__'		,50
UNION ALL SELECT 9041		,'9040__'		,51
UNION ALL SELECT 9042		,'9040__'		,52
UNION ALL SELECT 9084		,'9040__'		,53
UNION ALL SELECT 9043		,'9043__'		,54
UNION ALL SELECT 9044		,'9044__'		,55
UNION ALL SELECT 9045		,'9045__'		,56
UNION ALL SELECT 9046		,'9046__'		,57
UNION ALL SELECT 9047		,'9046__'		,58
UNION ALL SELECT 9048		,'9046__'		,59
UNION ALL SELECT 9085		,'9046__'		,60
UNION ALL SELECT 9049		,'9049__'		,61
UNION ALL SELECT 9050		,'9050__'		,62
UNION ALL SELECT 9051		,'9051__'		,63
UNION ALL SELECT 9052		,'9052__'		,64
UNION ALL SELECT 9053		,'9052__'		,65
UNION ALL SELECT 9054		,'9052__'		,66
UNION ALL SELECT 9086		,'9052__'		,67
UNION ALL SELECT 9055		,'9055__'		,68
UNION ALL SELECT 9056		,'9056__'		,69
UNION ALL SELECT 9057		,'9057__'		,70
UNION ALL SELECT 9058		,'9058__'		,71
UNION ALL SELECT 9059		,'9059__'		,72
UNION ALL SELECT 9060		,'9059__'		,73
UNION ALL SELECT 9061		,'9059__'		,74
UNION ALL SELECT 9074		,'9074__'		,75
UNION ALL SELECT 9063		,'9063__'		,76
UNION ALL SELECT 9067		,'9067__'		,77
UNION ALL SELECT 9064		,'9064__'		,78
UNION ALL SELECT 9066		,'9066__'		,79
UNION ALL SELECT 9076		,'9066__'		,80
UNION ALL SELECT 9065		,'9065__'		,81
UNION ALL SELECT 9062		,'9062__05'		,82
UNION ALL SELECT 9062		,'9062__10'		,83
----Map X Round Y			  
UNION ALL SELECT 9068		,'9068[0][1-5]__'	,84	
UNION ALL SELECT 9069		,'9069[0][1-5]__'	,84	
UNION ALL SELECT 9072		,'9072[0][1-5]__'	,84	
UNION ALL SELECT 9073		,'9073[0][1-5]__'	,84
----Map X Final Round Bomb Plant
UNION ALL SELECT 9075       ,'9075[0][1-5]'		,84
-----Map X Overtime
UNION ALL SELECT 9087       ,'9087[0][1-5]'		,84


GO

----********* STEP2: GENERATE NEW ARRANGEMENT **********
	--Map 01: range 1000~1999
	--Map 02: range 2000~2999
	--....
	--Map 05: range 5000~5999

	--9075[0][1-5]	Map X Final Round Bomb Plant: Range 10000~10099
	--9087X[0][1-5]	Map X Overtime: Range : Range 10100

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
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, RIGHT(p.ResourceId,2), l.Bettype) + 999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE p.ResourceID LIKE '____[0][1]%'
		AND RIGHT(p.ResourceID,2) < '43'
----MAP 2
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, RIGHT(p.ResourceId,2), l.Bettype) + 1999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][2]%'
		AND RIGHT(p.ResourceID,2) < '43'
----MAP 3
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, RIGHT(p.ResourceId,2), l.Bettype) + 2999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][3]%' 
		AND RIGHT(p.ResourceID,2) < '43'
----MAP 4
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, RIGHT(p.ResourceId,2), l.Bettype) + 3999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][4]%'
		AND RIGHT(p.ResourceID,2) < '43'
----MAP 5
	UNION ALL
	SELECT l.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY l.OrderGroup, RIGHT(p.ResourceId,2), l.Bettype) + 4999 AS NewOrderNo
	FROM #tmpProfile p
	INNER JOIN  #Order_ResourceESports l
		ON p.ResourceID LIKE l.ResourceID AND p.bettype = l.bettype
	WHERE  p.ResourceID LIKE '____[0][5]%'
		AND RIGHT(p.ResourceID,2) < '43'
----MAP 6
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY  p.Bettype) + 5999 AS NewOrderNo
	FROM #tmpProfile p
	WHERE  p.ResourceID IN( '904606','905206','905506','905606','905706')
----MAP 7
	UNION ALL
	SELECT p.BetType
		, p.ResourceID
		, ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY p.Bettype) + 6999 AS NewOrderNo
	FROM #tmpProfile p
	WHERE  p.ResourceID IN( '904607','905207','905507','905607','905707')

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













