/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
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
		- 20220317@Max: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
		- 20220419@Max: Max Payout - Retry for Reject Action [Redmine: #171674]
		- 20230223@Max: Max Payout - AccumTurnover / AccumPayout is Negative because of some reasons [Redmine: #183935]
		- 20230228@Max: Include LIC into SiteDBGroupID = 0 because 12Bet [Redmine: #183935]
		- 20230712@Max: Scale out credit [Redmine: #181595]
		- 20230905@Louisa: Support Max Payout for VS3 [Redmine:#193562]
		- 20240808@Max: Max Payout - Integrate Virtually Sports (VS5) [Redmine: #209070]
		- 20240923@Max: Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine: #211145]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Matchid INT, @eventtypeID TINYINT, @QueueId BIGINT, @movebetdate DATETIME, @SiteDBGroupID	SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #match_tmp (ID INT IDENTITY(1,1),MatchId INT, EventTypeID TINYINT)
	CREATE TABLE #match_archive (MatchId INT,  EventTypeID TINYINT)
	CREATE TABLE #tmp_QueueID (QueueID BIGINT PRIMARY KEY)
	CREATE TABLE #tmp_QueueRetry (ID INT IDENTITY(1,1), QueueId BIGINT)

	------------declare temporary table for phase 2 ---------------
	CREATE TABLE #tmp_TransId_pre_mbc (Transid BIGINT PRIMARY KEY, custid INT)
	CREATE TABLE #tmp_TransId_Parlay_mbc (CustId INT, TransId BIGINT)
	CREATE TABLE #tmp_TransId_pre_789 (Transid BIGINT PRIMARY KEY, custid INT)
	CREATE TABLE #tmp_TransId_Parlay_789 (CustId INT, TransId BIGINT)
	CREATE TABLE #tmp_TransId_Parlay_batch (CustId INT, TransId BIGINT)
	CREATE TABLE #tmp_TransId_pre_LIC (Transid BIGINT PRIMARY KEY, custid INT)
	CREATE TABLE #tmp_TransId_Parlay_LIC (CustId INT, TransId BIGINT)
	
	DECLARE @tmp_batch AS TABLE (QueueID BIGINT PRIMARY KEY)

	DECLARE @Archive_Date DATETIME, @Archive_Date_Parlay DATETIME
	SELECT @Archive_Date = DATEADD(DAY, -6, GETDATE())

	DECLARE @start INT = 1, @end INT

	--Get event
	INSERT INTO #match_archive(MatchId, EventTypeID)
	SELECT m.matchid, 1 EventTypeID
	FROM dbo.match m WITH (NOLOCK)
	WHERE m.eventdate <= @Archive_Date
		AND (m.sporttype <= 99 OR (m.sporttype IN (164,178,179,180,186,190,191,192,193,194,195,196,197))) --get support Sports

	UNION ALL
	SELECT m14.matchid, 1 EventTypeID
	FROM dbo.match14 m14 WITH (NOLOCK)
	WHERE m14.eventdate <= @Archive_Date
		AND (m14.sporttype <= 99 OR (m14.sporttype IN (164,178,179,180,186,190,191,192,193,194,195,196,197))) --get support Sports

	UNION ALL
	SELECT o.orid MatchId, 2 EventTypeID
	FROM dbo.outright o WITH (NOLOCK)
	WHERE o.eventdate <= @Archive_Date AND o.oddsstatus = 'Completed'

	UNION ALL
	SELECT o14.orid MatchId, 2 EventTypeID
	FROM dbo.outright14 o14 WITH (NOLOCK)
	WHERE o14.eventdate <= @Archive_Date

	UNION ALL
	SELECT m.Match3rdId, 1 EventTypeID
	FROM dbo.Match3rd m WITH (NOLOCK)
	WHERE m.eventdate <= @Archive_Date
		AND m.SportType IN (147)
	UNION ALL
	SELECT m14.Match3rdId, 1 EventTypeID
	FROM dbo.Match3rd14 m14 WITH (NOLOCK)
	WHERE m14.eventdate <= @Archive_Date
		AND m14.SportType IN (147)

	UNION ALL
	SELECT m.EventID, 6 EventTypeID
	FROM dbo.VSRaceInfo m WITH (NOLOCK)
	WHERE m.EventTime <= @Archive_Date
		AND m.SportType IN (177,198)
	UNION ALL
	SELECT m14.EventID, 6 EventTypeID
	FROM dbo.VSRaceInfo14 m14 WITH (NOLOCK)
	WHERE m14.EventTime <= @Archive_Date
		AND m14.SportType IN (177,198)

	--Get clean up data
	IF @SiteDBGroupID IN (0,3)
	BEGIN
		INSERT INTO #match_tmp (MatchId, EventTypeID)
		SELECT DISTINCT mc.Matchid, mc.EventTypeID
		FROM dbo.CustLimitBet_MBC mc WITH (NOLOCK)
			INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND (m.EventTypeID = mc.EventTypeID OR mc.EventTypeID = 5)
		UNION 
		SELECT DISTINCT mc.Matchid, mc.EventTypeID
		FROM dbo.CustLimitBet_789 mc WITH (NOLOCK)
			INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND (m.EventTypeID = mc.EventTypeID OR mc.EventTypeID = 5)
	END
	IF @SiteDBGroupID IN (0,1,2)
	BEGIN
		INSERT INTO #match_tmp (MatchId, EventTypeID)
		SELECT DISTINCT mc.Matchid, mc.EventTypeID
		FROM dbo.CustLimitBet_LIC mc WITH (NOLOCK)
			INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND (m.EventTypeID = mc.EventTypeID OR mc.EventTypeID = 5)
	END

	SET @end = (SELECT MAX(ID) FROM #match_tmp)
	--Delete data
	WHILE (@start <= @end)
	BEGIN
		
		SELECT @Matchid = matchid, @eventtypeID = eventtypeID
		FROM #match_tmp
		WHERE ID = @start

		
		--CustLimitBet_MBC
		IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE TOP(1000) mbc
				FROM dbo.CustLimitBet_MBC mbc
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
		END

		--CustLimitBet_789
		IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE TOP(1000) m789
				FROM dbo.CustLimitBet_789 m789 
				WHERE matchid = @Matchid and eventtypeid = @eventtypeID
			
				IF @@ROWCOUNT = 0 BREAK
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
		END

		--CustLimitBet_LIC
		IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE TOP(1000) lic
				FROM dbo.CustLimitBet_LIC lic
				WHERE matchid = @Matchid and eventtypeid = @eventtypeID
			
				IF @@ROWCOUNT = 0 BREAK
			END	

			--CustLimitBetHistory_LIC
			WHILE (1=1)
			BEGIN
				DELETE TOP(1000) lic
				FROM dbo.CustLimitBetHistory_LIC lic
				WHERE matchid = @Matchid and eventtypeid = @eventtypeID

				IF @@ROWCOUNT = 0 BREAK

				WAITFOR DELAY '00:00:00.020'
			END
		END
		
		--CustLimitBetQueue
		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) q
				OUTPUT DELETED.QueueID INTO #tmp_QueueRetry (QueueId)
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
	WHERE 1= CASE WHEN q.Matchid <> 29 AND q.EventTypeID IS NULL AND q.ExecTime <= @Archive_Date THEN 1
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

			INSERT INTO #tmp_QueueRetry (QueueId)
			SELECT QueueID FROM @tmp_batch

			DELETE q
			FROM dbo.CustLimitBetQueue q
				INNER JOIN @tmp_batch t ON t.QueueID = q.QueueID
		END
	END

	--Phase 2 - Clean up data for parlay - Only table CustLimitBetHistory_XXX
	--Get Movebetdate
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @movebetdate OUTPUT
	SET @Archive_Date_Parlay = DATEADD(DAY, -3, @movebetdate) 

	---MBC
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		INSERT INTO #tmp_TransId_pre_mbc (Transid,custid)
		SELECT transid, custid
		FROM dbo.CustLimitBetHistory_MBC m1 WITH (NOLOCK)
		WHERE m1.Matchid = 29
		GROUP BY matchid,transid,custid

		INSERT INTO #tmp_TransId_Parlay_mbc (CustId, TransId)
		SELECT t.custid, t.transid
		FROM #tmp_TransId_pre_mbc t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON t.Transid = b.transid
		WHERE b.winlostdate <= @Archive_Date_Parlay

		IF EXISTS (SELECT TOP 1 1 FROM #tmp_TransId_Parlay_mbc)
		BEGIN
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
		END
	END

	--789
	IF OBJECT_ID('CustLimitBetHistory_789', 'U') IS NOT NULL
	BEGIN
		INSERT INTO #tmp_TransId_pre_789 (Transid,custid)
		SELECT transid,custid
		FROM dbo.CustLimitBetHistory_789  m2 WITH (NOLOCK)
		WHERE m2.Matchid = 29
		GROUP BY matchid,transid,custid

		INSERT INTO #tmp_TransId_Parlay_789 (CustId, TransId)
		SELECT t.custid, t.transid
		FROM #tmp_TransId_pre_789 t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON t.Transid = b.transid
		WHERE b.winlostdate <= @Archive_Date_Parlay

		IF EXISTS (SELECT TOP 1 1 FROM #tmp_TransId_Parlay_789)
		BEGIN
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
		END
	END

	--LIC
	IF OBJECT_ID('CustLimitBetHistory_LIC', 'U') IS NOT NULL
	BEGIN
		INSERT INTO #tmp_TransId_pre_LIC (Transid,custid)
		SELECT transid,custid
		FROM dbo.CustLimitBetHistory_LIC  m2 WITH (NOLOCK)
		WHERE m2.Matchid = 29
		GROUP BY matchid,transid,custid

		INSERT INTO #tmp_TransId_Parlay_LIC (CustId, TransId)
		SELECT t.custid, t.transid
		FROM #tmp_TransId_pre_LIC t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON t.Transid = b.transid
		WHERE b.winlostdate <= @Archive_Date_Parlay

		IF EXISTS (SELECT TOP 1 1 FROM #tmp_TransId_Parlay_LIC)
		BEGIN
			----------LIC-----------
			TRUNCATE TABLE #tmp_TransId_Parlay_batch

			WHILE (1 = 1)
			BEGIN
  
				DELETE TOP (1000) r 
				OUTPUT DELETED.custid,DELETED.TransId
				INTO #tmp_TransId_Parlay_batch (custid, TransId)    
				FROM #tmp_TransId_Parlay_LIC r 
  
				IF @@ROWCOUNT = 0
				BREAK
  
				DELETE t
				FROM dbo.CustLimitBetHistory_LIC t 
					INNER JOIN #tmp_TransId_Parlay_batch b ON t.CustID = b.CustId and t.Transid = b.TransId
				WHERE t.matchid = 29 

				TRUNCATE TABLE #tmp_TransId_Parlay_batch

				WAITFOR DELAY '00:00:00.020'

			END
		END
	END

	--CustLimitBet_QueueRetry
	SET @end = (SELECT MAX(ID) FROM #tmp_QueueRetry)
	SET @start = 1

	WHILE (@start <= @end)
	BEGIN
		
		SELECT @QueueId = QueueId
		FROM #tmp_QueueRetry
		WHERE ID = @start

		WHILE (1=1)
		BEGIN
			DELETE TOP(1000) q
			FROM dbo.CustLimitBet_QueueRetry q
			WHERE q.MainQueueId = @QueueId
			
			IF @@ROWCOUNT = 0 BREAK
		END	
		
		SET @start = @start + 1
	END

	DROP TABLE #match_tmp 
	DROP TABLE #match_archive 
	DROP TABLE #tmp_QueueID
	DROP TABLE #tmp_TransId_Parlay_789
	DROP TABLE #tmp_TransId_Parlay_batch
	DROP TABLE #tmp_TransId_Parlay_mbc
	DROP TABLE #tmp_TransId_pre_789
	DROP TABLE #tmp_TransId_pre_mbc
	DROP TABLE #tmp_TransId_Parlay_LIC
	DROP TABLE #tmp_TransId_pre_LIC
	DROP TABLE #tmp_QueueRetry
END
GO
	
