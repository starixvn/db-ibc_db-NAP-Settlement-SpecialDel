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
			, vh.SiteDBGroupID
		FROM dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vb.RequestID = vh.RequestId AND vb.VoidingHistoryId = vh.VoidingHistoryId
		WHERE vb.statusID = 1
		ORDER BY vb.createdDate ASC
	END
	ELSE IF @Mode = 2 -- get requests will run Lettalk
	BEGIN
		DECLARE @tmpResult TABLE (RequestID INT, VoidingHistoryId INT, statusID TINYINT, matchID INT, BroadcastSessionId VARCHAR(100) ,SiteDBGroupID SMALLINT, IsInsert BIT, cnt INT)
		DECLARE @min_RequestId INT, @IsAutoVoid BIT
		
		INSERT INTO @tmpResult (RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId, SiteDBGroupID, IsInsert)
		SELECT DISTINCT 
			  	vb.RequestID
				, vh.VoidingHistoryId
				, vb.statusID
				, vb.matchID
				, vh.BroadcastSessionId
				, vh.SiteDBGroupID
				, CASE WHEN lt.BroadcastSessionId IS NULL  THEN 1 --Insert
					   WHEN lt.BroadcastSessionId IS NOT NULL AND lt.statusID = 1 THEN 0--Update
					 END AS IsInsert 
		FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
		LEFT JOIN dbo.TicketVoiding_Letstalk lt WITH(NOLOCK) ON vh.RequestID = lt.RequestID AND lt.BroadcastSessionId = vh.BroadcastSessionId
		INNER JOIN dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK) ON vh.VoidingHistoryId = vb.VoidingHistoryId
		WHERE  vh.BroadcastSessionId IS NOT NULL AND vh.StatusId = 2 AND vb.statusID = 2
		AND 1 = CASE WHEN lt.BroadcastSessionId IS NULL  THEN 1
					 WHEN lt.BroadcastSessionId IS NOT NULL AND lt.statusID = 1 THEN 1
					ELSE 0 END
					
		UPDATE t1
		SET cnt = t2.cnt_BroadcastSessionId
		FROM @tmpResult t1
		 CROSS APPLY (
			SELECT COUNT (BroadcastSessionId) cnt_BroadcastSessionId
			FROM @tmpResult t2
			WHERE t1.BroadcastSessionId = t2.BroadcastSessionId
			GROUP BY BroadcastSessionId
			)t2

		SELECT @min_RequestId =  MIN(RequestID)
		FROM @tmpResult 

		SELECT @IsAutoVoid = CASE WHEN ActionId IN (1,4,6,7,8) THEN 1 ELSE 0 END
		FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @min_RequestId

		SELECT  RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId, SiteDBGroupID, IsInsert, @IsAutoVoid AS IsAutoVoid
		FROM @tmpResult t
			CROSS APPLY ( SELECT COUNT(BroadcastSessionId) as cnt
						  FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
						  WHERE t.RequestID = vh.RequestId AND t.BroadcastSessionId = vh.BroadcastSessionId
						  GROUP BY BroadcastSessionId
					)a
		WHERE t.cnt = a.cnt AND t.RequestID = @min_RequestId
	END
END