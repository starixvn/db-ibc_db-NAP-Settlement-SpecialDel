/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Insert]
(
	@BroadcastSessionId VARCHAR(50)
	,@RequestId INT
	,@MatchId INT
	,@StatusId TINYINT
	,@Action	VARCHAR(50)
	,@UserId INT = 0
	,@IP VARCHAR(50) = ''
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, BroadcastSessionId)
	SELECT @RequestId, @MatchId, @Action, @StatusId, @UserId, GETDATE(), @IP, @BroadcastSessionId

END		
GO


