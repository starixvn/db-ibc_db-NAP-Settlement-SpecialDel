/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Select]
	@VoidingHistoryIds	VARCHAR(MAX) = NULL
AS
/*	Created by: 20201203@Charles
	Task: select voiddata from TicketVoiding_VoidingHistory table [Redmine: #145719]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20201203@Charles: Optimize Voiding Workflow [Redmine: #145719]
		- 20230103@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20241223@July: [TVS] Support case after void steps are completed, except send email/Letstalk failed & user manually  [Redmine: #213398]
		- 20250616@Lani: [TVS] Recover Ticket - Support Recover More Products - Sub Parlay [Redmine: #227829]

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE  @xmlVoidData		XML
			,@VoidingHistoryId  INT
			,@SingleTransIds	VARCHAR(MAX) = NULL
			,@SubParlayTransIds	VARCHAR(MAX) = NULL
			,@BroadcastSessionId VARCHAR(100)
			,@IssueTypeId		TINYINT

	CREATE TABLE #tmpVoidingHistory(
		VoidingHistoryId INT
		,VoidData XML
		,BroadcastSessionId VARCHAR(100)
		,RequestId	INT
		,IsFinish BIT
	)
	CREATE TABLE #tmpVoidData (	
		VoidingHistoryId INT
		,IssueTypeId INT
		,SubIssueTypeId INT
		,SubIssueTypeName VARCHAR(500)
		,SubIssueTypeNameCS NVARCHAR(256)
		,Reason NVARCHAR(500)
		,ReasonSC NVARCHAR(500)
		,ContentChineseTraditional NVARCHAR(4000)
		,ContentChineseSimplified NVARCHAR(4000)
		,ContentNewChineseSimplified NVARCHAR(4000)
		,ContentEnglish NVARCHAR(4000)
		,ContentSpanish NVARCHAR(4000)
		,ContentItalian NVARCHAR(4000)
		,ContentJapanese NVARCHAR(4000)
		,ContentKorean NVARCHAR(4000)
		,ContentThai NVARCHAR(4000)
		,CreatorId INT
		,CreatorName NVARCHAR(50)
		,DecidedBy NVARCHAR(200)
		,VoidFromTime NVARCHAR(50)
		,VoidToTime NVARCHAR(50)
		,VoidFromDate NVARCHAR(20)
		,VoidToDate NVARCHAR(20)
		,IsHasSettledTicket BIT
		,TotalTicket INT --totalTicket
		,IsRunAutoAfterVoid BIT
		,BroadcastSessionId VARCHAR(100)
	)

	INSERT INTO #tmpVoidingHistory (VoidingHistoryId, VoidData, BroadcastSessionId, RequestId)
	SELECT s.VoidingHistoryId, vh.VoidData, vh.BroadcastSessionId, vh.RequestId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		CROSS APPLY (
			SELECT value AS VoidingHistoryId 
			FROM STRING_SPLIT(@VoidingHistoryIds,',') s
			WHERE vh.VoidingHistoryId = s.value
		)s

	INSERT INTO #tmpVoidingHistory (VoidingHistoryId, VoidData, BroadcastSessionId, RequestId)
	SELECT vh.VoidingHistoryId, vh.VoidData, vh.BroadcastSessionId, vh.RequestId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		INNER JOIN #tmpVoidingHistory t ON t.RequestId = vh.RequestId AND t.BroadcastSessionId = vh.BroadcastSessionId
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tmpVoidingHistory t WHERE t.VoidingHistoryId = vh.VoidingHistoryId)

	SET @IssueTypeId = (SELECT TOP 1 r.IssueTypeId
						FROM TicketVoiding_Request r WITH(NOLOCK)
							INNER JOIN #tmpVoidingHistory vh ON vh.RequestId = r.RequestId
					   )
			
	IF @IssueTypeId = 22 --Recover Ticket
	BEGIN
		SET @SingleTransIds =  STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (50))
									  FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
										INNER JOIN #tmpVoidingHistory vh ON s.RequestId = vh.RequestId
									  WHERE s.IssueTypeId = 22
									  FOR XML PATH ('')),1,1,'')

		SET @SubParlayTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (50))
									  FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH(NOLOCK)
										INNER JOIN #tmpVoidingHistory vh ON s.RequestId = vh.RequestId
									  WHERE s.IssueTypeId = 22
									  FOR XML PATH ('')),1,1,'')
	END

	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) t
		SET IsFinish = 1
			,@xmlVoidData = t.VoidData
			,@VoidingHistoryId = t.VoidingHistoryId
			,@BroadcastSessionId = t.BroadcastSessionId
		FROM #tmpVoidingHistory t
		WHERE t.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		INSERT INTO #tmpVoidData ( VoidingHistoryId, BroadcastSessionId, IssueTypeId, SubIssueTypeId, SubIssueTypeName, SubIssueTypeNameCS
								, Reason, ReasonSC, ContentChineseTraditional, ContentChineseSimplified, ContentNewChineseSimplified
								, ContentEnglish, ContentSpanish, ContentItalian, ContentJapanese, ContentKorean
								, ContentThai, CreatorId, CreatorName, DecidedBy, VoidFromTime
								, VoidToTime, VoidFromDate, VoidToDate, IsHasSettledTicket, TotalTicket, IsRunAutoAfterVoid
						)
		SELECT 
			 @VoidingHistoryId AS VoidingHistoryId
			,@BroadcastSessionId AS BroadcastSessionId
			,@IssueTypeId AS IssueTypeId
			,T.C.value('@SubIssueTypeId', 'INT') AS SubIssueTypeId
			,T.C.value('@SubIssueTypeName', 'VARCHAR(500)') AS SubIssueTypeName
			,T.C.value('@SubIssueTypeNameCS', 'NVARCHAR(256)') AS SubIssueTypeNameCS
			,T.C.value('@Reason', 'NVARCHAR(500)') AS Reason
			,T.C.value('@ReasonSC', 'NVARCHAR(500)') AS ReasonSC
			,T.C.value('@ContentChineseTraditional', 'NVARCHAR(4000)') AS ContentChineseTraditional
			,T.C.value('@ContentChineseSimplified', 'NVARCHAR(4000)') AS ContentChineseSimplified
			,T.C.value('@ContentNewChineseSimplified', 'NVARCHAR(4000)') AS ContentNewChineseSimplified
			,T.C.value('@ContentEnglish', 'NVARCHAR(4000)') AS ContentEnglish
			,T.C.value('@ContentSpanish', 'NVARCHAR(4000)') AS ContentSpanish
			,T.C.value('@ContentItalian', 'NVARCHAR(4000)') AS ContentItalian
			,T.C.value('@ContentJapanese', 'NVARCHAR(4000)') AS ContentJapanese
			,T.C.value('@ContentKorean', 'NVARCHAR(4000)') AS ContentKorean
			,T.C.value('@ContentThai', 'NVARCHAR(4000)') AS ContentThai
			,T.C.value('@CreatorId', 'INT') AS CreatorId
			,T.C.value('@CreatorName', 'NVARCHAR(50)') AS CreatorName
			,T.C.value('@DecidedBy', 'NVARCHAR(200)') AS DecidedBy
			,T.C.value('@VoidFromTime', 'NVARCHAR(50)') AS VoidFromTime
			,T.C.value('@VoidToTime', 'NVARCHAR(50)') AS VoidToTime
			,T.C.value('@VoidFromDate', 'NVARCHAR(20)') AS VoidFromDate
			,T.C.value('@VoidToDate', 'NVARCHAR(20)') AS VoidToDate
			,T.C.value('@IsHasSettledTicket', 'BIT') AS IsHasSettledTicket
			,T.C.value('@TotalTicket', 'INT') AS TotalTicket
			,T.C.value('@IsRunAutoAfterVoid', 'BIT') AS IsRunAutoAfterVoid
		FROM	@xmlVoidData.nodes('/VoidData') AS T(C)
		OPTION (OPTIMIZE FOR (@xmlVoidData = NULL ))
	END

	/*****************Return table **************************/
	SELECT 
		 VoidingHistoryId 
		,BroadcastSessionId --Support insert Service & insert Letstalk status = 1
		,IssueTypeId 
		,SubIssueTypeId
		,SubIssueTypeName
		,SubIssueTypeNameCS 
		,Reason
		,ReasonSC
		,ContentChineseTraditional
		,ContentChineseSimplified
		,ContentNewChineseSimplified
		,ContentEnglish
		,ContentSpanish
		,ContentItalian 
		,ContentJapanese 
		,ContentKorean 
		,ContentThai 
		,CreatorId 
		,CreatorName 
		,DecidedBy 
		,VoidFromTime 
		,VoidToTime 
		,VoidFromDate 
		,VoidToDate 
		,IsHasSettledTicket 
		,TotalTicket
		,IsRunAutoAfterVoid
		,@SingleTransIds AS SingleTransIds
		,@SubParlayTransIds AS SubParlayTransIds
	FROM #tmpVoidData

	DROP TABLE #tmpVoidingHistory
	DROP TABLE #tmpVoidData

END
GO