/*<info serverAlias="DBSIC-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Retry_Credit]
(
	@QueueId	BIGINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
)
AS
/*	
	Created: 20230712@Max
    Task: Scale out DBTRANS for Credit market - [Redmine: #181595]
    DB: DBSIC/bodb02
    Revisions:
		- 20230712@Max: Clone from DBTRANS - [Redmine: #181595]
		- 20250225@Max: Enhance case duplicate rejected parlay ticket in queue [Redmine: #218599]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @TryCount TINYINT = 1
		, @Success BIT = 0
		, @rowcountMBC INT = 0
		, @rowcount789 INT = 0
		, @IsExistsMBC BIT = 0
		, @IsExists789	BIT = 0

	CREATE TABLE #CustLimitBet_RetryTransId_MBC (TransId BIGINT, TryCount TINYINT)
	CREATE TABLE #CustLimitBet_RetryTransId_789 (TransId BIGINT, TryCount TINYINT)

	DECLARE @CustLimitBet_RetryTransId_Batch AS TABLE (TransId BIGINT, IsProcessed BIT DEFAULT (0))

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
				OUTPUT DELETED.TransId, 0 INTO @CustLimitBet_RetryTransId_Batch (TransId, IsProcessed)
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
					--Delete invalid transid in case insert queue duplicate
					UPDATE t
						SET IsProcessed = 1
					FROM @CustLimitBet_RetryTransId_Batch t
					CROSS APPLY (
							SELECT SUM(l.TurnoverAdjust) AS TurnoverAdjust
							FROM dbo.CustLimitBetHistory_MBC l WITH (NOLOCK)
							WHERE l.Transid = t.transid
							GROUP BY l.Matchid, l.CustID, l.Transid
					) t1
					WHERE t1.TurnoverAdjust = 0

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
								WHERE t1.IsProcessed = 0
								GROUP BY t2.Matchid, t2.CustId, t1.transid, t2.EventTypeID
							)tmpsum
							WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
							GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
						)tmp

					INSERT INTO dbo.CustLimitBetHistory_MBC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
					SELECT t1.CustId, t1.MatchId, t.transid
						, -MAX(t1.TurnoverAdjust) 
						, -MAX(t1.PayoutAdjust)
						, t1.EventTypeID
					FROM @CustLimitBet_RetryTransId_Batch t
						INNER JOIN dbo.CustLimitBetHistory_MBC t1 WITH (NOLOCK) ON t1.Transid = t.transid
					WHERE t.IsProcessed = 0
					GROUP BY t1.Matchid, t1.CustId, t.transid, t1.EventTypeID

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
				OUTPUT DELETED.TransId, 0 INTO @CustLimitBet_RetryTransId_Batch (TransId, IsProcessed)
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
					--Delete invalid transid in case insert queue duplicate
					UPDATE t
						SET IsProcessed = 1
					FROM @CustLimitBet_RetryTransId_Batch t
					CROSS APPLY (
							SELECT SUM(l.TurnoverAdjust) AS TurnoverAdjust
							FROM dbo.CustLimitBetHistory_789 l WITH (NOLOCK)
							WHERE l.Transid = t.transid
							GROUP BY l.Matchid, l.CustID, l.Transid
					) t1
					WHERE t1.TurnoverAdjust = 0

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
								WHERE t1.IsProcessed = 0
								GROUP BY t2.Matchid, t2.CustId, t1.transid, t2.EventTypeID
							)tmpsum
							WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
							GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
						)tmp

					INSERT INTO dbo.CustLimitBetHistory_789 (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
					SELECT t1.CustId, t1.MatchId, t.transid
						, -MAX(t1.TurnoverAdjust) 
						, -MAX(t1.PayoutAdjust)
						, t1.EventTypeID
					FROM @CustLimitBet_RetryTransId_Batch t
						INNER JOIN dbo.CustLimitBetHistory_789 t1 WITH (NOLOCK) ON t1.Transid = t.transid
					WHERE t.IsProcessed = 0
					GROUP BY t1.Matchid, t1.CustId, t.transid, t1.EventTypeID

					--Update Retry queue
					UPDATE q SET
						q.StatusId = 1
						,q.Trycount = @TryCount
					FROM dbo.CustLimitBet_QueueRetry q WITH (ROWLOCK, UPDLOCK)
						INNER JOIN @CustLimitBet_RetryTransId_Batch t1 ON t1.TransId = q.TransId
					WHERE q.MainQueueId = @QueueId
				END
			END

			IF @rowcountMBC = 0 AND @rowcount789 = 0
				BREAK;
		END

		IF @IsExistsMBC = 1 OR @IsExists789 = 1
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
END	

GO


