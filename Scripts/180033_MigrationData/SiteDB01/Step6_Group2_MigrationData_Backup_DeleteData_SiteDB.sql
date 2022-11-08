/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB01tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#180033] 
							 bettrans, transfer, bettransm, BettransInfo, Transfer_Coll, TransferInfo
								
*/

USE SiteDB01tmp
GO

------------------------------------------------
/*****************Copy Stucture of Tables************************/
SELECT TOP 1 *
INTO bettrans_delete
FROM bodb02.dbo.bettrans b WITH (NOLOCK)

SELECT TOP 1 *
INTO BettransInfo_delete
FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransm_delete
FROM bodb02.dbo.bettransm bm WITH (NOLOCK)

SELECT TOP 1 *
INTO Transfer_delete
FROM bodb02.dbo.Transfer b WITH (NOLOCK)

SELECT TOP 1 *
INTO Transfer_Coll_delete
FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)

SELECT TOP 1 *
INTO TransferInfo_delete
FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)

/*****************Truncate Table************************/
TRUNCATE TABLE bettrans_delete
TRUNCATE TABLE BettransInfo_delete
TRUNCATE TABLE bettransm_delete
TRUNCATE TABLE Transfer_delete
TRUNCATE TABLE Transfer_Coll_delete
TRUNCATE TABLE TransferInfo_delete

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
--bodb02.dbo.bettransm
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT bm.TransId
FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = bm.custid

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