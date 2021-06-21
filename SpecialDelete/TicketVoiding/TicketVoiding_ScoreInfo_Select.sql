/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #WrongScore (ScoreId INT PRIMARY KEY IDENTITY(1,1), MatchId INT, Score VARCHAR(20), updatetime DATETIME, IsActive BIT, KickOffTime DATETIME)
	
	INSERT INTO #WrongScore (MatchId, Score, updatetime, IsActive, KickOffTime)
	SELECT md.matchid
		, md.Score
		, md.updatetime
		, md.IsActive
		, m.kickofftime
	FROM dbo.MatchReportDetail md WITH (NOLOCK)
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = md.matchid
	WHERE md.matchid = @MatchId
		AND md.ModeId IN (1,2,3,4)
		AND md.Score IS NOT NULL
	ORDER BY md.id

	SELECT w1.ScoreId
		, w1.Score AS WrongScore
		, CASE WHEN w1.ScoreId = 1 THEN w1.KickOffTime ELSE w1.updatetime END AS FilterFromTransTime
		, DATEADD(MS, -100, w2.updatetime) AS FilterToTransTime
		, w1.IsActive
	FROM #WrongScore w1
		LEFT JOIN #WrongScore w2 ON w2.ScoreId = w1.ScoreId + 1

	DROP TABLE #WrongScore

END
GO