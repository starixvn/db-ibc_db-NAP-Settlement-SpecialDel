/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 CustLimitBet_LIC,CustLimitBetHistory_LIC: get by custid
							 CustLimitBet_QueueRetry & CustLimitBetQueue: Only get status = 0 [running]
*/

USE bodb02
GO
------------------------------------------------
--CustLimitBet_LIC
------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch

CREATE TABLE #CustLimitBet_LIC(
	[Matchid] [int] NOT NULL,
	[CustID] [int] NOT NULL,
	[AccumTurnover] [money] NOT NULL,
	[AccumPayout] [money] NOT NULL,
	[EventTypeID] [tinyint] NOT NULL,
	[LastQueueID] [bigint] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL
)

CREATE TABLE #CustLimitBet_LIC_update(
	[Matchid] [int] NOT NULL,
	[CustID] [int] NOT NULL,
	[AccumTurnover] [money] NOT NULL,
	[AccumPayout] [money] NOT NULL,
	[EventTypeID] [tinyint] NOT NULL,
	[LastQueueID] [bigint] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
	rid INT IDENTITY (1,1) PRIMARY KEY
)

CREATE TABLE #CustLimitBet_LIC_insert(
	[Matchid] [int] NOT NULL,
	[CustID] [int] NOT NULL,
	[AccumTurnover] [money] NOT NULL,
	[AccumPayout] [money] NOT NULL,
	[EventTypeID] [tinyint] NOT NULL,
	[LastQueueID] [bigint] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
	rid INT IDENTITY (1,1) PRIMARY KEY
)

INSERT INTO #CustLimitBet_LIC ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
SELECT [Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBet_LIC_Copy WITH (NOLOCK)

INSERT INTO #CustLimitBet_LIC_update ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
SELECT b.[Matchid], b.[CustID], b.[AccumTurnover], b.[AccumPayout], b.[EventTypeID], b.[LastQueueID], b.[ModifiedDate]
FROM #CustLimitBet_LIC b
	INNER JOIN [dbo].[CustLimitBet_LIC] main WITH (NOLOCK) ON b.custid = main.custid AND b.Matchid = main.Matchid AND b.EventTypeID = b.EventTypeID

INSERT INTO #CustLimitBet_LIC_insert ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
SELECT b.[Matchid], b.[CustID], b.[AccumTurnover], b.[AccumPayout], b.[EventTypeID], b.[LastQueueID], b.[ModifiedDate]
FROM #CustLimitBet_LIC b
	LEFT JOIN [dbo].[CustLimitBet_LIC] main WITH (NOLOCK) ON b.custid = main.custid AND b.Matchid = main.Matchid AND b.EventTypeID = b.EventTypeID
WHERE main.custid IS NULL

-- START to update first
DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(rid) FROM #CustLimitBet_LIC_update)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	UPDATE main
		SET [Matchid]=b.[Matchid],[AccumTurnover]=b.[AccumTurnover],[AccumPayout]=b.[AccumPayout],[EventTypeID]=b.[EventTypeID],
			[LastQueueID]=b.[LastQueueID],[ModifiedDate]=b.[ModifiedDate]
	FROM  [dbo].[CustLimitBet_LIC] main WITH (UPDLOCK,ROWLOCK)
		INNER JOIN #CustLimitBet_LIC_update b ON b.custid = main.custid AND b.Matchid = main.Matchid AND b.EventTypeID = b.EventTypeID
	WHERE b.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
-- START to insert 
SET @MaxRow = (SELECT MAX(rid) FROM #CustLimitBet_LIC_insert)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

	INSERT INTO [dbo].[CustLimitBet_LIC] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
	SELECT	b.[Matchid], b.[CustID], b.[AccumTurnover], b.[AccumPayout], b.[EventTypeID], b.[LastQueueID], b.[ModifiedDate]
	FROM #CustLimitBet_LIC_insert b WITH (NOLOCK)
	WHERE b.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END
----------2. CustLimitBetHistory_LIC
CREATE TABLE #CustLimitBetHistory_LIC(
	[Matchid] [int] NOT NULL,
	[CustID] [int] NOT NULL,
	[Transid] [bigint] NOT NULL,
	[TurnoverAdjust] [money] NOT NULL,
	[PayoutAdjust] [money] NOT NULL,
	[EventTypeID] [tinyint] NOT NULL,
	[CreatedDate] [datetime] NOT NULL,
	rid INT IDENTITY (1,1) PRIMARY KEY
)

INSERT INTO #CustLimitBetHistory_LIC ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBetHistory_LIC_Copy clbh WITH (NOLOCK)

-- START to insert ONLY
SET @MaxRow = (SELECT MAX(rid) FROM #CustLimitBetHistory_LIC)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	INSERT INTO [dbo].[CustLimitBetHistory_LIC] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
	SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
	FROM #CustLimitBetHistory_LIC clbh
	WHERE clbh.rid BETWEEN @StartRow AND @StopRow 

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--CustLimitBet_QueueRetry
INSERT INTO CustLimitBet_QueueRetry ([TransId], [Sitetype], [MainQueueId], [StatusId], [Createddate], [Trycount])
SELECT [TransId], [Sitetype], [MainQueueId], [StatusId], [Createddate], [Trycount]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBet_QueueRetry_Copy q WITH (NOLOCK)

--CustLimitBetQueue
INSERT INTO [dbo].[CustLimitBetQueue] ([Matchid], [CustID], [EventTypeID], [Transids], [ActionID], [Statusid], [CreatedDate], [ExecTime], [Duration], [ErrMsg])
SELECT	q.[Matchid], q.[CustID], q.[EventTypeID], q.[Transids], q.[ActionID], q.[Statusid], q.[CreatedDate], q.[ExecTime], q.[Duration], q.[ErrMsg]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBetQueue_Copy q WITH (NOLOCK)

