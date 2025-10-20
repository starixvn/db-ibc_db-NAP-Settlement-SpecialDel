/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ResultChangeLog_Sel]
(
	@FromDate	DATETIME		= NULL
	,@ToDate	DATETIME		= NULL
	,@IsTest	BIT				= 0
	,@ErrCode	INT				= 0		OUTPUT
	,@ErrMsg	NVARCHAR(200)	= ''	OUTPUT
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
		SELECT @ErrCode = 99
			,@ErrMsg = 'The entered time cannot exceed 3 days. Please try again.'

		SELECT NULL AS MatchId, NULL AS changetime
		RETURN
	END
	
	DECLARE @tmpMatch TABLE (MatchId INT, ResourceId VARCHAR(20), HomeValue VARCHAR(100), AwayValue VARCHAR(100), changetime DATETIME)

	-- Step 1: Get raw data
	INSERT INTO @tmpMatch (MatchId, ResourceId, HomeValue, AwayValue, changetime)
	SELECT 
		s.MatchID,
		ResourceID,
		HomeValue,
		AwayValue,
		LogDate
	FROM [dbo].[SettlementLog] s WITH (NOLOCK)
	WHERE LogDate BETWEEN @FromDate AND @ToDate
		AND ResourceID IN ('00','01')
	
	--Step 2: Return data
	;WITH cte AS(	
		SELECT MatchId, ResourceId, HomeValue, AwayValue, changetime
			,LAG(t.HomeValue,1) OVER(PARTITION BY t.MatchId, t.ResourceID ORDER BY t.changetime ASC) AS PreHome
			,LAG(t.AwayValue,1) OVER(PARTITION BY t.MatchId, t.ResourceID ORDER BY t.changetime ASC) AS PreAway
			,ROW_NUMBER() OVER (PARTITION BY t.Matchid, t.ResourceID ORDER BY t.changetime ASC) AS rn
		FROM @tmpMatch t
	)
	SELECT DISTINCT MatchId, changetime
	FROM cte s
	WHERE rn <> 1
		AND (HomeValue <> PreHome OR AwayValue <> PreAway)
		AND EXISTS (
			SELECT TOP 1 1 AS valid
			FROM bodb02.dbo.match m with (NOLOCK)	
			WHERE m.matchid = s.MatchID
				AND m.sporttype <= 99
				AND m.isTestMatch = @IsTest
		)		
	ORDER BY MatchId ASC, changetime ASC

END
GO
	