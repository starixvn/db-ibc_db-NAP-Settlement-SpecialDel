 ALTER PROCEDURE [dbo].[Nap_Set_LeagueMetricGamingSel]
	@fromdate	DATETIME,
	@todate		DATETIME
 AS
	/*
		Created: Johnson
		Date: 2015-06-29
		Task: Get all leagues offer Metric Gaming
		DB: DBPRO/bodb02
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT DISTINCT l.leagueid, l.leaguename
	FROM match m WITH(NOLOCK)
		INNER JOIN ResultDetail3rd rs WITH(NOLOCK) ON m.matchid = rs.matchid
		INNER JOIN VendorStatus vs WITH(NOLOCK) ON m.matchid = vs.matchid
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE m.eventdate BETWEEN @fromdate AND @todate
		AND m.sporttype = 1
		AND vs.opened = 1-- this match is offered Metric Gaming		
		AND vs.VendorID = 5
	ORDER BY leaguename
END


GO
GRANT EXECUTE ON [dbo].[Nap_Set_LeagueMetricGamingSel] TO [bodbAdminNet]