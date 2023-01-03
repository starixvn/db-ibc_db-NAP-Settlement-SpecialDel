/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Service_SelectAll](
	@Mode TINYINT
)
AS
/*	Created by: 20201217@Raymond
	Task: Optimize voiding flow [Redmine: #145719]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20201217@Raymond: Create new SP [Redmine: #145719]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230103@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	IF @Mode = 1  -- get request will run after void
	BEGIN
		SELECT TOP 1 
			  vb.RequestID
			, vb.VoidingHistoryId
			, vb.statusID
			, vb.matchID
			, vh.BroadcastSessionId 
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
			INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vb.RequestID = vh.RequestId
		WHERE vb.statusID = 1
		ORDER BY vb.createdDate ASC
	END
	ELSE IF @Mode = 2 -- get requests will run Lettalk
	BEGIN
		SELECT DISTINCT 
			  vb.RequestID
			, vh.VoidingHistoryId
			, vb.statusID
			, vb.matchID
			, vh.BroadcastSessionId
			, CASE WHEN lt.RequestID IS NULL THEN 1 --Insert
				  WHEN lt.RequestID IS NOT NULL AND lt.statusID = 1 THEN 0 --Update
			  END AS IsInsert 
		FROM dbo.Ticketvoiding_VoidBetAutomation_Service vb WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vb.RequestID = vh.RequestId AND vh.StatusId = 2
			LEFT JOIN dbo.TicketVoiding_Letstalk lt WITH(NOLOCK) ON vb.RequestID = lt.RequestID AND lt.BroadcastSessionId = vh.BroadcastSessionId
		WHERE vb.statusID = 2 AND vh.BroadcastSessionId IS NOT NULL
		AND 1 = CASE WHEN lt.RequestID IS NULL THEN 1
					 WHEN lt.RequestID IS NOT NULL AND lt.statusID = 1 THEN 1
					 ELSE 0 END
	END
END