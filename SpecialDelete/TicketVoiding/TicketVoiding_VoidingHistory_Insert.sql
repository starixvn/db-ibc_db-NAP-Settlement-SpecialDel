/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Insert]
	@RequestId INT
	,@UserId INT
	
	,@VoidingHistoryId INT = 0 OUTPUT
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

	INSERT INTO dbo.TicketVoiding_VoidingHistory (
			RequestId
			,UserId
			,StatusId
		)
	SELECT	@RequestId
			,@UserId
			,1 -- running

	SET @VoidingHistoryId = SCOPE_IDENTITY()

END
GO

