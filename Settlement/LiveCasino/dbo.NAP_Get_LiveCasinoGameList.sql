CREATE PROCEDURE [NAP_Get_LiveCasinoGameList]
	@FromDate datetime,
	@ToDate datetime,
	@LeagueID int = 0,
	@StatusID INT = 0
AS

/*
	Created by: 20140121@Kathy
	Task: get game hand by leagueid
	DB: DB02.BODB02

	Revisions:		
	
	Param explanation:
		@LeagueID: 
			0: show info of all leagues 		
		@StatusID:
			0: All
			1: Running
			2: Closed
			3: Completed
			4: Refund 
			5: Completed + Refund (Call from Result page) -- Remove filter by both completed and refund status
*/
BEGIN

	SET NOCOUNT ON

	SELECT 
		m.matchid
		,m.matchcode
		,m.eventdate
		,m.kickofftime
		,m.showtime AS GameEvent
		,m.finalhomescore
		,m.finalawayscore
		,CASE WHEN m.betstatus= 'Refund' THEN NULL ELSE m.betstatus END betstatus
		,CASE WHEN m.betstatus = 'Refund' THEN 'Refund' ELSE eventstatus END eventstatus
		,m.leagueid
		,CASE WHEN ISNULL(homeid2,0) = 0 THEN 1101 ELSE homeid2 END AS bettype
	FROM match m WITH(NOLOCK)
		INNER JOIN league l WITH(NOLOCK) ON l.leagueid = m.leagueid
	WHERE m.eventdate BETWEEN @FromDate AND @ToDate
		AND m.sporttype = 162 
		AND m.leagueid = CASE WHEN @LeagueID = 0 THEN m.leagueid ELSE @LeagueID END
		AND m.eventstatus = CASE @StatusID	WHEN 1 THEN 'running'
											WHEN 2 THEN 'closed'
											WHEN 3 THEN 'completed' 
											WHEN 4 THEN 'Refund' -- Remove filter by both completed and refund status
											ELSE m.eventstatus END
		AND ISNULL(m.betstatus,'') = CASE	WHEN @StatusID = 4 THEN 'Refund' ELSE ISNULL(m.betstatus,'') END
		AND CASE WHEN @StatusID = 3 THEN ISNULL(m.betstatus,'')ELSE '1' END <> CASE WHEN @StatusID = 3 THEN 'Refund' ELSE '2' END 
	order BY m.matchid
 
END


GO

GRANT EXECUTE ON [NAP_Get_LiveCasinoGameList] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Get_LiveCasinoGameList] TO [vnteam] AS [dbo]
GO


