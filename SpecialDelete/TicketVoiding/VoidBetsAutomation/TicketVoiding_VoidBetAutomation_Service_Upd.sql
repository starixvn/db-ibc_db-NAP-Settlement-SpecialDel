/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_Upd]
(
	@SessionId 						INT = NULL,
	@UpdateType						INT,
	@StatusId						INT = NULL,
	@RequestId						INT = NULL,
	@VoidingHistoryId				INT = NULL,
	@MessageId						INT = NULL,
	@ReasonId						INT = NULL,
	@IsSentBatchMessage				BIT = NULL,
	@IsSentMessageToAdminSite 		BIT = NULL,
	@IsInsertedVoidedTransaction	BIT = NULL,
	@IsUpdatedVoidingHistory		BIT = NULL,
	@IsSentEmail					BIT = NULL,
	@IsRunExternalService			BIT = NULL,
	@IsSentLetsTalk					BIT = NULL,
	@VoidResults					XML = NULL
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200215@Max: Create new SP [Redmine: #128359]
		- 20201203@Charles: Optimize Voiding Workflow [Redmine: #145719]
	
	Param's explanation:
	- @UpdateType:
			   1: Update status by VoidingHistory
			   2: Update status by session
			   3: Update MessageId by VoidingHistory
			   4: Update MessageId by Session
			   5: Update after void step
			   6: Update all after void steps
			   7: Update Emails Result By VoidingHistory
	
*/
BEGIN
	SET NOCOUNT ON
	IF @UpdateType = 1
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET statusID = @StatusId
			,ModifiedDate = GETDATE()
		WHERE RequestId = @RequestId AND VoidingHistory = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 2
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET statusID = @StatusId
			,ModifiedDate = GETDATE()
		WHERE SessionID = @SessionId
	END
	ELSE IF @UpdateType = 3
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET MessageId = @MessageId
			,ModifiedDate = GETDATE()
		WHERE RequestId = @RequestId AND VoidingHistory = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 4
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET MessageId = @MessageId
			,ModifiedDate = GETDATE()
		WHERE SessionID = @SessionId
	END
	ELSE IF @UpdateType = 5
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET ModifiedDate = GETDATE()
			,MessageId = ISNULL(@MessageId, MessageId)
			,ReasonId = ISNULL(@ReasonId, ReasonId)
			,IsSentBatchMessage = ISNULL(@IsSentBatchMessage, IsSentBatchMessage)
			,IsSentMessageToAdminSite = ISNULL(@IsSentMessageToAdminSite, IsSentMessageToAdminSite)
			,IsInsertedVoidedTransaction = ISNULL(@IsInsertedVoidedTransaction, IsInsertedVoidedTransaction)
			,IsUpdatedVoidingHistory = ISNULL(@IsUpdatedVoidingHistory, IsUpdatedVoidingHistory)
			,IsSentEmail = ISNULL(@IsSentEmail, IsSentEmail)
			,IsRunExternalService = ISNULL(@IsRunExternalService, IsRunExternalService)
			,IsSentLetsTalk = ISNULL(@IsSentLetsTalk, IsSentLetsTalk)
			,VoidResults = ISNULL(@VoidResults, VoidResults)
		WHERE RequestId = @RequestId AND VoidingHistory = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 6
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET ModifiedDate = GETDATE()
			,MessageId = @MessageId
			,ReasonId = @ReasonId
			,IsSentBatchMessage = @IsSentBatchMessage
			,IsSentMessageToAdminSite = @IsSentMessageToAdminSite
			,IsInsertedVoidedTransaction = @IsInsertedVoidedTransaction
			,IsUpdatedVoidingHistory = @IsUpdatedVoidingHistory
			,IsSentEmail = @IsSentEmail
			,IsRunExternalService = @IsRunExternalService
			,IsSentLetsTalk = @IsSentLetsTalk
			,VoidResults = ISNULL(@VoidResults, VoidResults)
		WHERE RequestId = @RequestId AND VoidingHistory = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 7
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET VoidResults = @VoidResults
			,ModifiedDate = GETDATE()
		WHERE RequestId = @RequestId AND VoidingHistory = @VoidingHistoryId
	END
END