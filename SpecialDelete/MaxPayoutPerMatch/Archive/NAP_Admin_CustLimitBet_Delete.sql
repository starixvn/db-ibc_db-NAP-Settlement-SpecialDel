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
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Matchid INT, @eventtypeID TINYINT
	CREATE TABLE #match_tmp (ID INT IDENTITY(1,1),MatchId INT, EventTypeID TINYINT)
	CREATE TABLE #match_archive (MatchId INT,  EventTypeID TINYINT)
	CREATE TABLE #tmp_QueueID (QueueID BIGINT PRIMARY KEY)
	DECLARE @tmp_batch AS TABLE (QueueID BIGINT PRIMARY KEY)
	DECLARE @Archive_Date DATETIME
	SELECT @Archive_Date = DATEADD(DAY, -6, GETDATE())

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
		INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND m.EventTypeID = mc.EventTypeID
	UNION 
	SELECT DISTINCT mc.Matchid, mc.EventTypeID
	FROM dbo.CustLimitBet_789 mc WITH (NOLOCK)
		INNER JOIN #match_archive m ON m.MatchId = mc.Matchid AND m.EventTypeID = mc.EventTypeID

	DECLARE @start INT = 1, @end INT

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
	WHERE q.Statusid = 1
		AND q.ErrMsg <> ''
		AND q.ExecTime <= @Archive_Date

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

	DROP TABLE #match_tmp 
	DROP TABLE #match_archive 
	DROP TABLE #tmp_QueueID
END
GO
	
