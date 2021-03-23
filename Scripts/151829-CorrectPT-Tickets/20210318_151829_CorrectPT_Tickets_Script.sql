/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: Helen
	Date 20210318
	Task: Adjust Sportsbook PT for all licensees - Update tickets - [Redmine:151829]
	DB: DBTXN/bodb02
*/
USE bodb02
GO
--- define temporary tables 
CREATE TABLE #supers (custid INT, PT SMALLMONEY, apositiontaking	smallmoney)
CREATE TABLE #tmpSite (site VARCHAR(200), apositiontaking	smallmoney)
CREATE TABLE #input_Super (custid INT, apositiontaking	smallmoney)
CREATE TABLE #tmp_recommend (custid INT,apositiontaking	smallmoney)
CREATE TABLE #Match_Final (Matchid INT, ID INT IDENTITY(1,1))
CREATE TABLE #tickets_tmp (transid BIGINT, matchid INT,apositiontaking smallmoney, IsBettrans BIT, IsTranslog BIT,IsFinish BIT)
CREATE TABLE #input_BAMember (custid INT)
CREATE TABLE #Ticket_OldValue_BackupForCompare ( transid BIGINT
												,apositiontaking smallmoney
												,tpositiontaking smallmoney
												,apositiontaking_new smallmoney
												)
