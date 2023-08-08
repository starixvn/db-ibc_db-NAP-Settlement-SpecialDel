--Group 3 - In UM
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: compare data between SITEDB3 and DBTRANS [Redmineid:#181595] 

		1) Bettransm    
		2) zzzbettrans  -> zzzbettrans_maxkeyid_beforeUM
		3) zzzbettransm -> zzzbettransm_maxkeyid_beforeUM
		

*/
---Run on SITEDB3
DROP TABLE IF EXISTS #__CheckSum_MigrateSiteDB3_Temp
CREATE TABLE #__CheckSum_MigrateSiteDB3_Temp (recommend INT, TableName VARCHAR(100))

DROP TABLE IF EXISTS #__recommendList
CREATE TABLE #__recommendList(custid INT)

INSERT INTO #__recommendList(custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer c WITH (NOLOCK)
	INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
WHERE s.SiteLabel  = 'IBC' AND c.roleid = 2

BEGIN--------compare 1) bettransm  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT cc.recommend
				,CHECKSUM_AGG(CHECKSUM( t.[custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], [liveindicator], [betteam], t.[creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], [scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm]
								)) AS TotalCheckSum
		FROM dbo.bettransm t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = cc.recommend
		GROUP BY cc.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT cc.recommend, CHECKSUM_AGG(CHECKSUM(  t.[custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], [liveindicator], [betteam], t.[creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], [scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.bettransm t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = cc.recommend 
									GROUP BY cc.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'bettransm' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END


BEGIN--------compare 2) zzzbettrans  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT cc.recommend
				,CHECKSUM_AGG(CHECKSUM( t.[transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
								)) AS TotalCheckSum
		FROM dbo.zzzbettrans t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = cc.recommend
		GROUP BY cc.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT cc.recommend, CHECKSUM_AGG(CHECKSUM(  t.[transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],t.[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.zzzbettrans t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_customer cc WITH(NOLOCK) ON t.custid = cc.custid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = cc.recommend 
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

BEGIN--------compare 3) zzzbettransm  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT cc.recommend
				,CHECKSUM_AGG(CHECKSUM( [transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
								)) AS TotalCheckSum
		FROM dbo.zzzbettransm t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = cc.recommend
		GROUP BY cc.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT cc.recommend, CHECKSUM_AGG(CHECKSUM(  [transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],t.[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.zzzbettransm t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_customer cc WITH(NOLOCK) ON t.custid = cc.custid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = cc.recommend 
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
GO