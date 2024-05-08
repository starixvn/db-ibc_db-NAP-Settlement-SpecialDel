/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Queue_Job]
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBCTG/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210928@Max: HotFix Issue Max Payout - [Redmine: #158846]
		- 20211112@Max: MPO Phase 2 - Enhancement [Redmine #159626]
		- 20240429@Max: Enhance the MaxPayout for the Parlay Settlement [Redmine: #204464]
	
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
		,@xml			XML = NULL

	CREATE TABLE #CustLimitBet_Queue (QueueId INT, matchid INT, CustId INT, EventTypeID TINYINT, Transids VARCHAR(MAX), ActionId TINYINT, CreatedDate DATETIME, IsFinished INT DEFAULT(0))

	CREATE INDEX IX_IsFinished ON #CustLimitBet_Queue (IsFinished, CreatedDate)

	DECLARE @tmp_SettleParlay AS TABLE (CustId INT, transid BIGINT, ruben TINYINT)

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

		IF @ActionId = 6 -- in case settle parlay
		BEGIN
			SET @xml = CONVERT(XML, @Transids)

			INSERT INTO @tmp_SettleParlay (CustId, transid, ruben)
			SELECT t.c.value('@custid','INT') AS custid
					,t.c.value('@transid','BIGINT') AS transid
					,t.c.value('@ruben','tinyint') AS ruben
			FROM @xml.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@xml = NULL))
			
			IF EXISTS (SELECT TOP 1 1 FROM @tmp_SettleParlay WHERE ruben = 1)
			BEGIN	
				SET @ActionId = 4
				SET @TransIds = (SELECT t.CustId AS '@custid'
										,t.TransId AS '@transid'
									FROM	@tmp_SettleParlay t
									WHERE t.ruben = 1
									FOR XML PATH('r'), ROOT('root')
								)

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
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmp_SettleParlay WHERE ruben = 0)
			BEGIN	
				SET @ActionId = 5
				SET @TransIds = (SELECT t.CustId AS '@custid'
										,t.TransId AS '@transid'
									FROM	@tmp_SettleParlay t
									WHERE t.ruben = 0
									FOR XML PATH('r'), ROOT('root')
								)

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
			END
		END
		ELSE
		BEGIN
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
		END

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


