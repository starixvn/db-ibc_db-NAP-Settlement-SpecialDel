/*<info serverAlias="DBSIC-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Queue_Credit_Job]
AS
/*	
	Created: 20230712@Max
    Task: Scale out DBTRANS for Credit market - [Redmine: #181595]
    DB: DBSIC/bodb02
    Revisions:
		- 20230712@Max: Clone from DBTRANS - [Redmine: #181595]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @QueueId	INT
		,@MatchId		INT
		,@Transids		VARCHAR(MAX)
		,@ErrCode		INT
		,@ErrMsg		VARCHAR(300)
		,@StatusId		TINYINT
		,@ActionId		TINYINT
		,@EventTypeID	TINYINT


	----- Starting auto voiding process--------
	CREATE TABLE #CustLimitBet_Queue (QueueId INT, matchid INT, CustId INT, EventTypeID TINYINT, Transids VARCHAR(MAX), ActionId TINYINT, CreatedDate DATETIME, IsFinished INT DEFAULT(0))

	CREATE INDEX IX_IsFinished ON #CustLimitBet_Queue (IsFinished, CreatedDate)

	INSERT #CustLimitBet_Queue (QueueId, matchid, CustId, EventTypeID, Transids, ActionId, CreatedDate)
	SELECT q.QueueId, q.matchid, q.CustID, q.EventTypeID, q.Transids, q.ActionID, q.CreatedDate
	FROM dbo.CustLimitBetQueue q WITH(NOLOCK)
	WHERE q.StatusId = 0
	
	WHILE(1=1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = ''
	
		;WITH t AS (SELECT TOP (1) * FROM #CustLimitBet_Queue WHERE IsFinished = 0 ORDER BY CreatedDate)
		UPDATE t
		SET t.IsFinished = 1
			, @QueueId = t.QueueId
			, @MatchId = t.matchid
			, @Transids = t.Transids
			, @EventTypeID = t.EventTypeID
			, @ActionId = t.ActionId
		FROM t
		
		IF @@ROWCOUNT = 0 
			BREAK

		UPDATE	q  WITH(ROWLOCK, UPDLOCK)
			SET Exectime = GETDATE()
		FROM	dbo.CustLimitBetQueue q
		WHERE	q.QueueId = @QueueId

		BEGIN TRY
			EXEC dbo.NAP_Admin_CustLimitBet_Insert_Credit
				@MatchId = @MatchId
				,@Transids = @Transids
				,@QueueId = @QueueId
				,@EventTypeID = @EventTypeID
				,@ActionId = @ActionId
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
		END CATCH

		IF (ISNULL(@ErrCode, 0) <> 0 )
		BEGIN
			IF @ErrCode = 101 --No ticket found
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 1
					,ErrMsg = @ErrMsg
				FROM	dbo.CustLimitBetQueue q
				WHERE	QueueId = @QueueId 
			END
			ELSE
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 2
					,ErrMsg = @ErrMsg
				FROM	dbo.CustLimitBetQueue q
				WHERE	QueueId = @QueueId
			END
		END
		ELSE
		BEGIN
			UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 1
			FROM	dbo.CustLimitBetQueue q 
			WHERE q.QueueId = @QueueId
		END
			
	END

	DROP TABLE #CustLimitBet_Queue
END	

GO


