/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_GetBalanceByTransID]
(	
	@TransID	VARCHAR(MAX)
)
RETURNS TABLE 
AS

/*
    Created by: Paul
	Date: 20170726
	Original: 
	Task: 
	DB: DBTXN.bodb02

	Revisions:			
		- 20170726@Paul: Create new [RedmineID: #77175]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's Explanation:      
		You need to use option: option (maxrecursion 0) at the statement if the lengh of string exceed 100 levels

*/

RETURN 
(
	WITH cteTransId AS (
		SELECT CAST(value AS BIGINT) transid
		FROM STRING_SPLIT(@TransID, ',')

		UNION ALL

		SELECT NULL
	), cteBettrans AS (
		SELECT	b.matchid,
				b.custid,
				b.winlost,
				b.actual_stake,
				b.playercomm,
				b.winlostdate,
				b.ruben,
				b.bettype
		FROM dbo.bettrans b WITH(ROWLOCK)
			INNER JOIN cteTransId t ON b.transid = t.transid

		UNION ALL

		SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	), cteMatch AS (
		SELECT	b.matchid,
				b.custid,
				b.winlost,
				b.actual_stake,
				b.playercomm,
				b.winlostdate,
				b.ruben,
				b.bettype,
				m.SportType
		FROM cteBettrans b
			INNER JOIN dbo.Match3rd m WITH(NOLOCK) ON m.Match3rdId = b.matchid
		UNION ALL

		SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	), cteBalanceType AS (
		SELECT	DISTINCT CASE WHEN s.BetType BETWEEN 801 AND 806 THEN 4 ELSE p.BalanceType END AS BalanceType,
				s.SportType,
				s.BetType
		FROM dbo.SportBettypeMatrix s WITH(NOLOCK)
			INNER JOIN dbo.Products p WITH(NOLOCK) ON p.ProductID = s.ProductID
	)
	SELECT	bt.BalanceType,
			b.custid,
			SUM(b.winlost - b.actual_stake + b.playercomm) AS Balance,
			b.winlostdate,
			SUM(CASE when b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END) AS GameBalance
	FROM cteMatch b
		INNER JOIN cteBalanceType bt WITH(NOLOCK) ON bt.SportType = b.sporttype AND bt.BetType = b.bettype
	GROUP BY b.custid, b.winlostdate, bt.BalanceType	
)
GO