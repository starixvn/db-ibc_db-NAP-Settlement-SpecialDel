/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ScoreInfo_Select]
(	
	@MatchId              INT
)
AS
/*	
	Created by: Max
	Date 20210422
	Task: TVS - Wrong Score [Redmine: #140953]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20210422@Max: Create new SP [Redmine: #140953]
		- 20210527@Max: Exclude 2H ticket from get score & time range [Redmine: #155598]
		- 20210528@Max: Exclude some group bettypes [Redmine: #155598]
		- 20210616@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20220120@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #WrongScore (Id SMALLINT PRIMARY KEY IDENTITY(1,1), ScoreId INT, MatchId INT, Score VARCHAR(20), updatetime DATETIME, IsActive BIT, KickOffTime DATETIME)
	
	--init for first  score 0-0
	IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.Dot_Admin_Suspender_Actionlog WITH (NOLOCK) WHERE MatchID = @MatchId AND EventID = 1 AND HomeVal = '0' AND AwayVal = '0')
	BEGIN
		INSERT INTO #WrongScore (ScoreId, MatchId, Score, updatetime, IsActive, KickOffTime)
		SELECT 0, @MatchId, '0-0', NULL, 1, m.kickofftime
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.matchid = @MatchId
	END
	
	--getdate from table MatchReportDetail
	INSERT INTO #WrongScore (ScoreId, MatchId, Score, updatetime, IsActive)
	SELECT md.LogID 
		, md.matchid
		, md.HomeVal + '-' + md.AwayVal
		, md.InsertDateTime
		, md.IsActive
	FROM dbo.Dot_Admin_Suspender_Actionlog md WITH (NOLOCK)
	WHERE md.matchid = @MatchId
		AND md.EventID IN (1,3)
		AND md.HomeVal IS NOT NULL
		AND md.AwayVal IS NOT NULL
	ORDER BY md.LogID
	
	SELECT @MatchId AS MatchId 
		, w1.ScoreId
		, w1.Score AS WrongScore
		, CASE WHEN w1.updatetime IS NULL THEN w1.KickOffTime ELSE w1.updatetime END AS FilterFromTransTime
		, DATEADD(MS, -100, w2.updatetime) AS FilterToTransTime
		, w1.IsActive
	FROM #WrongScore w1
		LEFT JOIN #WrongScore w2 ON w2.Id = w1.Id + 1

	DROP TABLE #WrongScore

END
GO