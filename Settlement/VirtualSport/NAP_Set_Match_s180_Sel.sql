/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_Match_s180_Sel
    @MatchID    INT
AS
/*	
	Creator: 20231016@Aries 
	Task: Auto Send Announcement When Refund VS
	DB: DBPRO-bodb02
	
	Revisions:
		- 20231016@Aries: Created [Redmine:#195333]
 
*/

BEGIN
	SET NOCOUNT ON

	SELECT m.eventstatus, m.kickofftime,l.leaguename
	FROM dbo.match m WITH(NOLOCK)
		LEFT JOIN dbo.league AS l  WITH(NOLOCK) ON  l.leagueId = m.leagueId 
	WHERE m.matchid = @matchid
		AND m.IsDeleted  = 0
END
GO