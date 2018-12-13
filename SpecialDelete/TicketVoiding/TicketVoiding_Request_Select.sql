/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Select]
	@RequestId		INT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	r.Sporttype
			,r.SubIssueTypeId
			,r.ActionId
			,r.MistakenBy
			,r.DecidedBy
			,(SELECT	o.OperatorId AS '@OperatorId', o.OperatorTypeId AS '@TypeId'
				FROM	dbo.TicketVoiding_OperatorInfo o WITH(NOLOCK)
				WHERE	o.RequestId = @RequestId
				FOR XML PATH ('r'), ROOT('root')) AS OperatorInfo
			,r.Provider
			,r.Source
			,r.Remark
	FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
	WHERE	r.RequestId = @RequestId

	SELECT	rd.MatchId
			,m.eventdate
			,m.ParentID
			,rd.LeagueId
			,rd.MatchId
			,rd.HomeId
			,rd.AwayId
			,rd.KickOffTime
	FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		CROSS APPLY (
			SELECT	m.eventdate, m.ParentID
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.matchid = rd.matchid
		) m
	WHERE	rd.RequestId = @RequestId

END
GO