INSERT INTO #tmpSite(site,apositiontaking)
SELECT 	'11bet',	0.9
UNION ALL SELECT 	'12BET',	0.9
UNION ALL SELECT 	'18Luck',	0.9
UNION ALL SELECT 	'24AVIA',	0.92
UNION ALL SELECT 	'365online',	0.9
UNION ALL SELECT 	'368CASH',	0.9
UNION ALL SELECT 	'396Club',	0.9
UNION ALL SELECT 	'3STAR88',	0.9
UNION ALL SELECT 	'568Win',	0.93
UNION ALL SELECT 	'633esports',	0.93
UNION ALL SELECT 	'7kplatform',	0.9
UNION ALL SELECT 	'818Bet',	0.9
UNION ALL SELECT 	'88MACAO',	0.9
UNION ALL SELECT 	'9BET',	0.9
UNION ALL SELECT 	'9CLUB',	0.9
UNION ALL SELECT 	'9dianyule',	0.9
UNION ALL SELECT 	'A1game',	0.93
UNION ALL SELECT 	'ABCASINO',	0.9
UNION ALL SELECT 	'AE88',	0.9
UNION ALL SELECT 	'AEUG',	0.9
UNION ALL SELECT 	'AG',	0.9
UNION ALL SELECT 	'allwincity',	0.9
UNION ALL SELECT 	'Alpha88',	0.9
UNION ALL SELECT 	'Alphalota',	0.9
UNION ALL SELECT 	'ANGbet',	0.9
UNION ALL SELECT 	'AnvoFH',	0.9
UNION ALL SELECT 	'AOGcasino',	0.9
UNION ALL SELECT 	'AONCASH',	0.9
UNION ALL SELECT 	'AWC',	0.9
UNION ALL SELECT 	'awc2',	0.9
UNION ALL SELECT 	'B24VN',	0.9
UNION ALL SELECT 	'Baji',	0.9
UNION ALL SELECT 	'Baolong',	0.9
UNION ALL SELECT 	'Haifa',	0.95
UNION ALL SELECT 	'BBIN2',	0.95
UNION ALL SELECT 	'BBIN3',	0.95
UNION ALL SELECT 	'bdtt',	0.9
UNION ALL SELECT 	'BE7',	0.9
UNION ALL SELECT 	'BETSUN',	0.9
UNION ALL SELECT 	'BigGaming',	0.9
UNION ALL SELECT 	'Bobbet',	0.95
UNION ALL SELECT 	'Bobo88',	0.91
UNION ALL SELECT 	'BOG22',	0.9
UNION ALL SELECT 	'Bolanation',	0.9
UNION ALL SELECT 	'BOMA365',	0.9
UNION ALL SELECT 	'Boying',	0.9
UNION ALL SELECT 	'BPLE',	0.9
UNION ALL SELECT 	'Bsdbet',	0.9
UNION ALL SELECT 	'BWGaming',	0.9
UNION ALL SELECT 	'Callmeboss',	0.9
UNION ALL SELECT 	'CGame',	0.9
UNION ALL SELECT 	'CGame4',	0.9
UNION ALL SELECT 	'Champion',	0.9
UNION ALL SELECT 	'alog',	0.9
UNION ALL SELECT 	'Datang001',	0.9
UNION ALL SELECT 	'Dawoo',	0.9
UNION ALL SELECT 	'DBP',	0.9
UNION ALL SELECT 	'Debet',	0.9
UNION ALL SELECT 	'DEWA',	0.9
UNION ALL SELECT 	'DF88',	0.9
UNION ALL SELECT 	'Diamond',	0.93
UNION ALL SELECT 	'DingTai',	0.93
UNION ALL SELECT 	'e8casino',	0.9
UNION ALL SELECT 	'ECLBET',	0.9
UNION ALL SELECT 	'erhaozhan',	0.9
UNION ALL SELECT 	'Fabet',	0.9
UNION ALL SELECT 	'FB88',	0.9
UNION ALL SELECT 	'Five88',	0.9
UNION ALL SELECT 	'FLC',	0.9
UNION ALL SELECT 	'asiabet88',	0.93
UNION ALL SELECT 	'FYyule',	0.9
UNION ALL SELECT 	'GAMEBee',	0.9
UNION ALL SELECT 	'GAMINGSOFT',	0.92
UNION ALL SELECT 	'Gampag',	0.9
UNION ALL SELECT 	'Gaobet',	0.9
UNION ALL SELECT 	'gbkj',	0.9
UNION ALL SELECT 	'GESAB',	0.9
UNION ALL SELECT 	'GGBOOK',	0.9
UNION ALL SELECT 	'GGBOOKES',	0.9
UNION ALL SELECT 	'GMaster',	0.9
UNION ALL SELECT 	'GPIgame',	0.9
UNION ALL SELECT 	'HBO999',	0.9
UNION ALL SELECT 	'HC6YAYOU',	0.9
UNION ALL SELECT 	'Heaven',	0.9
UNION ALL SELECT 	'HECBET',	0.9
UNION ALL SELECT 	'Happy1668',	0.9
UNION ALL SELECT 	'Hejiyongle',	0.9
UNION ALL SELECT 	'hjccasino',	0.9
UNION ALL SELECT 	'HL8',	0.9
UNION ALL SELECT 	'HONBET',	0.9
UNION ALL SELECT 	'HONORW',	0.9
UNION ALL SELECT 	'HOT99',	0.9
UNION ALL SELECT 	'HuangMa',	0.9
UNION ALL SELECT 	'iBET',	0.9
UNION ALL SELECT 	'ID88',	0.9
UNION ALL SELECT 	'ig128',	0.93
UNION ALL SELECT 	'ig128s',	0.93
UNION ALL SELECT 	'IGPTech',	0.9
UNION ALL SELECT 	'INSERTGAME',	0.9
UNION ALL SELECT 	'IONClub',	0.9
UNION ALL SELECT 	'ITCBET',	0.9
UNION ALL SELECT 	'J9YAYOU',	0.9
UNION ALL SELECT 	'JIBET',	0.9
UNION ALL SELECT 	'Junbet',	0.9
UNION ALL SELECT 	'JZFortune',	0.9
UNION ALL SELECT 	'khmer',	0.9
UNION ALL SELECT 	'khmerA2',	0.9
UNION ALL SELECT 	'KUTECH',	0.9
UNION ALL SELECT 	'IBO',	0.93
UNION ALL SELECT 	'Kzing2',	0.93
UNION ALL SELECT 	'Lagadewa',	0.9
UNION ALL SELECT 	'Leng4D',	0.9
UNION ALL SELECT 	'LIGA',	0.9
UNION ALL SELECT 	'liv66',	0.9
UNION ALL SELECT 	'liv66SW',	0.9
UNION ALL SELECT 	'KeenOcean',	0.9
UNION ALL SELECT 	'livv88sw',	0.9
UNION ALL SELECT 	'Lode88',	0.9
UNION ALL SELECT 	'Lucky88',	0.9
UNION ALL SELECT 	'M8BOLA',	0.9
UNION ALL SELECT 	'MACAUBET',	0.9
UNION ALL SELECT 	'MANBETX',	0.93
UNION ALL SELECT 	'ManCity',	0.9
UNION ALL SELECT 	'mansion88',	0.9
UNION ALL SELECT 	'MARS',	0.9
UNION ALL SELECT 	'MAX88',	0.9
UNION ALL SELECT 	'Mayayule',	0.9
UNION ALL SELECT 	'Mayibet',	0.9
UNION ALL SELECT 	'MICL',	0.9
UNION ALL SELECT 	'Monaco',	0.9
UNION ALL SELECT 	'Monstergol',	0.9
UNION ALL SELECT 	'Mopgaming',	0.93
UNION ALL SELECT 	'MTech',	0.93
UNION ALL SELECT 	'mtegames',	0.93
UNION ALL SELECT 	'Mybet88',	0.9
UNION ALL SELECT 	'N88',	0.9
UNION ALL SELECT 	'N8B',	0.9
UNION ALL SELECT 	'N8BK',	0.9
UNION ALL SELECT 	'N8G',	0.9
UNION ALL SELECT 	'Nbbet',	0.92
UNION ALL SELECT 	'Nbet',	0.9
UNION ALL SELECT 	'NEWHONBET',	0.9
UNION ALL SELECT 	'NEXTBET',	0.9
UNION ALL SELECT 	'NukeGaming',	0.91
UNION ALL SELECT 	'OCMS',	0.9
UNION ALL SELECT 	'Okada',	0.9
UNION ALL SELECT 	'OLE777',	0.9
UNION ALL SELECT 	'One88',	0.9
UNION ALL SELECT 	'Onegaming',	0.9
UNION ALL SELECT 	'OneSports',	0.91
UNION ALL SELECT 	'OPEbet',	0.9
UNION ALL SELECT 	'OSUSDT',	0.91
UNION ALL SELECT 	'OXbet',	0.9
UNION ALL SELECT 	'Pay4d',	0.91
UNION ALL SELECT 	'Pinbo',	0.9
UNION ALL SELECT 	'PKbet',	0.9
UNION ALL SELECT 	'PKKing',	0.9
UNION ALL SELECT 	'pmwint',	0.93
UNION ALL SELECT 	'Q8BOLA',	0.9
UNION ALL SELECT 	'Raisetech',	0.93
UNION ALL SELECT 	'Ratugg',	0.9
UNION ALL SELECT 	'Red88',	0.9
UNION ALL SELECT 	'ROYAL',	0.9
UNION ALL SELECT 	'SDY',	0.9
UNION ALL SELECT 	'SENIBET',	0.9
UNION ALL SELECT 	'shengboyun',	0.93
UNION ALL SELECT 	'Sin88',	0.9
UNION ALL SELECT 	'Sky88',	0.9
UNION ALL SELECT 	'Soon88',	0.9
UNION ALL SELECT 	'Spark',	0.9
UNION ALL SELECT 	'Sunriseb2b',	0.9
UNION ALL SELECT 	'Sunwin',	0.9
UNION ALL SELECT 	'SV88',	0.9
UNION ALL SELECT 	'TangChao',	0.9
UNION ALL SELECT 	'TaoCai',	0.9
UNION ALL SELECT 	'TCbet',	0.9
UNION ALL SELECT 	'TGO',	0.9
UNION ALL SELECT 	'Tianbo',	0.95
UNION ALL SELECT 	'TLC',	0.93
UNION ALL SELECT 	'TopGame',	0.93
UNION ALL SELECT 	'Tripleone',	0.9
UNION ALL SELECT 	'TT128',	0.9
UNION ALL SELECT 	'txwl002',	0.93
UNION ALL SELECT 	'TYCgame',	0.9
UNION ALL SELECT 	'ug396',	0.9
UNION ALL SELECT 	'UNOBET',	0.9
UNION ALL SELECT 	'US8YAYOU',	0.9
UNION ALL SELECT 	'UwinY',	0.9
UNION ALL SELECT 	'Uwoniwin',	0.9
UNION ALL SELECT 	'VCBA',	0.9
UNION ALL SELECT 	'VN88',	0.9
UNION ALL SELECT 	'VWIN66',	0.9
UNION ALL SELECT 	'W88',	0.9
UNION ALL SELECT 	'WABET',	0.9
UNION ALL SELECT 	'Wanbo',	0.93
UNION ALL SELECT 	'Wanfang',	0.9
UNION ALL SELECT 	'WBS',	0.9
UNION ALL SELECT 	'weicai',	0.93
UNION ALL SELECT 	'win365',	0.9
UNION ALL SELECT 	'Winbox',	0.91
UNION ALL SELECT 	'WINCLUB88',	0.9
UNION ALL SELECT 	'Winn69',	0.9
UNION ALL SELECT 	'WKCUR',	0.9
UNION ALL SELECT 	'WKPHIL',	0.9
UNION ALL SELECT 	'wmcasino',	0.9
UNION ALL SELECT 	'X2Dynamic',	0.9
UNION ALL SELECT 	'Xinbo',	0.9
UNION ALL SELECT 	'XTDGT',	0.9
UNION ALL SELECT 	'Xtu168',	0.92
UNION ALL SELECT 	'Yibo',	0.9
UNION ALL SELECT 	'YongBao',	0.9
UNION ALL SELECT 	'YTX',	0.9
UNION ALL SELECT 	'Yunji',	0.9
UNION ALL SELECT 	'Zbet',	0.9
UNION ALL SELECT 	'ZFRT080',	0.93
UNION ALL SELECT 	'ZFRT082',	0.93
UNION ALL SELECT 	'ZFRT125',	0.93
UNION ALL SELECT 	'ZFRT128',	0.93
UNION ALL SELECT 	'ZFRT132',	0.93
UNION ALL SELECT 	'ZFRT133',	0.93
UNION ALL SELECT 	'Newfuture',	0.93
UNION ALL SELECT 	'ZhiFeng009',	0.93
UNION ALL SELECT 	'ZhiFeng021',	0.93
UNION ALL SELECT 	'ZhiFeng032',	0.93
UNION ALL SELECT 	'ZhiFeng035',	0.93
UNION ALL SELECT 	'ZhiFeng036',	0.93
UNION ALL SELECT 	'ZhiFeng037',	0.93
UNION ALL SELECT 	'ZhiFeng040',	0.93
UNION ALL SELECT 	'Zowin',	0.9
UNION ALL SELECT 	'zt828',	0.91
UNION ALL SELECT 	'M8Credit',	0.9
UNION ALL SELECT 	'Hong88',	0.9
UNION ALL SELECT 	'Calibet',	0.9
UNION ALL SELECT 	'Jumbo88',	0.9
UNION ALL SELECT 	'Jarvis',	0.9
UNION ALL SELECT 	'Taipanbet',	0.9
UNION ALL SELECT 	'Asian88',	0.9
UNION ALL SELECT 	'Betdeal',	0.92
UNION ALL SELECT 	'Dade',	0.92
UNION ALL SELECT 	'Jinyazhou',	0.9
UNION ALL SELECT 	'Titancraft',	0.9
UNION ALL SELECT 	'webet88',	0.9
UNION ALL SELECT 	'HAPPY8',	0.9
--UNION ALL SELECT 	'BSSB168',	0.93
--UNION ALL SELECT 	'TSEnter',	0.93

