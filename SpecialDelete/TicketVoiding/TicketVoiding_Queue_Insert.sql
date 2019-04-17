/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Insert]
	@RequestId			INT
	,@MatchId			INT
	,@BatchId			INT = NULL
	,@VoidingHistoryId	INT
	,@VoidingTypeId		TINYINT
	,@TotalTicket		INT
	,@TransIds			VARCHAR(MAX)

	,@UserId			INT
	,@IP				VARCHAR(50)
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

	INSERT INTO dbo.TicketVoiding_Queue (
		RequestId
		,MatchId
		,VoidingHistoryId
		,TransIds
		,StatusId
		,UserId
		,Ip
		,VoidingTypeId
		,TotalTicket
	)
	SELECT	@RequestId
			,@MatchId
			,@VoidingHistoryId
			,@TransIds
			,0 -- waiting
			,@UserId
			,@IP
			,@VoidingTypeId
			,@TotalTicket

END
GO

