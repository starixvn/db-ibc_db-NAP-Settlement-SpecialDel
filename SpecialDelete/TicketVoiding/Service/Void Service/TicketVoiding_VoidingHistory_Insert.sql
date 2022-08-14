/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Insert]
(
	@BroadcastSessionId VARCHAR(50)
	,@SiteDBGroupId TINYINT
	,@IsAutoVoid BIT = 0
	,@RequestInfoXml XML = NULL
	,@UserId INT = 0
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
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

	CREATE TABLE #tmpRequestInfo (RequestId INT, IssueTypeId INT, MatchId INT, TransIds VARCHAR(MAX), VoidData VARCHAR(MAX), BroadcastSessionId VARCHAR(50), SiteDBGroupId TINYINT, IsAutoVoid BIT)

	INSERT INTO #tmpRequestInfo (RequestId, IssueTypeId, MatchId, TransIds, VoidData, BroadcastSessionId, SiteDBGroupId, IsAutoVoid)
	SELECT t.c.value('@RequestId','INT') 
			,t.c.value('@IssueTypeId','INT')
			,t.c.value('@MatchId','INT')
			,t.c.value('@TransIds','VARCHAR(MAX)')
			,t.c.value('@VoidData','VARCHAR(MAX)')
			,@BroadcastSessionId, @SiteDBGroupId, @IsAutoVoid
	FROM @RequestInfoXml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@RequestInfoXml = NULL))

	IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
								INNER JOIN #tmpRequestInfo t ON t.RequestId = v.RequestId
					WHERE v.BroadcastSessionId = @BroadcastSessionId
				)
	BEGIN
		INSERT INTO dbo.TicketVoiding_VoidingHistory (
				RequestId
				,UserId
				,StatusId
				,TransIds
				,VoidData
			)
		SELECT t.RequestId
			,@UserId
			,1
			,t.TransIds
			,t.VoidData
		FROM #tmpRequestInfo t 

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
			,t.BroadcastSessionId
			,t.SiteDBGroupId
			,t.IsAutoVoid
			,t.MatchId
		FROM #tmpRequestInfo t
			INNER JOIN dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK) ON v.RequestId = v.RequestId AND v.StatusId = 1
	END

	SELECT DISTINCT v.RequestId, v.VoidingHistoryId
	FROM dbo.TicketVoiding_Void_Service v WITH (NOLOCK)
	WHERE v.BroadcastSessionId = @BroadcastSessionId

END
GO

