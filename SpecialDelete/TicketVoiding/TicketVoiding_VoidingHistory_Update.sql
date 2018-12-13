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
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	UPDATE	dbo.TicketVoiding_VoidingHistory 
		SET	StatusId = @StatusId
			,MessageId = @MessageId
			,ReasonId = @ReasonId
	WHERE	VoidingHistoryId = @VoidingHistoryId

END
GO

