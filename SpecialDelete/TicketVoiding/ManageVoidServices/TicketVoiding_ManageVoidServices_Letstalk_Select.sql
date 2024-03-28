/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_Letstalk_Select]
(
	@RequestId				INT
   ,@BroadcastSessionId		VARCHAR(100) = NULL
)
AS
/*	
	Created by: 20230303@July
	Task: [TVS] Manage Void Service - Support web [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230303@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT RequestId 
		  ,BroadcastSessionId
		  ,StatusId
		  ,CreatedDate
		  ,ModifiedDate
	FROM dbo.TicketVoiding_Letstalk WITH(NOLOCK)
	WHERE RequestId = @RequestId 
		AND (BroadcastSessionId = @BroadcastSessionId OR @BroadcastSessionId IS NULL)

END		
GO

