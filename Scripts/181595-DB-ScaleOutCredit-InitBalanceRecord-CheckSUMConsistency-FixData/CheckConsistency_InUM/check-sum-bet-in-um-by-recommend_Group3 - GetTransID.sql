--Group 3 - In UM
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: compare data between SITEDB3 and DBTRANS [Redmineid:#181595] 

		1) Bettransm    
		2) zzzbettrans  
		3) zzzbettransm 
		

*/
---Run on SITEDB3
/* ----Find text and replace by list of wrong recommends 

1) Bettransm    -> bettransm_recommendList
2) zzzbettrans  -> zzzbettrans_recommendList
3) zzzbettransm -> zzzbettransm_recommendList

*/
DROP TABLE IF EXISTS #__CheckSum_MigrateSiteDB3_Temp
CREATE TABLE #__CheckSum_MigrateSiteDB3_Temp (transid BIGINT, TableName VARCHAR(100))

BEGIN--------compare 1) bettransm  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.TransId
				,BINARY_CHECKSUM( 
				t.[custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], [liveindicator], [betteam], t.[creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], [scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm]
								) AS TotalCheckSum
		FROM dbo.bettransm t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
		WHERE cc.recommend IN (bettransm_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.transid, BINARY_CHECKSUM(  t.[custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], [liveindicator], [betteam], t.[creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], [scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm]
																	) AS TotalCheckSum
									FROM bodb02.dbo.bettransm t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
									WHERE t.recommend IN (bettransm_recommendList)
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.TransId, t.transid), 'bettransm' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.transid = t.transid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END


BEGIN--------compare 2) zzzbettrans  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.keyid
				,BINARY_CHECKSUM( t.[transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],t.[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
								) AS TotalCheckSum
		FROM dbo.zzzbettrans t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
		WHERE cc.recommend IN (zzzbettrans_recommendList)
	
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.keyid, BINARY_CHECKSUM(  t.[transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],t.[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
																	) AS TotalCheckSum
									FROM bodb02.dbo.zzzbettrans t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_customer cc WITH(NOLOCK) ON t.custid = cc.custid
									WHERE cc.recommend IN (zzzbettrans_recommendList)
								'
						)
	)
	
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.keyid, t.keyid), 'zzzbettrans' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.keyid = t.keyid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 3) zzzbettransm  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.keyid
				,BINARY_CHECKSUM( [transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],t.[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
								) AS TotalCheckSum
		FROM dbo.zzzbettransm t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_Customer cc WITH(NOLOCK) ON t.custid = cc.custid
		WHERE cc.recommend IN (zzzbettransm_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.keyid, BINARY_CHECKSUM(  [transid],t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[livehomescore],[liveawayscore],[liveindicator],[betteam],t.[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[matchid],[bettype],[VoidingHistoryId]
																	) AS TotalCheckSum
									FROM bodb02.dbo.zzzbettransm t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_customer cc WITH(NOLOCK) ON t.custid = cc.custid
									WHERE cc.recommend IN (zzzbettransm_recommendList)
								'
						)
	)
	
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.keyid, t.keyid), 'zzzbettransm' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.keyid = t.keyid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

SELECT COUNT(1) as cnt, TableName
FROM #__CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)
GROUP BY TableName

-- zzzbettrans/zzzbettransm -> transid in temporary table: keyid
SELECT transid, TableName
FROM #__CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)

GO
