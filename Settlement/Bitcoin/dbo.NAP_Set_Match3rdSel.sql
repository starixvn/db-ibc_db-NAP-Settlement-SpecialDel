/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_Match3rdSel]
    @MatchID    INT
AS
/*
    Created: 20220719@Kathy
    Task : get match3rd information
    DB: DBPRO/bodb02
   

    Revisions:
       - 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
       - 20240704@Aries: VS5 - Virtually Sports [Redmine:#207309]
		
    Parameters Explanation:


*/
BEGIN
    SET NOCOUNT ON

	SELECT m.Match3rdId AS MatchId
          ,m.SportType 
          ,m.StartTime AS KickOffTime 
          ,m.League3rdId AS LeagueId
          ,m.homeid
          ,m.awayid 
          ,m.eventstatus
          ,m.BetStatus
          ,m.EventDate
          ,m.hthomescore
          ,m.htawayscore
          ,m.finalhomescore
          ,m.finalawayscore
	FROM dbo.Match3rd m WITH(NOLOCK)
	WHERE m.Match3rdId = @MatchID;

END
GO