/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Update]
	@MatchIds		VARCHAR(MAX)	= NULL,
	@TransDate		DATETIME		= NULL,
	@IsFromMoveBet	BIT				= 0
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion
		
	Explanation's Param:
*/
BEGIN
SET NOCOUNT ON
	CREATE TABLE #Match (MatchId INT PRIMARY KEY)
	INSERT INTO #Match (MatchId)
	SELECT DISTINCT val 
	FROM dbo.f_SplitString(@MatchIds, ',')
	WHERE val <> ''
	OPTION (maxrecursion 0)

	CREATE TABLE #Tickets (TransId BIGINT PRIMARY KEY)
	INSERT INTO #Tickets (TransId)
	SELECT mt.TransId
	FROM dbo.MarkedTransaction mt WITH(NOLOCK)
	INNER JOIN #Match m WITH(NOLOCK) ON m.MatchId = mt.MatchId
	WHERE (@IsFromMoveBet = 0 AND mt.CreatedDate BETWEEN @TransDate AND DATEADD(DAY, 1, @TransDate)) OR @IsFromMoveBet = 1

	-- Delete Transaction
	DELETE m FROM dbo.MarkedTransaction m
	WHERE m.TransId IN (SELECT TransId FROM #Tickets)

	DELETE b FROM #Match b
		INNER JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.MatchId = m.MatchId

	SELECT b.MatchId, m.HomeId, m.AwayId, m.SportType, m.IsNeutral 
	FROM #Match b
		LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId

	DROP TABLE #Match
	DROP TABLE #Tickets
SET NOCOUNT OFF
END
GO