INSERT INTO #input_Super(custid, apositiontaking)
SELECT ci.custid, t.apositiontaking 	
FROM CUSTDB.dbo.Dep_custsuper cs WITH (NOLOCK) 	
	INNER JOIN CUSTDB.dbo.custinfo ci WITH(NOLOCK) ON cs.custid = ci.custid
	INNER JOIN #tmpSite t ON cs.site = t.site
WHERE ci.Enabled=1

INSERT INTO #input_BAMember (custid)
SELECT custid
FROM dbcust.custdb.dbo.Dep_CustBAActive WITH (NOLOCK)

SELECT custid, onDate
INTO #input_BAMember_History
FROM DBCUST.bodb_licensee.dbo.LicenseeBAHistory a WITH (NOLOCK)
WHERE Status= 'Running'

SELECT custid, ba_tmp.onDate
INTO #input_BAMember_Final
FROM #input_BAMember ba WITH (NOLOCK)
	CROSS APPLY (SELECT TOP 1 onDate 
				 FROM #input_BAMember_History ba_h 
				 WHERE ba.custid = ba_h.CustID
				 ORDER BY onDate DESC
				 ) AS ba_tmp

-------------------------- DATA PREPARATION  ------------------------
------ GET list of recommend to utilize index IX_recommend on bettrans
INSERT INTO #tmp_recommend (custid, apositiontaking)
SELECT ci.custid, s.apositiontaking
FROM CustDB.dbo.custInfo ci WITH (NOLOCK)
	INNER JOIN #input_Super s WITH (NOLOCK) ON s.custid = ci.srecommend
