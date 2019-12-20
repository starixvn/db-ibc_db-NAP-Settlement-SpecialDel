/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Select]
(
	@RequestId		INT
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190815@Raymond.Le: Return column IssueTypeId [#116617]
		- 20191111@Max: Ticket Voiding System - Abnormal Bet Issue Type [Redmine: #111541]
		- 20191219@Helen: Ticket Voiding System - hotfix [Redmine: #111541]
		- 20191220@Max: Some enhancement for TVS Abnormal Bets [Redmine: #125828]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	r.Sporttype
			,r.IssueTypeId
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
			,r.IsTest
			,ISNULL(isVoided,0) AS isVoided
			,cr.username AS RequestedBy
			,cv.username AS VoidedBy
	FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
		LEFT JOIN CustDB.dbo.Customer cr WITH (NOLOCK) ON cr.custid = r.UserId
		OUTER APPLY (SELECT TOP 1 1 AS isVoided, tv.UserId AS VoidBy
					 FROM TicketVoiding_VoidingHistory tv WITH (NOLOCK)
					 WHERE tv.RequestId = r.RequestId AND tv.StatusId = 2
					 ORDER BY tv.CreatedDate DESC
					)AS tblVoid
		LEFT JOIN CustDB.dbo.Customer cv WITH (NOLOCK) ON cv.custid = tblVoid.VoidBy			
	WHERE	r.RequestId = @RequestId

	SELECT	rd.MatchId
			,m.eventdate
			,m.ParentID
			,rd.LeagueId
			,rd.MatchId
			,rd.HomeId
			,rd.AwayId
			,rd.KickOffTime
			,rd.TransIds
			,m.hthomescore
			,m.htawayscore
			,m.finalhomescore
			,m.finalawayscore
	FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		CROSS APPLY (
			SELECT	m.eventdate, m.ParentID, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.matchid = rd.matchid
			UNION
			SELECT	m.eventdate, m.ParentID, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
			FROM	dbo.match14 m WITH(NOLOCK)
			WHERE	m.matchid = rd.matchid
		) m
	WHERE	rd.RequestId = @RequestId
	
	SELECT TOP 1 tv.MessageId
			,msg.Content_en AS ContentEnglish
			,msg.Content_ch AS ContentChineseTraditional
			,msg.Content_cs AS ContentChineseSimplified
	FROM TicketVoiding_VoidingHistory tv WITH (NOLOCK)
		CROSS APPLY (
				SELECT m.Content_en, m.Content_ch, m.Content_cs
				FROM DBMSG.bodb_Message.dbo.Msg m WITH (NOLOCK)
				WHERE m.MessageId = tv.MessageId
			) msg
	WHERE tv.RequestId = @RequestId AND tv.StatusId = 2
	ORDER BY tv.CreatedDate DESC

END