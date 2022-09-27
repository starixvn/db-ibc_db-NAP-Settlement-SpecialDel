-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_09]
(
	@transIds VARCHAR(MAX)
	, @SiteDBGroupID SMALLINT = 1
	, @tablename VARCHAR(200) = ''
)
/*
	Created by: 20220926@Victoria
	Task: execRep SP for Settlement [Redmine:#178142]
	DB: DBCTG-bodb02
	
	Revisions:
		- 	20220926@Victoria: update sitedbgroupid [Redmine:#178142]

	Param's Explanation:
	
	Samlple execution to parse XML

	DECLARE @transIds VARCHAR(MAX), @xml XML
	
	SET @transIds = (SELECT TOP 10 transid as t
		from bettrans (NOLOCK)
		FOR XML RAW ('r'), ROOT ('root'))

	SET @xml = CAST(@transIds as XML)

	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))

*/	
AS
BEGIN

	DECLARE @transidXML XML
	DECLARE @tempTrans TABLE (TransID BIGINT PRIMARY KEY)

	SET @transidXML = CONVERT(XML, @Transids)
	
	INSERT INTO @tempTrans (TransID)
	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))
	
	IF (@tablename = 'bettrans' AND OBJECT_ID(N'dbo.bettrans') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
		
	IF (@tablename = 'bettransm' AND OBJECT_ID(N'dbo.bettransm') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettrans14' AND OBJECT_ID(N'dbo.bettrans14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransm14' AND OBJECT_ID(N'dbo.bettransm14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransRnG' AND OBJECT_ID(N'dbo.bettransRnG') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'Translog' AND OBJECT_ID(N'dbo.Translog') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF (@tablename = 'BettransLC' AND OBJECT_ID(N'dbo.BettransLC') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransG' AND OBJECT_ID(N'dbo.bettransG') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransRnG14' AND OBJECT_ID(N'dbo.bettransRnG14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'Translog14' AND OBJECT_ID(N'dbo.Translog14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF (@tablename = 'BettransLC14' AND OBJECT_ID(N'dbo.BettransLC14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransG14' AND OBJECT_ID(N'dbo.bettransG14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'zzzbettrans' AND OBJECT_ID(N'dbo.zzzbettrans') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'zzzbettransm' AND OBJECT_ID(N'dbo.zzzbettransm') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'TicketVoiding_RequestDetailTicket_Single' AND OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_Single') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_Single b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'TicketVoiding_RequestDetailTicket_SubParlay' AND OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_SubParlay') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_SubParlay b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
			
END

GO
-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)

CREATE TABLE #tmp_bettrans_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettrans14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransm_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransm14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)


CREATE TABLE #tmp_bettransLC_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransLC14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransRnG_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransRnG14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_bettransG_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransG14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_translog_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_translog14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_zzzbettrans_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_zzzbettransm_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_TicketVoiding_RequestDetailTicket_Single (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_TicketVoiding_RequestDetailTicket_SubParlay (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
--------------------------------------------------------------
INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN	('24Tech', 'MRCATSB', '24AVIA', 'allwincity', 'allwinCV', 'bdtt', 'bdtt2', 'GB888CV', 'Bobbet', 'Tianbo', 'ig128', 'A1game', 'txwl002', 'weicai', 'DingTai', 'MTech', 'shengboyun', '633esports', 'pmwint',
					'Diamond', 'ig128s', '442ball', 'Omni88', 'e8casino', 'e8casinoCV', 'asiabet88', 'TLC', 'JBO', 'Betway', 'KingFun', 'IBO', 'Kzing2', 'MANBETX', 'LS88', 'TH3', 'V03', 'XTSB', 'KZO41', 'kzsbxjCV', 'Nexus',
					'GoldenF', 'LEIHUO', 'DongYing', 'bmwbet', 'HIDZ', 'HONBET', 'Newhonbet', 'HOT99', 'XTDGT', 'LLgaming', 'IGPTech', 'AEUG', 'UG2', 'JJBGAME', 'VKGAME', 'JJBGAMECV', 'VKGAMECV', 'AJJCV', 'KeenOcean', 'K8VN',
					'Storm88', 'liv66', 'liv66SW', 'win365', 'livv88sw', 'WINHX1', 'KhmerG', 'afb99', 'khmer', 'KOKVN', 'KOKVN2', 'Lucky88', '11bet', 'Fabet', 'One88', 'Debet', 'Zbet', 'Sin88', 'Sunwin', 'Five88',
					'Red88', 'Lode88', 'Zowin', 'SV88', 'Nbet', 'OXbet', 'Sky88', 'SM88', 'SL88SW', 'ManCity', 'Mancity2', 'N88', 'N8B', 'N8G', 'NukeGaming', 'Pay4d', 'Weiwei', 'Avia', 'MARS', 'Okada',
					'BPLE', 'OkadaSW', 'AnvoFH', 'erhaozhan', 'TCbet', 'TaoCai', 'FHLMSABA', 'Titank', 'FHLMSABAS', 'SunGame', 'Sun988', 'SSSSEA', 'Sunrise', 'Sunriseb2b', 'SunriseCV', 'Ty777', 'Wanfang', 'KUTECH', 'GamingSoft', 'Dade',
					'Nbbet', 'BetDeal', 'Xtu168', 'GSCSW', 'Yibo', 'YiboCV', 'Mopgaming', 'Raisetech', 'TopGame', 'JIDU', 'Wanbo', 'ZhiFeng032', 'ZhiFeng036', 'ZhiFeng035', 'ZhiFeng021', 'ZhiFeng009', 'ZFRT082', 'mtegames', 'ZhiFeng037', 'ZFRT125',
					'ZFRT133', 'NewFuture', 'ZFRT132', 'ZhiFeng040', 'ZFRT128', 'ZFRT080', 'JIB88', 'ZhiFeng012', 'ZFRT115', 'ZFRT142', 'SAGAME88', 'ZFRT150', 'ZFRT081', 'ZFRT143', 'ZFRT166', 'ZhiFeng055', 'ZFRT156', 'ZhiFeng106', 'ZhiFeng122', 'ZFRT129',
					'ZhiFeng098', 'ZFRT165', 'ZFRT144', 'ZhiFeng147', 'ZFRT155', 'ZhiFeng026', 'ZFRT186', 'ZhiFeng156', 'ZhiFeng133', 'ZFRT126CV', 'ZFRT126', 'CENTRAL168', 'ZFRT090', 'ZF055PMW', 'ZFRT195', 'ZhiFeng138', 'ZhiFeng183', 'ZhiFeng013', 'ZFRT167', 'ZF138THB',
					'ZFRT144CV', 'ZF138VND', 'ZFRT161', 'ZhiFeng201', 'ZFRT158CV', 'Zhifeng215', 'ZhiFeng208', 'ZFRT213', 'ZhiFeng222', 'Zzun88', 'Man1878', 'NextBet', 'iBET', 'IONclub', 'Xinbo', 'HonorW', 'M8Credit', 'Ae88', 'FLC', 'OCMS',
					'Liga', 'dj888', 'JIBET', 'awc2', 'YongBao', 'Datang001', 'ISC888', 'infini88', 'Hecbet', 'Royal', 'vssports', 'DEWA', '88Macao', '9wickets', 'LSM99', 'Leng4D', 'Bonanza88', 'Senibet', 'WBS', 'OPEBET',
					'DFGame', 'OYO', 'awc', 'loc', 'wmcasino', 'OESports', 'yuanbao', 'Rakyat4DSW', 'GBET', 'Towin', 'C7YOUXICV', 'SEAL888', 'ZF026', 'starsoccer', '24AVIASL', 'H1royal', 'HFYX', 'ZhiFeng142', 'ZFRT218', 'KSTECH',
					'WLSTAR', 'ZFRT198', 'F88IN1SW', 'ZhiFeng084', 'GoldenF2CV', 'WGAMING', 'DMsports', '12B', 'Riverich', 'ZF215aTR', 'AKYL99', 'Lucklotter', 'Niu8gaming'
					)

-------------------DATA PREPARATION --------------------------
-- bettrans
INSERT INTO #tmp_bettrans_scaleout (transid)
SELECT transid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettrans14
INSERT INTO #tmp_bettrans14_scaleout (transid)
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransm
INSERT INTO #tmp_bettransm_scaleout (transid)
SELECT transid
FROM bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransm14
INSERT INTO #tmp_bettransm14_scaleout (transid)
SELECT transid
FROM bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
	
-- bettransLC
INSERT INTO #tmp_bettransLC_scaleout (transid)
SELECT transid
FROM bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransLC14
INSERT INTO #tmp_bettransLC14_scaleout (transid)
SELECT transid
FROM bettransLC14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransRnG
INSERT INTO #tmp_bettransRnG_scaleout (transid)
SELECT transid
FROM bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransRnG14
INSERT INTO #tmp_bettransRnG14_scaleout (transid)
SELECT transid
FROM bettransRnG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransG
INSERT INTO #tmp_bettransG_scaleout (transid)
SELECT transid
FROM bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- bettransG14
INSERT INTO #tmp_bettransG14_scaleout (transid)
SELECT transid
FROM bettransG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- translog
INSERT INTO #tmp_translog_scaleout (transid)
SELECT translogid
FROM translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- translog14
INSERT INTO #tmp_translog14_scaleout (transid)
SELECT translogid
FROM translog14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- zzzbettrans
INSERT INTO #tmp_zzzbettrans_scaleout (transid)
SELECT b.transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- zzzbettransm
INSERT INTO #tmp_zzzbettransm_scaleout (transid)
SELECT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- TicketVoiding_RequestDetailTicket_Single
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_Single (transid)
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

-- TicketVoiding_RequestDetailTicket_Single
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_Single (transid)
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

-- TicketVoiding_RequestDetailTicket_SubParlay
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_SubParlay (transid)
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_SubParlay (transid)
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

---------------------- param declare to process data -----
DECLARE @StartRow INT = 1
	, @StopRow INT 
	, @MaxRow INT 
	, @Threshold INT = 2000 -- the number of each batch
	, @tablename VARCHAR (200)
	, @transIds VARCHAR (MAX) = ''
	, @siteDBGroupID SMALLINT = 1

DECLARE @debug_message VARCHAR(500)

------ 1. bettrans - #tmp_bettrans_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans_scaleout)
BEGIN
	SET @tablename = 'bettrans'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans_scaleout)
	-- SET for first batch
	SET @StopRow = @Threshold
	WHILE (1 = 1)
	BEGIN
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettrans_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK

	END