WHERE ci.roleid = 2
	
-------------------------------------------------------------
---- GET affected transid
--DECLARE @winlostdate DATETIME
--SET @winlostdate = '2021-04-01 00:00:00.000'

INSERT INTO #tickets_tmp(transid, Matchid,apositiontaking, IsBettrans, IsTranslog)
-- bettrans
SELECT b.transid, b.Matchid, r.apositiontaking, 1, 0
FROM #tmp_recommend r
	INNER JOIN bettrans b WITH (NOLOCK) ON r.custid = b.recommend
	INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid 
	LEFT JOIN #input_BAMember_Final ba ON ba.custid = b.custid AND ba.OnDate < b.transdate
WHERE m.sporttype < 99 AND eventstatus <> 'completed'
	AND b.statusID IN (0,1,102)
	AND b.apositiontaking  <> r.apositiontaking
	AND b.bettype < 19999
	AND b.bettype NOT IN (29)
	--AND b.winlostdate >= @winlostdate
	AND ba.custid IS NULL
	
UNION ALL
-- outright
SELECT b.transid, b.Matchid, r.apositiontaking, 1, 0
FROM #tmp_recommend r
	INNER JOIN bettrans b WITH (NOLOCK) ON r.custid = b.recommend
	LEFT JOIN #input_BAMember_Final ba ON ba.custid = b.custid AND ba.OnDate < b.transdate
