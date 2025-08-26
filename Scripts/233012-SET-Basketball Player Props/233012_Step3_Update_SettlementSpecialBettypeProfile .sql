/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250822@Louisa: Update OrderNo to display on popup calculate [Redmine:#233012]
*/


IF OBJECT_ID ('tempdb..#tmpOrderDetail' ) IS NOT NULL
DROP TABLE #tmpOrderDetail
CREATE TABLE #tmpOrderDetail ( Bettype SMALLINT, Betid BIGINT, ResourceID VARCHAR(50), OrderNo SMALLINT )

DECLARE @tmpOrder TABLE ( RankNo BIGINT,  bettype SMALLINT)

INSERT INTO @tmpOrder (RankNo, bettype )
		  SELECT 1   ,653	---point
UNION ALL SELECT 2   ,654	---point
UNION ALL SELECT 3   ,655	---point
UNION ALL SELECT 4   ,685	---point

UNION ALL SELECT 5   ,656	---assists
UNION ALL SELECT 6   ,657	---assists
UNION ALL SELECT 7   ,658	---assists
UNION ALL SELECT 8   ,686	---assists

UNION ALL SELECT 9   ,665	---blocks
UNION ALL SELECT 10  ,666	---blocks

UNION ALL SELECT 11  ,659	---rebounds
UNION ALL SELECT 12  ,660	---rebounds
UNION ALL SELECT 13  ,661	---rebounds
UNION ALL SELECT 14  ,687	---rebounds

UNION ALL SELECT 15  ,667	---steals
UNION ALL SELECT 16  ,668	---steals

UNION ALL SELECT 17  ,662	---3-point
UNION ALL SELECT 18  ,663	---3-point
UNION ALL SELECT 19  ,664	---3-point
UNION ALL SELECT 20  ,688	---3-point

UNION ALL SELECT 21  ,669	---point-assists-rebound
UNION ALL SELECT 22  ,670	---point-assists-rebound
UNION ALL SELECT 23  ,671	---point-assists-rebound

UNION ALL SELECT 24  ,672	---assists-rebound
UNION ALL SELECT 25  ,673	---point-rebound
UNION ALL SELECT 26  ,674	---block-steaks
UNION ALL SELECT 27  ,677	---double-double
UNION ALL SELECT 28  ,679	---triple-double
UNION ALL SELECT 29  ,675	---have 30+ and WAS win 
UNION ALL SELECT 30  ,676	---have 10+pint and 4+assists and WAS win
UNION ALL SELECT 31  ,678	---have 10+pint and 4+assists 5+rebound and WAS win

--Other
UNION ALL SELECT 32  ,680	---most point score (order by player)
UNION ALL SELECT 33  ,683	---most assists (order by player)
UNION ALL SELECT 34  ,681	---most rebound (order by player)
UNION ALL SELECT 35  ,684	---Most 3-point (order by player)
UNION ALL SELECT 36  ,682	---most steal (order by player)
 

INSERT INTO  #tmpOrderDetail (Bettype, Betid, ResourceID, OrderNo)
SELECT cte.Bettype, cte.Betid, cte.ResourceID
	, CASE WHEN cte.bettype NOT IN (680,681,682,683,684) ---bettype Player X, mỗi range betid chiếm 500
				THEN (CAST(RIGHT(betid,2) AS INT)-1)*500 
				ELSE 25000 END ---range bettype other từ 25000
	+ RN AS OrderNo
FROM (	SELECT cte.RankNo, sp.bettype ---, b.typenamee
				, sp.betid , ResourceID
				,ROW_NUMBER() OVER(PARTITION BY CASE WHEN sp.bettype NOT IN (680,681,682,683,684) THEN sp.betid ELSE 100+betid END
									ORDER BY CASE WHEN sp.bettype NOT IN (680,681,682,683,684) THEN 1 ELSE 2 END
														,sp.betid, cte.RankNo
														,CASE WHEN sp.bettype NOT IN (680,681,682,683,684) THEN CAST(RIGHT (sp.ResourceID,2) AS INT) ELSE 0 END
									)AS RN
				
		FROM @tmpOrder cte
			INNER JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
				ON cte.bettype = sp.bettype
			--INNER JOIN bettype b WITH(NOLOCK) ON sp.bettype = b.typeid
	)cte


UPDATE sp
SET sp.OrdNo = od.OrderNo
FROM #tmpOrderDetail od
INNER JOIN SettlementSpecialBettypeProfile sp WITH(NOLOCK)
	ON od.Bettype = sp.BetType AND od.Betid = sp.BetID AND od.ResourceID = sp.ResourceID AND sp.SportType = 2

