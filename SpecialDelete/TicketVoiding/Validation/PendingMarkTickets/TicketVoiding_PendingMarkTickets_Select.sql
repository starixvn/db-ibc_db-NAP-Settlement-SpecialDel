/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_PendingMarkTickets_Select]
/*	
	Created by: 20250610@July
	Task: [TVS] Enhance TVS in case 1 or many siteDBs down - Add/Edit request [Redmine: #228047]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20250610@July: Create new SP [Redmine: #228047]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MarkTransIds VARCHAR(MAX) =''

	SELECT t.TransId
		  ,t.MatchId
		  ,t.StatusId
		  ,t.SiteDBGroupID
		  ,t.RequestId
	FROM dbo.TicketVoiding_PendingMarkTickets AS t WITH (NOLOCK)
	WHERE t.StatusId IN (1) -- Only Running

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(TransId AS VARCHAR(50)) 
										FROM dbo.TicketVoiding_PendingMarkTickets WITH (NOLOCK)
										WHERE StatusId IN (1) -- Only Running
										FOR XML PATH('')), 1,1,''),'')
	
	SELECT @MarkTransIds AS MarkTransIds

END
GO