-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
--- GROUP 4: bettransm, bettransm14, bettransRnG14, bettransLC14, translog14, bettransG, bettransG14, zzzbettrans, zzzbettransm, TicketVoiding_RequestDetailTicket_Single, TicketVoiding_RequestDetailTicket_SubParlay
CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)

CREATE TABLE #tmp_bettransm_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransm14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransLC14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransRnG14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_bettransG_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_bettransG14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
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
WHERE site IN ('18Luck','TGAA0813','XinliCV','Xinli2CV','YSYBO688','SKY1688','vnggame','368Cash','TT128','368CashSW','568Win','568WinSW','ab6688','ABEMT','Abcasino','Million','AG','AMG','PKbet','PanguGame','BETSUN','HuangMa','BigGaming','818Bet','HongChow','TangChao','CGame','SSSGaming','HCVIP','WinWin','BWGaming','CGame4','7kplatform','BGCV','SEAGaming','Aoncash','M8bola','Q8bola','NBCbet','Unobet','Winn69','Axiawin','Ratugg','Lagadewa','Monstergol','B24VN','Rio66','HAIFA','BBIN2','BBIN3','BE7','Luckywin88','beplay','beplayCV','DBP','Monaco','RBCV','Dawoo','pinbo','QUBO','DawooCV','Dawooxin','YYHbet','FB88','FB88CV','Happy1668','YAYOU','US8YAYOU','HC6YAYOU','J9YAYOU','Hejiyongle','Boma365','Hengcai88','GESAB','mansion88','Happy8','THECLUB','THEDEN','Mayayule','Dachen','MayFair','Vwin','MrCat','Fugui','TitanOne','VWIN66','WKCUR','WKPHIL','TitanCraft','Saibo','Titanbet','Mayibet','MayibetCV','OLE777','OLE777CV','Soon88','Soon88CV','TGO','365online','YBTech','BOSSB','YTX','Yunji','GAMEBee','SDY','dfbetCV','SDYSW','Entaplay','Tripleone','MICL','laba360','TSEnter','BSSB168','MYGAME','IgameTech','ARYA','MYGAMECV','BSSB168CV','TSXJCV','W88','GPIGAME','MAX88','ALPHA88','VN88','Win88','DF88','Asian88','ID88','BOG22','W88CV','ROYAL88','alog','zt828','Winbox','JDYGaming','V9betSW','PKKing','ug396','Baji','998bet','hjccasino','ITCbet','Callmeboss','HL8','9bet','WABET','VCBA','GMASTER','Gampag','bigbet','Peakk','Bolanation','Comebet','N8BK','3ge888','C7YOUXI','Gaobet','OSUSDT','VCBACV','Uwoniwin','383sport','USSBET','X33Asia','9w','LUCKYBET','kbosportCV','GoToWin','kbosports','ANGbet','TGXICV','Winsplay','GmasterS','YSYBO688CV','OBGM','9wtest','ABCGAME','ABCgamevip','AOGcasino','Apollo369','Asiasigma','AWS08','B8KRW','baowang188','Belegend','Bet88CV','Bigwiner','BoAPI09','BoAPI10','BoAPI11','C88bet','CandyA18','CCLive','CloudRock','CMBSW','d3sports','DCSDemo','DDwin','DemoCV','dghash','dghashCV','directapi','ECBet88','EclipseSW','FKsport','G4ALL','GLive','GMDFD','golden8','GsportsCV','Happistar','Heji888','HOHPLAY','HX9Candy','HY6','IvoryBet','JUYOU','kgsports','KingBet','LegendWin','lionsclub','luckybuy','M88ASIA','n88clubSW','NFBI','Nova88','OBsystem','oddstest','OGWLS','Opal88','opsl','opsl188','Ot88','PINT','PLAYES','QASite','Saba789','SabaDemo','SBObet','ScaleDemo1','SENBKK','skykey','Spondemo','SWDemo','SWSite','Tesla','Test0112','Test1607','TGXI','Twowin','TWWIN','TYM2','VEGA77','Vwin88','WBG88','Wcasino','Wcasino88','Webet88','WinboxSW','wmcasinoS','Xiaojin','Xinli3CV','T1SOFTSW','JK8API')
-------------------DATA PREPARATION --------------------------
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
	
-- bettransLC14
INSERT INTO #tmp_bettransLC14_scaleout (transid)
SELECT transid
FROM bettransLC14 b WITH (NOLOCK)
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

-- translog14
INSERT INTO #tmp_translog14_scaleout (transid)
SELECT translogid
FROM translog14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- zzzbettrans
INSERT INTO #tmp_zzzbettrans_scaleout (transid)
SELECT DISTINCT b.transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- zzzbettransm
INSERT INTO #tmp_zzzbettransm_scaleout (transid)
SELECT DISTINCT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

-- TicketVoiding_RequestDetailTicket_Single
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_Single (transid)
SELECT DISTINCT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans s WITH (NOLOCK) ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

-- TicketVoiding_RequestDetailTicket_Single
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_Single (transid)
SELECT DISTINCT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans14 s WITH (NOLOCK) ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

-- TicketVoiding_RequestDetailTicket_SubParlay
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_SubParlay (transid)
SELECT DISTINCT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm s WITH (NOLOCK) ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
-- Only update for tickets created before migration on 22/09/2022
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_SubParlay (transid)
SELECT DISTINCT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm14 s WITH (NOLOCK) ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

---------------------- param declare to process data -----
DECLARE @StartRow INT = 1
	, @StopRow INT 
	, @MaxRow INT 
	, @Threshold INT = 2000 -- the number of each batch
	, @tablename VARCHAR (200)
	, @transIds VARCHAR (MAX) = ''
	, @siteDBGroupID SMALLINT = 2

DECLARE @debug_message VARCHAR(500)


------ 3. bettransm - #tmp_bettransm_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransm_scaleout)
BEGIN
	SET @tablename = 'bettransm'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransm_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransm_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransm14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransLC14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransRnG14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransG_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettransG14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_translog14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_zzzbettrans_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_zzzbettransm_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_TicketVoiding_RequestDetailTicket_Single R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC Bet_ExecRep14_00 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

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