END
------ 2. bettrans14 - #tmp_bettrans14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans14_scaleout)
BEGIN 
	SET @tablename = 'bettrans14'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettrans14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK

	END
END
------ 3. bettransm - #tmp_bettransm_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransm_scaleout)
BEGIN
	SET @tablename = 'bettransm'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransm_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransm_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END
------ 4. bettransm14 - #tmp_bettransm14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransm14_scaleout)
BEGIN 
	SET @tablename = 'bettransm14'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransm14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransm14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

---------------------new -----------------
------ 5. bettransLC - #tmp_bettransLC_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransLC_scaleout)
BEGIN 
	SET @tablename = 'bettransLC'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransLC_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransLC_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 6. bettransLC14 - #tmp_bettransLC14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransLC14_scaleout)
BEGIN 
	SET @tablename = 'bettransLC14'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransLC14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransLC14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 7. bettransRnG - #tmp_bettransRnG_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransRnG_scaleout)
BEGIN 
	SET @tablename = 'bettransRnG'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransRnG_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransRnG_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 8. bettransRnG14 - #tmp_bettransRnG14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransRnG14_scaleout)
BEGIN 
	SET @tablename = 'bettransRnG14'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransRnG14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransRnG14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 9. bettransG - #tmp_bettransG_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransG_scaleout)
