/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_AutoUnmark_Ticket_Select]
	@MatchId INT
AS
/*
	Created by: July
	Task : [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02

	Revisions:
		- 202120831@July: Create new SP - Get ticket of abnormal bet [Redmine:#175412]
*/
BEGIN
	SET NOCOUNT ON

	SELECT TransId, SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK) 
	WHERE IssueTypeId = 11 AND MatchId = @MatchId

	SET NOCOUNT OFF
END
GO
