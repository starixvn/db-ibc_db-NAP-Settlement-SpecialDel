/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB01tmp

	 Revisions:
		- 20221107@Victoria: DELETE and BACKUP tickets for the following tables [Redmineid:#180033] 
								--statusid NOT IN (0,1)
								bettrans
								bettransRnG
								bettransLC
								bettransG
								translog
								bettransm

								----------------------
								--Get All
								BettransInfo
								transfer
								Transfer_Coll
								TransferInfo
								BetParlayDetail
								BetParlayResult
								zzzbettrans
								zzzbettransm
								
*/

USE SiteDB01tmp
GO

------------------------------------------------
/*****************Copy Stucture of Tables************************/
SELECT TOP 1 *
INTO BettransInfo_delete
FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)

SELECT TOP 1 *
INTO Transfer_delete
FROM bodb02.dbo.Transfer b WITH (NOLOCK)

SELECT TOP 1 *
INTO Transfer_Coll_delete
FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)

SELECT TOP 1 *
INTO TransferInfo_delete
FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)

SELECT TOP 1 *
INTO BetParlayDetail_delete
FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)

SELECT TOP 1 *
INTO BetParlayResult_delete
FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)

SELECT TOP 1 *
INTO zzzbettrans_delete
FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)

SELECT TOP 1 *
INTO zzzbettransm_delete
FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)

/*****************Truncate Table************************/
TRUNCATE TABLE BettransInfo_delete
TRUNCATE TABLE Transfer_delete
TRUNCATE TABLE Transfer_Coll_delete
TRUNCATE TABLE TransferInfo_delete
TRUNCATE TABLE BetParlayDetail_delete
TRUNCATE TABLE BetParlayResult_delete
TRUNCATE TABLE zzzbettrans_delete
TRUNCATE TABLE zzzbettransm_delete

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
	LEFT JOIN bettrans_delete del WITH (NOLOCK) ON del.TransId = b.TransId
WHERE del.TransId IS NULL

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
	LEFT JOIN bettransRnG_delete del WITH (NOLOCK) ON del.TransId = b.TransId
WHERE del.TransId IS NULL

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
	LEFT JOIN bettransLC_delete del WITH (NOLOCK) ON del.TransId = b.TransId
WHERE del.TransId IS NULL

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
	LEFT JOIN bettransG_delete del WITH (NOLOCK) ON del.TransId = b.TransId
WHERE del.TransId IS NULL

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
	LEFT JOIN translog_delete del WITH (NOLOCK) ON del.TransId = b.translogid
WHERE del.TransId IS NULL

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
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = bm.custid
	LEFT JOIN bettransm_delete del WITH (NOLOCK) ON del.TransId = bm.TransId
WHERE del.TransId IS NULL

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

----------------------------------------------
--bodb02.dbo.BettransInfo
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.BettransInfo b WITH (NOLOCK)
	INNER JOIN dbo.bettrans_delete bd WITH (NOLOCK) ON bd.transid = b.transid 

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	DELETE  binfo
	OUTPUT deleted.[transid], deleted.[SecAcceptTime], deleted.[LiveBetAcceptTime], deleted.[OriginalOdds], deleted.[RepUpdateTime], deleted.[ThirdTransID]
	INTO BettransInfo_delete ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [RepUpdateTime], [ThirdTransID])
	FROM bodb02.dbo.BettransInfo binfo WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = binfo.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.Transfer
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT bm.TransId
FROM bodb02.dbo.Transfer bm WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = bm.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT  deleted.[TransId], deleted.[CustId], deleted.[TransDate], deleted.[WinlostDate], deleted.[Bettype], deleted.[Stake], deleted.[Actual_Stake], deleted.[Winlost], deleted.[AWinlost], deleted.[MWinlost], deleted.[SWinlost], deleted.[PlayerComm], 
			deleted.[Comm], deleted.[AComm], deleted.[SComm], deleted.[StatusId], deleted.[RefNo], deleted.[TransDesc], deleted.[Recommend], deleted.[MRecommend], deleted.[SRecommend], deleted.[Username], deleted.[Currency], deleted.[CurrencyName], 
			deleted.[ActualRate], deleted.[Creator], deleted.[Balance], deleted.[IP], deleted.[CheckTime], deleted.[SerialNo], deleted.[RepUpdateTime]
	INTO Transfer_delete ([TransId], [CustId], [TransDate], [WinlostDate], [Bettype], [Stake], [Actual_Stake], [Winlost], [AWinlost], [MWinlost], [SWinlost], [PlayerComm], 
							[Comm], [AComm], [SComm], [StatusId], [RefNo], [TransDesc], [Recommend], [MRecommend], [SRecommend], [Username], [Currency], [CurrencyName], 
							[ActualRate], [Creator], [Balance], [IP], [CheckTime], [SerialNo], [RepUpdateTime])
	FROM bodb02.dbo.Transfer b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.Transfer_Coll
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)
	INNER JOIN dbo.Transfer_delete b1 WITH (NOLOCK) ON b1.TransID = b.TransID

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT  deleted.[CustId], deleted.[WinlostDate], deleted.[TransDate], deleted.[Bettype], deleted.[Debit], deleted.[Credit], deleted.[Currency], deleted.[ActualRate], deleted.[TransID], deleted.[RefNo], deleted.[Username], 
			deleted.[Recommend], deleted.[MRecommend], deleted.[SRecommend], deleted.[Creator], deleted.[TransDesc], deleted.[IP], deleted.[RepUpdateTime]
	INTO Transfer_Coll_delete (	[CustId], [WinlostDate], [TransDate], [Bettype], [Debit], [Credit], [Currency], [ActualRate], [TransID], [RefNo], [Username], 
									[Recommend], [MRecommend], [SRecommend], [Creator], [TransDesc], [IP], [RepUpdateTime])
	FROM bodb02.dbo.Transfer_Coll b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.TransferInfo
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)
	INNER JOIN dbo.Transfer_delete b1 WITH (NOLOCK) ON b1.TransID = b.TransID

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  b
	OUTPUT	deleted.[TransId], deleted.[APositiontaking], deleted.[MPositiontaking], deleted.[SPositiontaking], deleted.[EPositiontaking], deleted.[PlayerDiscount], deleted.[Discount], deleted.[ADiscount], deleted.[SDiscount], 
			deleted.[WalletType], deleted.[BonusID], deleted.[Amount], deleted.[CheckerId], deleted.[CheckerName], deleted.[IsCollection], deleted.[IsDel], deleted.[RepUpdateTime] 
	INTO TransferInfo_delete ([TransId], [APositiontaking], [MPositiontaking], [SPositiontaking], [EPositiontaking], [PlayerDiscount], [Discount], [ADiscount], [SDiscount], 
								[WalletType], [BonusID], [Amount], [CheckerId], [CheckerName], [IsCollection], [IsDel], [RepUpdateTime])
	FROM bodb02.dbo.TransferInfo b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.BetParlayDetail
