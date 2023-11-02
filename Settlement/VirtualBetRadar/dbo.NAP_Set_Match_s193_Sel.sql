/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_Match_s193_Sel]
    @MatchID    INT
AS
/*
    Created: 20220719@Kathy
    Task : get match VS betradar information
    DB: DBPRO/bodb02
   

    Revisions:
      - 20220928@Kathy: Update Send Mail Notification Rule for VS BetRadar [Redmine:#178262]
      - 20231016@Aries: Auto Send Announcement When Refund VS [Redmine:#195333]
		
    Parameters Explanation:


*/
BEGIN
    SET NOCOUNT ON

	SELECT	mk.calculate, mk.calrefund, mk.multiple, mk.refund, m.eventstatus, m.kickofftime,l.leagueId,l.LeagueGroupID,m.homeid, m.awayid  
	FROM	dbo.match  AS m WITH(NOLOCK)
        LEFT JOIN dbo.match_remark AS mk WITH(NOLOCK) ON  m.matchid = mk.matchid 
        LEFT JOIN dbo.league AS l  WITH(NOLOCK) ON  l.leagueId = m.leagueId 
	WHERE	m.matchid = @MatchId

END
GO