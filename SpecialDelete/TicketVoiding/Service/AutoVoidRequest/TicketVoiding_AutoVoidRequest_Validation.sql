/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Validation]
(
	@SingleTicketsXML	XML = NULL
	,@ParlayTicketsXML	XML = NULL
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]

	Param's explanation:
		- XML: <root><r req="" iss="" tid=""/></root>
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, IsMixParlay BIT DEFAULT(0))
	CREATE TABLE #tmpTransIds (TransId BIGINT PRIMARY KEY, RequestId INT, StatusID TINYINT, statuswinlost TINYINT, refno BIGINT, IsMixParlay BIT DEFAULT(0), Matchid INT)
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, Matchid INT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, Matchid INT)
	CREATE TABLE #SingleTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT)
	CREATE TABLE #ParlayTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT)
	CREATE TABLE #RequestMixParlay_NoStatusWL (RequestId INT)

	IF @SingleTicketsXML IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId)
		SELECT t.c.value('@tid','BIGINT') AS TransId
				,t.c.value('@req','INT') AS RequestId
		FROM @SingleTicketsXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@SingleTicketsXML = NULL)) 
	END

	IF @ParlayTicketsXML IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, IsMixParlay)
		SELECT t.c.value('@tid','BIGINT') AS TransId
				,t.c.value('@req','INT') AS RequestId
				,1 AS IsMixParlay
		FROM @ParlayTicketsXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@ParlayTicketsXML = NULL)) 
	END

	INSERT INTO #tmpTransIds (TransId, RequestId, StatusID, statuswinlost, IsMixParlay, refno, Matchid)
	SELECT t.TransId
		,t.RequestId
		,b.statusID
		,b.statuswinlost
		,t.IsMixParlay
		,b.refno
		,b.matchid
	FROM #tmpTransIds t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
	WHERE b.statusID NOT IN (101, 102, 103)
	
	IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE statuswinlost IS NOT NULL)
	BEGIN
		INSERT INTO #SingleTickets (TransId, RequestId, Matchid)
		SELECT t.TransId, t.RequestId, t.Matchid
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 0
			AND t.statuswinlost IN (1,2)

		INSERT INTO #SingleTickets_ReSettle (TransId, RequestId, Matchid)
		SELECT t.TransId, t.RequestId, t.Matchid
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 0
			AND t.statuswinlost IN (0,3,4)

		INSERT INTO #ParlayTickets (TransId, RequestId, Matchid)
		SELECT t.TransId, t.RequestId, t.Matchid
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 1
			AND t.statuswinlost IN (1,2)

		INSERT INTO #ParlayTickets_ReSettle (TransId, RequestId, Matchid)
		SELECT t.TransId, t.RequestId, t.Matchid
		FROM #tmpTransIds t
		WHERE t.IsMixParlay = 1
			AND t.statuswinlost IN (0,3,4)
	END
	
	IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE IsMixParlay = 1 AND statuswinlost IS NULL) 
	BEGIN
		;WITH cte_MainTransId AS
		(
			SELECT t.TransId, t.RequestId, t.refno
			FROM #tmpTransIds t
			WHERE t.IsMixParlay = 1
				AND t.statuswinlost IS NULL
		)
		,cte_SubMatch AS
		(
			SELECT c.TransId
			FROM cte_MainTransId c
				CROSS APPLY (
					SELECT TOP(1) bm.matchid
					FROM dbo.bettransm bm WITH (NOLOCK)
						INNER JOIN dbo.match m WITH (NOLOCK) ON bm.matchid = m.matchid AND m.eventstatus <> 'completed'
					WHERE bm.refno = c.refno
				)sub
		)
		INSERT INTO #RequestMixParlay_NoStatusWL (RequestId)
		SELECT DISTINCT t.RequestId
		FROM #tmpTransIds t
			LEFT JOIN cte_SubMatch c ON c.TransId = t.TransId
		WHERE t.IsMixParlay = 1
				AND t.statuswinlost IS NULL
				AND c.TransId IS NULL
	END

	SELECT TransId, RequestId FROM #SingleTickets
	SELECT TransId, RequestId FROM #ParlayTickets
	SELECT TransId, RequestId FROM #SingleTickets_ReSettle
	SELECT TransId, RequestId FROM #ParlayTickets_ReSettle
	SELECT RequestId FROM #RequestMixParlay_NoStatusWL

	DROP TABLE #tmpInputTransId
	DROP TABLE #tmpTransIds
	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
	DROP TABLE #SingleTickets_ReSettle
	DROP TABLE #ParlayTickets_ReSettle
	DROP TABLE #RequestMixParlay_NoStatusWL
END		
GO


