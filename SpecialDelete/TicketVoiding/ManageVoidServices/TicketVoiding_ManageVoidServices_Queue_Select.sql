/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_Queue_Select]
(
	@VoidingHistoryId	INT
)
AS
/*	
	Created by: 20220927@July
	Task: [TVS] Manage Void Service - Support web [Redmine: #178172]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220927@July: Create new SP [Redmine:#178172]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteDBGroupID	SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SELECT @SiteDBGroupID AS SiteDBGroupID
		  ,QueueId
		  ,RequestId
		  ,MatchId
		  ,VoidingHistoryId
		  ,StatusId
		  ,TransIds
		  ,UserId
		  ,Starttime
		  ,Exectime
		  ,Duration
		  ,TotalTicket
		  ,VoidingTypeId
		  ,IssueTypeId
		  ,NegativeBalanceUsers
		  ,FailedTransIds
		  ,ErrMsg
	FROM dbo.TicketVoiding_Queue WITH(NOLOCK)
	WHERE VoidingHistoryId = @VoidingHistoryId

END		
GO