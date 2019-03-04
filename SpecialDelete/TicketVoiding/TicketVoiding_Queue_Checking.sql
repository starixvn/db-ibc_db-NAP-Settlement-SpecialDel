/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Checking]
	@VoidingHistoryId INT
AS
/*	Created by: Kathy
	Date 20181212
	Task: get queue's status [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	q.MatchId
			,q.TotalTicket
			,q.ErrMsg
			,q.StatusId
			,q.FailedTransIds
			,q.NegativeBalanceUsers
	FROM	dbo.TicketVoiding_Queue q WITH(NOLOCK)
	WHERE	q.VoidingHistoryId = @VoidingHistoryId

END
GO

