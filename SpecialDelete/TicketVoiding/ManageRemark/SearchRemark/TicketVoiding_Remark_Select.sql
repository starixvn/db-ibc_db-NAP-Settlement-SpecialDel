/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Remark_Select]
	@RemarkId		INT
AS
/*	Created by: 20251120@Lani
	Task: Manage Remark - New function  [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20251120@Lani: Create new SP - Load a remark detail info [Redmine:#234937]
		
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT	@RemarkId AS RemarkId
		   ,r.MatchId
		   ,m.MatchCode
		   ,m.HomeId
		   ,m.AwayId
		   ,m.KickOffTime
		   ,m.LeagueId
		   ,r.IsCheckedVar
		   ,r.IsTest
		   ,r.MistakenBy
		   ,r.DecidedBy
		   ,r.PerformedBy
		   ,r.TV_IPTV AS Iptv
		   ,r.Provider
		   ,r.Source
		   ,r.Remark
		   ,r.Message
		   ,r.ActionId
		   ,r.Description
		   ,(SELECT	o.OperatorId AS '@OperatorId', o.OperatorTypeId AS '@TypeId'
			 FROM dbo.TicketVoiding_OperatorInfo o WITH (NOLOCK)
			 WHERE o.RemarkId = @RemarkId
			 FOR XML PATH ('r'), ROOT('root')) AS OperatorInfo
	FROM dbo.TicketVoiding_Remark AS r WITH (NOLOCK)
	OUTER APPLY (
		SELECT m.MatchId, m.matchcode, m.HomeId, m.AwayId, m.KickOffTime, m.LeagueId
		FROM dbo.match AS m WITH (NOLOCK)
		WHERE m.matchid = r.matchid
		UNION ALL
		SELECT m14.MatchId, m14.matchcode, m14.HomeId, m14.AwayId, m14.KickOffTime, m14.LeagueId
		FROM dbo.match14 AS m14 WITH (NOLOCK)
		WHERE m14.matchid = r.matchid
	) AS m	
	WHERE r.RemarkId = @RemarkId

END
