/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Insert]
	@RequestId INT
	,@UserId INT
	,@TransIds VARCHAR(MAX) = ''
	,@VoidingHistoryId INT = 0 OUTPUT
	,@VoidData XML = NULL
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20201202@Charles: Insert data for new VoidData column [Redmine:#143666]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.TicketVoiding_VoidingHistory (
			RequestId
			,UserId
			,StatusId
			,TransIds
			,VoidData
		)
	SELECT	@RequestId
			,@UserId
			,1 -- running
			,@TransIds
			,@VoidData
	SET @VoidingHistoryId = SCOPE_IDENTITY()

END
GO

