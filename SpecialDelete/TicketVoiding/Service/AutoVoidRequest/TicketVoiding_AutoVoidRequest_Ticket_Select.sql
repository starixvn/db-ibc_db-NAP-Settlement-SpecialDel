/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Ticket_Select]
(
	@SiteDBGroupID	SMALLINT
	,@MatchId		INT = 0
	,@Action		VARCHAR(50) = 'CAL'
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

	IF @RequestId > 0 AND EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Request r WITH (NOLOCK) WHERE r.RequestId = @RequestId AND r.ActionId NOT IN (2,3,5))
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
	END
	ELSE
	BEGIN
		IF @Action <> 'CAL-PAR'
		BEGIN
			--Single
			INSERT INTO #SingleTickets (TransId, RequestId, IssueTypeId, MatchId)
			SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
			WHERE rds.MatchId = @MatchId
				AND rds.SiteDBGroupID = @SiteDBGroupID
				AND rds.MatchId <> 29
				AND r.ActionId NOT IN (2,3,5)
		END
		ELSE
		BEGIN
			--Main parlay
			INSERT INTO #ParlayTickets (TransId, RequestId, IssueTypeId, MatchId)
			SELECT  rds.transid, rds.RequestId, rds.IssueTypeId, rds.MatchId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK)
				INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
				CROSS APPLY (
						SELECT m.MainTransId
						FROM dbo.TicketVoiding_RequestDetail_MixParlay m WITH (NOLOCK)
						WHERE m.MatchId = @MatchId
							AND m.MainTransId = rds.TransId
					)rm
			WHERE rds.SiteDBGroupID = @SiteDBGroupID
				AND rds.MatchId = 29
				AND r.ActionId NOT IN (2,3,5)
		END
	END

	SELECT TransId, RequestId, IssueTypeId, MatchId FROM #SingleTickets
	SELECT TransId, RequestId, IssueTypeId, MatchId FROM #ParlayTickets

	DROP TABLE #SingleTickets
	DROP TABLE #ParlayTickets
END		
GO


