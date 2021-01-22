/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Job]
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestId			INT
			,@MatchId			INT
			,@VoidingHistoryId	INT
			,@VoidingTypeId		TINYINT
			,@QueueId			INT
			,@TransIds			VARCHAR(MAX)
			,@UserId			INT
			,@IP				VARCHAR(50)
			,@StatusId			TINYINT

			,@ErrCode			INT
			,@ErrMsg			VARCHAR(300)
			,@FailedTransIds	VARCHAR(MAX)
			,@NegativeBalanceUsers VARCHAR(MAX)
			,@IssueTypeId	TINYINT
			,@QueueIds VARCHAR(MAX)

	DECLARE @tmpQueue TABLE (
		RequestId		INT
		,QueueId		INT
		,MatchId		INT
		,VoidingTypeId	TINYINT
		,TransIds		VARCHAR(MAX)
		,UserId			INT
		,IP				VARCHAR(50)
		,IsFinished		BIT DEFAULT(0)
	)

	DECLARE @tmpVoidBetAutomation_Service TABLE (
		RequestID	INT
	)

	DECLARE @tmpQueue_update TABLE (
		QueueId	INT
	)

	IF EXISTS(SELECT TOP 1 1 FROM dbo.TicketVoiding_Queue WHERE StatusId = 1)
		RETURN

	SELECT TOP (1) @VoidingHistoryId = VoidingHistoryId
	FROM	dbo.TicketVoiding_Queue WITH(ROWLOCK)
	WHERE	StatusId = 0 -- waiting
	ORDER BY Starttime 
			,VoidingHistoryId

	IF @@ROWCOUNT = 0
		RETURN

	INSERT INTO @tmpQueue (
		RequestId
		,QueueId
		,MatchId
		,VoidingTypeId
		,TransIds
		,UserId
		,IP
	)
	SELECT	RequestId
			,QueueId
			,MatchId
			,VoidingTypeId
			,TransIds
			,UserId
			,IP
	FROM	dbo.TicketVoiding_Queue WITH(NOLOCK)
	WHERE	VoidingHistoryId = @VoidingHistoryId
			AND StatusId = 0

	WHILE(1 = 1)
	BEGIN
		UPDATE	TOP (1) q 
			SET IsFinished = 1
				,@RequestId = q.RequestId
				,@QueueId = q.QueueId
				,@MatchId = q.MatchId
				,@VoidingTypeId = q.VoidingTypeId
				,@TransIds = q.TransIds
				,@UserId = q.UserId
				,@IP = q.IP
		FROM	@tmpQueue q
			INNER JOIN dbo.TicketVoiding_Queue t WITH (NOLOCK) ON t.QueueId = q.QueueId AND t.StatusId = 0
		WHERE	q.IsFinished = 0

		IF @@ROWCOUNT = 0
			BREAK

		SELECT	@ErrCode = 0
				,@ErrMsg = ''
				,@FailedTransIds = ''
				,@StatusId = 1 -- running

		UPDATE	q  WITH(ROWLOCK, UPDLOCK)
			SET StatusId = @StatusId
				,Exectime = GETDATE()
		FROM	dbo.TicketVoiding_Queue q
		WHERE	q.QueueId = @QueueId
	
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK) WHERE RequestID = @RequestId AND VoidingHistory = @VoidingHistoryId)
		BEGIN
			DECLARE @sessionID INT = 0
			SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1

			SET @IssueTypeId = (SELECT IssueTypeId FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId)

			INSERT INTO Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistory,statusID,matchID,SessionID, IsAutoVoid)
			SELECT @RequestId, @VoidingHistoryId,1,CASE WHEN @IssueTypeId <> 13 THEN @MatchId ELSE NULL END,@sessionID,0
		END

		BEGIN TRY
			EXEC dbo.TicketVoiding_Ticket_Update 
				@RequestId = @RequestId
				,@MatchId = @MatchId
				,@TransIds = @TransIds
				,@VoidingHistoryId = @VoidingHistoryId
				,@VoidingTypeId = @VoidingTypeId
				,@UserId = @UserId
				,@IP = @IP
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
				,@FailedTransIds = @FailedTransIds OUTPUT
				,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
				,@QueueIds = @QueueIds OUTPUT

		END TRY
		BEGIN CATCH
			SELECT	@StatusId = 3 -- failed
					,@ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
					,@FailedTransIds = @FailedTransIds
					,@NegativeBalanceUsers = @NegativeBalanceUsers
		END CATCH

		INSERT INTO @tmpQueue_update(QueueId)
		SELECT	val AS TransId
		FROM	dbo.f_SplitString(@QueueIds, ',')
		OPTION (maxrecursion 0)

		UPDATE	q WITH(ROWLOCK, UPDLOCK)
			SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
				,StatusId = CASE WHEN @ErrCode <> 0 AND @ErrCode <> 100 THEN 3 
								 ELSE 2 END
				,ErrMsg = @ErrMsg
				,FailedTransIds = @FailedTransIds
				,NegativeBalanceUsers = @NegativeBalanceUsers
		FROM	dbo.TicketVoiding_Queue q
			INNER JOIN @tmpQueue_update q1 ON q1.QueueId = q.QueueId

		UPDATE s WITH (ROWLOCK, UPDLOCK)
			SET s.statusID = CASE WHEN @ErrCode = 100 THEN 12 -- Service completed
								  WHEN @ErrCode <> 0 AND @ErrCode <> 100 THEN 3 -- Failed
								  ELSE 2 END -- DB completed
				,s.NegativeBalanceUsers = @NegativeBalanceUsers
		FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
		WHERE RequestID = @RequestId AND VoidingHistory = @VoidingHistoryId

		IF @ErrCode = 100 --'No ticket found.'
		BEGIN
			UPDATE vh WITH (ROWLOCK, UPDLOCK)
				SET vh.statusID = 2 -- Completed
			FROM dbo.TicketVoiding_VoidingHistory vh
			WHERE RequestID = @RequestId AND VoidingHistoryId = @VoidingHistoryId
		END

	END
END
GO


