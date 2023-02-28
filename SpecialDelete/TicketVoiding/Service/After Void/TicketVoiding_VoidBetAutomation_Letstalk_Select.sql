/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Letstalk_Select]
AS
/*	Created by: 20230117@July
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230117@July: Create new SP - get requests will run Letstalk [Redmine: #180625]
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @BroadcastSessionId VARCHAR(100)
		  , @min_RequestId		INT
		  , @cnt_RequestId		INT

	DECLARE @tmpResultLetstalk TABLE (
			 RequestID			INT
			,VoidingHistoryId	INT
			,MatchID			INT
			,BroadcastSessionId VARCHAR(100)
			,SiteDBGroupID		SMALLINT
			,IsAutoVoid			BIT
			,cnt				INT
	)
		
	INSERT INTO @tmpResultLetstalk (RequestID, VoidingHistoryId, MatchID, BroadcastSessionId, SiteDBGroupID, IsAutoVoid)
	SELECT DISTINCT 
			vb.RequestID
			, vh.VoidingHistoryId
			, vb.MatchID
			, vh.BroadcastSessionId
			, vh.SiteDBGroupID
			, vb.IsAutoVoid
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
		INNER JOIN dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK) ON vh.RequestID = vb.RequestId AND vh.VoidingHistoryId = vb.VoidingHistoryId  
		LEFT JOIN dbo.TicketVoiding_Letstalk lt WITH(NOLOCK) ON vh.RequestID = lt.RequestID AND lt.BroadcastSessionId = vh.BroadcastSessionId
	WHERE  vh.BroadcastSessionId IS NOT NULL AND vh.StatusId = 2 AND vb.statusID = 2
		AND 1 = CASE WHEN lt.BroadcastSessionId IS NULL THEN 1
					 WHEN lt.BroadcastSessionId IS NOT NULL AND lt.StatusId = 1 THEN 1
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

	SELECT @cnt_RequestId = COUNT(DISTINCT RequestId)
	FROM  TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
	WHERE BroadcastSessionId = @BroadcastSessionId
	
	IF @cnt_RequestId = 1 --1 BroadcastSessionId, 1 RequestId, many VoidingHistoryId
	BEGIN
		SELECT  RequestID
			  , VoidingHistoryId
			  , MatchID
			  , BroadcastSessionId
			  , SiteDBGroupID
			  , IsAutoVoid
		FROM @tmpResultLetstalk t
			CROSS APPLY ( SELECT COUNT(BroadcastSessionId) as cnt
							FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
							WHERE t.RequestID = vh.RequestID AND t.BroadcastSessionId = vh.BroadcastSessionId
							GROUP BY BroadcastSessionId
					)a
		WHERE t.cnt = a.cnt AND t.BroadcastSessionId = @BroadcastSessionId
	END
	ELSE --Case auto void winning: 1 BroadcastSessionId, many RequestIds, many VoidingHistoryIds => Get 1 min_RequestID 
	BEGIN
		SELECT  RequestID
			  , VoidingHistoryId
			  , MatchID
			  , BroadcastSessionId
			  , SiteDBGroupID
			  , IsAutoVoid
		FROM @tmpResultLetstalk t
			CROSS APPLY ( SELECT COUNT(vh.BroadcastSessionId) as cnt
							FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
								INNER JOIN dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK) ON vh.RequestID = vb.RequestId AND vh.VoidingHistoryId = vb.VoidingHistoryId
								LEFT JOIN dbo.TicketVoiding_Letstalk lt WITH(NOLOCK) ON vh.RequestID = lt.RequestID AND lt.BroadcastSessionId = vh.BroadcastSessionId
							WHERE t.BroadcastSessionId = vh.BroadcastSessionId AND vh.RequestId >= @min_RequestId
								AND vb.statusID = 2 AND vh.StatusId = 2 AND lt.BroadcastSessionId IS NULL
							GROUP BY vh.BroadcastSessionId
					)a
		WHERE t.cnt = a.cnt AND t.BroadcastSessionId = @BroadcastSessionId
			
	END
END