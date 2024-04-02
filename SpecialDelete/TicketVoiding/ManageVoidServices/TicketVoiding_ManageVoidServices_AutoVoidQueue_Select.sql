/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_AutoVoidQueue_Select]
(
	@BroadcastSessionId		VARCHAR(100) = NULL
	,@StatusId				TINYINT  = NULL
)
AS
/*	
	Created by: 20220927@July
	Task: [TVS] Manage Void Service - Support web [Redmine: #178172]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220927@July: Create new SP [Redmine:#178172]
		- 20230303@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteDBGroupID	SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	IF @BroadcastSessionId IS NOT NULL
	BEGIN
		SELECT @SiteDBGroupID AS SiteDBGroupID
			  ,QueueId
			  ,RequestIds
			  ,MatchId
			  ,Action
			  ,StatusId
			  ,CreatedDate
			  ,ModifiedDate
			  ,ErrMsg
			  ,BroadcastSessionId
		FROM dbo.TicketVoiding_AutoVoidQueue WITH(NOLOCK)
		WHERE BroadcastSessionId = @BroadcastSessionId
	END
	ELSE IF @StatusId IS NOT NULL
	BEGIN
		SELECT TOP 100
			  @SiteDBGroupID AS SiteDBGroupID
			  ,QueueId
			  ,RequestIds
			  ,MatchId
			  ,Action
			  ,StatusId
			  ,CreatedDate
			  ,ModifiedDate
			  ,ErrMsg
			  ,BroadcastSessionId
		FROM dbo.TicketVoiding_AutoVoidQueue WITH(NOLOCK)
		WHERE StatusId = @StatusId
		ORDER BY QueueId DESC
	END

END		
GO


