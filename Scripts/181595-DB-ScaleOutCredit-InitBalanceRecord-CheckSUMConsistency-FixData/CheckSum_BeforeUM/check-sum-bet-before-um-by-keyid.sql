--Group 2 - Before UM
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: compare data between SITEDB3 and DBTRANS [Redmineid:#181595] 

		1) zzzbettrans
		2) zzzbettransm
*/
DROP TABLE IF EXISTS #__CheckSum_MigrateSiteDB3_Temp
CREATE TABLE #__CheckSum_MigrateSiteDB3_Temp (recommend INT, TableName VARCHAR(100))

DROP TABLE IF EXISTS #__recommendList
CREATE TABLE #__recommendList(custid INT PRIMARY KEY)

INSERT INTO #__recommendList(custid)
SELECT DISTINCT custid
FROM dbo.Customer c WITH (NOLOCK)
	INNER JOIN dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
WHERE s.SiteLabel  = 'IBC' AND c.roleid = 2

BEGIN--------compare 1) zzzbettrans  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT cc.recommend
				,CHECKSUM_AGG(CHECKSUM( t.[transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
								)) AS TotalCheckSum
		FROM dbo.zzzbettrans t WITH(NOLOCK)
			INNER JOIN custdb.dbo.custInfo cc WITH(NOLOCK) ON t.custid = cc.custid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = cc.recommend
		WHERE keyid <= 1012490248
		GROUP BY cc.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT cc.recommend, CHECKSUM_AGG(CHECKSUM(  t.[transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.zzzbettrans t WITH (NOLOCK)
										INNER JOIN custdb.dbo.custInfo cc WITH(NOLOCK) ON t.custid = cc.custid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = cc.recommend 
									WHERE keyid <= 1012490248
									GROUP BY cc.recommend
								'
						)
	)
	
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'zzzbettrans' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 2) zzzbettransm  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT cc.recommend
				,CHECKSUM_AGG(CHECKSUM( [transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
								)) AS TotalCheckSum
		FROM dbo.zzzbettransm t WITH(NOLOCK)
			INNER JOIN custdb.dbo.custInfo cc WITH(NOLOCK) ON t.custid = cc.custid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = cc.recommend
		WHERE keyid <= 514528
		GROUP BY cc.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT cc.recommend, CHECKSUM_AGG(CHECKSUM(  [transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.zzzbettransm t WITH (NOLOCK)
										INNER JOIN custdb.dbo.custInfo cc WITH(NOLOCK) ON t.custid = cc.custid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = cc.recommend 
									WHERE keyid <= 514528
									GROUP BY cc.recommend
								'
						)
	)
	
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'zzzbettransm' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END