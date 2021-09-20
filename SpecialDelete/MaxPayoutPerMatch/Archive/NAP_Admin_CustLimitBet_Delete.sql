/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Delete]
AS
/*	
	Created: 20210914@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #match_tmp (MatchId INT, Eventdate DATETIME, EventTypeID TINYINT)
	DECLARE @tmp_batch AS TABLE (MatchId INT, EventTypeID TINYINT)

	DECLARE @Archive_Date DATETIME
	SELECT @Archive_Date = DATEADD(DAY, -6, GETDATE())

	INSERT INTO #match_tmp (MatchId, EventTypeID, Eventdate)
	SELECT DISTINCT mc.Matchid, mc.EventTypeID, m.eventdate
	FROM (
			SELECT Matchid, EventTypeID
			FROM dbo.CustLimitBet_MBC mbc WITH (NOLOCK)

			UNION ALL
			SELECT Matchid, EventTypeID
			FROM dbo.CustLimitBet_789 m789 WITH (NOLOCK)
		)mc
		OUTER APPLY (
			SELECT eventdate
			FROM dbo.match m WITH (NOLOCK)
			WHERE mc.EventTypeID = 1 AND mc.Matchid = m.matchid

			UNION ALL
			SELECT eventdate
			FROM dbo.match14 m14 WITH (NOLOCK)
			WHERE mc.EventTypeID = 1 AND mc.Matchid = m14.matchid

			UNION ALL
			SELECT o.eventdate
			FROM dbo.outright o WITH (NOLOCK)
			WHERE mc.EventTypeID = 2 AND o.orid = mc.Matchid

			UNION ALL
			SELECT o14.eventdate
			FROM dbo.outright14 o14 WITH (NOLOCK)
			WHERE mc.EventTypeID = 2 AND o14.orid = mc.Matchid
		)m

	--Check delete rule
	DELETE #match_tmp WHERE Eventdate > @Archive_Date
	
	DECLARE @row_cnt INT = 0
	--Delete data
	WHILE (1=1)
	BEGIN
		DELETE @tmp_batch

		DELETE TOP (1000)
		FROM #match_tmp 
		OUTPUT DELETED.MatchId, DELETED.EventTypeID
		INTO @tmp_batch(MatchId, EventTypeID)

		IF @@ROWCOUNT = 0
			BREAK

		--CustLimitBet_MBC
		DELETE	mbc
		FROM dbo.CustLimitBet_MBC mbc WITH(ROWLOCK, UPDLOCK) 
			INNER JOIN @tmp_batch t ON t.MatchId = mbc.Matchid AND t.EventTypeID = mbc.EventTypeID

		--CustLimitBet_789
		DELETE	m789
		FROM dbo.CustLimitBet_789 m789 WITH(ROWLOCK, UPDLOCK) 
			INNER JOIN @tmp_batch t ON t.MatchId = m789.Matchid AND t.EventTypeID = m789.EventTypeID

		--Loop for History & queue
		WHILE (1=1)
		BEGIN
			--CustLimitBetHistory_MBC
			DELETE TOP(1000) mbc
			FROM dbo.CustLimitBetHistory_MBC mbc WITH(ROWLOCK, UPDLOCK) 
				INNER JOIN @tmp_batch t ON t.MatchId = mbc.Matchid AND t.EventTypeID = mbc.EventTypeID
				
			SELECT @row_cnt = @row_cnt + @@ROWCOUNT
			
			--CustLimitBetHistory_789
			DELETE TOP(1000) m789
			FROM dbo.CustLimitBetHistory_789 m789 WITH(ROWLOCK, UPDLOCK) 
				INNER JOIN @tmp_batch t ON t.MatchId = m789.Matchid AND t.EventTypeID = m789.EventTypeID

			SELECT @row_cnt = @row_cnt + @@ROWCOUNT

			--CustLimitBetQueue
			DELETE TOP(1000) q
			FROM dbo.CustLimitBetQueue q WITH(ROWLOCK, UPDLOCK) 
				INNER JOIN @tmp_batch t ON t.MatchId = q.Matchid AND t.EventTypeID = q.EventTypeID
			
			SELECT @row_cnt = @row_cnt + @@ROWCOUNT
			IF @row_cnt < 1000
			BREAK
		END
	
	END

	DROP TABLE #match_tmp 
END
GO
	
