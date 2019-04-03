/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Nap_SpecialDelete_MarkedTickets_Update	
	@TransIds			VARCHAR(MAX)	= NULL,
	@UserId				INT				= 0,
	@IP					VARCHAR(15)		= NULL,
	@ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
    @ErrCode			INT				= 0		OUTPUT
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	
*/
BEGIN
SET NOCOUNT ON
	CREATE TABLE #TransIds (TransId BIGINT PRIMARY KEY)
	INSERT INTO #TransIds (TransId)
	SELECT DISTINCT val 
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (maxrecursion 0)

	CREATE TABLE #Match (MatchId INT)
	INSERT INTO #Match 
	SELECT DISTINCT m.MatchId
	FROM #TransIds t
		LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON m.TransId = t.TransId
	
	-- Delete Transaction
	DELETE m FROM dbo.MarkedTransaction m
	WHERE m.TransId IN (SELECT TransId FROM #TransIds)

	DELETE b FROM #Match b
		INNER JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.MatchId = m.MatchId

	SELECT b.MatchId, m.HomeId, m.AwayId, m.SportType, m.IsNeutral 
	FROM #Match b
		LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId
		
	DROP TABLE #TransIds
	DROP TABLE #Match

SET NOCOUNT OFF
END
GO
