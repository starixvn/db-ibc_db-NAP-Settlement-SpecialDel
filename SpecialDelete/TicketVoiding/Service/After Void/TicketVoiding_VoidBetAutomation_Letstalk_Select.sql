/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_Letstalk_Select]
AS
/*	Created by: 20230117@July
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230117@July: Create new SP - get requests will run Letstalk [Redmine: #180625]
		- 20240925@Max: Exclude recover issuetype [Redmine: #186029]
		- 20250108@July: Filter range date send Letstalk [Redmine: #213398]
	
	Param's explanation:	
		Note table: TicketVoiding_Letstalk - Only support data within 2 months
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @BroadcastSessionId VARCHAR(100)
		  , @min_RequestId		INT
		  , @cnt_Row			INT
		  , @SettingTime		DATETIME
	
	SET @SettingTime = DATEADD(MONTH, -2, CAST(GETDATE() AS DATE))
	DECLARE @tmpInfoGetLetstalk TABLE (
			 RequestID			INT
			,VoidingHistoryId	INT
			,MatchID			INT
			,BroadcastSessionId VARCHAR(100)
			,SiteDBGroupID		SMALLINT
			,IsAutoVoid			BIT
			,cnt				INT
	)
	
	DECLARE @tmpResultLetstalk TABLE (
			RequestID			INT
			,VoidingHistoryId	INT
			,MatchID			INT
			,BroadcastSessionId VARCHAR(100)
			,SiteDBGroupID		SMALLINT
			,IsAutoVoid			BIT
	)

	INSERT INTO @tmpInfoGetLetstalk (RequestID, VoidingHistoryId, MatchID, BroadcastSessionId, SiteDBGroupID, IsAutoVoid)
	SELECT DISTINCT 
			vb.RequestID
			, vh.VoidingHistoryId
			, vb.MatchID
			, vh.BroadcastSessionId
			, vh.SiteDBGroupID
			, vb.IsAutoVoid
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
		INNER JOIN dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK) ON vh.RequestID = vb.RequestId AND vh.VoidingHistoryId = vb.VoidingHistoryId  
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON vh.RequestId = r.RequestId 
		LEFT JOIN dbo.TicketVoiding_Letstalk lt WITH(NOLOCK) ON vh.RequestID = lt.RequestID AND lt.BroadcastSessionId = vh.BroadcastSessionId AND lt.CreatedDate > @SettingTime
	WHERE  vh.BroadcastSessionId IS NOT NULL 
		AND vh.StatusId = 2 AND vb.statusID = 2
		AND r.IssueTypeId NOT IN (17,22) --Not send letstalk for issuetype archive, recover
		AND 1 = CASE WHEN lt.BroadcastSessionId IS NULL THEN 1
					 WHEN lt.BroadcastSessionId IS NOT NULL AND lt.StatusId = 1 THEN 1
					 ELSE 0 END
		AND vb.createdDate > @SettingTime
		
	UPDATE t1
	SET cnt = t2.cnt_BroadcastSessionId
	FROM @tmpInfoGetLetstalk t1
		CROSS APPLY (
		SELECT COUNT (BroadcastSessionId) cnt_BroadcastSessionId
		FROM @tmpInfoGetLetstalk t2
		WHERE t1.BroadcastSessionId = t2.BroadcastSessionId AND t1.RequestID = t2.RequestID
		GROUP BY BroadcastSessionId
		)t2
	
	WHILE (1=1)
	BEGIN
		SELECT @min_RequestId =  MIN(RequestID) FROM @tmpInfoGetLetstalk 
		IF @min_RequestId IS NULL
			RETURN;

		SELECT @BroadcastSessionId = t1.BroadcastSessionId
		FROM @tmpInfoGetLetstalk t1
		CROSS APPLY (
					SELECT MIN(VoidingHistoryId) AS VoidingHistoryId
					FROM @tmpInfoGetLetstalk t2
					WHERE t1.RequestID = t2.RequestID AND t2.RequestID = @min_RequestId
					)t2
		WHERE t1.VoidingHistoryId = t2.VoidingHistoryId

		INSERT INTO @tmpResultLetstalk (RequestID, VoidingHistoryId, MatchID, BroadcastSessionId, SiteDBGroupID, IsAutoVoid)
		SELECT  RequestID
				, VoidingHistoryId
				, MatchID
				, BroadcastSessionId
				, SiteDBGroupID
				, IsAutoVoid
		FROM @tmpInfoGetLetstalk t
			CROSS APPLY ( SELECT COUNT(BroadcastSessionId) as cnt
							FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
							WHERE t.RequestID = vh.RequestID AND t.BroadcastSessionId = vh.BroadcastSessionId
							GROUP BY BroadcastSessionId
					)a
		WHERE t.cnt = a.cnt AND t.BroadcastSessionId = @BroadcastSessionId AND t.RequestID = @min_RequestId
			
		SET @cnt_Row = @@ROWCOUNT
	
		IF @cnt_Row = 0 
		BEGIN
			DELETE FROM @tmpInfoGetLetstalk WHERE RequestID = @min_RequestId
		END
		ELSE
		BEGIN
			SELECT  RequestID
				  , VoidingHistoryId
				  , MatchID
				  , BroadcastSessionId
				  , SiteDBGroupID
				  , IsAutoVoid
			FROM @tmpResultLetstalk

			RETURN;
		END
	END
END