BEGIN 
	SET @tablename = 'bettransG'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransG_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransG_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END
------ 10. bettransG14 - #tmp_bettransG14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransG14_scaleout)
BEGIN 
	SET @tablename = 'bettransG14'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransG14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransG14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END
------ 11. translog - #tmp_translog_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_translog_scaleout)
BEGIN 
	SET @tablename = 'translog'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_translog_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_translog_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END
------ 12. translog14 - #tmp_translog14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_translog14_scaleout)
BEGIN 
	SET @tablename = 'translog14'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_translog14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_translog14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 13. zzzbettrans - #tmp_zzzbettrans_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_zzzbettrans_scaleout)
BEGIN 
	SET @tablename = 'zzzbettrans'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_zzzbettrans_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_zzzbettrans_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 14. zzzbettransm - #tmp_zzzbettransm_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_zzzbettransm_scaleout)
BEGIN 
	SET @tablename = 'zzzbettransm'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_zzzbettransm_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_zzzbettransm_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------ 15. TicketVoiding_RequestDetailTicket_Single - #tmp_TicketVoiding_RequestDetailTicket_Single ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_TicketVoiding_RequestDetailTicket_Single)
BEGIN 
	SET @tablename = 'TicketVoiding_RequestDetailTicket_Single'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_TicketVoiding_RequestDetailTicket_Single)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_TicketVoiding_RequestDetailTicket_Single R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

------16. TicketVoiding_RequestDetailTicket_SubParlay - #tmp_TicketVoiding_RequestDetailTicket_SubParlay ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay)
BEGIN 
	SET @tablename = 'TicketVoiding_RequestDetailTicket_SubParlay'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK
	END
END

/*
------------ CHECKING DATA AFTER RUN SCRIPT -----------------------
--bettrans
SELECT transid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettrans14
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransm
SELECT transid
FROM bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransm14
SELECT transid
FROM bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
	
-- bettransLC
SELECT transid
FROM bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransLC14
SELECT transid
FROM bettransLC14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransRnG
SELECT transid
FROM bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransRnG14
SELECT transid
FROM bettransRnG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransG
SELECT transid
FROM bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransG14
SELECT transid
FROM bettransG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- translog
SELECT translogid
FROM translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- translog14
SELECT translogid
FROM translog14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--zzzbettrans
SELECT transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--zzzbettransm
SELECT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_Single
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_Single
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

*/


