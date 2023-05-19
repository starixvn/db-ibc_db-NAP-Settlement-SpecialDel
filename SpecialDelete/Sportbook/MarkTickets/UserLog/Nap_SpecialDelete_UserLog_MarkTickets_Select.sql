/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_SpecialDelete_UserLog_MarkTickets_Select
	@LogDateFrom	DATETIME
	,@LogDateTo		DATETIME
	,@MatchId		INT = 0
	,@LogActionIds	VARCHAR(MAX)
	,@DoneBy		VARCHAR(30) = NULL
AS
/*
	Create By: 20190606@Raymond.Le
	Task: Implement view User Log of Mark tickets function - [Redmine: 114596]
	DB: DBLOG/bodb_CustomerLog
	
	Revisions: 
		- 20190606@Raymond.Le: Create new SP [Redmine: #114596]
		- 20191101@Charles: Get score and ko time for userlogs [122187]
		- 20191126@Charles: Show DoneBy column when return results [124451]
		- 20200414@Charles: Separate single tickets with parlay tickets on LogData [131670]
		- 20200914@Zane: Return logdata [Redmine: #141235]
		- 20210923@Zane: Change data type of filter time [Redmine: #160209]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #LogActionId (Id INT);

	INSERT INTO #LogActionId (Id)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@LogActionIds, ',')
	WHERE value <> ''

	DECLARE @tmpMatchId TABLE (MatchId INT)
	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM bodb02.dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype <> 50 AND MatchId = @MatchId THEN 1
					WHEN sporttype = 50 AND (MatchId = @MatchId OR ParentID = @MatchId) THEN 1 -- Get main/child matchid
						ELSE 0 END

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
			,ISNULL(CAST(rdHT.hthomescore AS VARCHAR(10)) + '-' + CAST(rdHT.htawayscore AS VARCHAR(10)), '-') AS 'HTScore'
			,ISNULL(CAST(rdFT.finalhomescore AS VARCHAR(10)) + '-' + CAST(rdFT.finalawayscore AS VARCHAR(10)), '-') AS 'FTScore'
			,c.username 
		FROM dbo.TicketVoiding_Log AS l WITH (NOLOCK)
			LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON l.MatchId = m.matchid
			LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON l.UserId = c.custid
			OUTER APPLY (
					SELECT TOP 1 m.hthomescore, m.htawayscore
					FROM bodb02.dbo.match_remark mr WITH (NOLOCK)
					WHERE IsHTCal = 1 
						AND mr.matchid = m.matchid			
				)rdHT
			OUTER APPLY (
					SELECT TOP 1 m.finalhomescore, m.finalawayscore
					FROM bodb02.dbo.match_remark mr WITH (NOLOCK)
					WHERE mr.calculate = 1 
						AND mr.matchid = m.matchid			
				)rdFT
		WHERE l.CreatedDate BETWEEN @LogDateFrom AND @LogDateTo
			AND (@MatchId = 0 OR l.MatchId IN (SELECT MatchId FROM @tmpMatchId))
			AND EXISTS (SELECT TOP 1 1 FROM #LogActionId AS lid WHERE lid.Id = l.LogActionId)
			AND (@DoneBy IS NULL OR c.username like '%' + @DoneBy +'%')
	ORDER BY l.CreatedDate DESC

	-- Check and update information of match if it was moved to match14
	UPDATE lr
	SET lr.homeid = m.homeid,
		lr.awayid = m.awayid,
		lr.kickofftime = m.kickofftime,
		lr.HTScore = ISNULL(CAST(rdHT.hthomescore AS VARCHAR(10)) + '-' + CAST(rdHT.htawayscore AS VARCHAR(10)), '-'),
		lr.FTSCore = ISNULL(CAST(rdFT.finalhomescore AS VARCHAR(10)) + '-' + CAST(rdFT.finalawayscore AS VARCHAR(10)), '-')
	FROM #LogResult lr WITH(ROWLOCK, UPDLOCK)
		LEFT JOIN bodb02.dbo.match14 AS m WITH (NOLOCK) ON lr.MatchId = m.matchid
		OUTER APPLY (
				SELECT TOP 1 m.hthomescore, m.htawayscore
				FROM bodb02.dbo.match_remark mr WITH (NOLOCK)
				WHERE IsHTCal = 1 
					AND mr.matchid = m.matchid			
				)rdHT
		OUTER APPLY (
				SELECT TOP 1 m.finalhomescore, m.finalawayscore
				FROM bodb02.dbo.match_remark mr WITH (NOLOCK)
				WHERE mr.calculate = 1 
					AND mr.matchid = m.matchid			
			)rdFT
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