/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ManageVoidServices_Queue_Update]
(
	@QueueIds	VARCHAR(MAX) = NULL
   ,@StatusId	TINYINT
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
	DECLARE @tmpQueueId TABLE (QueueId INT)
	
	INSERT INTO @tmpQueueId (QueueId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@QueueIds, ',')
	WHERE value <> ''

	UPDATE q WITH(ROWLOCK, UPDLOCK)
	SET StatusId = @StatusId
	FROM dbo.TicketVoiding_Queue q 
		INNER JOIN @tmpQueueId tmp ON q.QueueId = tmp.QueueId

END		
GO


