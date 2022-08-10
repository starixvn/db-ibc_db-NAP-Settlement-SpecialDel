/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Select]
(
	@SiteDBGroupID	SMALLINT
	,@MatchId		INT = 0
	,@Action		VARCHAR(50) = NULL
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

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #SingleTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT)
	CREATE TABLE #ParlayTickets (TransId BIGINT, RequestId INT, IssueTypeId INT, MatchId INT)

	IF @RequestId > 0
	BEGIN
		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
		WHERE rds.RequestId = @RequestId
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId <> 29

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
		WHERE rds.RequestId = @RequestId
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId = 29

		--Sub parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rds WITH (NOLOCK)
		WHERE rds.RequestId = @RequestId
			AND rds.SiteDBGroupID = @SiteDBGroupID
	END
	ELSE
	BEGIN
		--Single
		INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
		WHERE rds.MatchId = @MatchId
			AND rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId <> 29

		--Main parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
			CROSS APPLY (
					SELECT m.MainTransId
					FROM dbo.TicketVoiding_RequestDetail_MixParlay m WITH (NOLOCK)
					WHERE m.MatchId = @MatchId
						AND m.MainTransId = rds.TransId
				)rm
		WHERE rds.SiteDBGroupID = @SiteDBGroupID
			AND rds.MatchId = 29

		--Sub parlay
		INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId)
		SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rds WITH (NOLOCK)
		WHERE rds.MatchId = @MatchId
			AND rds.SiteDBGroupID = @SiteDBGroupID
	END

	SELECT TransId, RequestId, IssueTypeId, MatchId FROM #SingleTickets
	SELECT TransId, RequestId, IssueTypeId, MatchId FROM #ParlayTickets

	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
END		
GO


