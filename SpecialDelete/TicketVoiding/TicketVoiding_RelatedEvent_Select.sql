/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RelatedEvent_Select]
(	
	@MatchId		INT
	,@EventDate		DATETIME = NULL
	,@IsMainMatch	BIT = 1
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200828@Charles: Get linked matches of main match [Redmine: #140339]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	IF @IsMainMatch = 1
	BEGIN
		CREATE TABLE #Match (matchid INT, eventdate DATETIME, homeid INT, awayid INT)

		INSERT INTO #Match(matchid, eventdate, homeid, awayid)
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.ParentID = @MatchId

		INSERT INTO #Match(matchid, eventdate, homeid, awayid)
		SELECT lm.MainMatchID, m.eventdate, m.homeid, m.awayid
		FROM dbo.Dot_Admin_LinkedMatch lm WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK) ON lm.MainMatchID = m.matchid
		WHERE lm.MainMatchID = @MatchId

		SELECT matchid, eventdate, homeid, awayid
		FROM #Match
		GROUP BY matchid, eventdate, homeid, awayid

		DROP TABLE #Match
	END
	ELSE
	BEGIN
		SELECT m.matchid, m.eventdate, m.homeid, m.awayid
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.matchid = @MatchId
			AND m.eventdate = @EventDate
			AND m.sporttype IN (1)
	END
	
END
GO

