/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_TicketRequest_Void_Select] 
(
	@RequestId INT = 0
)
AS
/*	
	Created by: 20221124@Max
	Task: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20221124@Max: Create new SP [Redmine: #180863]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]

	Param's explanation:	
		- @TransIds: '12343091763609600,12343108943478784'
		
*/
BEGIN
	SET NOCOUNT ON	

	--Single ticket (exclude cancel CO)
	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId AND ISNULL(IsCancelCO,0) = 0

	--Parlay ticket 
	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId

	--Cancel CO ticket
	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId AND IsCancelCO = 1
END

