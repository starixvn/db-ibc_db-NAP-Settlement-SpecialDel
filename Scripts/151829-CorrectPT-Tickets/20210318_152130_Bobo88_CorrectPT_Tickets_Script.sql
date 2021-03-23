/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: Helen
	Date 20210323
	Task: Adjust Sportsbook PT for all licensees - Update tickets - [Redmine:152130]
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
SELECT 	'Bobo88', 0.915

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
DECLARE @winlostdate DATETIME
SET @winlostdate = '2021-04-01 00:00:00.000'

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
	AND b.winlostdate >= @winlostdate
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
	AND b.winlostdate >= @winlostdate
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
	AND b.winlostdate >= @winlostdate
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


