/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Ticket_Select]
(
	@SiteDBGroupID	SMALLINT = NULL
	,@RequestId		INT = 0

)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT, SiteDBGroupId SMALLINT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT, SiteDBGroupId SMALLINT)

	IF @RequestId > 0
	BEGIN
		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			LEFT JOIN dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK) ON v.TransId = rds.TransId
		WHERE rds.RequestId = @RequestId
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId <> 29
			AND 1 = CASE WHEN rds.IsProcessed IS NULL THEN 1
						WHEN rds.IsProcessed = 1 AND v.TransId IS NULL THEN 1
					ELSE 0 END

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			LEFT JOIN dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK) ON v.TransId = rds.TransId
		WHERE rds.RequestId = @RequestId
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId = 29
			AND 1 = CASE WHEN rds.IsProcessed IS NULL THEN 1
						WHEN rds.IsProcessed = 1 AND v.TransId IS NULL THEN 1
					ELSE 0 END
	END
	ELSE
	BEGIN
		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rds.MatchId
		WHERE rds.MatchId <> 29
			AND r.ActionId = 1
			AND rds.IsProcessed IS NULL
			AND r.CreatedDate >= m.GlobalShowTime

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
		WHERE rds.MatchId = 29
			AND r.ActionId = 1
			AND rds.IsProcessed IS NULL
	END

	SELECT TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId FROM #SingleTickets
	SELECT TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId FROM #ParlayTickets

	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
END		
GO


