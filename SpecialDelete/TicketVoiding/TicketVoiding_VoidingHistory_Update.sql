/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Update]
	@VoidingHistoryId	INT
	,@StatusId			TINYINT
	,@MessageId			INT
	,@ReasonId			INT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]\
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	UPDATE	dbo.TicketVoiding_VoidingHistory WITH(ROWLOCK, UPDLOCK)
		SET	StatusId = @StatusId
			,MessageId = CASE WHEN @StatusId <> 1 THEN @MessageId ELSE MessageId END
			,ReasonId = CASE WHEN @StatusId <> 1 THEN  @ReasonId ELSE ReasonId END
	WHERE	VoidingHistoryId = @VoidingHistoryId

END
GO

