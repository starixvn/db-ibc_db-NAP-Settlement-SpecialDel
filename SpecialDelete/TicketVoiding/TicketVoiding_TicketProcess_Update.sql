/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TicketProcess_Update]
(
	@SingleTicketsJSON	VARCHAR(MAX) = NULL
	,@ParlayTicketsJSON	VARCHAR(MAX) = NULL
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

	CREATE TABLE #tmpInputTransId_Single (TransId BIGINT, RequestId INT, MatchId INT)
	CREATE TABLE #tmpInputTransId_Parlay (TransId BIGINT, RequestId INT, MatchId INT)

	DECLARE @tmpTransIdBatch AS TABLE (TransId BIGINT, RequestId INT, MatchId INT)

	IF @SingleTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId_Single (TransId, RequestId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.MatchID
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, MatchID INT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId_Parlay (TransId, RequestId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.MatchId
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, MatchId INT) tbl
	END

	--Single update
	WHILE(1=1)
	BEGIN
		DELETE @tmpTransIdBatch

		DELETE TOP(2000) s OUTPUT deleted.TransId, deleted.RequestId INTO @tmpTransIdBatch(TransId, RequestId)
		FROM #tmpInputTransId_Single s

		IF @@ROWCOUNT = 0
			BREAK

		UPDATE s SET s.IsProcessed = 1
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIdBatch t ON t.RequestId = s.RequestId AND t.TransId = s.TransId

	END
	
	--Main, Sub parlay update
	WHILE(1=1)
	BEGIN
		DELETE @tmpTransIdBatch

		DELETE TOP(2000) s OUTPUT deleted.TransId, deleted.RequestId, deleted.MatchId INTO @tmpTransIdBatch(TransId, RequestId, MatchId)
		FROM #tmpInputTransId_Parlay s

		IF @@ROWCOUNT = 0
			BREAK

		UPDATE s SET s.IsProcessed = 1
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIdBatch t ON t.RequestId = s.RequestId AND t.TransId = s.TransId
		WHERE t.MatchId = 29

		UPDATE s SET s.IsProcessed = 1
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIdBatch t ON t.RequestId = s.RequestId AND t.TransId = s.TransId
		WHERE t.MatchId <> 29

	END
	

	DROP TABLE #tmpInputTransId_Single
	DROP TABLE #tmpInputTransId_Parlay
END		
GO


