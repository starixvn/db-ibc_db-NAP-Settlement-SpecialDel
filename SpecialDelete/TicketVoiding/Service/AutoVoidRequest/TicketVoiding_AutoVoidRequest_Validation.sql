/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Validation]
(
	@SingleTicketsJSON	XML = NULL
	,@ParlayTicketsJSON	XML = NULL
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, IsMixParlay BIT DEFAULT(0), IssueTypeId TINYINT)
	CREATE TABLE #tmpTransIds (TransId BIGINT PRIMARY KEY, RequestId INT, StatusID TINYINT, statuswinlost TINYINT, refno BIGINT, IsMixParlay BIT DEFAULT(0), Matchid INT, IssueTypeId TINYINT)
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #SingleTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #ParlayTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)

	IF @SingleTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId)
		SELECT tbl.TransId, tbl.RequestId, tbl.IssueTypeId
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IsMixParlay, IssueTypeId)
		SELECT tbl.TransId, tbl.RequestId, 1, tbl.IssueTypeId
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, IssueTypeId INT) tbl
	END
	
	INSERT INTO #tmpTransIds (TransId, RequestId, StatusID, statuswinlost, IsMixParlay, refno, Matchid, IssueTypeId)
	SELECT t.TransId
		,t.RequestId
		,b.statusID
		,b.statuswinlost
		,t.IsMixParlay
		,b.refno
		,b.matchid
		,t.IssueTypeId
	FROM #tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
	WHERE b.statusID IN (0,1)
	
	IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE statuswinlost IS NOT NULL)
	BEGIN
		INSERT INTO #SingleTickets (TransId, RequestId, Matchid, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.Matchid, t.IssueTypeId
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 0
			AND t.statuswinlost IN (1,2)

		INSERT INTO #SingleTickets_ReSettle (TransId, RequestId, Matchid, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.Matchid, t.IssueTypeId
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 0
			AND t.statuswinlost IN (0,3,4)

		INSERT INTO #ParlayTickets (TransId, RequestId, Matchid, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.Matchid, t.IssueTypeId
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 1
			AND t.statuswinlost IN (1,2)

		INSERT INTO #ParlayTickets_ReSettle (TransId, RequestId, Matchid, IssueTypeId)
		SELECT t.TransId, t.RequestId, t.Matchid, t.IssueTypeId
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 1
			AND t.statuswinlost IN (0,3,4)
	END
	

	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #SingleTickets
	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #ParlayTickets
	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #SingleTickets_ReSettle
	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #ParlayTickets_ReSettle

	DROP TABLE #tmpInputTransId
	DROP TABLE #tmpTransIds
	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
	DROP TABLE #SingleTickets_ReSettle
	DROP TABLE #ParlayTickets_ReSettle
END		
GO


