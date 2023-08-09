--Group 2 - In UM - Get transid(s)
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
/* find text and replace by list of wrong recommends 
1) Bettrans -> bettrans_recommendList
2) BettransInfo -> bettransInfo_recommendList
3) BettransLC -> bettransLC_recommendList
4) BettransRnG -> BettransRnG_recommendList
5) bettransG -> bettransG_recommendList
6) Translog -> Translog_recommendList
7) Transfer -> Transfer_recommendList
8) Transfer_Coll -> Transfer_Coll_recommendList
9) TransferInfo -> TransferInfo_recommendList

*/
DROP TABLE IF EXISTS #__CheckSum_MigrateSiteDB3_Temp
CREATE TABLE #__CheckSum_MigrateSiteDB3_Temp (transid BIGINT, TableName VARCHAR(100))
BEGIN--------compare 1) bettrans  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT transid
				,BINARY_CHECKSUM( t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[awinlost],[mwinlost],[playercomm],[comm],[acomm],[apositiontaking],[mpositiontaking],[tpositiontaking],[playerdiscount],[discount],[adiscount],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[oddsspread],[actualrate],[matchid],[recommend],[mrecommend],[ruben],[betid],[statuswinlost],[modds],[bettype],[betdaqid],[actual_stake],[currency],[ip],[transdesc],[sdiscount],[scomm],[spositiontaking],[swinlost],[srecommend],[Username],[CurrencyName],[virtualrate],[oddstype],[statusID],[currency2],[balance],[SecAcceptFlag],[transid2],[recommdate],[ExtraInfo],[WalletType],[BonusID],[RefCode],[epositiontaking],[ReasonID],[sort],[BetSiteID]
								) AS TotalCheckSum
		FROM dbo.bettrans t WITH(NOLOCK, INDEX=IX_Recommend)
		WHERE t.recommend IN (bettrans_recommendList)
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT transid, BINARY_CHECKSUM(  t.[custid],[transdate],[oddsid],[hdp1],[hdp2],[odds],[stake],[status],[winlost],[awinlost],[mwinlost],[playercomm],[comm],[acomm],[apositiontaking],[mpositiontaking],[tpositiontaking],[playerdiscount],[discount],[adiscount],[livehomescore],[liveawayscore],[liveindicator],[betteam],[creator],[refno],[comstatus],[winlostdate],[betfrom],[betcheck],[checktime],[oddsspread],[actualrate],[matchid],[recommend],[mrecommend],[ruben],[betid],[statuswinlost],[modds],[bettype],[betdaqid],[actual_stake],[currency],[ip],[transdesc],[sdiscount],[scomm],[spositiontaking],[swinlost],[srecommend],[Username],[CurrencyName],[virtualrate],[oddstype],[statusID],[currency2],[balance],[SecAcceptFlag],[transid2],[recommdate],[ExtraInfo],[WalletType],[BonusID],[RefCode],[epositiontaking],[ReasonID],[sort],[BetSiteID]
																	) AS TotalCheckSum
									FROM bodb02.dbo.bettrans t WITH (NOLOCK, INDEX= IX_Recommend)
									WHERE t.recommend IN (bettrans_recommendList)
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.transid, t.transid), 'bettrans' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.transid = t.transid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 2) bettransInfo  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT b.transid
				,BINARY_CHECKSUM(  [SecAcceptTime],[LiveBetAcceptTime],[OriginalOdds], [ThirdTransID]
								) AS TotalCheckSum
		FROM dbo.bettransInfo t WITH(NOLOCK)
			INNER JOIN dbo.bettrans b WITH(NOLOCK, INDEX=IX_Recommend) ON t.transid = b.transid
		WHERE b.recommend IN (bettransInfo_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT b.transid, BINARY_CHECKSUM(  [SecAcceptTime],[LiveBetAcceptTime],[OriginalOdds], [ThirdTransID]
																	) AS TotalCheckSum
									FROM bodb02.dbo.bettransInfo t WITH (NOLOCK)
										INNER JOIN bodb02.dbo.bettrans b WITH(NOLOCK, INDEX=IX_Recommend) ON t.transid = b.transid
										
									WHERE b.recommend IN (bettransInfo_recommendList)
									
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.transid, t.transid), 'bettransInfo' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.transid = t.transid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 3) bettransLC  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT transid
				,BINARY_CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[NetStake],[SiteID],[epositiontaking]
								) AS TotalCheckSum
		FROM dbo.bettransLC t WITH(NOLOCK, INDEX=IX_Recommend)
		WHERE t.recommend IN (bettransLC_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT transid
										,BINARY_CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[NetStake],[SiteID],[epositiontaking]
															) AS TotalCheckSum
									FROM bodb02.dbo.bettransLC t WITH(NOLOCK, INDEX=IX_Recommend)
									WHERE t.recommend IN (bettransLC_recommendList)	
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( recommend, TableName )
	SELECT ISNULL(s.transid, t.transid), 'bettransLC' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.transid = t.transid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)

END

