/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Insert]
(
	@BroadcastSessionId		VARCHAR(50)
	,@IsAutoVoid			BIT = 0
	,@VoidServiceXml		XML = NULL
	,@VoidData				XML = NULL
	,@UserId				INT = 0
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20201202@Charles: Insert data for new VoidData column [Redmine:#143666]
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpRequestInfo (RequestId INT, IssueTypeId INT, MatchId INT, TransIds VARCHAR(MAX), SiteDBGroupId SMALLINT)
	DECLARE @VoidingHistory_tmp AS TABLE (VoidingHistoryId INT, RequestId INT)

	INSERT INTO #tmpRequestInfo (RequestId, IssueTypeId, MatchId, TransIds, SiteDBGroupId)
	SELECT t.c.value('@RequestId','INT') 
			,t.c.value('@IssueTypeId','INT')
			,t.c.value('@MatchId','INT')
			,t.c.value('@TransIds','VARCHAR(MAX)')
			,t.c.value('@SiteDBGroupId','SMALLINT')
	FROM @VoidServiceXml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@VoidServiceXml = NULL))

	IF EXISTS (SELECT TOP(1) 1 FROM #tmpRequestInfo t
						LEFT JOIN dbo.TicketVoiding_Void_Service v WITH (NOLOCK) 
							ON t.RequestId = v.RequestId 
								AND t.SiteDBGroupId = v.SiteDBGroupID
								AND v.BroadcastSessionId = @BroadcastSessionId
					WHERE v.RequestId IS NULL
				)
	BEGIN
		IF @IsAutoVoid = 1
		BEGIN
			--Initial VoidingHistory
			INSERT INTO dbo.TicketVoiding_VoidingHistory (
					RequestId
					,UserId
					,StatusId
					,TransIds
					,VoidData
			)
			OUTPUT INSERTED.VoidingHistoryId, INSERTED.RequestId INTO @VoidingHistory_tmp (VoidingHistoryId, RequestId)
			SELECT t.RequestId
				,@UserId
				,1
				,t.TransIds
				,@VoidData
			FROM #tmpRequestInfo t 
			WHERE NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
									WHERE v.BroadcastSessionId = @BroadcastSessionId AND t.RequestId = v.RequestId AND t.SiteDBGroupId = v.SiteDBGroupID
							)
		END	
		ELSE
		BEGIN
			DECLARE @RequestId INT

			SELECT @RequestId = MAX(t.RequestId)
			FROM #tmpRequestInfo t

			--Initial VoidingHistory
			INSERT INTO dbo.TicketVoiding_VoidingHistory (
					RequestId
					,UserId
					,StatusId
					,VoidData
			)
			OUTPUT INSERTED.VoidingHistoryId, INSERTED.RequestId INTO @VoidingHistory_tmp (VoidingHistoryId, RequestId)
			SELECT @RequestId
				,@UserId
				,1
				,@VoidData
			WHERE NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
										WHERE v.BroadcastSessionId = @BroadcastSessionId AND v.RequestId = @RequestId)
		END


		INSERT INTO @VoidingHistory_tmp (VoidingHistoryId, RequestId)
		SELECT DISTINCT v.VoidingHistoryId, v.RequestId
		FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
		WHERE v.BroadcastSessionId = @BroadcastSessionId
			AND NOT EXISTS (SELECT TOP(1) 1 FROM @VoidingHistory_tmp t WHERE t.VoidingHistoryId = v.VoidingHistoryId AND v.RequestId = t.RequestId)

		--Initial Void Service
		INSERT INTO dbo.TicketVoiding_Void_Service (
				RequestId
				,VoidingHistoryId
				,StatusId
				,BroadcastSessionId
				,SiteDBGroupID
				,IsAutoVoid
				,MatchId
			)
		SELECT t.RequestId
			,v.VoidingHistoryId
			,1
			,@BroadcastSessionId
			,t.SiteDBGroupId
			,@IsAutoVoid
			,t.MatchId
		FROM #tmpRequestInfo t
			INNER JOIN @VoidingHistory_tmp v ON v.RequestId = t.RequestId
	END
	ELSE
	BEGIN
		INSERT INTO @VoidingHistory_tmp (VoidingHistoryId, RequestId)
		SELECT DISTINCT v.VoidingHistoryId, v.RequestId
		FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
		WHERE v.BroadcastSessionId = @BroadcastSessionId

		--Insert other site after initial
		INSERT INTO dbo.TicketVoiding_Void_Service (
				RequestId
				,VoidingHistoryId
				,StatusId
				,BroadcastSessionId
				,SiteDBGroupID
				,IsAutoVoid
				,MatchId
			)
		SELECT t.RequestId
			,v.VoidingHistoryId
			,1
			,@BroadcastSessionId
			,t.SiteDBGroupId
			,@IsAutoVoid
			,t.MatchId
		FROM #tmpRequestInfo t
			INNER JOIN @VoidingHistory_tmp v ON v.RequestId = t.RequestId
		WHERE NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Void_Service s WITH (NOLOCK) 
						WHERE s.RequestId = t.RequestId AND s.VoidingHistoryId = v.VoidingHistoryId AND s.SiteDBGroupID = t.SiteDBGroupId)
	END

	SELECT v.BroadcastSessionId, v.SiteDBGroupID, v.RequestId, v.VoidingHistoryId, v.StatusId, v.IsAutoVoid, v.MatchId, tmp.IssueTypeId
	FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
		CROSS APPLY (
				SELECT TOP(1) t.IssueTypeId
				FROM #tmpRequestInfo t 
				WHERE t.RequestId = v.RequestId 
		)tmp
	WHERE v.BroadcastSessionId = @BroadcastSessionId

	DROP TABLE #tmpRequestInfo

END
GO

