/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_Match_VS_Sel]
    @MatchID    INT
AS
/*	
	Creator: 20240206@Louisa 
	Task: Enhance VS2
	DB: DBPRO-bodb02
	
	Revision:
		- 20240206@Louisa: Initial [Redmine:#189854]
 
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
