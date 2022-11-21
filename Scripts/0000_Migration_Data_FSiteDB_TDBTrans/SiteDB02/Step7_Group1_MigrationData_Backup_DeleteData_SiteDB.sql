/*<info serverAlias="DBSIG-SiteDB02tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB02tmp

	 Revisions:
		- 20221107@Victoria: DELETE and BACKUP tickets (statusid in (0,1)) for the following tables [Redmineid:#180033] 
								bettrans
								bettransRnG
								bettransLC
								bettransG
								translog
								bettransm
								
*/

USE SiteDB02tmp
GO

------------------------------------------------
/*****************Copy Stucture of Tables************************/
SELECT TOP 1 *
INTO bettrans_delete
FROM bodb02.dbo.bettrans b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransRnG_delete
FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransLC_delete
FROM bodb02.dbo.bettransLC b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransG_delete
FROM bodb02.dbo.bettransG b WITH (NOLOCK)

SELECT TOP 1 *
INTO translog_delete
FROM bodb02.dbo.translog b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransm_delete
FROM bodb02.dbo.bettransm bm WITH (NOLOCK)

/*****************Truncate Table************************/
TRUNCATE TABLE bettrans_delete
TRUNCATE TABLE bettransRnG_delete
TRUNCATE TABLE bettransLC_delete
TRUNCATE TABLE bettransG_delete
TRUNCATE TABLE translog_delete
TRUNCATE TABLE bettransm_delete

/*******************BACKUP & DELETE Data**********************/
--bodb02.dbo.bettrans
------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
		, @batch INT = 2000

DECLARE @debug_message VARCHAR(500)

CREATE TABLE #TempBatch (rid INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT)

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID IN (0,1)

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[playercomm], deleted.[comm], 
			deleted.[acomm], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[livehomescore], deleted.[liveawayscore], 
			deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[oddsspread], deleted.[actualrate], 
			deleted.[matchid], deleted.[recommend], deleted.[mrecommend], deleted.[ruben], deleted.[betid], deleted.[statuswinlost], deleted.[modds], deleted.[bettype], deleted.[betdaqid], deleted.[actual_stake], deleted.[currency], 
			deleted.[ip], deleted.[transdesc], deleted.[sdiscount], deleted.[scomm], deleted.[spositiontaking], deleted.[swinlost], deleted.[srecommend], deleted.[Username], deleted.[CurrencyName], deleted.[virtualrate], deleted.[oddstype], 
			deleted.[statusID], deleted.[currency2], deleted.[balance], deleted.[SecAcceptFlag], deleted.[transid2], deleted.[recommdate], deleted.[ExtraInfo], deleted.[WalletType], deleted.[BonusID], deleted.[RefCode], deleted.[SettlementTime],
			deleted.[epositiontaking], deleted.[ReasonID], deleted.[sort], deleted.[BetSiteID], deleted.[RepUpdateTime], deleted.[RepDstUpdateTime], deleted.[SiteDBGroupID], deleted.[FcUpdateTime]
	INTO bettrans_delete ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], 
							[acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [actualrate], 
							[matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], 
							[ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [virtualrate], [oddstype], 
							[statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], [RefCode], [SettlementTime],
							[epositiontaking], [ReasonID], [sort], [BetSiteID], [RepUpdateTime], [RepDstUpdateTime], [SiteDBGroupID], [FcUpdateTime])
	FROM bodb02.dbo.bettrans b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.bettransRnG
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID IN (0,1)

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
			deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
			deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], deleted.[gameID], 
			deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[RefNo], deleted.[IsSum], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm], 
			deleted.[Transdate3rd], deleted.[SiteID], deleted.[Additional], deleted.[JackpotInfo], deleted.[RefNo2], deleted.[ContributionRate], deleted.[BetStake], deleted.[ContributionStake3rd], 
			deleted.[epositiontaking], deleted.[SiteDBGroupID], deleted.[RepUpdateTime]
	INTO bettransRnG_delete (	[transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], 
								[vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], 
								[Transdate3rd], [SiteID], [Additional], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd], 
								[epositiontaking], [SiteDBGroupID], [RepUpdateTime])
	FROM bodb02.dbo.bettransRnG b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