CREATE TABLE #BetParlayDetail_tmp (Refno BIGINT, Serial INT, transid BIGINT, rid INT IDENTITY (1,1) PRIMARY KEY)
INSERT INTO #BetParlayDetail_tmp (Refno, Serial,transid)
SELECT DISTINCT bpd.RefNo, bpd.Serial, transid
FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)
		INNER JOIN refno_delete tmp WITH (NOLOCK) ON tmp.refno = bpd.refno

SET @MaxRow = (SELECT MAX(rid) FROM #BetParlayDetail_tmp)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE bpd
	OUTPUT	deleted.[RefNo], deleted.[Serial], deleted.[transid], deleted.[winlostdate], deleted.[statuswinlost], deleted.[statusid], deleted.[matchid], deleted.[bettype], deleted.[stake], deleted.[odds], deleted.[betteam], deleted.[hdp1], deleted.[hdp2], 
			deleted.[livehomescore], deleted.[liveawayscore], deleted.[liveindicator], deleted.[betcheck], deleted.[transdesc]
	INTO BetParlayDetail_delete (	[RefNo], [Serial], [transid], [winlostdate], [statuswinlost], [statusid], [matchid], [bettype], [stake], [odds], [betteam], [hdp1], [hdp2], 
									[livehomescore], [liveawayscore], [liveindicator], [betcheck], [transdesc])
	FROM bodb02.dbo.BetParlayDetail bpd WITH (ROWLOCK)
		INNER JOIN #BetParlayDetail_tmp t ON bpd.RefNo = t.Refno AND bpd.Serial = t.Serial AND bpd.transid = t.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.BetParlayResult
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT bpr.refno
FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)
		INNER JOIN refno_delete tmp WITH (NOLOCK) ON tmp.refno = bpr.refno

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE bpr
	OUTPUT	deleted.[RefNo], deleted.[Serial], deleted.[transid], deleted.[winlostdate], deleted.[statusid], deleted.[stake], deleted.[Odds], deleted.[mOdds], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm]
	INTO BetParlayResult_delete ([RefNo], [Serial], [transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm])
	FROM bodb02.dbo.BetParlayResult bpr WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = bpr.RefNo
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

--bodb02.dbo.zzzbettrans
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT z.transid
FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = z.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE z
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[livehomescore], deleted.[liveawayscore], 
			deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[matchid], deleted.[bettype], 
			deleted.[VoidingHistoryId], deleted.[RepUpdateTime], deleted.[SiteDBGroupID]
	INTO zzzbettrans_delete ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [matchid], [bettype], 
								[VoidingHistoryId], [RepUpdateTime], [SiteDBGroupID])
	FROM bodb02.dbo.zzzbettrans z WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = z.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END		

--bodb02.dbo.zzzbettransm
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT z.transid
FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = z.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE z
	OUTPUT	deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[livehomescore], deleted.[liveawayscore], 
			deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[matchid], deleted.[bettype], 
			deleted.[VoidingHistoryId], deleted.[RepUpdateTime], deleted.[SiteDBGroupID]
	INTO zzzbettransm_delete ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [matchid], [bettype], 
								[VoidingHistoryId], [RepUpdateTime], [SiteDBGroupID])
	FROM bodb02.dbo.zzzbettransm z WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = z.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END
