/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_cts" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CTS_ProblemCustomerSelect_Archive]
	@Datetime		DATETIME = NULL
AS
/*	Created by: 20220606@July
	Task: TVS - Send problem customer in Abnormal Bet request to CTS - Archive process [Redmine:#172634]
	DB: DBARC/bodb_Archive
	
	Revisions: 
		- 20220606@July: Create new SP [Redmine:#172634]
		- 20220614@July: Remove '=' support CTS [Redmine:#172634]
		- 20230330@July: [TVS] Send problem customer in Abnormal Account request to CTS [Redmine:#185238]
		- 20231211@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
		- 20250707@Lani: [TVS] Abnormal Bet - Send ticket of the username in AB Exception List to CTS [Redmine: #231465]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpResult (RequestId INT, ReasonID INT, CustId INT, CreatedBy INT, CreatedDate DATETIME, IsParlay BIT, Sporttype SMALLINT, IssueTypeId TINYINT)

	DECLARE @RequestListTbl AS TABLE (RequestId INT, TransIds VARCHAR(MAX))
	DECLARE @RequestABWhiteTransIds AS TABLE (RequestId INT, TransId BIGINT, CustId INT, Sporttype SMALLINT, IsParlay BIT, CreatedBy INT, CreatedDate DATETIME, IssueTypeId TINYINT)
	
	--Get list transid
	INSERT INTO @RequestListTbl (RequestId, TransIds)
	SELECT DISTINCT r.RequestId
					, TRY_CAST(t.TransIds AS XML).value('(/r/@ABWhiteListTransIds)[1]', 'VARCHAR(MAX)')
	FROM TicketVoiding_Request_bk AS r WITH (NOLOCK)
	CROSS APPLY 
	(
		SELECT TOP 1 rd.TransIds, r.LastModifiedBy, r.LastModifiedDate
		FROM TicketVoiding_RequestDetail_bk AS rd WITH (NOLOCK)
		WHERE rd.RequestId = r.RequestId
	) AS t
	WHERE r.LastModifiedDate > @Datetime AND r.IssueTypeId IN (11) AND t.TransIds IS NOT NULL

	INSERT INTO @RequestABWhiteTransIds (RequestId, TransId)
	SELECT r.RequestId, value
	FROM @RequestListTbl AS r
	CROSS APPLY STRING_SPLIT(r.TransIds,',')

	UPDATE t
	SET t.CustId = b.CustId
	  , t.Sporttype = CASE WHEN b.matchid <> 29 THEN m.sporttype ELSE NULL END
	  , t.IsParlay = CASE WHEN b.matchid <> 29 THEN NULL ELSE 1 END
	  , t.CreatedBy = r.LastModifiedBy
	  , t.CreatedDate = r.LastModifiedDate
	  , t.IssueTypeId = r.IssueTypeId
	FROM @RequestABWhiteTransIds t
	INNER JOIN TicketVoiding_Request_bk AS r WITH (NOLOCK) ON r.RequestId = t.RequestId
	INNER JOIN bettrans_bk AS b WITH (NOLOCK) ON b.TransId = t.TransId
	INNER JOIN match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid

	-- Get TVS - add/edit request
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate, IsParlay, Sporttype, IssueTypeID)
	SELECT DISTINCT s.RequestId
		 , s.SubIssueTypeId AS ReasonID
		 , s.CustId
		 , r.LastModifiedBy AS CreatedBy
		 , r.LastModifiedDate AS CreatedDate
		 , CASE WHEN r.IssueTypeId = 11 AND s.MatchId = 29 THEN 1 ELSE NULL END AS IsParlay
		 , CASE WHEN rd.cnt = 1 THEN dt.Sporttype ELSE NULL END AS Sporttype
		 , r.IssueTypeId
	FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)  
		INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) ON r.RequestId = s.RequestId
		OUTER APPLY (
			SELECT TOP 1 rd.Sporttype
			FROM dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK)
			WHERE rd.RequestId = r.RequestId AND r.IssueTypeId = 11 
		)dt
		OUTER APPLY (
			SELECT rd.RequestId, COUNT(DISTINCT rd.Sporttype) cnt
			FROM dbo.TicketVoiding_RequestDetail_bk rd WITH (NOLOCK)
			WHERE rd.RequestId = r.RequestId  AND r.IssueTypeId = 11
			GROUP BY rd.RequestId
		)rd
	WHERE r.IssueTypeId IN (11,13) AND r.LastModifiedDate > @Datetime
		AND s.CustId IS NOT NULL
	UNION 
	SELECT t.RequestId
		, s.SubIssueTypeId AS ReasonID
		, t.CustId 
		, t.CreatedBy
		, t.CreatedDate
		, t.IsParlay
		, t.Sporttype
		, t.IssueTypeId
	FROM @RequestABWhiteTransIds AS t 
	CROSS APPLY
	(
		SELECT TOP 1 SubIssueTypeId
		FROM TicketVoiding_RequestDetail_bk rd WITH (NOLOCK)
		WHERE rd.RequestId = t.RequestId
	) s

	-- Get Function - Void by betid
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate, IsParlay, Sporttype, IssueTypeId)
	SELECT NULL AS RequestId
		 , tv.SubIssueTypeId AS ReasonID
		 , tv.CustID
		 , 10278938 AS CreatedBy
		 , MAX(tv.CreatedDate) AS CreatedDate
		 , NULL AS IsParlay
		 , m.sporttype
		 , 11 AS IssueTypeId
	FROM dbo.Ticketvoiding_VoidedTransaction_bk tv WITH (NOLOCK)  
		OUTER APPLY (
					SELECT TOP(1) vh.RequestId
					FROM dbo.TicketVoiding_VoidingHistory_bk vh WITH (NOLOCK) 
					WHERE 1 = CASE WHEN vh.MessageId IS NOT NULL AND tv.MessageId = vh.MessageId THEN 1
					               WHEN vh.MessageIdSpecial IS NOT NULL AND tv.MessageId = vh.MessageIdSpecial THEN 1
								   ELSE 0 END
			)r
		CROSS APPLY (
					SELECT	 m.sporttype
					FROM	dbo.match_bk m WITH(NOLOCK)
					WHERE	m.matchid = tv.MatchId
			)m
	WHERE tv.IssueTypeId = 11 AND tv.CreatedDate > @Datetime AND r.RequestId IS NULL 
	GROUP BY tv.SubIssueTypeId, tv.CustID, m.sporttype

	SELECT CustID, ReasonID, CreatedBy, RequestID, IsParlay, Sporttype, IssueTypeId
	FROM #tmpResult

	DROP TABLE #tmpResult
END
GO