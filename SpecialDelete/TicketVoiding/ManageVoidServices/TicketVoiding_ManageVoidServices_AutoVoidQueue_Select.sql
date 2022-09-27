/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_AutoVoidQueue_Select]
(
	@BroadcastSessionId		VARCHAR(100)
)
AS
/*	
	Created by: July
	Date 20220927
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
		  ,Action
		  ,StatusId
		  ,BroadcastSessionId
		  ,sporttype
		  ,ErrMsg
		  ,Starttime
		  ,Exectime
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH(NOLOCK)
	WHERE BroadcastSessionId = @BroadcastSessionId

END		
GO