BEGIN--------compare 4) BettransRnG  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.transid
				,BINARY_CHECKSUM( t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[SiteID],[Additional],[JackpotInfo],[RefNo2],[ContributionRate],[BetStake],[ContributionStake3rd],[epositiontaking]
								) AS TotalCheckSum
		FROM dbo.BettransRnG t WITH(NOLOCK, INDEX=IX_recommend)
		WHERE t.recommend IN (BettransRnG_recommendList)
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.transid, BINARY_CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[vendorID],[GameId3rd],[TranId3rd],[RefNo],[IsSum],[winlost],[awinlost],[mwinlost],[swinlost],[playercomm],[comm],[acomm],[scomm],[Transdate3rd],[SiteID],[Additional],[JackpotInfo],[RefNo2],[ContributionRate],[BetStake],[ContributionStake3rd],[epositiontaking]
																	) AS TotalCheckSum
									FROM bodb02.dbo.BettransRnG t WITH (NOLOCK, INDEX=IX_recommend)
									WHERE t.recommend IN (BettransRnG_recommendList)
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.transid, t.transid), 'BettransRnG' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.transid = t.transid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 5) bettransG  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.transid
				,BINARY_CHECKSUM( t.[custid],[transdate],[oddsid],[odds],[stake],[status],[winlost],[betteam],t.[creator],[refno],[winlostdate],[betfrom],[checktime],[apositiontaking],[mpositiontaking],[tpositiontaking],[awinlost],[mwinlost],[playerdiscount],[discount],[adiscount],[playercomm],[comm],[acomm],[actualrate],[matchid],[matchdate],[statuswinlost],[ruben],[bettype],[spositiontaking],[swinlost],[sdiscount],[scomm],[statusID],[virtualrate],[SiteID],[transdesc],[BetID3rd],[epositiontaking],[actual_stake],[netstake]
								) AS TotalCheckSum
		FROM dbo.bettransG t WITH(NOLOCK)
			INNER JOIN custdb.dbo.vw_customer cc WITH(NOLOCK) ON t.custid = cc.custid
		WHERE cc.recommend IN (bettransG_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT transid, BINARY_CHECKSUM(  t.[custid],[transdate],[oddsid],[odds],[stake],[status],[winlost],[betteam],t.[creator],[refno],[winlostdate],[betfrom],[checktime],[apositiontaking],[mpositiontaking],[tpositiontaking],[awinlost],[mwinlost],[playerdiscount],[discount],[adiscount],[playercomm],[comm],[acomm],[actualrate],[matchid],[matchdate],[statuswinlost],[ruben],[bettype],[spositiontaking],[swinlost],[sdiscount],[scomm],[statusID],[virtualrate],[SiteID],[transdesc],[BetID3rd],[epositiontaking],[actual_stake],[netstake]
																	) AS TotalCheckSum
									FROM bodb02.dbo.bettransG t WITH (NOLOCK)
										INNER JOIN custdb.dbo.vw_customer cc WITH(NOLOCK) ON t.custid = cc.custid
									WHERE cc.recommend IN (bettransG_recommendList)
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.transid, t.transid), 'bettransG' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.transid = t.transid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 6) Translog  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT translogid
				,BINARY_CHECKSUM( t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[eventID],[vendorID],[GameId3rd],[TranId3rd],[custom1],[custom2],[custom3],[LiveIndicator],[checkCount],[SiteId],[epositiontaking],[LicenseeTransId]
								) AS TotalCheckSum
		FROM dbo.Translog t WITH(NOLOCK, INDEX=IX_recommend)
		WHERE t.recommend IN (Translog_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT translogid, BINARY_CHECKSUM(  t.[custid],[transdate],[odds],[stake],[status],[apositiontaking],[mpositiontaking],[tpositiontaking],[spositiontaking],[playerdiscount],[discount],[adiscount],[sdiscount],[creator],[winlostdate],[betfrom],[virtualrate],[actualrate],[actual_stake],[currency],[CurrencyName],[recommend],[mrecommend],[srecommend],[ip],[statusID],[balance],[Username],[transdesc],[productID],[gameID],[eventID],[vendorID],[GameId3rd],[TranId3rd],[custom1],[custom2],[custom3],[LiveIndicator],[checkCount],[SiteId],[epositiontaking],[LicenseeTransId]
																	) AS TotalCheckSum
									FROM bodb02.dbo.Translog t WITH (NOLOCK, INDEX=IX_recommend)
									WHERE t.recommend IN (Translog_recommendList)
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( transid, TableName )
	SELECT ISNULL(s.translogid, t.translogid), 'Translog' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.translogid = t.translogid
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 7) Transfer  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.TransId
				,BINARY_CHECKSUM( t.[CustId],[TransDate],[WinlostDate],[Bettype],[Stake],[Actual_Stake],[Winlost],[AWinlost],[MWinlost],[SWinlost],[PlayerComm],[Comm],[AComm],[SComm],[StatusId],[RefNo],[TransDesc],[Recommend],[MRecommend],[SRecommend],[Username],[Currency],[CurrencyName],[ActualRate],[Creator],[Balance],[IP],[CheckTime],[SerialNo]
								) AS TotalCheckSum
		FROM dbo.Transfer t WITH(NOLOCK, INDEX=IX_recommend)
		WHERE t.recommend IN (Transfer_recommendList)
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.TransId, BINARY_CHECKSUM(  t.[CustId],[TransDate],[WinlostDate],[Bettype],[Stake],[Actual_Stake],[Winlost],[AWinlost],[MWinlost],[SWinlost],[PlayerComm],[Comm],[AComm],[SComm],[StatusId],[RefNo],[TransDesc],[Recommend],[MRecommend],[SRecommend],[Username],[Currency],[CurrencyName],[ActualRate],[Creator],[Balance],[IP],[CheckTime],[SerialNo]
																	) AS TotalCheckSum
									FROM bodb02.dbo.Transfer t WITH (NOLOCK, INDEX=IX_recommend)
									WHERE t.recommend IN (Transfer_recommendList)	
									
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT ISNULL(s.TransId, t.TransId), 'Transfer' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.TransId = t.TransId
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------compare 8) Transfer_Coll  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.TransID
				,BINARY_CHECKSUM( t.[CustId],t.[WinlostDate],t.[TransDate],t.[Bettype],t.[Debit],t.[Credit],t.[Currency],t.[ActualRate],t.[RefNo],t.[Username],t.[Recommend],t.[MRecommend],t.[SRecommend],t.[Creator],t.[TransDesc],t.[IP]
								) AS TotalCheckSum
		FROM dbo.Transfer_Coll t WITH(NOLOCK)
			INNER JOIN dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
		WHERE tt.recommend IN (Transfer_Coll_recommendList) 
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.TransID, BINARY_CHECKSUM(  t.[CustId],t.[WinlostDate],t.[TransDate],t.[Bettype],t.[Debit],t.[Credit],t.[Currency],t.[ActualRate],t.[RefNo],t.[Username],t.[Recommend],t.[MRecommend],t.[SRecommend],t.[Creator],t.[TransDesc],t.[IP]
																	) AS TotalCheckSum
									FROM bodb02.dbo.Transfer_Coll t WITH (NOLOCK)
										INNER JOIN bodb02.dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
									WHERE tt.recommend IN (Transfer_Coll_recommendList)
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( TransID, TableName )
	SELECT ISNULL(s.TransID, t.TransID), 'Transfer_Coll' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.TransID = t.TransID
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

