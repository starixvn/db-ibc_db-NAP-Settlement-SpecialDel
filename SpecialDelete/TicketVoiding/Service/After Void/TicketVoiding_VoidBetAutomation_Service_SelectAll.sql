/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_SelectAll]
AS
/*	Created by: Raymond
	Date 20201217
	Task: Optimize voiding flow [Redmine: #145719]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20201217@Raymond: Create new SP [Redmine: #145719]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	
	Param's explanation:	
		- @StatusId: 1 - DBJobRunning
					 2 - DBJobDone
					 3 - DBJobFailed
					 12 - WinServiceDone
					 13 - WinServiceFailed
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SessionId INT
	SELECT @SessionId = (SELECT MIN(SessionID) 
						FROM dbo.Ticketvoiding_VoidBetAutomation_Service vb WITH(NOLOCK) 
						WHERE statusID = 1 
						AND NOT EXISTS (
										SELECT TOP 1 1
										FROM dbo.Ticketvoiding_VoidBetAutomation_Service temp WITH(NOLOCK)
										WHERE vb.SessionID = temp.SessionID AND temp.statusID IN (1,3,13)
									))
	
	-- get requests will run after void
	SELECT vb.RequestID
		, vb.VoidingHistory
		, vb.statusID
		, vb.matchID
		, vb.SessionID
		, vb.NegativeBalanceUsers
		, vb.IsAutoVoid
		, vb.IsRunExternalService
		, vb.MessageId
		, vb.ReasonId
		, vb.IsSentBatchMessage
		, vb.IsSentMessageToAdminSite
		, vb.IsInsertedVoidedTransaction
		, vb.IsUpdatedVoidingHistory
		, vb.IsSentEmail
		, vb.IsSentLetsTalk
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service vb WITH (NOLOCK)
	WHERE vb.SessionID = @SessionId
END