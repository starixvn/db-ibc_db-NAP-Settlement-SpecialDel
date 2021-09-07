/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Queue_Job]
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	
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
	CREATE TABLE #CustLimitBet_Queue (QueueId INT, matchid INT, CustId INT, EventTypeID TINYINT, Transids VARCHAR(MAX), ActionId TINYINT, IsFinished INT DEFAULT(0))

	INSERT #CustLimitBet_Queue (QueueId, matchid, CustId, EventTypeID, Transids, ActionId)
	SELECT q.QueueId, q.matchid, q.CustID, q.EventTypeID, q.Transids, q.ActionID
	FROM dbo.CustLimitBetQueue q WITH(NOLOCK)
	WHERE q.StatusId = 0
	ORDER BY CreatedDate
	
	WHILE(1=1)
	BEGIN
		UPDATE TOP (1) t
		SET t.IsFinished = 1
			, @QueueId = t.QueueId
			, @MatchId = t.matchid
			, @Transids = t.Transids
			, @EventTypeID = t.EventTypeID
			, @ActionId = t.ActionId
		FROM #CustLimitBet_Queue t
		WHERE IsFinished = 0 
		
		IF @@ROWCOUNT = 0 
			BREAK
		
		UPDATE	q  WITH(ROWLOCK, UPDLOCK)
			SET Exectime = GETDATE()
		FROM	dbo.CustLimitBetQueue q
		WHERE	q.QueueId = @QueueId

		BEGIN TRY
			EXEC dbo.NAP_Admin_CustLimitBet_Insert
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


