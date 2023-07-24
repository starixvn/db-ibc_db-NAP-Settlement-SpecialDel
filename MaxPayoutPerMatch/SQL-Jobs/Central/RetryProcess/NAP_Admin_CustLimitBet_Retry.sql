/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Retry]
(
	@QueueId	BIGINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
)
AS
/*	
	Created: 20220419@Max
    Task: Max Payout - Retry for Reject Action [Redmine: #171674]
    DB: DBCTG/bodb02
    Revisions:
		- 20220419@Max: Max Payout - Retry for Reject Action [Redmine: #171674]
		- 20230216@Max: Max Payout - AccumTurnover / AccumPayout is Negative because of some reasons [Redmine: #183935]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @TryCount TINYINT = 1
		, @Success BIT = 0
		, @rowcountMBC INT = 0
		, @rowcount789 INT = 0
		, @rowcountLIC INT = 0
		, @IsExistsMBC BIT = 0
		, @IsExists789	BIT = 0
		, @IsExistsLIC BIT = 0

	CREATE TABLE #CustLimitBet_RetryTransId_MBC (TransId BIGINT, TryCount TINYINT)
	CREATE TABLE #CustLimitBet_RetryTransId_789 (TransId BIGINT, TryCount TINYINT)
	CREATE TABLE #CustLimitBet_RetryTransId_LIC (TransId BIGINT, TryCount TINYINT)

	DECLARE @CustLimitBet_RetryTransId_Batch AS TABLE (TransId BIGINT)

	--Prepare data for MBC
	INSERT #CustLimitBet_RetryTransId_MBC (TransId, TryCount)
	SELECT q.TransId, @TryCount
	FROM dbo.CustLimitBet_QueueRetry q WITH(NOLOCK)
	WHERE q.MainQueueId = @QueueId
		AND q.sitetype = 1
		AND q.StatusId = 0
	
	IF @@ROWCOUNT > 0 
		SET @IsExistsMBC = 1

	--Prepare data for 789
	INSERT #CustLimitBet_RetryTransId_789 (TransId, TryCount)
	SELECT q.TransId, @TryCount
	FROM dbo.CustLimitBet_QueueRetry q WITH(NOLOCK)
	WHERE q.MainQueueId = @QueueId
		AND q.sitetype = 2
		AND q.StatusId = 0

	IF @@ROWCOUNT > 0 
		SET @IsExists789 = 1

	--Prepare data for LIC
	INSERT #CustLimitBet_RetryTransId_LIC (TransId, TryCount)
	SELECT q.TransId, @TryCount
	FROM dbo.CustLimitBet_QueueRetry q WITH(NOLOCK)
	WHERE q.MainQueueId = @QueueId
		AND q.sitetype = 3
		AND q.StatusId = 0

	IF @@ROWCOUNT > 0 
		SET @IsExistsLIC = 1
	
	--Start Retry Process
	WHILE (@Success = 0 AND @TryCount <= 5)
	BEGIN
		SET @Success = 1

		WHILE (1=1)
		BEGIN
			--MBC
			IF @IsExistsMBC = 1
			BEGIN
				DELETE @CustLimitBet_RetryTransId_Batch

				DELETE TOP(2000) t1
				OUTPUT DELETED.TransId INTO @CustLimitBet_RetryTransId_Batch
				FROM #CustLimitBet_RetryTransId_MBC t1
					INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Transid = t1.transid
				WHERE t1.TryCount = @TryCount

				SET @rowcountMBC = @@ROWCOUNT
				IF @rowcountMBC = 0
				BEGIN
					IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_RetryTransId_MBC WHERE TryCount = @TryCount)
					BEGIN
						UPDATE t1 SET TryCount = TryCount + 1
						FROM #CustLimitBet_RetryTransId_MBC t1
						WHERE TryCount = @TryCount
					END
					ELSE
					BEGIN
						SET @IsExistsMBC = 0
					END
				END

				IF @rowcountMBC > 0
				BEGIN
					--UPDATE CustLimitBet_MBC
					UPDATE t SET t.AccumTurnover = (t.AccumTurnover + tmp.AccumTurnover), t.AccumPayout = (t.AccumPayout + tmp.AccumPayout), t.LastQueueID = @QueueId, t.ModifiedDate = GETDATE()
					FROM dbo.CustLimitBet_MBC t WITH (ROWLOCK)
						CROSS APPLY (
							SELECT -SUM(tmpsum.AccumTurnover)  AS AccumTurnover
								, -SUM(tmpsum.AccumPayout) AS AccumPayout
								,tmpsum.MatchId, tmpsum.CustId
							FROM
							(
								SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t2.MatchId, t2.CustId, t1.transid, t2.EventTypeID
								FROM @CustLimitBet_RetryTransId_Batch t1
									INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Transid = t1.transid
								GROUP BY t2.Matchid, t2.CustId, t1.transid, t2.EventTypeID
							)tmpsum
							WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
							GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
						)tmp

					--Update Retry queue
					UPDATE q SET
						q.StatusId = 1
						,q.Trycount = @TryCount
					FROM dbo.CustLimitBet_QueueRetry q WITH (ROWLOCK, UPDLOCK)
						INNER JOIN @CustLimitBet_RetryTransId_Batch t1 ON t1.TransId = q.TransId
					WHERE q.MainQueueId = @QueueId
				END
			END
			
			--789y
			IF @IsExists789 = 1
			BEGIN
				DELETE @CustLimitBet_RetryTransId_Batch

				DELETE TOP(2000) t1
				OUTPUT DELETED.TransId INTO @CustLimitBet_RetryTransId_Batch
				FROM #CustLimitBet_RetryTransId_789 t1
					INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Transid = t1.transid
				WHERE t1.TryCount = @TryCount

				SET @rowcount789 = @@ROWCOUNT
				IF @rowcount789 = 0
				BEGIN
					IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_RetryTransId_789 WHERE TryCount = @TryCount)
					BEGIN
						UPDATE t1 SET TryCount = TryCount + 1
						FROM #CustLimitBet_RetryTransId_789 t1
						WHERE TryCount = @TryCount
					END
					ELSE
					BEGIN
						SET @IsExists789 = 0
					END
				END

				IF @rowcount789 > 0
				BEGIN
					--UPDATE CustLimitBet_789
					UPDATE t SET t.AccumTurnover = (t.AccumTurnover + tmp.AccumTurnover), t.AccumPayout = (t.AccumPayout + tmp.AccumPayout), t.LastQueueID = @QueueId, t.ModifiedDate = GETDATE()
					FROM dbo.CustLimitBet_789 t WITH (ROWLOCK)
						CROSS APPLY (
							SELECT -SUM(tmpsum.AccumTurnover)  AS AccumTurnover
								, -SUM(tmpsum.AccumPayout) AS AccumPayout
								,tmpsum.MatchId, tmpsum.CustId
							FROM
							(
								SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t2.MatchId, t2.CustId, t1.transid, t2.EventTypeID
								FROM @CustLimitBet_RetryTransId_Batch t1
									INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Transid = t1.transid
								GROUP BY t2.Matchid, t2.CustId, t1.transid, t2.EventTypeID
							)tmpsum
							WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
							GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
						)tmp

					--Update Retry queue
					UPDATE q SET
						q.StatusId = 1
						,q.Trycount = @TryCount
					FROM dbo.CustLimitBet_QueueRetry q WITH (ROWLOCK, UPDLOCK)
						INNER JOIN @CustLimitBet_RetryTransId_Batch t1 ON t1.TransId = q.TransId
					WHERE q.MainQueueId = @QueueId
				END
			END

			--LIC
			IF @IsExistsLIC = 1
			BEGIN
				DELETE @CustLimitBet_RetryTransId_Batch

				DELETE TOP(2000) t1
				OUTPUT DELETED.TransId INTO @CustLimitBet_RetryTransId_Batch
				FROM #CustLimitBet_RetryTransId_LIC t1
					INNER JOIN dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK) ON t2.Transid = t1.transid
				WHERE t1.TryCount = @TryCount

				SET @rowcountLIC = @@ROWCOUNT
				IF @rowcountLIC = 0
				BEGIN
					IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_RetryTransId_LIC WHERE TryCount = @TryCount)
					BEGIN
						UPDATE t1 SET TryCount = TryCount + 1
						FROM #CustLimitBet_RetryTransId_LIC t1
						WHERE TryCount = @TryCount
					END
					ELSE
					BEGIN
						SET @IsExistsLIC = 0
					END
				END

				IF @rowcountLIC > 0
				BEGIN
					--UPDATE CustLimitBet_LIC
					UPDATE t SET t.AccumTurnover = (t.AccumTurnover + tmp.AccumTurnover), t.AccumPayout = (t.AccumPayout + tmp.AccumPayout), t.LastQueueID = @QueueId, t.ModifiedDate = GETDATE()
					FROM dbo.CustLimitBet_LIC t WITH (ROWLOCK)
						CROSS APPLY (
							SELECT -SUM(tmpsum.AccumTurnover)  AS AccumTurnover
								, -SUM(tmpsum.AccumPayout) AS AccumPayout
								,tmpsum.MatchId, tmpsum.CustId
							FROM
							(
								SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t2.MatchId, t2.CustId, t1.transid, t2.EventTypeID
								FROM @CustLimitBet_RetryTransId_Batch t1
									INNER JOIN dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK) ON t2.Transid = t1.transid
								GROUP BY t2.Matchid, t2.CustId, t1.transid, t2.EventTypeID
							)tmpsum
							WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
							GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
						)tmp

					--Update Retry queue
					UPDATE q SET
						q.StatusId = 1
						,q.Trycount = @TryCount
					FROM dbo.CustLimitBet_QueueRetry q WITH (ROWLOCK, UPDLOCK)
						INNER JOIN @CustLimitBet_RetryTransId_Batch t1 ON t1.TransId = q.TransId
					WHERE q.MainQueueId = @QueueId
				END
			END

			IF @rowcountMBC = 0 AND @rowcount789 = 0 AND @rowcountLIC = 0 
				BREAK;
		END

		IF @IsExistsMBC = 1 OR @IsExists789 = 1 OR @IsExistsLIC = 1
		BEGIN
			SET @TryCount = @TryCount + 1
			SET @Success = 0

			WAITFOR DELAY '00:00:05'
		END
	END

	IF @Success = 0
	BEGIN	
		SELECT @ErrCode = 100
		RETURN
	END

	DROP TABLE #CustLimitBet_RetryTransId_MBC
	DROP TABLE #CustLimitBet_RetryTransId_789
	DROP TABLE #CustLimitBet_RetryTransId_LIC
END	

GO


