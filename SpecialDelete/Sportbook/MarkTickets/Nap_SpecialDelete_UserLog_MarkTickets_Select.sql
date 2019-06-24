/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_SpecialDelete_UserLog_MarkTickets_Select @LogDateFrom DATE
	,@LogDateTo DATE
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

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #LogActionId (Id INT);

	DECLARE @LogDateFromGMTMinus4 DATETIME
		,@LogDateToGMTMinus4 DATETIME

	SELECT @LogDateFromGMTMinus4 = DATEADD(HOUR, - 12, @LogDateFrom + CAST('00:00:00.000' AS DATETIME))
		,@LogDateToGMTMinus4 = DATEADD(HOUR, - 12,  @LogDateTo + CAST('23:59:59.997' AS DATETIME))

	INSERT INTO #LogActionId (Id)
	SELECT DISTINCT val
	FROM dbo.f_StringSplit(@LogActionIds, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0);

	-- Return log result
	SELECT l.SessionId
		,l.CreatedDate
		,l.LogActionId
		,l.MatchId
		,m.homeid
		,m.awayid
		,l.LogData
		,c.username AS 'DoneBy'
	FROM dbo.TicketVoiding_Log AS l WITH (NOLOCK)
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON l.UserId = c.custid
		LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON l.MatchId = m.matchid
	WHERE l.CreatedDate BETWEEN @LogDateFromGMTMinus4 AND @LogDateToGMTMinus4
		AND (@MatchId IS NULL OR l.MatchId = @MatchId)
		AND EXISTS (
			SELECT TOP 1 1
			FROM #LogActionId AS lid
			WHERE lid.Id = l.LogActionId
			)
		AND (@DoneBy IS NULL OR c.username like '%' + @DoneBy +'%')
	ORDER BY l.CreatedDate DESC

	DROP TABLE #LogActionId
END