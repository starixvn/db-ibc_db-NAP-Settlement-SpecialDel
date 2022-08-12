/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SpecialDelete_UserLog_MarkTickets_Select
	@LogDateFrom DATETIME
	,@LogDateTo DATETIME
	,@MatchId INT = NULL
	,@LogActionIds VARCHAR(MAX)
	,@DoneBy VARCHAR(30) = NULL
AS
/*
	Create By: Raymond.Le
	Created Date: 20190606
	Task: Implement view User Log of Mark tickets function - [Redmine: 114596]
	DB: DBLOG/bodb_CustomerLog
	
	Revisions: 
		- 20190606@Raymond.Le: Create new SP [Redmine: #114596]
		- 20191101@Charles: Get score and ko time for userlogs [122187]
		- 20191126@Charles: Show DoneBy column when return results [124451]
		- 20200414@Charles: Separate single tickets with parlay tickets on LogData [131670]
		- 20200914@Zane: Return logdata [Redmine: #141235]
		- 20210923@Zane: Change data type of filter time [Redmine: #160209]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #LogActionId (Id INT);

	INSERT INTO #LogActionId (Id)
	SELECT DISTINCT val
	FROM dbo.f_StringSplit(@LogActionIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0);

	CREATE TABLE #LogResult (
		SessionId 	INT,
		CreatedDate DATETIME,
		LogActionId INT,
		MatchId 	INT,
		homeid		INT,
		awayid		INT,
		LogData		VARCHAR(MAX),
		kickofftime	DATETIME,
		HTScore		VARCHAR(10),
		FTSCore		VARCHAR(10),
		username	VARCHAR(30)
	);

	-- Insert data to temp log result
	INSERT INTO #LogResult(
			SessionId
			,CreatedDate
			,LogActionId
			,MatchId
			,homeid
			,awayid
			,LogData
			,kickofftime
			,HTScore
			,FTSCore
			,username)
	SELECT l.SessionId
			,l.CreatedDate
			,l.LogActionId
			,l.MatchId
			,m.homeid
			,m.awayid
			,l.LogData
			,m.kickofftime
			,ISNULL(rdHT.HomeValue + '-' + rdHT.AwayValue, '-') AS 'HTScore'
			,ISNULL(rdFT.HomeValue + '-' + rdFT.AwayValue, '-') AS 'FTSCore'
			,c.username 
		FROM dbo.TicketVoiding_Log AS l WITH (NOLOCK)
			LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON l.MatchId = m.matchid
			LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON l.UserId = c.custid
			LEFT JOIN bodb02.dbo.ResultDetail AS rdHT WITH (NOLOCK) ON rdHT.MatchId = m.matchid AND rdHT.ResourceID = '01'
			LEFT JOIN bodb02.dbo.ResultDetail AS rdFT WITH (NOLOCK) ON rdFT.MatchId = m.matchid AND rdFT.ResourceID = '00'
		WHERE l.CreatedDate BETWEEN @LogDateFrom AND @LogDateTo
			AND (@MatchId IS NULL OR l.MatchId = @MatchId)
			AND EXISTS (
				SELECT TOP 1 1
				FROM #LogActionId AS lid
				WHERE lid.Id = l.LogActionId
				)
			AND (@DoneBy IS NULL OR c.username like '%' + @DoneBy +'%')
	ORDER BY l.CreatedDate DESC
	OPTION (MAXRECURSION 0);

	-- Check and update information of match if it was moved to match14
	UPDATE lr
	SET lr.homeid = m.homeid,
		lr.awayid = m.awayid,
		lr.kickofftime = m.kickofftime,
		lr.HTScore = ISNULL(rdHT.HomeValue + '-' + rdHT.AwayValue, '-'),
		lr.FTSCore = ISNULL(rdFT.HomeValue + '-' + rdFT.AwayValue, '-')
	FROM #LogResult lr WITH(ROWLOCK, UPDLOCK)
		LEFT JOIN bodb02.dbo.match14 AS m WITH (NOLOCK) ON lr.MatchId = m.matchid
		LEFT JOIN bodb02.dbo.ResultDetail14 AS rdHT WITH (NOLOCK) ON rdHT.MatchId = m.matchid AND rdHT.ResourceID = '01'
		LEFT JOIN bodb02.dbo.ResultDetail14 AS rdFT WITH (NOLOCK) ON rdFT.MatchId = m.matchid AND rdFT.ResourceID = '00'
	WHERE lr.homeid is NULL

	-- Return log result
	SELECT 	SessionId,
			CreatedDate,
			LogActionId,
			MatchId,
			homeid,
			awayid,
			LogData,
			kickofftime,
			HTScore,
			FTSCore,
			username AS 'DoneBy'
	FROM #LogResult

	DROP TABLE #LogActionId
	DROP TABLE #LogResult
END