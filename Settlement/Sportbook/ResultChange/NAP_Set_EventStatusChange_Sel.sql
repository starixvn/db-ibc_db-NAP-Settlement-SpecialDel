/*<info serverAlias="DBTP-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_EventStatusChange_Sel]
(
	@FromDate DATETIME
	,@ToDate DATETIME
)
AS
/*	
	Created: 20250908@Max
    Task: Settlement - Integration - Support providing an API when results are changed for the Licensee - [Redmine: #236783]
    DB: DBTP-bodb02
    Revisions:
		- 20250908@Max: Create SP - [Redmine: #236783]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MatchList (MatchId INT) 
	CREATE TABLE #StatusChangePoints (MatchId INT, Eventstatus NVARCHAR(500), rn INT)
	CREATE TABLE #PivotData (MatchId INT, status_1 NVARCHAR(500), status_2 NVARCHAR(500), status_3 NVARCHAR(500))

	-- Step 1: Get list distinct MatchID in range time
	INSERT INTO #MatchList (MatchId)
	SELECT DISTINCT mt.matchid
	FROM [dbo].[Match_Tracking] mt WITH (NOLOCK)
		INNER JOIN dbo.match m with (NOLOCK) ON m.MatchId = mt.Matchid AND m.SportType <= 99
		INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid AND l.isTest = 0
	WHERE mt.UpdateTime BETWEEN @FromDate AND @ToDate

	-- Step 2: Get all records of MatchID and filter LAG
	;WITH StatusChanges AS (
		SELECT 
			mt.matchid,
			CASE WHEN mt.betstatus = 'Refund;' THEN 'Refund' ELSE mt.eventstatus END AS eventstatus,
			mt.UpdateTime,
			LAG(CASE WHEN mt.betstatus = 'Refund;' THEN 'Refund' ELSE mt.eventstatus END) OVER (PARTITION BY mt.matchid ORDER BY mt.UpdateTime ASC) as prev_eventstatus
		FROM [dbo].[Match_Tracking] mt WITH (NOLOCK)
			INNER JOIN #MatchList ml ON mt.matchid = ml.matchid
		WHERE mt.eventstatus IS NOT NULL
	)
	INSERT INTO #StatusChangePoints (MatchId, Eventstatus, rn)
	SELECT 
		matchid,
		eventstatus,
		ROW_NUMBER() OVER (PARTITION BY matchid ORDER BY UpdateTime DESC) as rn
	FROM StatusChanges
	WHERE prev_eventstatus IS NULL  -- First record
	   OR prev_eventstatus != eventstatus  -- Status changed

	-- Step 3: Just keep 3 lastest records
	DELETE FROM #StatusChangePoints WHERE rn > 3

	-- Step 4: Pivot data
	INSERT INTO #PivotData (MatchId, status_1, status_2, status_3)
	SELECT 
		matchid,
		MAX(CASE WHEN rn = 1 THEN eventstatus END) AS status_1,
		MAX(CASE WHEN rn = 2 THEN eventstatus END) AS status_2,
		MAX(CASE WHEN rn = 3 THEN eventstatus END) AS status_3
	FROM #StatusChangePoints
	GROUP BY matchid

	-- Step 5: Return data
	SELECT DISTINCT MatchId
	FROM #PivotData
	WHERE (status_1 = 'running' AND status_2 IN ('completed','Refund'))
	   OR (status_1 IN ('completed','Refund') AND status_2 = 'running' AND status_3 IN ('completed','Refund'))
	   OR (status_1 = 'completed' AND status_2 = 'Refund')
	   OR (status_1 = 'Refund' AND status_2 = 'completed')

	DROP TABLE #MatchList
	DROP TABLE #PivotData
	DROP TABLE #StatusChangePoints

END
GO
	