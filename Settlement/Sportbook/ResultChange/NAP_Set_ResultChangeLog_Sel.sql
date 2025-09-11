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

	DECLARE @tmpMatch TABLE (MatchId INT, ResourceId VARCHAR(20), ResultValue VARCHAR(200), LastLogDate DATETIME)

	-- Step 1: Get raw data
	INSERT INTO @tmpMatch (MatchId, ResourceId, ResultValue, LastLogDate)
	SELECT 
		s.MatchID,
		ResourceID,
		CONCAT(ISNULL(HomeValue,''), '-', ISNULL(AwayValue,'')),
		MAX(LogDate)
	FROM [dbo].[SettlementLog] s WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 l.leagueid AS leagueid 
			FROM bodb02.dbo.match m with (NOLOCK)	
				INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE m.matchid = s.MatchID
				AND m.sporttype <= 99
				AND l.isTest = 0
		)m		
	WHERE LogDate BETWEEN @FromDate AND @ToDate
		AND ResourceID IN ('00','01')
	GROUP BY s.MatchID,
		ResourceID,
		CONCAT(ISNULL(HomeValue,''), '-', ISNULL(AwayValue,''))
	
	--Step 2: Return data
	SELECT DISTINCT m.MatchId 
	FROM @tmpMatch m
		CROSS APPLY (
			SELECT TOP 1 1 AS valid
			FROM [dbo].[SettlementLog] s WITH (NOLOCK)
			WHERE s.MatchID = m.MatchId
				AND s.ResourceID = m.ResourceId
				AND s.LogDate < m.LastLogDate
				AND CONCAT(ISNULL(s.HomeValue,''), '-', ISNULL(s.AwayValue,'')) != m.ResultValue
		)tmp

END
GO
	