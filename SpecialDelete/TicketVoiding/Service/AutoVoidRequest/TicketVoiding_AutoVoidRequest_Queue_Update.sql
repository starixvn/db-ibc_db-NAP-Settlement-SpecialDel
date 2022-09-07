/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Update]
(
	@QueueId INT
	,@StatusId INT = NULL
	,@ErrMsg VARCHAR(1000) = NULL
	,@IsUpdateStartTime BIT = 0
	,@BroadcastsessionId VARCHAR(100) = NULL
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

	UPDATE q SET 
		q.StatusId = ISNULL(@StatusId, q.StatusId)
		,q.Starttime = CASE WHEN @IsUpdateStartTime = 1 THEN GETDATE() ELSE q.Starttime END
		,q.BroadcastSessionId = ISNULL(@BroadcastsessionId, q.BroadcastSessionId)
		,q.ErrMsg = @ErrMsg		
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH (ROWLOCK, UPDLOCK)
	WHERE q.QueueId = @QueueId	

END		
GO


