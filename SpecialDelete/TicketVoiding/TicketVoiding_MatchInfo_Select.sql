/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_MatchInfo_Select]
	@EventDate		DATETIME
	,@Sporttype		SMALLINT	
	,@LeagueId		INT			 = 0
AS
/*	Created by: Kathy
	Date 20181212
	Task: get match info [Redmine:#90155]
	DB: DBPRO/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:		
*/
BEGIN
	SET NOCOUNT ON

	IF @LeagueId = 0 
	BEGIN
		SELECT	m.matchid, m.homeid, m.awayid, m.leagueid
		FROM	dbo.match m WITH(NOLOCK)
		WHERE	m.eventdate = @EventDate
				AND m.sporttype = @Sporttype
	END
	ELSE
	BEGIN
		SELECT	m.matchid, m.homeid, m.awayid, m.leagueid
		FROM	dbo.match m WITH(NOLOCK)
		WHERE	m.eventdate = @EventDate
				AND m.sporttype = @Sporttype
				AND m.leagueid = @LeagueId
	END
	
END
GO
