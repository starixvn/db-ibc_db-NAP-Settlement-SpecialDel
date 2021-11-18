/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Delete]
AS
/*	
	Created: 20210914@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20211001@Tina: Add  more filter oddsstatus for Outright and tuning performance - [Redmine: #158073]
		- 20211007@Tina: fixed locking issue - [Redmine: #158073]
		- 20211012@Max: Delete bonus for CustLimitBetQueue - [Redmine: #158073]
		- 20211112@Max: MPO Phase 2 - Clean up data for Parlay [Redmine: #159626]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Matchid INT, @eventtypeID TINYINT

	CREATE TABLE #match_tmp (ID INT IDENTITY(1,1),MatchId INT, EventTypeID TINYINT)
	CREATE TABLE #match_archive (MatchId INT,  EventTypeID TINYINT)
	CREATE TABLE #tmp_QueueID (QueueID BIGINT PRIMARY KEY)

	------------declare temporary table for phase 2 ---------------
	CREATE TABLE #tmp_TransId_pre_mbc (Transid BIGINT PRIMARY KEY, custid INT)
	CREATE TABLE #tmp_TransId_Parlay_mbc (CustId INT, TransId BIGINT)
	CREATE TABLE #tmp_TransId_pre_789 (Transid BIGINT PRIMARY KEY, custid INT)
	CREATE TABLE #tmp_TransId_Parlay_789 (CustId INT, TransId BIGINT)
	CREATE TABLE #tmp_TransId_Parlay_batch (CustId INT, TransId BIGINT)
	
	DECLARE @tmp_batch AS TABLE (QueueID BIGINT PRIMARY KEY)

	DECLARE @Archive_Date DATETIME
	SELECT @Archive_Date = DATEADD(DAY, -6, GETDATE())

	DECLARE @start INT = 1, @end INT

	--Get event
	INSERT INTO #match_archive(MatchId, EventTypeID)
	SELECT m.matchid, 1 EventTypeID
	FROM dbo.match m WITH (NOLOCK)
	WHERE m.eventdate <= @Archive_Date
		AND (m.sporttype <= 99 OR (m.sporttype IN (164,180,186,190,191,192,193,194,195,196,197))) --get support Sports

	UNION ALL
	SELECT m14.matchid, 1 EventTypeID
	FROM dbo.match14 m14 WITH (NOLOCK)
	WHERE m14.eventdate <= @Archive_Date
		AND (m14.sporttype <= 99 OR (m14.sporttype IN (164,180,186,190,191,192,193,194,195,196,197))) --get support Sports

	UNION ALL
	SELECT o.orid MatchId, 2 EventTypeID
	FROM dbo.outright o WITH (NOLOCK)
	WHERE o.eventdate <= @Archive_Date AND o.oddsstatus = 'Completed'

	UNION ALL
	SELECT o14.orid MatchId, 2 EventTypeID
	FROM dbo.outright14 o14 WITH (NOLOCK)
	WHERE o14.eventdate <= @Archive_Date

	--Get clean up data
	INSERT INTO #match_tmp (MatchId, EventTypeID)
	SELECT DISTINCT mc.Matchid, mc.EventTypeID
	FROM dbo.CustLimitBet_MBC mc WITH (NOLOCK)
		INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND (m.EventTypeID = mc.EventTypeID OR mc.EventTypeID = 5)
	UNION 
	SELECT DISTINCT mc.Matchid, mc.EventTypeID
	FROM dbo.CustLimitBet_789 mc WITH (NOLOCK)
		INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND (m.EventTypeID = mc.EventTypeID OR mc.EventTypeID = 5)

	SET @end = (SELECT MAX(ID) FROM #match_tmp)
	--Delete data
	WHILE (@start <= @end)
	BEGIN
		
		SELECT @Matchid = matchid, @eventtypeID = eventtypeID
		FROM #match_tmp
		WHERE ID = @start

		--CustLimitBet_MBC
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) mbc
			FROM dbo.CustLimitBet_MBC mbc
			WHERE matchid = @Matchid and eventtypeid = @eventtypeID
			
			IF @@ROWCOUNT = 0 BREAK
		END	

		--CustLimitBet_789
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) m789
			FROM dbo.CustLimitBet_789 m789 
			WHERE matchid = @Matchid and eventtypeid = @eventtypeID
			
			IF @@ROWCOUNT = 0 BREAK
		END
		
		--CustLimitBetHistory_MBC
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) mbc
			FROM dbo.CustLimitBetHistory_MBC mbc 
			WHERE matchid = @Matchid and eventtypeid = @eventtypeID
			
			IF @@ROWCOUNT = 0 BREAK

			WAITFOR DELAY '00:00:00.020'
		END

		--CustLimitBetHistory_789
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) m789
			FROM dbo.CustLimitBetHistory_789 m789
			WHERE matchid = @Matchid and eventtypeid = @eventtypeID

			IF @@ROWCOUNT = 0 BREAK

			WAITFOR DELAY '00:00:00.020'
		END

		--CustLimitBetQueue
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) q
			FROM dbo.CustLimitBetQueue q
			WHERE matchid = @Matchid and eventtypeid = @eventtypeID
			
			IF @@ROWCOUNT = 0 BREAK
		END
	
		SET @start = @start + 1
	END

	--Get bonus delete data for CustLimitBetQueue
	INSERT INTO #tmp_QueueID (QueueID)
	SELECT q.QueueID
	FROM dbo.CustLimitBetQueue q WITH (NOLOCK)
	WHERE 1= CASE WHEN q.Statusid = 1 AND q.ErrMsg <> '' AND q.ExecTime <= @Archive_Date THEN 1
				WHEN q.Matchid = 29 AND DATEDIFF(DAY, q.CreatedDate, GETDATE()) >= 10 THEN 1 --Phase 2 delete for Parlay
			ELSE 0 END

	--delete bonus data CustLimitBetQueue
	IF EXISTS (SELECT TOP(1) 1 FROM #tmp_QueueID)
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE @tmp_batch

			DELETE TOP(1000) t OUTPUT DELETED.QueueID INTO @tmp_batch (QueueID)
			FROM #tmp_QueueID t

			IF @@ROWCOUNT = 0 
				BREAK

			DELETE q
			FROM dbo.CustLimitBetQueue q
				INNER JOIN @tmp_batch t ON t.QueueID = q.QueueID
		END
	END

	--Phase 2 - Clean up data for parlay - Only table CustLimitBetHistory_XXX
	---MBC
	INSERT INTO #tmp_TransId_pre_mbc (Transid,custid)
	SELECT transid, custid
	FROM dbo.CustLimitBetHistory_MBC m1 WITH (NOLOCK)
	WHERE m1.Matchid = 29
	GROUP BY matchid,transid,custid

	INSERT INTO #tmp_TransId_Parlay_mbc (CustId, TransId)
	SELECT t.custid, t.transid
	FROM #tmp_TransId_pre_mbc t
		LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON t.Transid = b.transid
	WHERE b.transid IS NULL

	--789
	INSERT INTO #tmp_TransId_pre_789 (Transid,custid)
	SELECT transid,custid
	FROM dbo.CustLimitBetHistory_789  m2 WITH (NOLOCK)
	WHERE m2.Matchid = 29
	GROUP BY matchid,transid,custid

	INSERT INTO #tmp_TransId_Parlay_789 (CustId, TransId)
	SELECT t.custid, t.transid
	FROM #tmp_TransId_pre_789 t
		LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON t.Transid = b.transid
	WHERE b.transid IS NULL

	--Delete Data
	---------mbc-----------
	WHILE (1 = 1)
	BEGIN
  
		DELETE TOP (1000) r 
		OUTPUT DELETED.custid,DELETED.TransId
		INTO #tmp_TransId_Parlay_batch (custid, TransId)    
		FROM #tmp_TransId_Parlay_mbc r 
  
		IF @@ROWCOUNT = 0
		BREAK
  
		DELETE t
		FROM dbo.CustLimitBetHistory_MBC t 
			INNER JOIN #tmp_TransId_Parlay_batch b ON t.CustID = b.CustId and t.Transid = b.TransId
		WHERE t.matchid = 29 

		TRUNCATE TABLE #tmp_TransId_Parlay_batch

		WAITFOR DELAY '00:00:00.020'
    
	END
	----------789-----------
	TRUNCATE TABLE #tmp_TransId_Parlay_batch

	WHILE (1 = 1)
	BEGIN
  
		DELETE TOP (1000) r 
		OUTPUT DELETED.custid,DELETED.TransId
		INTO #tmp_TransId_Parlay_batch (custid, TransId)    
		FROM #tmp_TransId_Parlay_789 r 
  
		IF @@ROWCOUNT = 0
		BREAK
  
		DELETE t
		FROM dbo.CustLimitBetHistory_789 t 
			INNER JOIN #tmp_TransId_Parlay_batch b ON t.CustID = b.CustId and t.Transid = b.TransId
		WHERE t.matchid = 29 

		TRUNCATE TABLE #tmp_TransId_Parlay_batch

		WAITFOR DELAY '00:00:00.020'
    
	END

	DROP TABLE #match_tmp 
	DROP TABLE #match_archive 
	DROP TABLE #tmp_QueueID
	DROP TABLE #tmp_TransId_Parlay_789
	DROP TABLE #tmp_TransId_Parlay_batch
	DROP TABLE #tmp_TransId_Parlay_mbc
	DROP TABLE #tmp_TransId_pre_789
	DROP TABLE #tmp_TransId_pre_mbc
END
GO
	
