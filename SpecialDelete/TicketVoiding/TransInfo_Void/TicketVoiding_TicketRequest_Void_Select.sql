/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_TicketRequest_Void_Select] 
(
	@RequestId INT = 0
)
AS
/*	
	Created by: Max
	Date 20221124
	Task: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20221124@Max: Create new SP [Redmine: #180863]

	Param's explanation:	
		- @TransIds: '12343091763609600,12343108943478784'
		
*/
BEGIN
	SET NOCOUNT ON	

	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId

	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId
END

