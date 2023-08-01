/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: compare data between SITEDB3 and DBTRANS [Redmineid:#181595] 

*/

---Run on SITEDB3

USE bodb02
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = 'CheckSum_MigrateSiteDB3_Temp')
BEGIN
	CREATE TABLE CheckSum_MigrateSiteDB3_Temp ( TransId BIGINT, TableName VARCHAR(100) )
END

TRUNCATE TABLE CheckSum_MigrateSiteDB3_Temp

--------compare bettrans  --------------------------------------
;WITH cte_bettrans_SITEDB3 AS (
	SELECT TransId, 
		BINARY_CHECKSUM([custid], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], [acomm], 
						[apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
						[liveindicator], [betteam], [creator], [refno], [comstatus], [betfrom], [betcheck], [oddsspread], CONVERT(DECIMAL(19,8), [actualrate]), [matchid], 
						[Recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], [ip], [transdesc], 
						[sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [oddstype], [statusID], [currency2], 
						[balance], [transid2], [WalletType], [BonusID], [RefCode]) AS TotalCheckSum
	FROM dbo.bettrans t WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)
,cte_bettrans_DBTRANS AS (
	SELECT TransId, 
			BINARY_CHECKSUM([custid], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], [acomm], 
						[apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
						[liveindicator], [betteam], [creator], [refno], [comstatus], [betfrom], [betcheck], [oddsspread], CONVERT(DECIMAL(19,8), [actualrate]), [matchid], 
						[Recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], [ip], [transdesc], 
						[sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [oddstype], [statusID], [currency2], 
						[balance], [transid2], [WalletType], [BonusID], [RefCode]) AS TotalCheckSum
	FROM DBCTG.bodb02.dbo.bettrans t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)

INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.transid, 'bettrans' AS TableName
FROM cte_bettrans_SITEDB3 site3
	FULL OUTER JOIN cte_bettrans_DBTRANS trans 
		ON site3.transid = trans.transid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)


--------bettransRnG --------------------------------------
;WITH cte_bettransRnG_SITEDB3 AS (
	SELECT	TransId,  
			BINARY_CHECKSUM( [custid], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], [playerdiscount], [discount], 
						[adiscount], [sdiscount], [creator], [betfrom], CONVERT(DECIMAL(19,8), [actualrate]), [actual_stake], [currency], [CurrencyName], [Recommend], 
						[mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], [vendorID], [GameId3rd], 
						[TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [Transdate3rd], 
						[SiteID], [Additional], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd]) AS TotalCheckSum
	FROM dbo.bettransRnG t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)
,cte_bettransRnG_DBTRANS AS (
	SELECT	TransId,  
			BINARY_CHECKSUM( [custid], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], [playerdiscount], [discount], 
						[adiscount], [sdiscount], [creator], [betfrom], CONVERT(DECIMAL(19,8), [actualrate]), [actual_stake], [currency], [CurrencyName], [Recommend], 
						[mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], [vendorID], [GameId3rd], 
						[TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [Transdate3rd], 
						[SiteID], [Additional], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd]) AS TotalCheckSum
	FROM DBCTG.bodb02.dbo.bettransRnG t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)

INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.transid, 'bettransRnG' AS TableName
FROM cte_bettransRnG_SITEDB3 site3
	FULL OUTER JOIN cte_bettransRnG_DBTRANS trans 
		ON site3.transid = trans.transid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

--------bettransLC  --------------------------------------
;WITH cte_bettransLC_SITEDB3 AS (
	SELECT	TransId, 
			BINARY_CHECKSUM( [custid], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], [playerdiscount], 
						[discount], [adiscount], [sdiscount], [creator], [betfrom], CONVERT(DECIMAL(19,8), [actualrate]), [actual_stake], [currency], [CurrencyName], 
						[Recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], [vendorID], [GameId3rd], 
						[TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [Transdate3rd], [NetStake], 
						[SiteID]) AS TotalCheckSum
	FROM dbo.bettransLC t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)
,cte_bettransLC_DBTRANS AS (
	SELECT	TransId,
			BINARY_CHECKSUM( [custid], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], [playerdiscount], 
						[discount], [adiscount], [sdiscount], [creator], [betfrom], CONVERT(DECIMAL(19,8), [actualrate]), [actual_stake], [currency], [CurrencyName], 
						[Recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], [vendorID], [GameId3rd], 
						[TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [Transdate3rd], [NetStake], 
						[SiteID]) AS TotalCheckSum
	FROM DBCTG.bodb02.dbo.bettransLC t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)
	
INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.transid, 'bettransLC' AS TableName
FROM cte_bettransLC_SITEDB3 site3
	FULL OUTER JOIN cte_bettransLC_DBTRANS trans 
		ON site3.transid = trans.transid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