--bodb02.dbo.bettransLC
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID IN (0,1)

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
			deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
			deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], 
			deleted.[gameID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[RefNo], deleted.[IsSum], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], 
			deleted.[scomm], deleted.[Transdate3rd], deleted.[NetStake], deleted.[SiteID], deleted.[epositiontaking], deleted.[SiteDBGroupID] , deleted.[RepUpdateTime]
	INTO bettransLC_delete (	[transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
								[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], 
								[scomm], [Transdate3rd], [NetStake], [SiteID], [epositiontaking], [SiteDBGroupID] , [RepUpdateTime])
	FROM bodb02.dbo.bettransLC b WITH (ROWLOCK)
			INNER JOIN #TempBatch t ON t.transid = b.TransId
			WHERE t.rid BETWEEN @StartRow AND @StopRow
		
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

--bodb02.dbo.bettransG
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.bettransG b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID IN (0,1)

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE b
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[winlostdate], deleted.[betfrom], 
			deleted.[checktime], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[awinlost], deleted.[mwinlost], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], 
			deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[actualrate], deleted.[matchid], deleted.[matchdate], deleted.[statuswinlost], deleted.[ruben], deleted.[bettype], deleted.[spositiontaking], deleted.[swinlost], 
			deleted.[sdiscount], deleted.[scomm], deleted.[statusID], deleted.[virtualrate], deleted.[SiteID], deleted.[transdesc], deleted.[BetID3rd], deleted.[epositiontaking], deleted.[actual_stake], deleted.[netstake], 
			deleted.[SiteDBGroupID], deleted.[RepUpdateTime]
	INTO bettransG_delete (	[transid], [custid], [transdate], [oddsid], [odds], [stake], [status], [winlost], [betteam], [creator], [refno], [winlostdate], [betfrom], 
								[checktime], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
								[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], 
								[sdiscount], [scomm], [statusID], [virtualrate], [SiteID], [transdesc], [BetID3rd], [epositiontaking], [actual_stake], [netstake], 
								[SiteDBGroupID], [RepUpdateTime])
	FROM bodb02.dbo.bettransG b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
		
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.translog
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.translogid
FROM bodb02.dbo.translog b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID IN (0,1)

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT deleted.[translogid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
			deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
			deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], 
			deleted.[gameID], deleted.[eventID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[custom1], deleted.[custom2], deleted.[custom3], deleted.[LiveIndicator], deleted.[checkCount], deleted.[SiteId], 
			deleted.[epositiontaking], deleted.[SiteDBGroupID], deleted.[LicenseeTransId], deleted.[RepUpdateTime]
	INTO translog_delete ([translogid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
							[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
							[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
							[gameID], [eventID], [vendorID], [GameId3rd], [TranId3rd], [custom1], [custom2], [custom3], [LiveIndicator], [checkCount], [SiteId], 
							[epositiontaking], [SiteDBGroupID], [LicenseeTransId], [RepUpdateTime])
	FROM bodb02.dbo.translog b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.translogid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

--bodb02.dbo.bettransm
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT bm.TransId
FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
	INNER JOIN bettrans_delete b WITH (NOLOCK) ON b.refno = bm.refno

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  bm
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[livehomescore], deleted.[liveawayscore], 
			deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[oddsspread], deleted.[apositiontaking], 
			deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[awinlost], deleted.[mwinlost], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[playercomm], deleted.[comm], deleted.[acomm], 
			deleted.[actualrate], deleted.[matchid], deleted.[matchdate], deleted.[finalodds], deleted.[isfinish], deleted.[statuswinlost], deleted.[ruben], deleted.[bettype], deleted.[spositiontaking], deleted.[swinlost], deleted.[sdiscount], 
			deleted.[scomm], deleted.[statusID], deleted.[recommdate], deleted.[transdesc], deleted.[SecAcceptFlag], deleted.[SecAcceptTime], deleted.[LiveBetAcceptTime], deleted.[ReasonIDm], deleted.[RepUpdateTime], deleted.[SiteDBGroupID]
	INTO bettransm_delete (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], 
								[mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], 
								[actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], 
								[scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm], [RepUpdateTime], [SiteDBGroupID])
	FROM bodb02.dbo.bettransm bm WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = bm.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END