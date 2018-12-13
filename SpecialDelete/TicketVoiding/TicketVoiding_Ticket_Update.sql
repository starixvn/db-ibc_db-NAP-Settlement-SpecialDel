/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Ticket_Update]
	@MatchId			INT
	,@TransIds			VARCHAR(MAX)
	,@VoidingHistoryId	INT
	,@VoidingTypeId		TINYINT
	,@UserId			INT
	,@IP				VARCHAR(50)

	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
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

	
	IF @VoidingTypeId = 1 -- Single
	BEGIN
		EXEC dbo.TicketVoiding_SingleType_Update
			@MatchId = @MatchId	
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@Reason = ''		
			,@ErrCode = @ErrCode OUTPUT	
			,@ErrMsg = @ErrMsg OUTPUT

	END
	ELSE IF @VoidingTypeId = 2 -- subParlay
	BEGIN
		EXEC dbo.TicketVoiding_ParlayType_Update
			@MatchId = @MatchId			
			,@VoidingHistoryId = @VoidingHistoryId
			,@TransIds = @TransIds
			,@UserId = @UserId
			,@IP = @IP
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END
	
END
GO

