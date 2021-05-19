/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelInfo] 
	@matchid 			   INT

AS
/*
    Created by: 20180802@Vicky
    Task: Info of match
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		
*/
BEGIN
	SET NOCOUNT ON
    
	SELECT m.matchId
        ,m.matchcode
        ,m.kickofftime
        ,datediff(minute, kickofftime, CURRENT_TIMESTAMP) playtime
        ,m.homeid
        ,m.awayid
        ,m.leagueId
        ,mr.BestOfMap
		,m.betstatus
		,mr.IsHTCal AS isHalftimeCal 
     FROM dbo.[match] m WITH (NOLOCK)
     	INNER JOIN dbo.[match_remark] mr WITH (NOLOCK) ON mr.matchid = m.matchid
     WHERE m.matchid = @matchid

END
GO
