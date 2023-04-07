/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Ticket_Select]
(
	@SiteDBGroupID		SMALLINT	  = NULL
	,@RequestIds		VARCHAR(MAX)  = NULL
)
AS
/*	
	Created by: 20220727@Max
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230321@Max: Hotfix scan request auto void winning [Redmine: #185526]

	Param's explanation:
		+ Both @RequestIds, @SiteDBGroupID IS NULL: Service scan signal settle 5p/time
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT, SiteDBGroupId SMALLINT, bettype SMALLINT, CustId INT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT, SiteDBGroupId SMALLINT)
	
	IF @RequestIds IS NOT NULL
	BEGIN
		DECLARE @tmpRequestId TABLE (RequestId INT)
		INSERT INTO @tmpRequestId (RequestId)
		SELECT value FROM STRING_SPLIT (@RequestIds, ',')

		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, bettype, CustId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, rds.Bettype, rds.CustId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
		WHERE rds.RequestId IN (SELECT RequestId FROM @tmpRequestId)
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId <> 29
			AND rds.IsProcessed IS NULL

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
		WHERE rds.RequestId IN (SELECT RequestId FROM @tmpRequestId)
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId = 29
			AND rds.IsProcessed IS NULL
	END
	ELSE --Get all ticket all requests
	BEGIN
		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, bettype, CustId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, rds.Bettype, rds.CustId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rds.MatchId
		WHERE rds.MatchId <> 29
			AND r.ActionId = 1
			AND rds.IsProcessed IS NULL
			AND GETDATE() >= m.GlobalShowTime

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
		WHERE rds.MatchId = 29
			AND r.ActionId = 1
			AND rds.IsProcessed IS NULL
	END

	--Single ticket exclude cricket bettype 501 of credit (NP)
	SELECT TransId, RequestId, IssueTypeId, MatchId, s.SiteDBGroupId 
	FROM #SingleTickets s
		INNER JOIN CustDB.dbo.custinfo c WITH (NOLOCK) ON c.custid = s.CustId
		LEFT JOIN CustDB.dbo.Dep_CustSuper ds WITH (NOLOCK) ON ds.custid = c.srecommend
	WHERE 1 = CASE WHEN s.bettype <> 501 THEN 1
				WHEN s.bettype = 501 AND ds.custid IS NOT NULL THEN 1 
			ELSE 0 END

	--Parlay
	SELECT TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId FROM #ParlayTickets

	--Cricket bettype 501 of credit (NP)
	SELECT TransId, RequestId, IssueTypeId, MatchId, s.SiteDBGroupId 
	FROM #SingleTickets s 
		INNER JOIN CustDB.dbo.custinfo c WITH (NOLOCK) ON c.custid = s.CustId
		LEFT JOIN CustDB.dbo.Dep_CustSuper ds WITH (NOLOCK) ON ds.custid = c.srecommend
	WHERE s.bettype = 501 AND ds.custid IS NULL

	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
END		
GO