--------bettransG  --------------------------------------
;WITH cte_bettransG_SITEDB3 AS (
	SELECT	TransId, 
			BINARY_CHECKSUM( g.[custid], g.[oddsid], g.[odds], g.[stake], g.[status], g.[winlost], g.[betteam], g.[creator], g.[refno], g.[betfrom],
						g.[apositiontaking], g.[mpositiontaking], g.[tpositiontaking], g.[awinlost], g.[mwinlost], g.[playerdiscount], g.[discount], g.[adiscount], g.[playercomm], g.[comm], 
						g.[acomm], CONVERT(DECIMAL(19,8), g.[actualrate]), g.[matchid], g.[matchdate], g.[statuswinlost], g.[ruben], g.[bettype], g.[spositiontaking], g.[swinlost], g.[sdiscount], g.[scomm], g.[statusID], 
						g.[SiteID], g.[TransDesc], g.[BetID3rd], g.[actual_stake], g.[netstake]) AS TotalCheckSum 
	FROM dbo.bettransG g WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = g.custid
)
,cte_bettransG_DBTRANS AS (
	SELECT	TransId, 
			BINARY_CHECKSUM(	g.[custid], g.[oddsid], g.[odds], g.[stake], g.[status], g.[winlost], g.[betteam], g.[creator], g.[refno], g.[betfrom],
						g.[apositiontaking], g.[mpositiontaking], g.[tpositiontaking], g.[awinlost], g.[mwinlost], g.[playerdiscount], g.[discount], g.[adiscount], g.[playercomm], g.[comm], 
						g.[acomm], CONVERT(DECIMAL(19,8), g.[actualrate]), g.[matchid], g.[matchdate], g.[statuswinlost], g.[ruben], g.[bettype], g.[spositiontaking], g.[swinlost], g.[sdiscount], g.[scomm], g.[statusID], 
						g.[SiteID], g.[TransDesc], g.[BetID3rd], g.[actual_stake], g.[netstake]) AS TotalCheckSum 
	FROM DBCTG.bodb02.dbo.bettransG g WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = g.custid
)

INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.transid, 'bettransG' AS TableName
FROM cte_bettransG_SITEDB3 site3
	FULL OUTER JOIN cte_bettransG_DBTRANS trans 
		ON site3.transid = trans.transid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)


---------translog  --------------------------------------
;WITH cte_translog_SITEDB3 AS (
	SELECT	translogid,  
			BINARY_CHECKSUM(	[custid], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
						[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [betfrom], CONVERT(DECIMAL(19,8), [actualrate]), [actual_stake], 
						[currency], [CurrencyName], [Recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
						[gameID], [eventID], [vendorID], [Gameid3rd], [Tranid3rd], [custom1], [liveindicator], [custom2], [custom3], [SiteId], 
						[checkCount]) AS TotalCheckSum 
	FROM dbo.translog t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)
,cte_translog_DBTRANS AS (
	SELECT	translogid,  
			BINARY_CHECKSUM(	[custid], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
						[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [betfrom], CONVERT(DECIMAL(19,8), [actualrate]), [actual_stake], 
						[currency], [CurrencyName], [Recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
						[gameID], [eventID], [vendorID], [Gameid3rd], [Tranid3rd], [custom1], [liveindicator], [custom2], [custom3], [SiteId], 
						[checkCount]) AS TotalCheckSum 
	FROM DBCTG.bodb02.dbo.translog t WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
)

INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.translogid, 'translog' AS TableName
FROM cte_translog_SITEDB3 site3
	FULL OUTER JOIN cte_translog_DBTRANS trans 
		ON site3.translogid = trans.translogid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

---------bettransm  --------------------------------------
;WITH cte_bettransm_SITEDB3 AS (
	SELECT	transid, 
			BINARY_CHECKSUM(	bm.[custid], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], 
						bm.[liveawayscore], bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[betfrom], 
						bm.[betcheck], bm.[oddsspread], bm.[apositiontaking], bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], 
						bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], CONVERT(DECIMAL(19,8), bm.[actualrate]), bm.[matchid], 
						bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], 
						bm.[sdiscount], bm.[scomm], bm.[statusID], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime]) AS TotalCheckSum
	FROM dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = bm.custid
)
,cte_bettransm_DBTRANS AS (
	SELECT	transid, 
			BINARY_CHECKSUM(	bm.[custid], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], 
						bm.[liveawayscore], bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[betfrom], 
						bm.[betcheck], bm.[oddsspread], bm.[apositiontaking], bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], 
						bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], CONVERT(DECIMAL(19,8), bm.[actualrate]), bm.[matchid], 
						bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], 
						bm.[sdiscount], bm.[scomm], bm.[statusID], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime]) AS TotalCheckSum
	FROM DBCTG.bodb02.dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = bm.custid
)

INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.transid, 'bettransm' AS TableName
FROM cte_bettransm_SITEDB3 site3
	FULL OUTER JOIN cte_bettransm_DBTRANS trans 
		ON site3.transid = trans.transid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

---------transfer  --------------------------------------
;WITH cte_transfer_SITEDB3 AS  (
	SELECT TransId,
		BINARY_CHECKSUM(CONVERT(VARCHAR(50), TransDate, 121),CONVERT(VARCHAR(50), WinlostDate, 121),Bettype,Stake,Actual_Stake
		,Winlost,AWinlost,MWinlost,SWinlost,PlayerComm,Comm,AComm,SComm,StatusId,TransDesc,Recommend,MRecommend,SRecommend,Currency,CurrencyName) TotalCheckSum
	FROM dbo.Transfer t WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH(NOLOCK) ON t.CustId = c.custid
)
, cte_transfer_DBTRANS AS  (
	SELECT TransId,
		BINARY_CHECKSUM(CONVERT(VARCHAR(50), TransDate, 121),CONVERT(VARCHAR(50), WinlostDate, 121),Bettype,Stake,Actual_Stake
		,Winlost,AWinlost,MWinlost,SWinlost,PlayerComm,Comm,AComm,SComm,StatusId,TransDesc,Recommend,MRecommend,SRecommend,Currency,CurrencyName) TotalCheckSum
	FROM DBCTG.bodb02.dbo.transfer t WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer_SiteDB_Migrate_xtest c WITH(NOLOCK) On t.CustId = c.custid
)

INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
SELECT site3.transid, 'transfer' AS TableName
FROM cte_transfer_SITEDB3 site3
	FULL OUTER JOIN cte_transfer_DBTRANS trans 
		ON site3.transid = trans.transid
WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)


------------------------------------------------
SELECT COUNT(1) as cnt, TableName
FROM CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)
GROUP BY TableName


