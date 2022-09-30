/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_VoidService_Select]
(
	@BroadcastSessionId		VARCHAR(100) = NULL
   ,@RequestId				INT = NULL
)
AS
/*	
	Created by: July
	Date 20220927
	Task: [TVS] Manage Void Service - Support web [Redmine: #178172]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220927@July: Create new SP [Redmine:#178172]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	IF @BroadcastSessionId IS NOT NULL
	BEGIN
		SELECT Id
			  ,BroadcastSessionId
			  ,SiteDBGroupID
			  ,RequestId
			  ,VoidingHistoryId
			  ,StatusId
			  ,IsAutoVoid
			  ,MatchId
			  ,CreatedDate
			  ,ModifiedDate
		FROM dbo.TicketVoiding_Void_Service q WITH(NOLOCK)
		WHERE BroadcastSessionId = @BroadcastSessionId
	END
	ELSE IF @RequestId IS NOT NULL
	BEGIN
		SELECT Id
			  ,BroadcastSessionId
			  ,SiteDBGroupID
			  ,RequestId
			  ,VoidingHistoryId
			  ,StatusId
			  ,IsAutoVoid
			  ,MatchId
			  ,CreatedDate
			  ,ModifiedDate
		FROM dbo.TicketVoiding_Void_Service q WITH(NOLOCK)
		WHERE RequestId = @RequestId
	END
END		
GO


