/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_Match_FirstTicketTime_Select] 
	@MatchId INT = 0
AS
/*
    Created by: 20190327@Alan
	Task: Get First Ticket Time 
	DB: DBTXN/bodb02

	Explanation's Param:
		
	Revisions:
		- 20190327@Alan: - Get First Ticket Time [108826]
		- 20190510@Alan: - Get Kick Off Time [112480]
		- 20190521@Raymond.Le: - Return 2001/1/1 when KOTime is null [113518]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @MinTransDate	DATETIME
		   ,@KickOffTime	DATETIME;
	
	DECLARE @tmpMatchId TABLE (MatchId INT, KickOffTime DATETIME)
	INSERT INTO @tmpMatchId (MatchId, KickOffTime)
	SELECT MatchId, ISNULL(kickofftime, '2001-01-01 00:00:00')
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype NOT IN (50,8) AND matchid = @MatchId THEN 1
				    WHEN sporttype IN (50,8) AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END

	CREATE TABLE #CTE_transdate (transdate DATETIME)
	INSERT INTO #CTE_transdate (transdate)
	SELECT b.transdate
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @tmpMatchId m ON b.matchid = m.MatchId
	UNION
	SELECT bm.transdate
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN @tmpMatchId m ON bm.matchid = m.MatchId
		
	SELECT @MinTransDate = MIN(transdate)
	FROM #CTE_transdate

	SELECT @KickOffTime = MIN(KickOffTime)
	FROM @tmpMatchId

	SELECT @MinTransDate AS MinTransDate
		  ,@KickOffTime AS KickOffTime;

	DROP TABLE #CTE_transdate
	SET NOCOUNT OFF;
END