WHERE  b.statusID IN (0,1,102)
	AND b.bettype = 10 -- outright
	AND b.apositiontaking  <> r.apositiontaking
	--AND b.winlostdate >= @winlostdate
	AND ba.custid IS NULL
	
UNION ALL
-- translog
SELECT b.translogid, b.eventID, r.apositiontaking,  0, 1
FROM #tmp_recommend r
	INNER JOIN translog b WITH (NOLOCK) ON r.custid = b.recommend
	LEFT JOIN #input_BAMember_Final ba ON ba.custid = b.custid AND ba.OnDate < b.transdate
WHERE b.gameID BETWEEN 801 AND 806
	AND b.statusID IN (0,1,102)
	AND b.apositiontaking  <> r.apositiontaking
	--AND b.winlostdate >= @winlostdate
	AND ba.custid IS NULL
	
-------------------- remove BA Transaction ---------------
SELECT TransID
INTO #BA_Transaction_tmp
FROM DBLIC.bodb_Licensee.dbo.LicenseeBATransaction_active WITH (NOLOCK)

DELETE t
FROM #tickets_tmp t
	INNER JOIN #BA_Transaction_tmp ba ON t.transid = ba.TransID

---- get list of matchid
INSERT INTO #Match_Final(Matchid)
SELECT matchid
FROM #tickets_tmp
GROUP BY matchid

----- BACKUP before update if need
INSERT INTO #Ticket_OldValue_BackupForCompare (transid,apositiontaking,tpositiontaking,apositiontaking_new)
SELECT t.transid
	, ISNULL(b.apositiontaking,tl.apositiontaking) apositiontaking
	, ISNULL(b.tpositiontaking,tl.tpositiontaking) tpositiontaking
	, t.apositiontaking as apositiontaking_new
FROM #tickets_tmp t
	LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid AND t.IsBettrans = 1
	LEFT JOIN dbo.translog tl WITH (NOLOCK) ON tl.translogid = t.transid AND t.IsTranslog = 1

------------ STARTING Update PT ----------------------------
DECLARE  @start INT  = 1
		, @end INT = 0
		, @matchid INT
		
