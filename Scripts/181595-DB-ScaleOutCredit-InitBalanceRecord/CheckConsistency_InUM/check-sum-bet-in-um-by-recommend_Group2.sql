--Group 2 - In UM
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: compare data between SITEDB3 and DBTRANS [Redmineid:#181595] 

		1) Bettrans
		2) BettransInfo
		3) BettransLC
		4) BettransRnG
		5) bettransG
		6) Translog
		7) Transfer
		8) Transfer_Coll
		9) TransferInfo

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

BEGIN--------compare 1) bettrans  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT recommend
				,CHECKSUM_AGG(CHECKSUM( t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[awinlost],[mwinlost],[playercomm],[comm],[acomm],[apositiontaking],[mpositiontaking],[tpositiontaking],[playerdiscount],[discount],[adiscount],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[oddsspread],[actualrate],[matchid],[recommend],[mrecommend],[ruben],[betid],[statuswinlost],[modds],[bettype],[betdaqid],[actual_stake],[currency],[ip],[transdesc],[sdiscount],[scomm],[spositiontaking],[swinlost],[srecommend],[Username],[CurrencyName],[virtualrate],[oddstype],[statusID],[currency2],[balance],[SecAcceptFlag],[transid2],[recommdate],[ExtraInfo],[WalletType],[BonusID],[RefCode],[epositiontaking],[ReasonID],[sort],[BetSiteID]
								)) AS TotalCheckSum
		FROM dbo.bettrans t WITH(NOLOCK, INDEX=IX_Recommend)
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = t.recommend
		WHERE t.winlostdate >= '2023-08-13' OR (t.matchid IN (29, 2799))
		GROUP BY recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT recommend, CHECKSUM_AGG(CHECKSUM(  t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[awinlost],[mwinlost],[playercomm],[comm],[acomm],[apositiontaking],[mpositiontaking],[tpositiontaking],[playerdiscount],[discount],[adiscount],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[oddsspread],[actualrate],[matchid],[recommend],[mrecommend],[ruben],[betid],[statuswinlost],[modds],[bettype],[betdaqid],[actual_stake],[currency],[ip],[transdesc],[sdiscount],[scomm],[spositiontaking],[swinlost],[srecommend],[Username],[CurrencyName],[virtualrate],[oddstype],[statusID],[currency2],[balance],[SecAcceptFlag],[transid2],[recommdate],[ExtraInfo],[WalletType],[BonusID],[RefCode],[epositiontaking],[ReasonID],[sort],[BetSiteID]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.bettrans t WITH (NOLOCK, INDEX=IX_Recommend)
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.recommend 
									WHERE t.winlostdate >= ''2023-08-13'' OR (t.matchid IN (29, 2799))
									GROUP BY recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'bettrans' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 1) bettransInfo  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT b.recommend
				,CHECKSUM_AGG(CHECKSUM(  [SecAcceptTime],[LiveBetAcceptTime],[OriginalOdds], [ThirdTransID]
								)) AS TotalCheckSum
		FROM dbo.bettransInfo t WITH(NOLOCK)
			INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX=IX_Recommend) ON t.transid = b.transid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = b.recommend
		WHERE b.winlostdate >= '2023-08-13'
		GROUP BY b.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT b.recommend, CHECKSUM_AGG(CHECKSUM(  [SecAcceptTime],[LiveBetAcceptTime],[OriginalOdds], [ThirdTransID]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.bettransInfo t WITH (NOLOCK)
										INNER JOIN bodb02.dbo.bettrans b WITH(NOLOCK, INDEX=IX_Recommend) ON t.transid = b.transid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = b.recommend 
									WHERE winlostdate >= ''2023-08-13''
									GROUP BY b.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'bettransInfo' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 1) bettransLC  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT recommend
				,CHECKSUM_AGG(CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[NetStake],[SiteID],[epositiontaking]
								)) AS TotalCheckSum
		FROM dbo.bettransLC t WITH(NOLOCK, INDEX=IX_Recommend)
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = t.recommend
		WHERE t.winlostdate >= '2023-08-13'
		GROUP BY t.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT recommend
										,CHECKSUM_AGG(CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[NetStake],[SiteID],[epositiontaking]
															)) AS TotalCheckSum
									FROM bodb02.dbo.bettransLC t WITH(NOLOCK, INDEX=IX_Recommend)
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.recommend
									WHERE t.winlostdate >= ''2023-08-13''	
									GROUP BY t.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'bettransLC' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)

