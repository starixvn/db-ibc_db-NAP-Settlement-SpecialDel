/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Insert]
(
	@SingleTicketsXML	XML = NULL
	,@ParlayTicketsXML	XML = NULL
	,@UserId			INT
	,@IP				VARCHAR(50)
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20210501@July: TVS - Abnormal Account [Redmine: #143666]
		- 20210209@Kathy: insert queue slowly with abnormal account issue type [Redmine:#150199]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestId INT
		, @VoidingHistoryId INT
		, @MatchId INT
		, @TotalTicket INT
		, @TransIds VARCHAR(MAX)
		, @start INT = 1
		, @end INT

	
	CREATE TABLE #tmpInputTransId (TransId BIGINT, RequestId INT, MatchId INT, VoidingHistoryId INT, IsMixParlay BIT DEFAULT(0))
	--CREATE TABLE #tmpInputParlayTransId (TransId BIGINT, RequestId INT, MatchId INT, VoidingHistoryId INT)

	DECLARE @tmpMatchId AS TABLE (ID INT IDENTITY(1,1), MatchId INT)
	DECLARE @tmpTransIdBatch AS TABLE (TransId BIGINT)

	IF @SingleTicketsXML IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, MatchId, VoidingHistoryId)
		SELECT t.c.value('@tid','BIGINT') AS TransId
				,t.c.value('@req','INT') AS RequestId
				,t.c.value('@mid','INT') AS MatchId
				,t.c.value('@vid','INT') AS VoidingHistoryId
		FROM @SingleTicketsXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@SingleTicketsXML = NULL)) 
	END

	IF @ParlayTicketsXML IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, RequestId, MatchId, VoidingHistoryId, IsMixParlay)
		SELECT t.c.value('@tid','BIGINT') AS TransId
				,t.c.value('@req','INT') AS RequestId
				,t.c.value('@mid','INT') AS MatchId
				,t.c.value('@vid','INT') AS VoidingHistoryId
				,1 AS IsMixParlay
		FROM @ParlayTicketsXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@ParlayTicketsXML = NULL)) 
	END

	SELECT @RequestId = MAX(t.RequestId)
		,@VoidingHistoryId = MAX(t.VoidingHistoryId)
	FROM #tmpInputTransId t

	INSERT INTO @tmpMatchId (MatchId)
	SELECT DISTINCT t.MatchId
	FROM #tmpInputTransId t

	SET @end = (SELECT MAX(ID) FROM @tmpMatchId)
	WHILE (@start <= @end)
	BEGIN		
		SELECT @Matchid = matchid
		FROM @tmpMatchId
		WHERE ID = @start

		IF EXISTS (SELECT TOP(1) 1 FROM #tmpInputTransId WHERE IsMixParlay = 0)
		BEGIN
			WHILE (1=1)
			BEGIN
				SELECT @TransIds = '', @TotalTicket = 0
				DELETE @tmpTransIdBatch

				DELETE TOP(2000) t OUTPUT DELETED.TransId INTO @tmpTransIdBatch (TransId)
				FROM #tmpInputTransId t
				WHERE t.MatchId = @MatchId
					AND t.IsMixParlay = 0

				SET @TotalTicket = @@ROWCOUNT
				IF @TotalTicket = 0
					BREAK;

				SET @TransIds = (STUFF((SELECT DISTINCT  ',' + CAST( m.TransId AS VARCHAR(20))
									FROM @tmpTransIdBatch m
									FOR XML PATH ('')
								),1,1,''))
				
				INSERT INTO dbo.TicketVoiding_Queue (
					RequestId
					,MatchId
					,VoidingHistoryId
					,TransIds
					,StatusId
					,UserId
					,Ip
					,VoidingTypeId
					,TotalTicket
				)
				SELECT	@RequestId
						,@MatchId
						,@VoidingHistoryId
						,@TransIds
						,99 -- waiting
						,@UserId
						,@IP
						,1
						,@TotalTicket
			END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #tmpInputTransId WHERE IsMixParlay = 1)
		BEGIN
			WHILE (1=1)
			BEGIN
				SELECT @TransIds = '', @TotalTicket = 0
				DELETE @tmpTransIdBatch

				DELETE TOP(2000) t OUTPUT DELETED.TransId INTO @tmpTransIdBatch (TransId)
				FROM #tmpInputTransId t
				WHERE t.MatchId = @MatchId
					AND t.IsMixParlay = 1

				SET @TotalTicket = @@ROWCOUNT
				IF @TotalTicket = 0
					BREAK;

				SET @TransIds = (STUFF((SELECT DISTINCT  ',' + CAST( m.TransId AS VARCHAR(20))
									FROM @tmpTransIdBatch m
									FOR XML PATH ('')
								),1,1,''))
				
				INSERT INTO dbo.TicketVoiding_Queue (
					RequestId
					,MatchId
					,VoidingHistoryId
					,TransIds
					,StatusId
					,UserId
					,Ip
					,VoidingTypeId
					,TotalTicket
				)
				SELECT	@RequestId
						,@MatchId
						,@VoidingHistoryId
						,@TransIds
						,99 -- waiting
						,@UserId
						,@IP
						,2
						,@TotalTicket
			END
		END

		SET @start = @start + 1
	END

	UPDATE q SET q.StatusId = 1
	FROM dbo.TicketVoiding_Queue q WITH (ROWLOCK, UPDLOCK)
	WHERE q.RequestId = @RequestId 
		AND q.VoidingTypeId = @VoidingHistoryId
		AND q.StatusId = 99

	DROP TABLE #tmpInputTransId
END
GO

