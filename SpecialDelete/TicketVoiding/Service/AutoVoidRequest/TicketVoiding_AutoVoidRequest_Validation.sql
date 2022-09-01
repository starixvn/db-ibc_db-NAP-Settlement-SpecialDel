/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Validation]
(
	@SingleTicketsXML	XML = NULL
	,@ParlayTicketsXML	XML = NULL
	,@Action			VARCHAR(50) = 'CAL'
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

	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, IsMixParlay BIT DEFAULT(0), IssueTypeId TINYINT)
	CREATE TABLE #tmpTransIds (TransId BIGINT PRIMARY KEY, RequestId INT, StatusID TINYINT, statuswinlost TINYINT, refno BIGINT, IsMixParlay BIT DEFAULT(0), Matchid INT, IssueTypeId TINYINT)
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #SingleTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #ParlayTickets_ReSettle (TransId BIGINT, RequestId INT, Matchid INT, IssueTypeId TINYINT)
	CREATE TABLE #RequestMixParlay_NoStatusWL (RequestId INT, ProcessMixParlayStatus TINYINT)

	IF @Action = 'MixParlay'
	BEGIN
		IF @ParlayTicketsXML IS NOT NULL
		BEGIN
			INSERT INTO #tmpInputTransId (TransId, RequestId, IsMixParlay, IssueTypeId)
			SELECT t.c.value('@tid','BIGINT') AS TransId
					,t.c.value('@req','INT') AS RequestId
					,1 AS IsMixParlay
					,t.c.value('@iss','TINYINT') AS IssueTypeId
			FROM @ParlayTicketsXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@ParlayTicketsXML = NULL)) 
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

		IF NOT EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds t)
		BEGIN
			INSERT INTO #RequestMixParlay_NoStatusWL (RequestId, ProcessMixParlayStatus)
			SELECT DISTINCT t.RequestId, 2
			FROM #tmpTransIds t
		END
		ELSE IF NOT EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds t WHERE t.StatusID IN (0,1) AND t.statuswinlost IS NOT NULL)
		BEGIN
			INSERT INTO #RequestMixParlay_NoStatusWL (RequestId, ProcessMixParlayStatus)
			SELECT DISTINCT t.RequestId, 1
			FROM #tmpTransIds t
		END
		ELSE IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE statuswinlost IS NOT NULL)
		BEGIN
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

			IF EXISTS (SELECT TOP(1) 1 FROM #tmpTransIds WHERE IsMixParlay = 1 AND statuswinlost IS NULL) 
			BEGIN
				INSERT INTO #RequestMixParlay_NoStatusWL (RequestId, ProcessMixParlayStatus)
				SELECT DISTINCT t.RequestId, 0
				FROM #tmpTransIds t
			END
			ELSE
			BEGIN
				INSERT INTO #RequestMixParlay_NoStatusWL (RequestId, ProcessMixParlayStatus)
				SELECT DISTINCT t.RequestId, 2
				FROM #tmpTransIds t
			END
		END
	END
	ELSE
	BEGIN
		IF @SingleTicketsXML IS NOT NULL
		BEGIN
			INSERT INTO #tmpInputTransId (TransId, RequestId, IssueTypeId)
			SELECT t.c.value('@tid','BIGINT') AS TransId
					,t.c.value('@req','INT') AS RequestId
					,t.c.value('@iss','TINYINT') AS IssueTypeId
			FROM @SingleTicketsXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@SingleTicketsXML = NULL)) 
		END

		IF @ParlayTicketsXML IS NOT NULL
		BEGIN
			INSERT INTO #tmpInputTransId (TransId, RequestId, IsMixParlay, IssueTypeId)
			SELECT t.c.value('@tid','BIGINT') AS TransId
					,t.c.value('@req','INT') AS RequestId
					,1 AS IsMixParlay
					,t.c.value('@iss','TINYINT') AS IssueTypeId
			FROM @ParlayTicketsXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@ParlayTicketsXML = NULL)) 
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
			INSERT INTO #RequestMixParlay_NoStatusWL (RequestId, ProcessMixParlayStatus)
			SELECT DISTINCT t.RequestId, 0
			FROM #tmpTransIds t
				LEFT JOIN cte_SubMatch c ON c.TransId = t.TransId
			WHERE t.IsMixParlay = 1
					AND t.statuswinlost IS NULL
					AND c.TransId IS NULL
		END
	END

	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #SingleTickets
	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #ParlayTickets
	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #SingleTickets_ReSettle
	SELECT TransId, RequestId, Matchid, IssueTypeId FROM #ParlayTickets_ReSettle
	SELECT RequestId, ProcessMixParlayStatus FROM #RequestMixParlay_NoStatusWL

	DROP TABLE #tmpInputTransId
	DROP TABLE #tmpTransIds
	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
	DROP TABLE #SingleTickets_ReSettle
	DROP TABLE #ParlayTickets_ReSettle
	DROP TABLE #RequestMixParlay_NoStatusWL
END		
GO


