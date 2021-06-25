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

	CREATE TABLE #WrongScore (Id SMALLINT PRIMARY KEY IDENTITY(1,1), ScoreId INT, MatchId INT, Score VARCHAR(20), updatetime DATETIME, IsActive BIT, KickOffTime DATETIME)
	
	--init for first  score 0-0
	INSERT INTO #WrongScore (ScoreId, MatchId, Score, updatetime, IsActive, KickOffTime)
	SELECT 0, @MatchId, '0-0', NULL, 1, m.kickofftime
	FROM dbo.match m WITH (NOLOCK)
	WHERE m.matchid = @MatchId
	
	--getdate from table MatchReportDetail
	INSERT INTO #WrongScore (ScoreId, MatchId, Score, updatetime, IsActive)
	SELECT md.id 
		, md.matchid
		, md.Score
		, md.updatetime
		, md.IsActive
	FROM dbo.MatchReportDetail md WITH (NOLOCK)
	WHERE md.matchid = @MatchId
		AND md.ModeId IN (1,2,3,4)
		AND md.Score IS NOT NULL
	ORDER BY md.id
	
	SELECT w1.ScoreId
		, w1.Score AS WrongScore
		, CASE WHEN w1.updatetime IS NULL THEN w1.KickOffTime ELSE w1.updatetime END AS FilterFromTransTime
		, DATEADD(MS, -100, w2.updatetime) AS FilterToTransTime
		, w1.IsActive
	FROM #WrongScore w1
		LEFT JOIN #WrongScore w2 ON w2.Id = w1.Id + 1

	DROP TABLE #WrongScore

END
GO