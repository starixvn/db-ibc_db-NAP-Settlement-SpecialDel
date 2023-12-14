/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_Upd]
(
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
	@VoidResults					XML = NULL,
	@MessageIdSpecial				INT = NULL
)
AS
/*	Created by: 20200212@Max
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20200215@Max: Create new SP [Redmine: #128359]
		- 20201203@Charles: Optimize Voiding Workflow [Redmine: #145719]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230103@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20231213@Max: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		
	Param's explanation:
	- @UpdateType:
			   1: Update status by VoidingHistory
			   3: Update MessageId by VoidingHistory
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
		WHERE RequestId = @RequestId AND VoidingHistoryId = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 3
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET MessageId = @MessageId
			,MessageIdSpecial = @MessageIdSpecial
			,ModifiedDate = GETDATE()
		WHERE RequestId = @RequestId AND VoidingHistoryId = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 5
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET ModifiedDate = GETDATE()
			,MessageId = ISNULL(@MessageId, MessageId)
			,@MessageIdSpecial = ISNULL(@MessageIdSpecial, @MessageId)
			,ReasonId = ISNULL(@ReasonId, ReasonId)
			,IsSentBatchMessage = ISNULL(@IsSentBatchMessage, IsSentBatchMessage)
			,IsSentMessageToAdminSite = ISNULL(@IsSentMessageToAdminSite, IsSentMessageToAdminSite)
			,IsInsertedVoidedTransaction = ISNULL(@IsInsertedVoidedTransaction, IsInsertedVoidedTransaction)
			,IsUpdatedVoidingHistory = ISNULL(@IsUpdatedVoidingHistory, IsUpdatedVoidingHistory)
			,IsSentEmail = ISNULL(@IsSentEmail, IsSentEmail)
			,IsRunExternalService = ISNULL(@IsRunExternalService, IsRunExternalService)
			,VoidResults = ISNULL(@VoidResults, VoidResults)
		WHERE RequestId = @RequestId AND VoidingHistoryId = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 6
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET ModifiedDate = GETDATE()
			,MessageId = @MessageId
			,MessageIdSpecial= @MessageIdSpecial
			,ReasonId = @ReasonId
			,IsSentBatchMessage = @IsSentBatchMessage
			,IsSentMessageToAdminSite = @IsSentMessageToAdminSite
			,IsInsertedVoidedTransaction = @IsInsertedVoidedTransaction
			,IsUpdatedVoidingHistory = @IsUpdatedVoidingHistory
			,IsSentEmail = @IsSentEmail
			,IsRunExternalService = @IsRunExternalService
			,VoidResults = ISNULL(@VoidResults, VoidResults)
		WHERE RequestId = @RequestId AND VoidingHistoryId = @VoidingHistoryId
	END
	ELSE IF @UpdateType = 7
	BEGIN
		UPDATE Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK, UPDLOCK)
		SET VoidResults = @VoidResults
			,ModifiedDate = GETDATE()
		WHERE RequestId = @RequestId AND VoidingHistoryId = @VoidingHistoryId
	END
END