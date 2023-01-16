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

	DECLARE @BroadcastSessionId VARCHAR(100)
	
	IF @Mode = 1  -- get request will run after void
	BEGIN
		DECLARE @xmlVoidResults XML = NULL
			  , @VoidingHistoryId INT

		DECLARE @tmpResultAfterVoid TABLE (
			RequestID INT
			,VoidingHistoryId INT
			,statusID INT
			,matchID INT
			,BroadcastSessionId VARCHAR(100)
			,NegativeBalanceUsers VARCHAR(100)
			,IsAutoVoid BIT
			,IsRunExternalService BIT
			,MessageId INT
			,ReasonId INT
			,IsSentBatchMessage BIT
			,IsSentMessageToAdminSite BIT
			,IsInsertedVoidedTransaction BIT
			,IsUpdatedVoidingHistory BIT
			,IsSentEmail BIT
			,IsSentLetsTalk BIT
			,SiteDBGroupID SMALLINT
		)
		DECLARE @tmpVoidingHistory_Service TABLE
		(
			RequestId INT
			,VoidingHistoryId INT
			,VoidingHistoryStatusId TINYINT
			,AfterVoidStatusId TINYINT
			,VoidResults XML
			,IsFinish BIT
		)
		
		DECLARE @tmpVoidResults TABLE ( VoidingHistoryId INT, Message VARCHAR(MAX), Type INT, Licensees VARCHAR(MAX))

		INSERT INTO @tmpResultAfterVoid (RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId , NegativeBalanceUsers
								, IsAutoVoid, IsRunExternalService, MessageId, ReasonId, IsSentBatchMessage, IsSentMessageToAdminSite
								, IsInsertedVoidedTransaction, IsUpdatedVoidingHistory, IsSentEmail, IsSentLetsTalk, SiteDBGroupID
		)
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
		
		SELECT @BroadcastSessionId = BroadcastSessionId FROM @tmpResultAfterVoid

		INSERT INTO @tmpVoidingHistory_Service(RequestId, VoidingHistoryId, VoidingHistoryStatusId, AfterVoidStatusId, VoidResults) 
		SELECT	 vh.RequestId
				,vh.VoidingHistoryId
				,vh.StatusId AS VoidingHistoryStatusId
				,vb.StatusId AS AfterVoidStatusId
				,vb.VoidResults
		FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
			INNER JOIN Ticketvoiding_VoidBetAutomation_Service vb WITH(NOLOCK) ON vh.RequestId = vb.RequestID AND vh.VoidingHistoryId = vb.VoidingHistoryId
		WHERE vh.BroadcastSessionId = @BroadcastSessionId 
			AND vh.StatusId <> 1

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1) t
			SET IsFinish = 1
				,@VoidingHistoryId = T.VoidingHistoryId
				,@xmlVoidResults = T.VoidResults
			FROM @tmpVoidingHistory_Service t
			WHERE t.IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			INSERT INTO @tmpVoidResults ( VoidingHistoryId, Message, Type, Licensees)
			SELECT  @VoidingHistoryId,
					T.C.value('@Message', 'VARCHAR(MAX)') AS Message
					,T.C.value('@Type', 'INT') AS Type
					,T.C.value('@Licensees', 'VARCHAR(MAX)') AS Licensees
			FROM	@xmlVoidResults.nodes('/VoidResults/VoidResult') as [T](C)
			OPTION (OPTIMIZE FOR (@xmlVoidResults = NULL ))
		END						


		--Table #1
		SELECT RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId , NegativeBalanceUsers
			, IsAutoVoid, IsRunExternalService, MessageId, ReasonId, IsSentBatchMessage, IsSentMessageToAdminSite
			, IsInsertedVoidedTransaction, IsUpdatedVoidingHistory, IsSentEmail, IsSentLetsTalk, SiteDBGroupID
		FROM @tmpResultAfterVoid

		--Table #2
		SELECT VoidingHistoryId, VoidingHistoryStatusId, AfterVoidStatusId
		FROM @tmpVoidingHistory_Service

		--Table #3
		SELECT VoidingHistoryId, Message, Type, Licensees
		FROM @tmpVoidResults

	END
	ELSE IF @Mode = 2 -- get requests will run Letstalk
	BEGIN
		DECLARE @tmpResultLetstalk TABLE (RequestID INT, VoidingHistoryId INT, statusID TINYINT, matchID INT, BroadcastSessionId VARCHAR(100) ,SiteDBGroupID SMALLINT, IsInsert BIT, cnt INT)
		DECLARE @min_RequestId INT, @IsAutoVoid BIT
		
		INSERT INTO @tmpResultLetstalk (RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId, SiteDBGroupID, IsInsert)
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
		INNER JOIN dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK) ON vh.RequestID = vb.RequestId AND vh.VoidingHistoryId = vb.VoidingHistoryId  
		LEFT JOIN dbo.TicketVoiding_Letstalk lt WITH(NOLOCK) ON vh.RequestID = lt.RequestID AND lt.BroadcastSessionId = vh.BroadcastSessionId
		WHERE  vh.BroadcastSessionId IS NOT NULL AND vh.StatusId = 2 AND vb.statusID = 2
		AND 1 = CASE WHEN lt.BroadcastSessionId IS NULL  THEN 1
					 WHEN lt.BroadcastSessionId IS NOT NULL AND lt.statusID = 1 THEN 1
					ELSE 0 END
					
		UPDATE t1
		SET cnt = t2.cnt_BroadcastSessionId
		FROM @tmpResultLetstalk t1
		 CROSS APPLY (
			SELECT COUNT (BroadcastSessionId) cnt_BroadcastSessionId
			FROM @tmpResultLetstalk t2
			WHERE t1.BroadcastSessionId = t2.BroadcastSessionId
			GROUP BY BroadcastSessionId
			)t2
		SELECT @min_RequestId =  MIN(RequestID) FROM @tmpResultLetstalk 

		DELETE FROM @tmpResultLetstalk WHERE RequestID > @min_RequestId

		SELECT @BroadcastSessionId = t1.BroadcastSessionId
		FROM @tmpResultLetstalk t1
		CROSS APPLY (
					SELECT MIN(VoidingHistoryId) AS VoidingHistoryId
					FROM @tmpResultLetstalk t2
					WHERE t1.RequestID = t2.RequestID
					)t2
		WHERE t1.VoidingHistoryId = t2.VoidingHistoryId

		SELECT @IsAutoVoid = CASE WHEN ActionId IN (1,4,6,7,8) THEN 1 ELSE 0 END
		FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @min_RequestId

		----Table #1 Get 1 RequestId, 1 BroadcastSessionId many VoidingHistoryId
		SELECT  RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId, SiteDBGroupID, IsInsert, @IsAutoVoid AS IsAutoVoid
		FROM @tmpResultLetstalk t
			CROSS APPLY ( SELECT COUNT(BroadcastSessionId) as cnt
						  FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
						  WHERE t.RequestID = vh.RequestId AND t.BroadcastSessionId = vh.BroadcastSessionId

						  GROUP BY BroadcastSessionId
					)a
		WHERE t.cnt = a.cnt AND t.BroadcastSessionId = @BroadcastSessionId
	END
END