BEGIN--------conpare 9) TransferInfo  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT t.TransID
				,BINARY_CHECKSUM( t.[APositiontaking],t.[MPositiontaking],t.[SPositiontaking],t.[EPositiontaking],t.[PlayerDiscount],t.[Discount],t.[ADiscount],t.[SDiscount],t.[WalletType],t.[BonusID],t.[Amount],t.[CheckerId],t.[CheckerName],t.[IsCollection],t.[IsDel]
								) AS TotalCheckSum
		FROM dbo.TransferInfo t WITH(NOLOCK)
			INNER JOIN dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
		WHERE tt.recommend IN (TransferInfo_recommendList)
		
	)
	,cte_bettrans_DBTRANS AS (
		SELECT *
		FROM OPENQUERY ( DBCTG, ' SELECT t.TransID, BINARY_CHECKSUM(  t.[APositiontaking],t.[MPositiontaking],t.[SPositiontaking],t.[EPositiontaking],t.[PlayerDiscount],t.[Discount],t.[ADiscount],t.[SDiscount],t.[WalletType],t.[BonusID],t.[Amount],t.[CheckerId],t.[CheckerName],t.[IsCollection],t.[IsDel]
																	) AS TotalCheckSum
									FROM bodb02.dbo.TransferInfo t WITH (NOLOCK)
										INNER JOIN bodb02.dbo.Transfer tt WITH(NOLOCK, INDEX=IX_recommend) ON t.TransID = tt.TransId
									WHERE tt.recommend in (TransferInfo_recommendList)	
								'
						)
	)
	INSERT INTO #__CheckSum_MigrateSiteDB3_Temp ( TransID, TableName )
	SELECT ISNULL(s.TransID, t.TransID), 'TransferInfo' AS TableName
	FROM cte_bettrans_SITEDB3 s
		FULL OUTER JOIN cte_bettrans_DBTRANS t
			ON s.TransID = t.TransID
	WHERE ISNULL(s.TotalCheckSum, 0) <> ISNULL(t.TotalCheckSum, 0)
END

------------------------------------------------
SELECT COUNT(1) as cnt, TableName
FROM #__CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)
GROUP BY TableName

SELECT transid, TableName
FROM #__CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)

------------------RESULT: transid list---------------------
SELECT t.TableName, STUFF (temp.transidlist,1,1,'') AS transidlist
FROM (SELECT DISTINCT TableName FROM #__CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)) AS t
	CROSS APPLY (SELECT ',' + CONVERT(VARCHAR(100),t1.transid)
				FROM #__CheckSum_MigrateSiteDB3_Temp t1 WITH(NOLOCK)
				WHERE t1.TableName = t.TableName
				FOR XML PATH ('')
				) AS temp(transidlist)

GO