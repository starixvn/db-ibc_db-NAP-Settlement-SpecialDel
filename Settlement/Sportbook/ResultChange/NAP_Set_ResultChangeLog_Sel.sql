/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ResultChangeLog_Sel]
(
	@FromDate DATETIME
	,@ToDate DATETIME
)
AS
/*	
	Created: 20250908@Max
    Task: Settlement - Integration - Support providing an API when results are changed for the Licensee - [Redmine: #236783]
    DB: DBLOG-bodb_CustomerLog
    Revisions:
		- 20250908@Max: Create SP - [Redmine: #236783]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpMatch TABLE (MatchId INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), IsChangedInTime BIT)
	DECLARE @tmpResult TABLE (MatchId INT)

	-- Step 1: Get raw data
	;WITH RawDataInRange AS (
		SELECT 
			MatchID,
			ResourceID,
			HomeValue,
			AwayValue,
			LogDate,
			ROW_NUMBER() OVER (PARTITION BY MatchID, ResourceID ORDER BY LogDate ASC) as rn
		FROM [dbo].[SettlementLog] WITH (NOLOCK)
		WHERE LogDate BETWEEN @FromDate AND @ToDate
		  AND ResourceID IN ('00', '01')
		  AND SportType <= 99
	),
	-- Step 2: Get detail data
	DetailData AS (
		SELECT 
			MatchID,
			ResourceID,
			COUNT(1) AS RecordCount,
			COUNT(DISTINCT CONCAT(ISNULL(HomeValue,''), '|', ISNULL(AwayValue,''))) AS DistinctResultCount
		FROM RawDataInRange
		GROUP BY MatchID, ResourceID
	)
	INSERT INTO @tmpMatch (MatchId, ResourceId, HomeValue, AwayValue, IsChangedInTime)
	SELECT 
		rd.MatchID,
		rd.ResourceID,
		rd.HomeValue,
		rd.AwayValue,
		CASE WHEN ad.RecordCount >= 2 AND ad.DistinctResultCount > 1 THEN 1 ELSE 0 END AS IsChangedInTime
	FROM RawDataInRange rd
		INNER JOIN DetailData ad ON rd.MatchID = ad.MatchID AND rd.ResourceID = ad.ResourceID
	WHERE rd.rn = 1

	-- Step 3: Get match changed in range time filter
	DELETE m OUTPUT deleted.MatchId INTO @tmpResult (MatchId)  
	FROM @tmpMatch m
	WHERE IsChangedInTime = 1

	-- Step 4: Get previous results
	;WITH PreviousResultsCTE AS (
		SELECT 
			t.MatchID,
			t.ResourceID,
			t.HomeValue as CurrentHomeValue,
			t.AwayValue as CurrentAwayValue,
			prev.HomeValue as PrevHomeValue,
			prev.AwayValue as PrevAwayValue
		FROM @tmpMatch t
		CROSS APPLY (
			SELECT TOP 1 HomeValue, AwayValue
			FROM [dbo].[SettlementLog] s WITH (NOLOCK)
			WHERE s.MatchID = t.MatchID 
			  AND s.ResourceID = t.ResourceID 
			  AND LogDate < @FromDate
			ORDER BY LogDate DESC
		) prev
	)
	-- Step 5: Insert result
	INSERT INTO @tmpResult (MatchId)
	SELECT MatchID
	FROM PreviousResultsCTE
	WHERE (CurrentHomeValue != PrevHomeValue OR CurrentAwayValue != PrevAwayValue)

	-- Final Result
	SELECT MatchId 
	FROM @tmpResult

END
GO
	