/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_CheckQueue]
(
	@SingleTicketsJSON	NVARCHAR(MAX) = NULL
	,@ParlayTicketsJSON	NVARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20221201
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20221201@Max: Create new SP [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, IsMixParlay BIT DEFAULT(0), IssueTypeId TINYINT)

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

	--Remove request has already exists waiting in queue
	DELETE t
	FROM #tmpInputTransId t
		INNER JOIN dbo.TicketVoiding_AutoVoidQueue q WITH (NOLOCK) ON q.RequestId = t.RequestId 
	WHERE q.Action = 'CAL'
		AND q.StatusId = 0
	
	--Get statusWL of tiket
	IF EXISTS (SELECT TOP(1) 1 FROM #tmpInputTransId t
					INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
				WHERE b.statuswinlost IS NOT NULL AND b.statusID IN (0,1))
	BEGIN
		SELECT DISTINCT t.RequestId, b.matchid
		FROM #tmpInputTransId t 
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransId
		WHERE b.statuswinlost IS NOT NULL 
			AND b.statusID IN (0,1)
	END
	

	DROP TABLE #tmpInputTransId
END		
GO


