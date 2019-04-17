/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Job]
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
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
				,@RequestId = RequestId
				,@QueueId = QueueId
				,@MatchId = MatchId
				,@VoidingTypeId = VoidingTypeId
				,@TransIds = TransIds
				,@UserId = UserId
				,@IP = IP
		FROM	@tmpQueue q
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

			SET @StatusId = CASE WHEN @ErrCode <> 0 THEN 3 ELSE 2 END
		END TRY
		BEGIN CATCH
			SELECT	@StatusId = 3 -- failed
					,@ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
					,@FailedTransIds = @FailedTransIds
					,@NegativeBalanceUsers = @NegativeBalanceUsers
		END CATCH

		UPDATE	q WITH(ROWLOCK, UPDLOCK)
			SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
				,StatusId = @StatusId
				,ErrMsg = @ErrMsg
				,FailedTransIds = @FailedTransIds
				,NegativeBalanceUsers = @NegativeBalanceUsers
		FROM	dbo.TicketVoiding_Queue q
		WHERE	QueueId = @QueueId
	END
END
GO