SET @end = (SELECT MAX(ID) FROM #Match_Final)

-- Deployer Info
DECLARE @Match_cnt INT, @index INT = 0, @ticket_cnt INT
SET @Match_cnt = @end
DECLARE @msg nvarchar(200) = 'Currently at order %d, MatchID: %d, Ticket_cnt: %d'
DECLARE @msg_total nvarchar(200) = 'Total of Match: %d.'
RAISERROR (@msg_total, 0, 1, @Match_cnt) WITH NOWAIT
-- LOOP BY matchid
DECLARE @CorrectPT_Batch_tmp AS TABLE (transid BIGINT, apositiontaking smallmoney, IsBettrans BIT, IsTranslog BIT)

WHILE @start <= @end
BEGIN
	
	SET @ticket_cnt	= 0
	
	SET @matchid = (SELECT matchid FROM #Match_Final WHERE ID = @start)
	
	SET @ticket_cnt = (SELECT COUNT(1) 
						FROM #tickets_tmp 
						WHERE matchid = @matchid)
						
	SET @index = @index + 1
	RAISERROR (@msg, 0, 1, @index, @matchid,@ticket_cnt) WITH NOWAIT
	
	WHILE (1=1)
	BEGIN
		DELETE @CorrectPT_Batch_tmp
			
		UPDATE TOP(2000) t
			SET isFinish = 1
		OUTPUT DELETED.TransId,DELETED.apositiontaking ,DELETED.IsBettrans, DELETED.IsTranslog
		INTO @CorrectPT_Batch_tmp(TransId,apositiontaking,IsBettrans, IsTranslog)
		FROM #tickets_tmp t 
		WHERE isFinish IS NULL
			AND t.Matchid = @matchid
		
		IF @@ROWCOUNT = 0 BREAK
		
		/*
		-- FOR CHECKING
		SELECT b.matchid, b.apositiontaking, b.tpositiontaking, c.apositiontaking as apositiontaking_new
		FROM dbo.bettrans b WITH (nolock)
			INNER JOIN @CorrectPT_Batch_tmp c ON b.transid = c.transid
		WHERE b.statusID IN (0,1,102)
			AND b.matchid = @matchid
			AND c.IsBettrans = 1
		
		IF EXISTS (SELECT TOP 1 1 FROM @CorrectPT_Batch_tmp WHERE IsTranslog = 1)
		BEGIN
			SELECT tl.eventID, tl.apositiontaking, tl.tpositiontaking, c.apositiontaking as apositiontaking_new
			FROM dbo.translog tl WITH (NOLOCK)
				INNER JOIN @CorrectPT_Batch_tmp c ON tl.translogid = c.transid
			WHERE tl.statusID IN (0,1,102)
				AND c.IsTranslog = 1
		END		
		*/	
		
		UPDATE b
			SET apositiontaking = c.apositiontaking
				,tpositiontaking =  c.apositiontaking + b.mpositiontaking + b.spositiontaking
		FROM dbo.bettrans b WITH (ROWLOCK)
			INNER JOIN @CorrectPT_Batch_tmp c ON b.transid = c.transid
		WHERE b.statusID IN (0,1,102)
			AND c.IsBettrans = 1
		
		IF EXISTS (SELECT TOP (1) 1 FROM @CorrectPT_Batch_tmp WHERE IsTranslog = 1)
		BEGIN
			UPDATE tl
				SET apositiontaking = c.apositiontaking
				,tpositiontaking =  c.apositiontaking + tl.mpositiontaking + tl.spositiontaking
			FROM dbo.translog tl WITH (ROWLOCK)
				INNER JOIN @CorrectPT_Batch_tmp c ON tl.translogid = c.transid
			WHERE tl.statusID IN (0,1,102)
				AND c.IsTranslog = 1	
		END
	END
	
	SET @start = @start + 1
	
END

---Final Step: check data after update between bettrans, translog & #Ticket_OldValue_BackupForCompare 
/*
SELECT t.transid
	--bettrans
	, b.apositiontaking, b.tpositiontaking
	-- translog
	, tl.apositiontaking, tl.tpositiontaking
	, old.apositiontaking_new
	-- old data
	, old.apositiontaking, old.tpositiontaking
FROM #tickets_tmp t
	INNER JOIN #Ticket_OldValue_BackupForCompare old ON old.transid = t.transid
	LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = old.transid AND t.IsBettrans = 1
	LEFT JOIN dbo.translog tl WITH (NOLOCK) ON tl.translogid = old.transid AND t.IsTranslog = 1
where b.apositiontaking <> old.apositiontaking_new
*/	
-- drop temporay tables when everything is ok
DROP TABLE #Match_Final
DROP TABLE #input_Super
DROP TABLE #tickets_tmp
DROP TABLE #tmp_recommend
DROP TABLE #Ticket_OldValue_BackupForCompare	
DROP TABLE #input_BAMember
DROP TABLE #supers
DROP TABLE #tmpSite
DROP TABLE #BA_Transaction_tmp
DROP TABLE #input_BAMember_Final
DROP TABLE #input_BAMember_History


