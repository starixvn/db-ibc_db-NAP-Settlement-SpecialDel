/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE NAP_Set_Match_s178_Sel
    @MatchID    INT
AS
/*	
	Creator: 20230704@Louisa 
	Task: Virtual Leap Gaming - VS3
	DB: DBPRO-bodb02
	
	Revisions:
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 [Redmine:#189854]
		- 20231016@Aries: Auto Send Announcement When Refund VS [Redmine:#195333]
		- 20231215@Louisa:  Enhance code [Redmine:#195536]
 
*/

BEGIN
	SET NOCOUNT ON

	SELECT @MatchID AS MatchID,m.eventstatus, s.SportType,kickofftime,l.leagueId,l.LeagueGroupID,m.homeid, m.awayid  
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.sporttype
		LEFT JOIN dbo.league AS l  WITH(NOLOCK) ON  l.leagueId = m.leagueId 
	WHERE matchid = @matchid
		AND m.IsDeleted  = 0
END
GO