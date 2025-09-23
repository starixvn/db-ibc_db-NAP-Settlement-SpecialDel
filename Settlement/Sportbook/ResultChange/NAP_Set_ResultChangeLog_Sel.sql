/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ResultChangeLog_Sel]
(
	@FromDate DATETIME = NULL
	,@ToDate DATETIME = NULL
	,@IsTest BIT = 0
)
AS
/*	
	Created: 20250908@Max
    Task: Settlement - Integration - Support providing an API when results are changed for the Licensee - [Redmine: #236783]
    DB: DBLOG-bodb_CustomerLog
    Revisions:
		- 20250908@Max: Create SP - [Redmine: #236783]
		- 20250922@Max: Adding change time [Redmine: #239413]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT @ToDate = ISNULL(@ToDate, GETDATE())
		,@FromDate = ISNULL(@FromDate, DATEADD(DAY, -3, @ToDate)) 

	IF DATEDIFF(DAY, @FromDate, @ToDate) > 3
	BEGIN
		RETURN
	END
	
	DECLARE @tmpMatch TABLE (MatchId INT, ResourceId VARCHAR(20), HomeValue VARCHAR(100), AwayValue VARCHAR(100), LastLogDate DATETIME)

	-- Step 1: Get raw data
	INSERT INTO @tmpMatch (MatchId, ResourceId, HomeValue, AwayValue, LastLogDate)
	SELECT 
		s.MatchID,
		ResourceID,
		HomeValue,
		AwayValue,
		MAX(LogDate)
	FROM [dbo].[SettlementLog] s WITH (NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 1 AS valid
			FROM bodb02.dbo.match m with (NOLOCK)	
			WHERE m.matchid = s.MatchID
				AND m.sporttype <= 99
				AND m.isTestMatch = @IsTest
		)m		
	WHERE LogDate BETWEEN @FromDate AND @ToDate
		AND ResourceID IN ('00','01')
	GROUP BY s.MatchID,
		ResourceID,
		HomeValue, 
		AwayValue
	
	--Step 2: Return data
	;WITH cteChangeInTime AS (
		SELECT MatchId, ResourceId
		FROM @tmpMatch t
		GROUP BY MatchId, ResourceId
		HAVING COUNT(1) > 1
	)
	,cteDataDetail AS (
		SELECT DISTINCT c.MatchId, LogDate AS changetime
		FROM [dbo].[SettlementLog] s WITH (NOLOCK)
			INNER JOIN cteChangeInTime c ON c.MatchId = s.MatchID AND c.ResourceId = s.ResourceID
		WHERE s.LogDate BETWEEN @FromDate AND @ToDate
			AND s.ResourceID IN ('00','01')
	)
	SELECT DISTINCT MatchId, changetime
	FROM cteDataDetail
	ORDER BY matchId ASC, changetime ASC

END
GO
	