/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Validation]
(
	 @SingleTicketsJSON			NVARCHAR(MAX) = NULL
	,@ParlayTicketsJSON			NVARCHAR(MAX) = NULL
	,@CancelCashOutTicketsJSON	NVARCHAR(MAX) = NULL
)
AS
/*	
	Created by:20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IssueTypeId TINYINT

	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, IsMixParlay BIT DEFAULT(0), IssueTypeId TINYINT, MatchId INT, TicketType TINYINT) --1: single(exclude cancel CO), 2 parlay, 3: cancel CO
	CREATE TABLE #tmpTransIds (TransId BIGINT PRIMARY KEY, RequestId INT, StatusID TINYINT, statuswinlost TINYINT, betdaqid BIGINT, IsMixParlay BIT DEFAULT(0), MatchId INT, IssueTypeId TINYINT, TicketType TINYINT)
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT)
	CREATE TABLE #SingleTickets_ReSettle (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT)
	CREATE TABLE #ParlayTickets_ReSettle (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT)
	CREATE TABLE #CancelCashOutTickets (TransId BIGINT, RequestId INT, MatchId INT, IssueTypeId TINYINT)

	IF @SingleTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 1
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IsMixParlay, IssueTypeId, MatchId, TicketType)
		SELECT tbl.TransId, tbl.RequestId, 1, tbl.IssueTypeId, tbl.MatchId, 2
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT) tbl
	END
	
	IF @CancelCashOutTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId, MatchId, TicketType)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId, tbl.MatchId, 3
		FROM OPENJSON(@CancelCashOutTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT, MatchId INT) tbl
	END

	SET @IssueTypeId = (SELECT TOP 1 IssueTypeId FROM #tmpInputTransId)
	IF @IssueTypeId IN (11,15) --For: action auto void winning
	BEGIN
		INSERT INTO #tmpTransIds (TransId, RequestId, StatusID, statuswinlost, IsMixParlay, MatchId, IssueTypeId)
		SELECT t.TransId
			,t.RequestId
			,b.statusID
			,b.statuswinlost
			,t.IsMixParlay
			,b.MatchId
			,t.IssueTypeId
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE b.statusID IN (0,1)
	
		IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE statuswinlost IS NOT NULL)
		BEGIN
			INSERT INTO #SingleTickets (TransId, RequestId, MatchId, IssueTypeId)
			SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
			FROM #tmpTransIds t
			WHERE t.IsMixParlay = 0
				AND t.statuswinlost IN (1,2)

			INSERT INTO #SingleTickets_ReSettle (TransId, RequestId, MatchId, IssueTypeId)
			SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
			FROM #tmpTransIds t
			WHERE t.IsMixParlay = 0
				AND t.statuswinlost IN (0,3,4)

			INSERT INTO #ParlayTickets (TransId, RequestId, MatchId, IssueTypeId)
			SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
			FROM #tmpTransIds t
			WHERE t.IsMixParlay = 1
				AND t.statuswinlost IN (1,2)

			INSERT INTO #ParlayTickets_ReSettle (TransId, RequestId, MatchId, IssueTypeId)
			SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
			FROM #tmpTransIds t
			WHERE t.IsMixParlay = 1
				AND t.statuswinlost IN (0,3,4)
		END
	END
	IF @IssueTypeId IN (1,10,3) 
	BEGIN
		INSERT INTO #tmpTransIds (TransId, RequestId, StatusID, betdaqid, MatchId, IssueTypeId, TicketType)
		SELECT t.TransId
			,t.RequestId
			,b.statusID
			,b.betdaqid
			,b.MatchId
			,t.IssueTypeId
			,t.TicketType
		FROM #tmpInputTransId t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE t.TicketType IN (1,3) AND b.statusID NOT IN (101,102,103)
		
		INSERT INTO #SingleTickets (TransId, RequestId, MatchId, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
		FROM #tmpTransIds t
		WHERE t.TicketType = 1

		INSERT INTO #ParlayTickets (TransId, RequestId, MatchId, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
		FROM #tmpInputTransId t
		WHERE t.TicketType = 2

		INSERT INTO #CancelCashOutTickets (TransId, RequestId, MatchId, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.MatchId, t.IssueTypeId
		FROM #tmpTransIds t
		WHERE t.TicketType = 3 AND t.betdaqid = -2 --NO CARE cancel CO -> running

	END

	SELECT TransId, RequestId, MatchId, IssueTypeId FROM #SingleTickets
	SELECT TransId, RequestId, MatchId, IssueTypeId FROM #ParlayTickets
	SELECT TransId, RequestId, MatchId, IssueTypeId FROM #SingleTickets_ReSettle
	SELECT TransId, RequestId, MatchId, IssueTypeId FROM #ParlayTickets_ReSettle
	SELECT TransId, RequestId, MatchId, IssueTypeId FROM #CancelCashOutTickets

	DROP TABLE #tmpInputTransId
	DROP TABLE #tmpTransIds
	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
	DROP TABLE #SingleTickets_ReSettle
	DROP TABLE #ParlayTickets_ReSettle
	DROP TABLE #CancelCashOutTickets
END		
GO


