/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidBetAutomation_AfterVoid_Select](
		@OnlineServerId			VARCHAR(10) = NULL --'0,1,2,3'
)
AS
/*	Created by: 20230117@July
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230117@July: Create new SP - get request will run after void [Redmine: #180625]
		- 20230401@Helen: Fix issue [Redmine: #186241]
		- 20231213@Max: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]
		- 20250527@Hyman: [TVS] Add column IsSentToMTS [Redmine: #227379]
		- 20250602@July: Enhance TVS in case 1 or many siteDBs down - Void services [Redmine: #224490]

	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @BroadcastSessionId VARCHAR(100)
	       ,@xmlVoidResults		XML = NULL
		   ,@VoidingHistoryId	INT
		   ,@RequestId			INT 
		   ,@IssueTypeId		TINYINT

	DECLARE @tmpResultAfterVoid AS TABLE (
		RequestID INT
		,VoidingHistoryId INT
		,statusID INT
		,matchID INT
		,BroadcastSessionId VARCHAR(100)
		,NegativeBalanceUsers VARCHAR(MAX)
		,IsAutoVoid BIT
		,IsRunExternalService BIT
		,MessageId INT
		,ReasonId INT
		,IsSentBatchMessage BIT
		,IsSentMessageToAdminSite BIT
		,IsInsertedVoidedTransaction BIT
		,IsUpdatedVoidingHistory BIT
		,IsSentEmail BIT
		,SiteDBGroupID SMALLINT
		,MessageIdSpecial INT
		,IsDeletedMessage BIT
		,IsDeletedVoidedTransaction BIT
		,IsDeletedzzzBettrans BIT
		,TransIds VARCHAR(MAX)
		,RequestDetailId INT
		,IsSentToMTS BIT
	)
	DECLARE @tmpVoidingHistory_Service AS TABLE
	(
		RequestId INT
		,VoidingHistoryId INT
		,VoidingHistoryStatusId TINYINT
		,AfterVoidStatusId TINYINT
		,VoidResults XML
		,IsFinish BIT
	)
		
	DECLARE @tmpVoidResults AS TABLE ( 
		  VoidingHistoryId INT
		, Message VARCHAR(MAX)
		, Type INT
		, Licensees VARCHAR(MAX)
	)
	DECLARE @tmp_OnlineServerId AS TABLE (ServerId SMALLINT)

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmp_OnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	INSERT INTO @tmpResultAfterVoid (RequestID, VoidingHistoryId, statusID, matchID, BroadcastSessionId , NegativeBalanceUsers
							, IsAutoVoid, IsRunExternalService, MessageId, ReasonId, IsSentBatchMessage, IsSentMessageToAdminSite
							, IsInsertedVoidedTransaction, IsUpdatedVoidingHistory, IsSentEmail, SiteDBGroupID, MessageIdSpecial, IsDeletedMessage, IsDeletedVoidedTransaction, IsDeletedzzzBettrans
							, TransIds, IsSentToMTS
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
		, vh.SiteDBGroupID
		, vb.MessageIdSpecial
		, vb.IsDeletedMessage
		, vb.IsDeletedVoidedTransaction
		, vb.IsDeletedzzzBettrans
		, vh.TransIds
		, vb.IsSentToMTS
	FROM dbo.TicketVoiding_VoidBetAutomation_Service vb WITH (NOLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vb.RequestID = vh.RequestId AND vb.VoidingHistoryId = vh.VoidingHistoryId
	WHERE vb.statusID = 1
		AND vh.SiteDBGroupID IN (SELECT ServerId FROM @tmp_OnlineServerId)
	ORDER BY vb.createdDate ASC
		
	SELECT @BroadcastSessionId = BroadcastSessionId, @RequestId = RequestId
	FROM @tmpResultAfterVoid

	SELECT @IssueTypeId = IssueTypeId FROM dbo.TicketVoiding_Request WITH (NOLOCK) WHERE RequestId = @RequestId
	
	IF @IssueTypeId = 12 --Wrong Market Offered
	BEGIN
		DECLARE @tmpTicketInfo TABLE (
			RequestId		INT
		   ,VoidingHistoryId INT 
		   ,SingleTransIds  VARCHAR(MAX)
		   ,ParlayTransIds  VARCHAR(MAX)
		)
		INSERT INTO @tmpTicketInfo (RequestId, VoidingHistoryId, SingleTransIds, ParlayTransIds)
		SELECT vh.RequestId, vh.VoidingHistoryId, tbl.SingleTransIds, tbl.ParlayTransIds
		FROM @tmpResultAfterVoid vh
		CROSS APPLY (
			SELECT SingleTransIds,ParlayTransIds
			FROM OPENJSON(vh.TransIds) 
			WITH( SingleTransIds VARCHAR(MAX)
				 ,ParlayTransIds VARCHAR(MAX)
				))tbl
		
		UPDATE vh
		SET vh.RequestDetailId = ISNULL(s.RequestDetailId, sp.RequestDetailId)
		FROM @tmpResultAfterVoid vh
			INNER JOIN @tmpTicketInfo t ON vh.RequestId = t.RequestId AND vh.VoidingHistoryId = t.VoidingHistoryId
			OUTER APPLY(
					SELECT TOP 1 s.RequestDetailId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
					WHERE s.TransId IN (SELECT value AS TransId FROM STRING_SPLIT(ISNULL(t.SingleTransIds,''), ',') )
						AND t.RequestId = s.RequestId
				)s	
			OUTER APPLY(
					SELECT TOP 1 sp.RequestDetailId
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay sp WITH(NOLOCK) 
					WHERE sp.TransId IN (SELECT value AS TransId FROM STRING_SPLIT(ISNULL(t.ParlayTransIds,''), ',') )
					AND t.RequestId = sp.RequestId
				)sp
	END

	INSERT INTO @tmpVoidingHistory_Service(RequestId, VoidingHistoryId, VoidingHistoryStatusId, AfterVoidStatusId, VoidResults) 
	SELECT	 vh.RequestId
			,vh.VoidingHistoryId
			,vh.StatusId AS VoidingHistoryStatusId
			,vb.StatusId AS AfterVoidStatusId
			,vb.VoidResults
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		LEFT JOIN Ticketvoiding_VoidBetAutomation_Service vb WITH(NOLOCK) ON vh.RequestId = vb.RequestID AND vh.VoidingHistoryId = vb.VoidingHistoryId
	WHERE vh.BroadcastSessionId = @BroadcastSessionId AND vh.RequestId = @RequestId
		AND vh.SiteDBGroupID IN (SELECT ServerId FROM @tmp_OnlineServerId)

	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) t
		SET IsFinish = 1
			,@VoidingHistoryId = T.VoidingHistoryId
			,@xmlVoidResults = T.VoidResults
		FROM @tmpVoidingHistory_Service t
		WHERE t.IsFinish IS NULL AND t.VoidResults IS NOT NULL

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
	SELECT RequestID
		, VoidingHistoryId
		, statusID
		, matchID
		, BroadcastSessionId
		, NegativeBalanceUsers
		, IsAutoVoid
		, IsRunExternalService
		, MessageId
		, ReasonId
		, IsSentBatchMessage
		, IsSentMessageToAdminSite
		, IsInsertedVoidedTransaction
		, IsUpdatedVoidingHistory
		, IsSentEmail
		, SiteDBGroupID
		, MessageIdSpecial
		, IsDeletedMessage
		, IsDeletedVoidedTransaction
		, IsDeletedzzzBettrans
		, RequestDetailId
		, IsSentToMTS
	FROM @tmpResultAfterVoid

	--Table #2: Get statusid lastest request & current status request
	SELECT VoidingHistoryId
		, VoidingHistoryStatusId
		, AfterVoidStatusId
	FROM @tmpVoidingHistory_Service

	--Table #3: Get signal Licensees new
	SELECT VoidingHistoryId
		, Message
		, Type
		, Licensees
	FROM @tmpVoidResults

END
