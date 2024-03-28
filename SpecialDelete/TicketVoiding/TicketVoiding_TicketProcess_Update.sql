/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_TicketProcess_Update]
(
	@SingleTicketsJSON			NVARCHAR(MAX) = NULL
	,@ParlayTicketsJSON			NVARCHAR(MAX) = NULL
	,@CancelCashOutTicketsJSON	NVARCHAR(MAX) = NULL
	,@CricketTicketsJSON		NVARCHAR(MAX) = NULL
	,@ResettledTransIds			VARCHAR(MAX)  = NULL
)
AS
/*	
	Created by: 20221201@Max
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20221201@Max: Create new SP [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpInputTransId_Single (TransId BIGINT, RequestId INT, MatchId INT)
	CREATE TABLE #tmpInputTransId_Parlay (TransId BIGINT, RequestId INT, MatchId INT)
	CREATE TABLE #tmpInputTransId_CancelCashOut (TransId BIGINT, RequestId INT, MatchId INT)

	DECLARE @tmpTransIdBatch AS TABLE (TransId BIGINT, RequestId INT, MatchId INT)

	IF (@SingleTicketsJSON IS NOT NULL)
	BEGIN
		INSERT INTO #tmpInputTransId_Single (TransId, RequestId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.MatchId
		FROM OPENJSON(@SingleTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, MatchId INT) tbl
	END

	IF @ParlayTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId_Parlay (TransId, RequestId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.MatchId
		FROM OPENJSON(@ParlayTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, MatchId INT) tbl
	END

	IF @CancelCashOutTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId_CancelCashOut (TransId, RequestId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.MatchId
		FROM OPENJSON(@CancelCashOutTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, MatchId INT) tbl
	END

	IF @CricketTicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId_Single (TransId, RequestId, MatchId)
		SELECT tbl.TransId, tbl.RequestId, tbl.MatchId
		FROM OPENJSON(@CricketTicketsJSON)
			WITH (RequestId INT, TransId BIGINT, MatchId INT) tbl
	END

	IF @ResettledTransIds IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId_Single (TransId)
		SELECT value 
		FROM string_split(@ResettledTransIds, ',')
		WHERE value <> ''

		WHILE(1=1)
		BEGIN
			DELETE @tmpTransIdBatch

			DELETE TOP(2000) s OUTPUT deleted.TransId INTO @tmpTransIdBatch(TransId)
			FROM #tmpInputTransId_Single s

			IF @@ROWCOUNT = 0
				BREAK

			UPDATE s SET s.IsProcessed = 2 --Mark resettled ticket
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tmpTransIdBatch t ON t.TransId = s.TransId

		END
		RETURN
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
	
	--Cancel cash-out update
	WHILE(1=1)
	BEGIN
		DELETE @tmpTransIdBatch

		DELETE TOP(2000) s OUTPUT deleted.TransId, deleted.RequestId INTO @tmpTransIdBatch(TransId, RequestId)
		FROM #tmpInputTransId_CancelCashOut s

		IF @@ROWCOUNT = 0
			BREAK

		UPDATE s SET s.IsProcessed = 1
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIdBatch t ON t.RequestId = s.RequestId AND t.TransId = s.TransId
		WHERE s.IsCancelCO = 1
	END
	

	DROP TABLE #tmpInputTransId_Single
	DROP TABLE #tmpInputTransId_Parlay
	DROP TABLE #tmpInputTransId_CancelCashOut
END		
GO