END

BEGIN--------compare 4) BettransRnG  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT recommend
				,CHECKSUM_AGG(CHECKSUM( t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[SiteID],[Additional],[JackpotInfo],[RefNo2],[ContributionRate],[BetStake],[ContributionStake3rd],[epositiontaking]
								)) AS TotalCheckSum
		FROM dbo.BettransRnG t WITH(NOLOCK, INDEX=IX_recommend)
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = t.recommend
		WHERE t.winlostdate >= '2023-08-13'
		GROUP BY t.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT recommend, CHECKSUM_AGG(CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[SiteID],[Additional],[JackpotInfo],[RefNo2],[ContributionRate],[BetStake],[ContributionStake3rd],[epositiontaking]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.BettransRnG t WITH (NOLOCK, INDEX=IX_recommend)
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.recommend 
									WHERE t.winlostdate >= ''2023-08-13''	
									GROUP BY t.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'BettransRnG' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 5) bettransG  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT cc.recommend
				,CHECKSUM_AGG(CHECKSUM( t.[custid],[transdate],[oddsid],[odds],[stake],[status],[winlost],[betteam],[creator],[refno],[winlostdate],[betfrom],[checktime],[apositiontaking],[mpositiontaking],[tpositiontaking],[awinlost],[mwinlost],[playerdiscount],[discount],[adiscount],[playercomm],[comm],[acomm],[actualrate],[matchid],[matchdate],[statuswinlost],[ruben],[bettype],[spositiontaking],[swinlost],[sdiscount],[scomm],[statusID],[virtualrate],[SiteID],[transdesc],[BetID3rd],[epositiontaking],[actual_stake],[netstake]
								)) AS TotalCheckSum
		FROM dbo.bettransG t WITH(NOLOCK)
			INNER JOIN custdb.dbo.custInfo cc WITH(NOLOCK) ON t.custid = cc.custid
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = cc.recommend
		WHERE t.winlostdate >= '2023-08-13'
		GROUP BY cc.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT recommend, CHECKSUM_AGG(CHECKSUM(  t.[custid],[transdate],[oddsid],[odds],[stake],[status],[winlost],[betteam],[creator],[refno],[winlostdate],[betfrom],[checktime],[apositiontaking],[mpositiontaking],[tpositiontaking],[awinlost],[mwinlost],[playerdiscount],[discount],[adiscount],[playercomm],[comm],[acomm],[actualrate],[matchid],[matchdate],[statuswinlost],[ruben],[bettype],[spositiontaking],[swinlost],[sdiscount],[scomm],[statusID],[virtualrate],[SiteID],[transdesc],[BetID3rd],[epositiontaking],[actual_stake],[netstake]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.bettransG t WITH (NOLOCK)
										INNER JOIN custdb.dbo.custInfo cc WITH(NOLOCK) ON t.custid = cc.custid
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = cc.recommend 
									WHERE t.winlostdate >= ''2023-08-13''	
									GROUP BY cc.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'bettransG' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 6) Translog  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT recommend
				,CHECKSUM_AGG(CHECKSUM( t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[eventID],[vendorID],[GameId3rd],[TranId3rd],[custom1],[custom2],[custom3],[LiveIndicator],[checkCount],[SiteId],[epositiontaking],[LicenseeTransId]
								)) AS TotalCheckSum
		FROM dbo.Translog t WITH(NOLOCK, INDEX=IX_recommend)
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = t.recommend
		WHERE t.winlostdate >= '2023-08-13'
		GROUP BY t.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT recommend, CHECKSUM_AGG(CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[eventID],[vendorID],[GameId3rd],[TranId3rd],[custom1],[custom2],[custom3],[LiveIndicator],[checkCount],[SiteId],[epositiontaking],[LicenseeTransId]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.Translog t WITH (NOLOCK, INDEX=IX_recommend)
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.recommend 
									WHERE t.winlostdate >= ''2023-08-13''
									GROUP BY t.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'Translog' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 7) Transfer  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT recommend
				,CHECKSUM_AGG(CHECKSUM( t.[CustId],[TransDate],[WinlostDate],[Bettype],[Stake],[Actual_Stake],[Winlost],[AWinlost],[MWinlost],[SWinlost],[PlayerComm],[Comm],[AComm],[SComm],[StatusId],[RefNo],[TransDesc],[Recommend],[MRecommend],[SRecommend],[Username],[Currency],[CurrencyName],[ActualRate],[Creator],[Balance],[IP],[CheckTime],[SerialNo],[RepUpdateTime]
								)) AS TotalCheckSum
		FROM dbo.Transfer t WITH(NOLOCK, INDEX=IX_recommend)
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = t.recommend
		WHERE t.winlostdate >= '2023-08-13'
		GROUP BY t.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT recommend, CHECKSUM_AGG(CHECKSUM(  t.[CustId],[TransDate],[WinlostDate],[Bettype],[Stake],[Actual_Stake],[Winlost],[AWinlost],[MWinlost],[SWinlost],[PlayerComm],[Comm],[AComm],[SComm],[StatusId],[RefNo],[TransDesc],[Recommend],[MRecommend],[SRecommend],[Username],[Currency],[CurrencyName],[ActualRate],[Creator],[Balance],[IP],[CheckTime],[SerialNo],[RepUpdateTime]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.Transfer t WITH (NOLOCK, INDEX=IX_recommend)
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.recommend 
									WHERE t.winlostdate >= ''2023-08-13''	
									GROUP BY recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'Transfer' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------8) Transfer_Coll  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT tt.recommend
				,CHECKSUM_AGG(CHECKSUM( t.[CustId],t.[WinlostDate],t.[TransDate],t.[Bettype],t.[Debit],t.[Credit],t.[Currency],t.[ActualRate],t.[RefNo],t.[Username],t.[Recommend],t.[MRecommend],t.[SRecommend],t.[Creator],t.[TransDesc],t.[IP]
								)) AS TotalCheckSum
		FROM dbo.Transfer_Coll t WITH(NOLOCK)
			INNER JOIN dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = tt.recommend
		WHERE tt.winlostdate >= '2023-08-13'
		GROUP BY tt.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT tt.recommend, CHECKSUM_AGG(CHECKSUM(  t.[CustId],t.[WinlostDate],t.[TransDate],t.[Bettype],t.[Debit],t.[Credit],t.[Currency],t.[ActualRate],t.[RefNo],t.[Username],t.[Recommend],t.[MRecommend],t.[SRecommend],t.[Creator],t.[TransDesc],t.[IP]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.Transfer_Coll t WITH (NOLOCK)
										INNER JOIN bodb02.dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = tt.recommend 
									WHERE tt.winlostdate >= ''2023-08-13''	
									GROUP BY tt.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'Transfer_Coll' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------9) TransferInfo  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT tt.recommend
				,CHECKSUM_AGG(CHECKSUM( t.[APositiontaking],t.[MPositiontaking],t.[SPositiontaking],t.[EPositiontaking],t.[PlayerDiscount],t.[Discount],t.[ADiscount],t.[SDiscount],t.[WalletType],t.[BonusID],t.[Amount],t.[CheckerId],t.[CheckerName],t.[IsCollection],t.[IsDel]
								)) AS TotalCheckSum
		FROM dbo.TransferInfo t WITH(NOLOCK)
			INNER JOIN dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
			INNER JOIN #__recommendList c WITH (NOLOCK) ON c.custid = tt.recommend
		WHERE tt.winlostdate >= '2023-08-13'
		GROUP BY tt.recommend
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT tt.recommend, CHECKSUM_AGG(CHECKSUM(  t.[APositiontaking],t.[MPositiontaking],t.[SPositiontaking],t.[EPositiontaking],t.[PlayerDiscount],t.[Discount],t.[ADiscount],t.[SDiscount],t.[WalletType],t.[BonusID],t.[Amount],t.[CheckerId],t.[CheckerName],t.[IsCollection],t.[IsDel]
																	)) AS TotalCheckSum
									FROM bodb02.dbo.TransferInfo t WITH (NOLOCK)
										INNER JOIN bodb02.dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
										INNER JOIN SiteDBtmp.dbo.RecommendSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = tt.recommend 
									WHERE tt.winlostdate >= ''2023-08-13''	
									GROUP BY tt.recommend
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.recommend, t.recommend), 'TransferInfo' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.recommend = t.recommend
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

------------------------------------------------
	SELECT COUNT(1) as cnt, TableName
	FROM #__CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)
	GROUP BY TableName

GO