/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: Helen
	Date 20200317
	Task: Remove Sportsbook Comm from 611111 Site - [Redmine:140856]
	DB: DBTXN/bodb02
	
*/
USE bodb02
GO
--- define temporary tables 

CREATE TABLE #tmp_recommend (custid INT)
CREATE TABLE #Match_Final (Matchid INT, ID INT IDENTITY(1,1))
CREATE TABLE #tickets_tmp (transid BIGINT, matchid INT, IsBettrans BIT, IsTranslog BIT,IsFinish BIT)

CREATE TABLE #Ticket_OldValue_BackupForCompare ( transid BIGINT
												, [playerdiscount] [decimal](9, 8) NULL
												, [discount] [decimal](9, 8) NULL
												, [adiscount] [decimal](9, 8) NULL
												, [sdiscount] [decimal](9, 8) NULL
												)

-------------------------- DATA PREPARATION  ------------------------
------ GET list of recommend to utilize index IX_recommend on bettrans

INSERT INTO #tmp_recommend (custid)
SELECT custid
FROM CUSTDB.dbo.customer WITH(NOLOCK)
WHERE roleid = 2
	AND currency IN (2,5,13)	--	RM,HK$,RMB
	AND site IN ('611111')
	
---- GET affected transid
DECLARE @winlostdate DATETIME 
SET @winlostdate = '2020-09-14 00:00:00'	
INSERT INTO #tickets_tmp(transid, Matchid, IsBettrans, IsTranslog)
-- bettrans
SELECT b.transid, b.Matchid, 1, 0
FROM #tmp_recommend r
	INNER JOIN bettrans b WITH (NOLOCK) ON r.custid = b.recommend
	INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid 
WHERE m.sporttype <= 99 AND eventstatus <> 'completed'
	AND b.statusID IN (0,1,102)
	AND b.playerdiscount + b.discount + b.adiscount + b.sdiscount  > 0
	AND b.bettype < 19999
	AND b.bettype NOT IN (29,10)
	AND b.winlostdate >= @winlostdate
	
UNION ALL
-- outright
SELECT b.transid, b.Matchid, 1, 0
FROM #tmp_recommend r
	INNER JOIN bettrans b WITH (NOLOCK) ON r.custid = b.recommend
WHERE  b.statusID IN (0,1,102)
	AND b.playerdiscount + b.discount + b.adiscount + b.sdiscount  > 0
	AND b.bettype = 10 -- outright
	AND b.winlostdate >= @winlostdate
	
UNION ALL
-- translog
SELECT b.translogid, b.eventID,  0, 1
FROM #tmp_recommend r
	INNER JOIN translog b WITH (NOLOCK) ON r.custid = b.recommend
WHERE b.gameID BETWEEN 801 AND 806
	AND b.statusID IN (0,1,102)
	AND b.playerdiscount + b.discount + b.adiscount + b.sdiscount  > 0
	AND b.winlostdate >= @winlostdate
	
---- get list of matchid
INSERT INTO #Match_Final(Matchid)
SELECT matchid
FROM #tickets_tmp
GROUP BY matchid

----- BACKUP before update if need
INSERT INTO #Ticket_OldValue_BackupForCompare (transid,playerdiscount,adiscount,discount,sdiscount)
SELECT t.transid
	, ISNULL(b.playerdiscount,tl.playerdiscount) playerdiscount
	, ISNULL(b.adiscount,tl.adiscount) adiscount
	, ISNULL(b.discount,tl.discount) discount
	, ISNULL(b.sdiscount,tl.sdiscount) AS sdiscount
FROM #tickets_tmp t
	LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid AND t.IsBettrans = 1
	LEFT JOIN dbo.translog tl WITH (NOLOCK) ON tl.translogid = t.transid AND t.IsTranslog = 1

------------ STARTING clear comm ----------------------------
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
DECLARE @ClearcommByBatch_tmp AS TABLE (transid BIGINT, IsBettrans BIT, IsTranslog BIT)
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
		DELETE @ClearcommByBatch_tmp
			
		UPDATE TOP(2000) t
			SET isFinish = 1
		OUTPUT DELETED.TransId, DELETED.IsBettrans, DELETED.IsTranslog
		INTO @ClearcommByBatch_tmp(TransId, IsBettrans, IsTranslog)
		FROM #tickets_tmp t 
		WHERE isFinish IS NULL
			AND t.Matchid = @matchid
		
		IF @@ROWCOUNT = 0 BREAK
		
		-- update bettrans
		UPDATE b
			SET playerdiscount = 0
				, discount = 0
				, adiscount = 0
				, sdiscount = 0
		FROM dbo.bettrans b WITH (ROWLOCK)
			INNER JOIN @ClearcommByBatch_tmp c ON b.transid = c.transid
		WHERE b.statusID IN (0,1,102)
			AND c.IsBettrans = 1
		
		-- update translog 
		IF EXISTS (SELECT TOP (1) 1 FROM @ClearcommByBatch_tmp WHERE IsTranslog = 1)
		BEGIN
			UPDATE tl
				SET playerdiscount = 0
					, discount = 0
					, adiscount = 0
					, sdiscount = 0
			FROM dbo.translog tl WITH (ROWLOCK)
				INNER JOIN @ClearcommByBatch_tmp c ON tl.translogid = c.transid
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
	, b.playerdiscount, b.discount, b.adiscount, b.sdiscount
	-- translog
	, tl.playerdiscount, tl.discount, tl.adiscount, tl.sdiscount
	-- old data
	, old.playerdiscount, old.discount, old.adiscount, old.sdiscount
FROM #tickets_tmp t
	INNER JOIN #Ticket_OldValue_BackupForCompare old ON old.transid = t.transid
	LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = old.transid AND t.IsBettrans = 1
	LEFT JOIN dbo.translog tl WITH (NOLOCK) ON tl.translogid = old.transid AND t.IsTranslog = 1

-- drop temporay tables when everything is ok
DROP TABLE #Match_Final
DROP TABLE #tblSMA
DROP TABLE #tickets_tmp
DROP TABLE #tmp_recommend
DROP TABLE #Ticket_OldValue_BackupForCompare	
	
*/

