/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TicketRequest_Void_Select] 
(
	@RequestId INT = 0
  , @RequestDetailId INT = NULL --Support WMO(12) issuetype
)
AS
/*	
	Created by: 20221124@Max
	Task: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20221124@Max: Create new SP [Redmine: #180863]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]

	Param's explanation:	
		- @TransIds: '12343091763609600,12343108943478784'
		
*/
BEGIN
	SET NOCOUNT ON	

	--Single ticket (exclude cancel CO)
	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId AND ISNULL(IsCancelCO,0) = 0
			AND (s.RequestDetailId = @RequestDetailId OR @RequestDetailId IS NULL)

	--Parlay ticket 
	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId
			AND (s.RequestDetailId = @RequestDetailId OR @RequestDetailId IS NULL)

	--Cancel CO ticket
	SELECT s.TransId, s.MatchId, s.SiteDBGroupID
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
	WHERE s.RequestId = @RequestId AND IsCancelCO = 1
			AND (s.RequestDetailId = @RequestDetailId OR @RequestDetailId IS NULL)
END

