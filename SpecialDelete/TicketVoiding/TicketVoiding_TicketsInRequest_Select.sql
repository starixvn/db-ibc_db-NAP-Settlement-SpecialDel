/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet,bodbSPUNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_TicketsInRequest_Select]
(
	@TransIds VARCHAR(MAX) = NULL
	,@MatchId INT
)
AS
/*	Created by: Max
	Date 20200521
	Task: [CTS] Problem Account Monitor
	DB: DBACC/bodb02
	
	Revisions: 
		- 20200521@Max:[CTS] Problem Account Monitor [Redmine:#133798]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #inputTransId (transid BIGINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT)

	INSERT INTO #inputTransId (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO #TransidInRequest (TransId, RequestId)
	SELECT tmp.transid, req.RequestId
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
		INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
		CROSS APPLY (SELECT value AS transid
						FROM STRING_SPLIT(rd.TransIds, ',')
					) AS tmp
	WHERE req.IssueTypeId = 11 
		AND rd.MatchId = @MatchId

	SELECT t.transid, req.RequestId
	FROM #inputTransId t WITH (NOLOCK)
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
		CROSS APPLY (
					SELECT TransId, RequestId
					FROM #TransidInRequest
					WHERE TransId = t.transid
			)req
	WHERE b.statusID NOT IN (101, 102, 103)
	
	DROP TABLE #inputTransId
	DROP TABLE #TransidInRequest
	
END		
GO


