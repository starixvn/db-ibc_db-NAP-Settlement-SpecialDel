/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB01tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#180033] 
							 bettrans14, bettransm14, BetParlayDetail, BettransInfo14, Task_bettrans14_IP2Country
								
*/

USE SiteDB01tmp
GO
------------------------------------------------
/*****************Copy Stucture of Tables************************/
SELECT TOP 1 *
INTO bettrans14_delete
FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)

SELECT TOP 1 *
INTO BettransInfo14_delete
FROM bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransm14_delete
FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)

SELECT TOP 1 *
INTO BetParlayDetail_delete
FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)

SELECT TOP 1 *
INTO Task_bettrans14_IP2Country_delete
FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (NOLOCK)

/*****************Truncate Table************************/
TRUNCATE TABLE bettrans14_delete
TRUNCATE TABLE BettransInfo14_delete
TRUNCATE TABLE bettransm14_delete
TRUNCATE TABLE BetParlayDetail_delete
TRUNCATE TABLE Task_bettrans14_IP2Country_delete

/*******************BACKUP & DELETE Data**********************/
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
FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

--bodb02.dbo.bettrans14
WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE b
	OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[playercomm], 
			deleted.[comm], deleted.[acomm], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[livehomescore], 
			deleted.[liveawayscore], deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[oddsspread], 
			deleted.[actualrate], deleted.[matchid], deleted.[recommend], deleted.[mrecommend], deleted.[ruben], deleted.[betid], deleted.[statuswinlost], deleted.[modds], deleted.[bettype], deleted.[betdaqid], 
			deleted.[actual_stake], deleted.[currency], deleted.[ip], deleted.[transdesc], deleted.[sdiscount], deleted.[scomm], deleted.[spositiontaking], deleted.[swinlost], deleted.[srecommend], deleted.[virtualrate], deleted.[Username], 
			deleted.[CurrencyName], deleted.[oddstype], deleted.[statusID], deleted.[currency2], deleted.[balance], deleted.[SecAcceptFlag], deleted.[transid2], deleted.[recommdate], deleted.[ExtraInfo], deleted.[WalletType], deleted.[BonusID], 
			deleted.[RefCode], deleted.[SettlementTime], deleted.[epositiontaking], deleted.[ReasonID], deleted.[sort], deleted.[SiteDBGroupID]
	INTO bettrans14_delete (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], 
								[comm], [acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], 
								[liveawayscore], [liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], 
								[actualrate], [matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], 
								[actual_stake], [currency], [ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [virtualrate], [Username], 
								[CurrencyName], [oddstype], [statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], 
								[RefCode], [SettlementTime], [epositiontaking], [ReasonID], [sort], [SiteDBGroupID])
	FROM bodb02.dbo.bettrans14 b WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = b.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--bodb02.dbo.BettransInfo14
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.BettransInfo14 b WITH (NOLOCK)
	INNER JOIN dbo.bettrans14_delete bd WITH (NOLOCK) ON bd.transid = b.transid 

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE  binfo
	OUTPUT deleted.[transid], deleted.[SecAcceptTime], deleted.[LiveBetAcceptTime], deleted.[OriginalOdds], deleted.[ThirdTransID]
	INTO BettransInfo14_delete ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [ThirdTransID])
	FROM bodb02.dbo.BettransInfo14 binfo WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = binfo.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END
--bodb02.dbo.bettransm14
TRUNCATE TABLE #TempBatch

INSERT INTO #TempBatch (transid)
SELECT DISTINCT b.TransId
FROM bodb02.dbo.bettransm14 b WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = b.custid

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
			deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[oddsspread], 
			deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[awinlost], deleted.[mwinlost], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], 
			deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[actualrate], deleted.[matchid], deleted.[matchdate], deleted.[finalodds], deleted.[isfinish], deleted.[statuswinlost], deleted.[ruben], deleted.[bettype], 
			deleted.[spositiontaking], deleted.[swinlost], deleted.[sdiscount], deleted.[scomm], deleted.[statusID], deleted.[recommdate], deleted.[transdesc], deleted.[SecAcceptFlag], deleted.[SecAcceptTime], 
			deleted.[LiveBetAcceptTime], deleted.[ReasonIDm], deleted.[SiteDBGroupID]
	INTO bettransm14_delete ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], 
								[apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
								[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], 
								[spositiontaking], [swinlost], [sdiscount], [scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], 
								[LiveBetAcceptTime], [ReasonIDm], [SiteDBGroupID])
	FROM bodb02.dbo.bettransm14 bm WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = bm.TransId
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

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
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

--bodb02.dbo.Task_bettrans14_IP2Country
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT tbip.TransId
FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_delete b WITH (NOLOCK) ON b.transid = tbip.transid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
WHILE (@MaxRow IS NOT NULL)
BEGIN

	DELETE  tbip
	OUTPUT	deleted.[transid], deleted.[winlostdate], deleted.[CountryShort], deleted.[IPArchive]
	INTO [Task_bettrans14_IP2Country_delete] ([transid], [winlostdate], [CountryShort], [IPArchive])
	FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = tbip.TransId
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

	