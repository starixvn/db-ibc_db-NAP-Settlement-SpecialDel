/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_CheckData_Job]
	@StartTime DATETIME OUTPUT,
	@EndTime DATETIME OUTPUT,
	@ErrorMessage VARCHAR(MAX) OUTPUT
AS
/*	
	Created: 20211111@Tina
    Task: Support check data for Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20211111@Tina: create

	Param's explanation:		
		
*/
BEGIN

	SET NOCOUNT ON

	SET @ErrorMessage = ''

	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())

	CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT)

	INSERT INTO #RunningMatch(matchid, sporttype)
	SELECT m.matchid, m.sporttype
	FROM [match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND m.sporttype > 99 AND m.sporttype NOT IN (164,180,186,190,191,192,193,194,195,196,197)

	IF EXISTS (SELECT TOP 1 1
				FROM CustLimitBet_789 cb WITH (NOLOCK)
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = cb.custid AND ci.[Site] = '789y'
					INNER JOIN #RunningMatch m ON cb.matchid = m.matchid
				WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
	BEGIN
		SET @ErrorMessage = '1. 789y - Main table is inserted data for excluded sporttype' + CHAR(13) + CHAR(10)
	END

	IF EXISTS (SELECT TOP 1 1
				FROM CustLimitBet_MBC cb WITH (NOLOCK)
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = cb.custid AND ci.[Site] <> '789y'
					INNER JOIN #RunningMatch m ON cb.matchid = m.matchid
				WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
	BEGIN
		SET @ErrorMessage =  @ErrorMessage + '1. MBC - Main table is inserted data for excluded sporttype' + CHAR(13) + CHAR(10)
	END
	
	IF EXISTS (SELECT TOP 1 1
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] = '789y'
					INNER JOIN #RunningMatch m ON b.matchid = m.matchid 
				WHERE B.bettype NOT IN (10,29,2799,38,801,802,803,804,805,806) 
					AND NOT EXISTS(SELECT TOP 1 1 FROM CustLimitBetHistory_789 h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.transdate BETWEEN @StartTime AND @EndTime
					AND ci.currency NOT IN (20,72)
					AND b.statusID NOT IN (101, 0))
	BEGIN
		SET @ErrorMessage = @ErrorMessage + '2. 789y - History table is missing data which EventTypeID = 1'  + CHAR(13) + CHAR(10)
	END
	
	IF EXISTS(SELECT TOP 1 1
			FROM bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] <> '789y'
				INNER JOIN #RunningMatch m ON b.matchid = m.matchid
			WHERE B.bettype NOT IN (10,29,2799,38,801,802,803,804,805,806)
				AND NOT EXISTS (SELECT TOP 1 1 FROM CustLimitBetHistory_MBC bh WITH (NOLOCK) WHERE bh.Matchid = b.matchid AND bh.transid = b.transid AND bh.CustID = b.custid)
				AND b.transdate BETWEEN @StartTime AND @EndTime
				AND ci.currency NOT IN (20,72)
				AND b.statusID NOT IN (101, 0)
				AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend))
	BEGIN
		SET @ErrorMessage = @ErrorMessage + '2. MBC - History table is missing data which EventTypeID = 1'  + CHAR(13) + CHAR(10)
	END

	IF EXISTS (SELECT TOP 1 1
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN outright O WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] = '789y'
				WHERE B.bettype = 10
					AND NOT EXISTS (SELECT TOP 1 1 FROM CustLimitBetHistory_789 bh WITH (NOLOCK) WHERE bh.transid = b.transid AND bh.Matchid = b.matchid AND bh.CustID = b.custid)
					AND b.transdate BETWEEN @StartTime AND @EndTime
					AND ci.currency NOT IN (20,72))
	BEGIN
		SET @ErrorMessage = @ErrorMessage + '3. 789y - History table is missing data which EventTypeID = 2'  + CHAR(13) + CHAR(10)
	END

	IF EXISTS (SELECT TOP 1 1
				FROM bettrans b WITH (NOLOCK)
					INNER JOIN outright O WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] <> '789y'
				WHERE B.bettype = 10
					AND NOT EXISTS (SELECT TOP 1 1 FROM CustLimitBetHistory_MBC bh WITH (NOLOCK) WHERE bh.Matchid = b.matchid AND bh.transid = b.transid AND bh.CustID = b.custid)
					AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)
					AND b.transdate BETWEEN @StartTime AND @EndTime
					AND ci.currency NOT IN (20,72))
	BEGIN
		SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. MBC - History table is missing data which EventTypeID = 2'  + CHAR(13) + CHAR(10)
	END

	--------------------------------------------------Transids on table Queue----------------------------------------------------------
	CREATE TABLE #Queue_Reject (ID INT IDENTITY(1,1), QueueID BIGINT, MatchID INT, CustID INT, EventTypeID TINYINT, Transids XML, StatusID TINYINT, CreatedDate DATETIME)
	CREATE TABLE #RejectInfo (ID INT, QueueID BIGINT, MatchID INT, CustID INT, EventTypeID TINYINT, MinTransID BIGINT, MaxTransID BIGINT, RejectTime DATETIME, IsFinished INT DEFAULT 0)
	CREATE TABLE #RejectInfo_Batch (ID INT, QueueID BIGINT, MatchID INT, CustID INT, EventTypeID TINYINT, MinTransID BIGINT, MaxTransID BIGINT, RejectTime DATETIME)
	CREATE TABLE #queue_issue (QueueID BIGINT)

	INSERT INTO #Queue_Reject(QueueID, MatchID, CustID, EventTypeID, Transids, StatusID, CreatedDate)
	SELECT Q.QueueID, Q.MatchID, Q.CustID, Q.EventTypeID, Q.Transids, Q.StatusID, Q.CreatedDate
	FROM CustLimitBetQueue Q WITH (NOLOCK)
	WHERE Q.ActionID = 2
		AND Q.CreatedDate BETWEEN @StartTime AND @EndTime

	TRUNCATE TABLE #RejectInfo
	DECLARE @start INT = 1, @CountQueue INT 

	SELECT @CountQueue = MAX(ID) FROM #Queue_Reject

	WHILE (@start < @CountQueue)
	BEGIN
		;WITH RejectQ AS
		(SELECT   R.c.value('@mintransid','bigint') MinTransID
				,R.c.value('@maxtransid','bigint') MaxTransID
				,R.c.value('@rejecttime','datetime') RejectTime
				,Q.MatchID
				,Q.QueueID
				,Q.CustID
				,Q.EventTypeID
				,Q.ID
		FROM #Queue_Reject Q
			CROSS APPLY Transids.nodes('root/rejectTicket') AS R(c)
		WHERE Q.ID between @start AND @start + 1000 
		)
		INSERT INTO #RejectInfo(ID, QueueID, MatchID, CustID, EventTypeID, MinTransID, MaxTransID, RejectTime)
		SELECT r.ID, r.QueueID, r.MatchID, r.CustID, r.EventTypeID, r.MinTransID, r.MaxTransID, r.RejectTime
		FROM RejectQ r
		;

		DECLARE @queueid_min BIGINT = 0, @queueid_max BIGINT = 0, @Index INT = 0
		SELECT @queueid_min = MIN(ID), @queueid_max = MAX(ID) FROM #RejectInfo

		WHILE(1=1)
		BEGIN
			TRUNCATE TABLE #RejectInfo_Batch
			TRUNCATE TABLE #queue_issue

			UPDATE TOP (100) #RejectInfo
			SET IsFinished = 1
			OUTPUT DELETED.ID, DELETED.QueueID, DELETED.MatchID, DELETED.CustID, DELETED.EventTypeID, DELETED.MinTransID, DELETED.MaxTransID, DELETED.RejectTime
			INTO #RejectInfo_Batch (ID, QueueID, MatchID, CustID, EventTypeID, MinTransID, MaxTransID, RejectTime)
			WHERE IsFinished = 0 AND ID >= @queueid_min AND ID < (@queueid_min + 100)

			IF @@ROWCOUNT = 0 BREAK;

			INSERT INTO #queue_issue (queueid)
			SELECT r.QueueID
			FROM #RejectInfo_Batch r
				CROSS APPLY (SELECT TOP 1 matchid
							FROM bettrans b WITH (NOLOCK) 
							WHERE b.matchid = r.matchid
								AND b.transid BETWEEN r.MinTransID AND r.MaxTransID AND b.statusID = 101 AND b.checktime = r.RejectTime
							) AS t
	
			IF (@@ROWCOUNT < 100 ) AND (@@ROWCOUNT < @queueid_max - @queueid_min)
			BEGIN
				--SELECT @queueid_min MinID, @queueid_max MaxID, @Index [Index], @@ROWCOUNT [RowCount], 'No ticket found on Queue'
				SELECT @ErrorMessage = @ErrorMessage +  'No ticket found on Queue ['+CAST(@queueid_min AS VARCHAR(128))+','+CAST(@queueid_max AS VARCHAR(128))+']'  + CHAR(13) + CHAR(10)
				BREAK
			END	

			SELECT @queueid_min = @queueid_min + 100
				  , @Index = @Index + 1
		END

		SET @start = @start + 1000
	END

	---------------------------------------------------Check sum--------------------------------------------------
	CREATE TABLE #CustLimitBet_MBC (MatchID INT, CustID INT, AccumTurnover MONEY, AccumPayout MONEY, EventTypeID TINYINT)

	--MBC
	INSERT INTO #CustLimitBet_MBC(MatchID, CustID, AccumTurnover, AccumPayout, EventTypeID)
	SELECT MatchID, CustID, AccumTurnover, AccumPayout, EventTypeID
	FROM CustLimitBet_MBC lb WITH (NOLOCK)
	WHERE lb.ModifiedDate BETWEEN @StartTime AND @EndTime
		AND NOT EXISTS (SELECT 1 FROM CustLimitBetQueue Q WITH (NOLOCK) WHERE lb.Matchid = Q.Matchid AND Q.ActionID = 2)
		AND lb.MatchID <> 29

	--SELECT TOP 1 hs.MatchID, hs.CustID, SUM(hs.TurnoverAdjust) SumTurnover, lb.AccumTurnover, SUM(hs.PayoutAdjust) SumPayout, lb.AccumPayout, hs.EventTypeID
	IF EXISTS (SELECT TOP 1 1
				FROM CustLimitBetHistory_MBC hs WITH (NOLOCK)
					INNER JOIN #CustLimitBet_MBC lb ON lb.MatchID = hs.Matchid AND lb.CustID = hs.CustID AND lb.EventTypeID = hs.EventTypeID 
				GROUP BY hs.Matchid, hs.CustID, hs.EventTypeID, lb.AccumPayout, lb.AccumTurnover
				HAVING SUM(hs.TurnoverAdjust) <> lb.AccumTurnover OR SUM(hs.PayoutAdjust) <> lb.AccumPayout)
	BEGIN
		SET @ErrorMessage = @ErrorMessage +  'MBC: Sum on history not equal with main table'  + CHAR(13) + CHAR(10)
	END

	 --789y
	CREATE TABLE #CustLimitBet_789 (MatchID INT, CustID INT, AccumTurnover MONEY, AccumPayout MONEY, EventTypeID TINYINT)

	INSERT INTO #CustLimitBet_789(MatchID, CustID, AccumTurnover, AccumPayout, EventTypeID)
	SELECT MatchID, CustID, AccumTurnover, AccumPayout, EventTypeID
	FROM CustLimitBet_789 lb WITH (NOLOCK)
	WHERE lb.ModifiedDate BETWEEN @StartTime AND @EndTime
		AND NOT EXISTS (SELECT 1 FROM CustLimitBetQueue Q WITH (NOLOCK) WHERE lb.Matchid = Q.Matchid AND Q.ActionID = 2)
		AND lb.MatchID <> 29

	--SELECT TOP 1 hs.MatchID, hs.CustID, SUM(hs.TurnoverAdjust) SumTurnover, lb.AccumTurnover, SUM(hs.PayoutAdjust) SumPayout, lb.AccumPayout, hs.EventTypeID
	IF EXISTS (SELECT TOP 1 1
				FROM CustLimitBetHistory_789 hs WITH (NOLOCK)
					INNER JOIN #CustLimitBet_789 lb ON lb.MatchID = hs.Matchid AND lb.CustID = hs.CustID AND lb.EventTypeID = hs.EventTypeID 
				GROUP BY hs.Matchid, hs.CustID, hs.EventTypeID, lb.AccumPayout, lb.AccumTurnover
				HAVING SUM(hs.TurnoverAdjust) <> lb.AccumTurnover OR SUM(hs.PayoutAdjust) <> lb.AccumPayout)
	BEGIN
		SET @ErrorMessage = @ErrorMessage +  '789y: Sum on history not equal with main table'  + CHAR(13) + CHAR(10)
	END

	

	-------------------------------------------------------
	--check duplicate data in queue table for reject action

	--SELECT TOP 1 COUNT(1), q.ActionID, q.CustID, q.Matchid, q.EventTypeID, min(q.CreatedDate) MinDate , max (CreatedDate) MaxDate, q.Transids
	IF EXISTS (SELECT TOP 1 1
				FROM CustLimitBetQueue Q with (nolock)
				WHERE q.ActionID = 2
					AND q.CreatedDate BETWEEN @StartTime AND @EndTime
				GROUP BY q.ActionID, q.CustID, q.Matchid, q.Transids, q.EventTypeID
				HAVING count(1) > 1
				ORDER BY q.Matchid)
	BEGIN
		SELECT TOP 1 @ErrorMessage = @ErrorMessage +  'Duplicate data in Queue table.' + CHAR(13) + CHAR(10)
	END

	-------------------------------------------------------------

	CREATE TABLE #TempReject (transid BIGINT, checktime DATETIME, matchid int, custid INT, sporttype int)

	INSERT INTO #TempReject (transid, checktime, matchid, custid, sporttype)
	SELECT b.transid, b.checktime, b.matchid, b.custid, m.sporttype
	FROM bettrans b WITH (NOLOCK)        
			INNER JOIN #RunningMatch m ON b.matchid = m.matchid 
	WHERE b.statusID = 101
			AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)
			AND b.transdate BETWEEN @StartTime AND @EndTime


	IF EXISTS (SELECT TOP 1 1
	FROM #TempReject T
	WHERE NOT EXISTS (SELECT *
	FROM CustLimitBetQueue Q with (nolock)
	WHERE q.Matchid = T.matchid AND Q.ActionID = 2 AND Q.Transids like '%'+CONVERT(varchar, checktime, 120)+'%'))
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Reject tickets are missing on CustLimitBetQueue table.' + CHAR(13) + CHAR(10)
	END

	IF (@ErrorMessage <> '')
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'SP: Nap_Admin_CustLimitBet_CheckData_Job'
	END

	--SELECT CASE WHEN @ErrorMessage = '' THEN 'NO Error' ELSE @ErrorMessage END ErrorMessage, @StartTime StartTime, @EndTime EndTime

	DROP TABLE #TempReject
	DROP TABLE #RunningMatch
	DROP TABLE #Queue_Reject
	DROP TABLE #RejectInfo
	DROP TABLE #RejectInfo_Batch
	DROP TABLE #queue_issue
	DROP TABLE #CustLimitBet_789
	DROP TABLE #CustLimitBet_MBC
	
END