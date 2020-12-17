/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_MatchSelDetail_ReCal]
(
	@matchid	INT
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBTXN/BODB02 
    
    Revisions:            
		- 20201211@Max: Support to Re-calculate Settled Tickets [Redmine: #145669]
		
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @sporttype					SMALLINT
        ,@FTStatus					NVARCHAR(50)
        ,@HTStatus					NVARCHAR(50)
		
	DECLARE @tmp_ExternalSourceResult TABLE (Matchid INT, SourceId TINYINT, ExHTHomeScore INT, ExHTAwayScore INT, ExFTHomeScore INT, ExFTAwayScore INT)
	DECLARE @status TABLE (GroupId TINYINT, BetCount INT, betRunningCount INT, betSettledCount INT, betMarkedCount INT
		, InRunning INT, Waiting_cnt INT, BetCountParlay INT, InRunningParlay INT, WaitingParlay_cnt INT
	)
		

	DECLARE @tmpBettypes TABLE (bettype SMALLINT, GroupId TINYINT, IsUsedGoalRecordValue BIT)
	INSERT INTO @tmpBettypes (bettype, GroupId, IsUsedGoalRecordValue)
	SELECT	BetType, GroupId, IsUsedGoalRecordValue
	FROM	dbo.[f_Set_GetGroupBettypes]()
	WHERE	IsAuto = 0

    SELECT @sporttype 	= sporttype
    FROM   DBPRO.bodb02.dbo.match WITH (NOLOCK)
    WHERE  matchid = @matchid
	
	DECLARE @tmpMarkedTransaction TABLE (
		bettype SMALLINT
		,betMarkedCount INT
	)

	CREATE TABLE #Data (
		bettype			SMALLINT  
		,InRunning		INT
		,Waiting_cnt	INT
		,betcount		INT
		,betRunningCount INT
		,betSettledCount INT
		,betMarkedCount INT 
		,InRunningParlay INT
		,WaitingParlay_cnt INT
		,betcountParlay	INT

		, PRIMARY KEY (bettype)
	)
	
	INSERT INTO #Data (bettype
		, InRunning,Waiting_cnt, betcount, betRunningCount, betSettledCount, betMarkedCount
		, InRunningParlay,WaitingParlay_cnt, betcountParlay
		)
	SELECT	b.bettype
			,MAX(CASE WHEN b.statusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS InRunning
			,SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS Waiting_cnt
			,COUNT(1) AS betcount
			,SUM(CASE WHEN b.statusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS betRunningCount
			,SUM(CASE WHEN b.statusID BETWEEN 111 AND 113 OR b.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN b.statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
			,0 InRunningParlay,0 WaitingParlay_cnt, 0 betcountParlay
	FROM	dbo.bettrans b WITH(NOLOCK)
				OUTER APPLY (
					SELECT TOP 1 mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
				)mt
	WHERE	b.matchid = @matchid
			AND b.statusID NOT IN (101, 102)
	GROUP BY b.bettype
	
	UNION ALL
	
	SELECT	bm.bettype
			,0 AS InRunning
			,0 AS Waiting_cnt
			,0 AS betcount
			,0 AS betRunningCount
			,0 AS betSettledCount
			,0 AS betMarkedCount
			,MAX(CASE WHEN statusID = 0 THEN 1 ELSE 0 END) InRunningParlay
			,SUM(CASE WHEN statusID = 1 THEN 1 ELSE 0 END) WaitingParlay_cnt
			,COUNT(1) betcountParlay
	FROM	dbo.bettransm bm WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND statusID NOT IN (101, 102)
	GROUP BY bm.bettype
	
    -- check match status
	INSERT INTO @status (GroupId, BetCount, betRunningCount, betSettledCount, betMarkedCount
		,InRunning, Waiting_cnt, BetCountParlay, InRunningParlay, WaitingParlay_cnt
	)
	SELECT	CASE 
				WHEN g.groupId = 1 THEN 1 -- HT
				WHEN g.groupId = 4 OR (g.GroupId = 2 AND g.IsUsedGoalRecordValue =1) THEN 2 -- FGLG
				WHEN g.groupId = 3 THEN 3 -- HT FGLG
					
				WHEN g.GroupId = 7 THEN 7 -- SS
				WHEN g.GroupId = 10 THEN 9 -- All quaters of Basketball
				ELSE 0
			END AS GroupId
		,SUM(b.betcount) AS betcount
		,SUM(b.betRunningCount) AS betRunningCount
		,SUM(b.betSettledCount) AS betSettledCount
		,SUM(b.betMarkedCount) AS betMarkedCount
		,MAX(b.InRunning) AS InRunning
		,SUM(b.Waiting_cnt)	AS Waiting_cnt
			
		,SUM(b.betcountParlay) AS betcountParlay
		,MAX(b.InRunningParlay) AS InRunningParlay
		,SUM(b.WaitingParlay_cnt)AS WaitingParlay_cnt
	FROM	#Data b
		INNER JOIN @tmpBettypes g
			ON	b.bettype = g.BetType
	GROUP BY CASE 
				WHEN g.groupId = 1 THEN 1 -- HT
				WHEN g.groupId = 4 OR (g.GroupId = 2 AND g.IsUsedGoalRecordValue =1) THEN 2 -- FT FGLG
				WHEN g.groupId = 3 THEN 3 -- HT FGLG
				WHEN g.GroupId = 7 THEN 7 -- SS
				WHEN g.GroupId = 10 THEN 9 -- All quaters of Basketball
				ELSE 0
			END

	INSERT INTO @status (GroupId, BetCount, InRunning, Waiting_cnt, BetCountParlay, InRunningParlay, WaitingParlay_cnt)
	SELECT t.GroupId, 0, 0, 0, 0, 0, 0, 0
	FROM (VALUES (0),(1),(2),(3),(7),(9)) AS t (GroupId)
	WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @status s WHERE s.GroupId = t.GroupId)

    SELECT @FTStatus = CASE 
							WHEN t.betcount = 0 AND t.betcountParlay = 0 THEN 'No Ticket'
							WHEN t.InRunning > 0 AND t.betSettledCount = 0 THEN 'Running'
							WHEN t.betMarkedCount > 0 AND t.betSettledCount = 0 THEN 'Marked'
							WHEN t.Waiting_cnt > 0 AND t.Waiting_cnt = t.BetCount THEN 'Waiting'
							WHEN ISNULL(t.BetCount,0) = 0 AND t.InRunningParlay > 0 THEN 'Parlay Running'
							WHEN ISNULL(t.BetCount,0) = 0 AND t.WaitingParlay_cnt > 0 AND t.betcountParlay = t.WaitingParlay_cnt THEN 'Parlay Waiting'
                            ELSE 'Calculated'
                        END
    FROM (
		SELECT ISNULL(SUM(betcount),0) AS betcount, ISNULL(MAX(inRunning),0) AS inRunning, ISNULL(SUM(Waiting_cnt),0) AS Waiting_cnt
				,ISNULL(SUM(BetCountParlay),0) AS betcountParlay, ISNULL(MAX(InRunningParlay),0) AS InRunningParlay, ISNULL(SUM(WaitingParlay_cnt),0) AS WaitingParlay_cnt
				,ISNULL(SUM(betMarkedCount),0) AS betMarkedCount, ISNULL(betSettledCount,0) AS betSettledCount
		FROM @status
		WHERE 1 = CASE WHEN GroupId IN (0,2) THEN 1 ELSE 0 END --include FT-FGLG
					
	) AS t				

    SELECT @HTStatus = CASE 
							WHEN t.betcount = 0 AND t.betcountParlay = 0 THEN 'No Ticket'
							WHEN t.InRunning > 0 AND t.betSettledCount = 0 THEN 'Running'
							WHEN t.betMarkedCount > 0 AND t.betSettledCount = 0 THEN 'Marked'
							WHEN t.Waiting_cnt > 0 AND t.Waiting_cnt = t.BetCount THEN 'Waiting'
							WHEN ISNULL(t.BetCount,0) = 0 AND t.InRunningParlay > 0 THEN 'Parlay Running'
							WHEN ISNULL(t.BetCount,0) = 0 AND t.WaitingParlay_cnt > 0 AND t.betcountParlay = t.WaitingParlay_cnt THEN 'Parlay Waiting'
                            ELSE 'Calculated'
                        END
    FROM (
		SELECT ISNULL(MAX(betcount),0) AS betcount, ISNULL(MAX(inRunning),0) AS inRunning, ISNULL(SUM(Waiting_cnt),0) AS Waiting_cnt
				,ISNULL(SUM(BetCountParlay),0) AS betcountParlay, ISNULL(MAX(InRunningParlay),0) AS InRunningParlay, ISNULL(SUM(WaitingParlay_cnt),0) AS WaitingParlay_cnt
				,ISNULL(SUM(betMarkedCount),0) AS betMarkedCount, ISNULL(betSettledCount,0) AS betSettledCount
		FROM @status
		WHERE 1 = CASE WHEN GroupId IN(1,3) THEN 1 ELSE 0 END --include HT-FGLG
	) AS t
	
	--Return Data
    SELECT match.sporttype
        ,match.betstatus
        ,hthomescore AS HalfTimeHomeScore
        ,htawayscore AS HalfTimeAwayScore
        ,match.finalhomescore
        ,match.finalawayscore
        ,@HTStatus HTStatus
        ,@FTStatus FTStatus
     FROM DBPRO.bodb02.dbo.match WITH (NOLOCK)
        LEFT OUTER JOIN DBPRO.bodb02.dbo.match_remark mr WITH (NOLOCK) ON match.matchid = mr.matchid
		INNER JOIN DBPRO.bodb02.dbo.league l WITH (NOLOCK) ON match.leagueid = l.leagueid
		OUTER APPLY (
			SELECT TOP(1) CAST(1 AS BIT) AS HasInstantCompleted
			FROM DBPRO.BODB02.dbo.AutoPayoutResult WITH(NOLOCK)
			WHERE matchid = match.matchid
			AND CalculationType IN (101, 102) -- Instant Calculation
			AND StatusId = 2 --completed
			
		) AS aps
    WHERE match.matchid = @matchid

	DROP TABLE #Data
	
END
GO