/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_BalanceUpdCreditCasino]
/*
	Created: 20200915@Helen
	Task: Get SP from Production
	DB: DBTXN/bodb02
	
	Revisions:   
		- 20200915@Helen: Balance Delay Issue [Redmine:#141293]
*/
AS
BEGIN
	SET NOCOUNT ON
	Declare @Version smallmoney SET @Version = 2.0

	Declare @beginTime datetime2, @startTime datetime2, @secUpdate smallmoney, @secDelete smallmoney
	Declare @totalCustID int, @loopCnt int, @mintstamp datetime2
	Declare @rn bigint, @rnx bigint, @RC int
	Declare @i int, @custid int, @balance money
	Declare @Retry int, @Success bit, @RetryCnt int, @RetryDelCnt int

	SET @beginTime = SYSDATETIME()
	SET @RetryCnt = 0
	SET @RetryDelCnt = 0

	IF NOT EXISTS (SELECT 1 FROM dbo.BalCreditCasinoPending)
	BEGIN
		WAITFOR DELAY '000:00:00.200'
		RETURN -- no data to be update.
	END

	SELECT @rn = MIN(rn), @rnx = MAX(rn), @mintstamp = MIN(tstamp)
	FROM dbo.BalCreditCasinoPending with (nolock)

	CREATE TABLE #Balance (rn int IDENTITY(1,1) PRIMARY KEY, custid int, balance money)
	CREATE TABLE #tmpBalance (custid int, balance money)

	-- Wait 5 seconds, to allow any INSERT process to finish working with current command.
	-- WAITFOR DELAY '000:00:05.000'

	SET @startTime = SYSDATETIME()
	-- collect balance value.
	INSERT INTO #Balance (custid, balance)
	SELECT custid, SUM(balance)
	FROM dbo.BalCreditCasinoPending with (ROWLOCK)
	WHERE rn <= @rnx
	GROUP BY custid
	ORDER BY MIN(rn)

	SET @totalCustID = @@ROWCOUNT
	SET @loopCnt = @totalCustID

	TryAgain:

	SET @i = 1

	-- perform update, retry 3 times for each account.
	WHILE @i <= @loopCnt
	BEGIN
		SELECT @custid = custid, @balance = balance
		FROM #Balance
		WHERE rn = @i

		SET @Retry = 0
		SET @Success = 0
		
		WHILE @Retry < 3 AND @Success = 0
		BEGIN
			BEGIN TRY
				SET @Success = 1
				BEGIN TRANSACTION
				
					UPDATE dbo.BalCreditCasino WITH (ROWLOCK, UPDLOCK)
					SET Balance = Balance + @balance
					WHERE custid = @custid
					
				COMMIT TRANSACTION
			END TRY
			BEGIN CATCH
				SET @Retry = @Retry + 1
				SET @Success = 0
				ROLLBACK TRANSACTION
			END CATCH
		END
		
		SET @RetryCnt = @RetryCnt + @Retry
		-- save failed attempt for next round.
		IF @Success = 0 INSERT INTO #tmpBalance (custid, balance) SELECT @custid, @balance
		
		SET @i = @i + 1
	END

	-- check for retry if got some account failed in previous loop
	IF EXISTS (SELECT 1 FROM #tmpBalance)
	BEGIN
		TRUNCATE TABLE #Balance
		
		INSERT INTO #Balance (custid, balance) SELECT custid, balance FROM #tmpBalance
		SET @loopCnt = @@ROWCOUNT
		
		DELETE FROM #tmpBalance
		GOTO TryAgain
	END

	SET @secUpdate = DATEDIFF(ms, @startTime, SYSDATETIME())/1000.00
	SET @startTime = SYSDATETIME()
	-- remove data which already updated.
	SET @RC = 1
	WHILE @RC > 0
	BEGIN
		BEGIN TRY
			IF @rn + 99 > @rnx SET @rn = @rnx - 99

			DELETE FROM dbo.BalCreditCasinoPending
				WHERE rn BETWEEN @rn AND @rn + 99
			SET @RC = @@ROWCOUNT

			SET @rn = @rn + 99
		END TRY
		BEGIN CATCH
			SET @RC = 1
			SET @RetryDelCnt = @RetryDelCnt + 1
		END CATCH
	END

	SET @secDelete = DATEDIFF(ms, @startTime, SYSDATETIME())/1000.00
	-- log process
	INSERT INTO dbo.BalancePendingProcessed (byVersion, secPending, totalCustID, retryCnt, retryDelCnt, secUpdate, secDelete, secProcess, Operation, tableSet)
	SELECT @Version * 100,
		DATEDIFF(ms, @mintstamp, SYSDATETIME())/1000.00, @totalCustID, @RetryCnt, @RetryDelCnt,
		@secUpdate, @secDelete, DATEDIFF(ms, @beginTime, SYSDATETIME())/1000.00 - 5, 'C', 3


	DROP TABLE #Balance
	DROP TABLE #tmpBalance
END	
GO


