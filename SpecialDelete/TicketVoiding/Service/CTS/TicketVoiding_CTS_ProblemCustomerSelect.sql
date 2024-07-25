/*<info serverAlias="DBTP-bodb02" executers="wsv_cts" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CTS_ProblemCustomerSelect]
(
	@Datetime				DATETIME = NULL
   ,@IsArchive				BIT = 0			OUTPUT
   ,@MaxTimeRequestActive	DATETIME = NULL OUTPUT
   ,@MissingDataRequestIds	VARCHAR(2000) = '' OUTPUT
)
AS
/*	Created by: 20220606@July
	Task: TVS - Send problem customer in Abnormal Bet request to CTS  [Redmine:#172634]
	DB: DBTP/bodb02
	
	Revisions: 
		- 20220606@July: Create new SP [Redmine:#172634]
		- 20220614@July: Remove '=' support CTS [Redmine:#172634]
		- 20230330@July: [TVS] Send problem customer in Abnormal Account request to CTS [Redmine:#185238]
		- 20231211@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20240327@Max: [CTS] - [TVS] - Missing Void Info - Not auto-mark PA [Redmine: #201993]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MinTimeRequestActive DATETIME = NULL

	SELECT @MinTimeRequestActive = MIN(LastModifiedDate) FROM dbo.TicketVoiding_Request WITH (NOLOCK) WHERE IssueTypeId IN (11,13)

	CREATE TABLE #tmpResult (RequestId INT, ReasonID INT, CustId INT, CreatedBy INT, CreatedDate DATETIME, IsParlay BIT, Sporttype SMALLINT, IssueTypeId TINYINT)

	DECLARE @tmp_Request AS TABLE (RequestId INT, Detail_count INT, Actual_count INT, CreatedBy INT, CreatedDate DATETIME, Sporttype SMALLINT, IssueTypeId TINYINT)
	DECLARE @tmp_Request_Retry AS TABLE (RequestId INT, Detail_count INT)

	INSERT INTO @tmp_Request (RequestId, Detail_count, Actual_count, CreatedBy, CreatedDate, Sporttype, IssueTypeId)
	SELECT r.RequestId, dt.Detail_count, act.Actual_count, r.LastModifiedBy, r.LastModifiedDate, CASE WHEN rd.cnt = 1 THEN dt.Sporttype ELSE NULL END AS Sporttype, r.IssueTypeId
	FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
	CROSS APPLY (
		SELECT TOP 1 rd.SingleCount AS Detail_count, rd.Sporttype
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE rd.RequestId = r.RequestId 
	)dt
	CROSS APPLY (
		SELECT COUNT(s.TransId) AS Actual_count
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
		WHERE s.RequestId = r.RequestId 
	)act
	OUTER APPLY (
		SELECT rd.RequestId, COUNT(DISTINCT rd.Sporttype) cnt
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE rd.RequestId = r.RequestId  AND r.IssueTypeId = 11
		GROUP BY rd.RequestId
	)rd
	WHERE r.IssueTypeId IN (11,13) AND r.LastModifiedDate > @Datetime

	--Apply retry process for some requests delayed
	INSERT INTO @tmp_Request_Retry (RequestId, Detail_count)
	SELECT RequestId, Detail_count
	FROM @tmp_Request 
	WHERE Actual_count < Detail_count

	IF @@ROWCOUNT > 0
	BEGIN
		DECLARE @i TINYINT = 1
			,@waitfor_delay DATETIME = '00:00:00.000'
		
		WHILE (@i <= 5)
		BEGIN
			SET @waitfor_delay = CASE WHEN @i = 1 THEN '00:00:01.000'
									  WHEN @i = 2 THEN '00:00:02.000'
									  WHEN @i = 3 THEN '00:00:05.000'
									  WHEN @i = 4 THEN '00:00:30.000' 
									  WHEN @i = 5 THEN '00:01:00.000'
								END
			WAITFOR DELAY @waitfor_delay

			DELETE t
			FROM @tmp_Request_Retry t
			CROSS APPLY (
				SELECT COUNT(s.TransId) AS Actual_count
				FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				WHERE s.RequestId = t.RequestId 
			)act
			WHERE act.Actual_count = t.Detail_count

			IF NOT EXISTS (SELECT TOP 1 1 FROM @tmp_Request_Retry)
				BREAK;

			SET @i += 1
		END
	END

	--Return error 
	SELECT @MissingDataRequestIds = ISNULL(STUFF((SELECT ',' + CAST(t.RequestId AS VARCHAR(50))
								FROM @tmp_Request_Retry t
								FOR XML PATH('')), 1, 1, ''), '')

	-- Get TVS - add/edit request
	INSERT INTO #tmpResult(RequestId, ReasonID, CustId, CreatedBy, CreatedDate, IsParlay, Sporttype, IssueTypeId)
	SELECT DISTINCT s.RequestId
		 , s.SubIssueTypeId AS ReasonID
		 , s.CustId
		 , r.CreatedBy
		 , r.CreatedDate
		 , CASE WHEN r.IssueTypeId = 11 AND s.MatchId = 29 THEN 1 ELSE NULL END AS IsParlay
		 , CASE WHEN r.IssueTypeId = 11 AND s.MatchId <> 29 THEN r.Sporttype ELSE NULL END AS Sporttype
		 , r.IssueTypeId
	FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)  
		INNER JOIN @tmp_Request r ON r.RequestId = s.RequestId
	WHERE s.CustId IS NOT NULL

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
	FROM dbo.Ticketvoiding_VoidedTransaction tv WITH (NOLOCK)  
		OUTER APPLY (
					SELECT TOP(1) vh.RequestId
					FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) 
					WHERE 1 = CASE WHEN vh.MessageId IS NOT NULL AND tv.MessageId = vh.MessageId THEN 1
					               WHEN vh.MessageIdSpecial IS NOT NULL AND tv.MessageId = vh.MessageIdSpecial THEN 1
								   ELSE 0 END
			)r
		CROSS APPLY (
					SELECT	 m.sporttype
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.matchid = tv.MatchId
					UNION
					SELECT	 m14.sporttype
					FROM	dbo.match14 m14 WITH(NOLOCK)
					WHERE	m14.matchid = tv.matchid
			)m
	WHERE tv.IssueTypeId = 11 AND tv.CreatedDate > @Datetime AND r.RequestId IS NULL 
	GROUP BY tv.SubIssueTypeId, tv.CustID, m.sporttype

	SELECT CustID, ReasonID, CreatedBy, RequestID, IsParlay, Sporttype, IssueTypeId
	FROM #tmpResult

	SELECT @MaxTimeRequestActive = MAX(CreatedDate) 
	FROM #tmpResult

	IF @Datetime < @MinTimeRequestActive
	BEGIN
		SET @IsArchive = 1
	END

	DROP TABLE #tmpResult
END

GO
