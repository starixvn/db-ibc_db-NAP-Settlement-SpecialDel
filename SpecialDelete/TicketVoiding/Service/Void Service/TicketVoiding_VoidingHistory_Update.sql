/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Update]
	@VoidingHistoryId	INT
	,@StatusId			TINYINT
	,@MessageId			INT = NULL
	,@ReasonId			INT = NULL
	,@TransIds			VARCHAR(MAX) = NULL
	,@MinWinLostDate	SMALLDATETIME = NULL
	,@MaxWinLostDate	SMALLDATETIME = NULL
	,@MessageIdSpecial	INT = NULL
AS
/*	
	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20231213@Max: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	UPDATE	dbo.TicketVoiding_VoidingHistory WITH(ROWLOCK, UPDLOCK)
		SET	StatusId = @StatusId
			,MessageId = ISNULL(@MessageId, MessageId)
			,ReasonId = ISNULL(@ReasonId, ReasonId)
			,TransIds = ISNULL(@TransIds, TransIds)
			,MinWinlostdate = ISNULL(@MinWinLostDate, MinWinlostdate)
			,MaxWinlostdate = ISNULL(@MaxWinLostDate, MaxWinlostdate)
			,ModifiedDate = GETDATE()
			,MessageIdSpecial = ISNULL(@MessageIdSpecial, MessageIdSpecial)
	WHERE	VoidingHistoryId = @VoidingHistoryId
END
GO

