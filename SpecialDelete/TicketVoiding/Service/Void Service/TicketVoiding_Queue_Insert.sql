/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Insert]
(
	@VoidingHistoryId		INT
	,@RequestId				INT
	,@TicketsJSON			NVARCHAR(MAX) = NULL
	,@UserId				INT
	,@IP					VARCHAR(50)
)
AS
/*	Created by: 20181212@Kathy
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20210501@July: TVS - Abnormal Account [Redmine: #143666]
		- 20210209@Kathy: insert queue slowly with abnormal account issue type [Redmine:#150199]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId		INT
		  , @TotalTicket	INT
		  , @TransIds		VARCHAR(MAX)
		  , @start			INT = 1
		  , @end			INT
		  , @IssueTypeId	INT = NULL
		  , @VoidingTypeId	TINYINT
	
	CREATE TABLE #tmpInputTransId (
		TransId BIGINT
		, MatchId INT
		, IssueTypeId INT
		, VoidingTypeId	TINYINT
	)

	DECLARE @tmpMatchId AS TABLE (ID INT IDENTITY(1,1), MatchId INT, VoidingTypeId TINYINT)
	DECLARE @tmpTransIdBatch AS TABLE (TransId BIGINT)

	IF @TicketsJSON IS NOT NULL
	BEGIN
		INSERT INTO #tmpInputTransId (TransId, MatchId, IssueTypeId, VoidingTypeId)
		SELECT tbl.TransId, tbl.MatchId, tbl.IssueTypeId, tbl.VoidingTypeId 
		FROM OPENJSON(@TicketsJSON)
			WITH (MatchId INT, TransId BIGINT, IssueTypeId INT, VoidingTypeId TINYINT) tbl
	END

	INSERT INTO @tmpMatchId (MatchId, VoidingTypeId)
	SELECT DISTINCT t.MatchId, t.VoidingTypeId
	FROM #tmpInputTransId t

	SET @IssueTypeId = (SELECT TOP(1) t.IssueTypeId FROM #tmpInputTransId t)

	SET @end = (SELECT MAX(ID) FROM @tmpMatchId)
	WHILE (@start <= @end)
	BEGIN		
		SELECT @Matchid = matchid, @VoidingTypeId = VoidingTypeId
		FROM @tmpMatchId
		WHERE ID = @start

		WHILE (1=1)
		BEGIN
			SELECT @TransIds = '', @TotalTicket = 0
			DELETE @tmpTransIdBatch

			DELETE TOP(2000) t OUTPUT DELETED.TransId INTO @tmpTransIdBatch (TransId)
			FROM #tmpInputTransId t
			WHERE t.MatchId = @MatchId
				AND t.VoidingTypeId = @VoidingTypeId

			SET @TotalTicket = @@ROWCOUNT
			IF @TotalTicket = 0
				BREAK;

			SET @TransIds = (STUFF((SELECT DISTINCT  ',' + CAST( m.TransId AS VARCHAR(20))
								FROM @tmpTransIdBatch m
								FOR XML PATH ('')
							),1,1,''))
				
			IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_Queue q WITH (NOLOCK) 
							WHERE q.RequestId = @RequestId AND q.VoidingHistoryId = @VoidingHistoryId AND q.TransIds = @TransIds)
			BEGIN
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
					,IssueTypeId
				)
				SELECT	@RequestId
						,@MatchId
						,@VoidingHistoryId
						,@TransIds
						,99 -- waiting
						,@UserId
						,@IP
						,@VoidingTypeId
						,@TotalTicket
						,@IssueTypeId
			END
		END
		
		SET @start = @start + 1
	END

	UPDATE q SET q.StatusId = 1
	FROM dbo.TicketVoiding_Queue q WITH (ROWLOCK, UPDLOCK)
	WHERE q.RequestId = @RequestId 
		AND q.VoidingHistoryId = @VoidingHistoryId
		AND q.StatusId = 99

	DROP TABLE #tmpInputTransId
END
GO

