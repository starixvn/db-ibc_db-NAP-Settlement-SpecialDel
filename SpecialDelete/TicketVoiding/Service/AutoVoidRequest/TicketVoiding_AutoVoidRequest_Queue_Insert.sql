/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Insert]
(
	 @RequestIds			VARCHAR(MAX)
	,@StatusId				TINYINT
	,@Action				VARCHAR(50)
	,@BroadcastSessionId	VARCHAR(100) = NULL
	,@MatchId				INT = 0
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.TicketVoiding_AutoVoidQueue(RequestIds, MatchId, [Action], StatusId, CreatedDate, BroadcastSessionId)
	SELECT @RequestIds, @MatchId, @Action, @StatusId, GETDATE(), @BroadcastSessionId

END		
GO




