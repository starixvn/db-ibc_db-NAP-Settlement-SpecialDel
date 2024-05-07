/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230814@Max: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		
	Param's explanation:
		+ Both @RequestIds, @SiteDBGroupID IS NULL: Service scan signal settle 5p/time
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT, SiteDBGroupId SMALLINT, bettype SMALLINT, CustId INT, VoidActionId TINYINT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT, SiteDBGroupId SMALLINT, VoidActionId TINYINT)
	
	IF @RequestIds IS NOT NULL
	BEGIN
		DECLARE @tmpRequestId TABLE (RequestId INT)
		INSERT INTO @tmpRequestId (RequestId)
		SELECT value FROM STRING_SPLIT (@RequestIds, ',')

		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, bettype, CustId, VoidActionId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, rds.Bettype, rds.CustId, r.ActionId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
		WHERE rds.RequestId IN (SELECT RequestId FROM @tmpRequestId)
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId <> 29
			AND rds.IsProcessed IS NULL

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, VoidActionId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, r.ActionId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
		WHERE rds.RequestId IN (SELECT RequestId FROM @tmpRequestId)
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId = 29
			AND rds.IsProcessed IS NULL
		UNION ALL
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, r.ActionId
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
		WHERE rds.RequestId IN (SELECT RequestId FROM @tmpRequestId)
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.IsProcessed IS NULL
	END
	ELSE --Get all ticket all requests
	BEGIN
		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, bettype, CustId, VoidActionId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, rds.Bettype, rds.CustId, r.ActionId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
			CROSS APPLY (
				SELECT m.GlobalShowTime
				FROM dbo.match m WITH (NOLOCK) 
				WHERE m.matchid = rds.MatchId
				UNION 
				SELECT m.GlobalShowTime
				FROM dbo.match14 m WITH (NOLOCK) 
				WHERE m.matchid = rds.MatchId
			)m
		WHERE rds.MatchId <> 29
			AND r.ActionId IN (1,9)
			AND rds.IsProcessed IS NULL
			AND GETDATE() >= m.GlobalShowTime

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, VoidActionId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, r.ActionId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
		WHERE rds.MatchId = 29
			AND r.ActionId = 1
			AND rds.IsProcessed IS NULL

		--Sub parlay for Reduced Over
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, VoidActionId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId, rds.SiteDBGroupID, r.ActionId
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rds WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId 
		WHERE r.ActionId = 9 AND r.IssueTypeId IN (19,23)
			AND rds.IsProcessed IS NULL
	END

	--Single ticket exclude cricket bettype 501 of credit (NP)
	SELECT TransId, RequestId, IssueTypeId, MatchId, s.SiteDBGroupId, s.VoidActionId
	FROM #SingleTickets s
		INNER JOIN CustDB.dbo.custinfo c WITH (NOLOCK) ON c.custid = s.CustId
		LEFT JOIN CustDB.dbo.Dep_CustSuper ds WITH (NOLOCK) ON ds.custid = c.srecommend
	WHERE 1 = CASE WHEN s.bettype <> 501 THEN 1
				WHEN s.bettype = 501 AND ds.custid IS NOT NULL THEN 1 
			ELSE 0 END

	--Parlay
	SELECT TransId, RequestId, IssueTypeId, MatchId, SiteDBGroupId, VoidActionId FROM #ParlayTickets

	--Cricket bettype 501 of credit (NP)
	SELECT TransId, RequestId, IssueTypeId, MatchId, s.SiteDBGroupId, VoidActionId
	FROM #SingleTickets s 
		INNER JOIN CustDB.dbo.custinfo c WITH (NOLOCK) ON c.custid = s.CustId
		LEFT JOIN CustDB.dbo.Dep_CustSuper ds WITH (NOLOCK) ON ds.custid = c.srecommend
	WHERE s.bettype = 501 AND ds.custid IS NULL

	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
END		
GO


