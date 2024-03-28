/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_Sel]
(
	@RequestId INT = 0,
	@VoidingHistoryID INT = 0
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20200215@Max: Create new SP [Redmine: #128359]
		- 20201203@Charles: Optimize Voiding Workflow [Redmine: #145719]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20231213@Max: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	SELECT tvs.RequestID
			, tvs.VoidingHistoryId AS VoidingHistoryId
			, tvs.statusID
			, tvs.matchID
			, tvs.SessionID
			, tvs.NegativeBalanceUsers
			, tvs.IsAutoVoid
			, tvs.IsRunExternalService
			, tvs.MessageId
			, tvs.ReasonId
			, tvs.IsSentBatchMessage
			, tvs.IsSentMessageToAdminSite
			, tvs.IsInsertedVoidedTransaction
			, tvs.IsUpdatedVoidingHistory
			, tvs.IsSentEmail
			, tvs.MessageIdSpecial
			, tvs.IsDeletedMessage
			, tvs.IsDeletedVoidedTransaction
			, tvs.IsDeletedzzzBettrans
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service tvs WITH(NOLOCK) 
	WHERE tvs.RequestID = @RequestId AND tvs.VoidingHistoryId = @VoidingHistoryID
END