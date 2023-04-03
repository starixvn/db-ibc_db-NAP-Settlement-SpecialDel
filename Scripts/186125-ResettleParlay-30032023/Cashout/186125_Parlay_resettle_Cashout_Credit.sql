-----------STEP 1: ALTER SP EXCREP ------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_07]
(
	@transidlist VARCHAR(MAX) = ''
)

/*	
	Creator: Helen
	Date: 20230403
	DB: DBCTG/bodb02

	Revisions:
		- 20230403@Helen: Resettle ticket for parlay  [Redmine:#186125]

	Notes: basing code from SP ExecRep_NAP_Admin_03 to process for cashout tickets

*/	
AS
BEGIN
	SET NOCOUNT ON
	-----------------------CHECK SERVER-----------------------------------------
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@AllowUndo			BIT
			,@AllowRefund		BIT
			--,@IsSiteDB			BIT = 0
			,@Mode		VARCHAR(20) = 'CAL'
	
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowUndo			= @AllowUndo OUTPUT
			,@AllowRefund		= @AllowRefund OUTPUT

		IF @AllowCalculation = 0 AND @mode = 'CAL'
			RETURN
		
		IF @AllowUndo = 0 AND @mode = 'UNDO'
			RETURN

		IF @AllowRefund = 0 AND @mode = 'REFUND'
			RETURN

	END

	DECLARE
			@statusId			TINYINT
			,@IsUpdated			BIT		
			,@settlementTime	DATETIME
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			--,@transinfoJson		NVARCHAR(MAX)	

	DECLARE @tempTrans TABLE (TransID BIGINT, statuswinlost TINYINT, winlost MONEY)

	DECLARE @transIDs AS TABLE (transid BIGINT)
	INSERT INTO @transIDs (transid)
	SELECT CAST(value AS BIGINT) transid
	FROM STRING_SPLIT(@transidlist, ',')

	INSERT INTO @tempTrans(TransID, statuswinlost, winlost)
	SELECT b.transid, statuswinlost, winlost
	FROM bettrans b WITH (NOLOCK)
		INNER JOIN @transIDs t ON b.TransId = t.transid

	UPDATE b
		SET @StatusId = CASE	
							WHEN b.statusID = 102 THEN 102
							WHEN t.statuswinlost = 6 THEN 103
							WHEN b.actual_stake < t.Winlost THEN 112
							WHEN b.actual_stake = t.Winlost THEN 111
							ELSE 113
						END
			,@IsUpdated = 1 --CASE WHEN b.statusID = 103 OR @StatusId = 103 THEN 1 ELSE 0 END
			,@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
								WHEN '0' THEN 1
								WHEN '1' THEN 0
								ELSE 1 END
			,@commLostRate = CASE b.comstatus
								WHEN '0' THEN 1
								WHEN '1' THEN 2
								ELSE 1 END
			,statusID = CASE WHEN @IsUpdated = 1 THEN @StatusId ELSE b.statusID END
			,winlost = CASE 
							WHEN @IsUpdated = 1 
								THEN CASE WHEN @StatusId = 103 THEN b.actual_stake ELSE t.Winlost END 
							ELSE b.winlost 
						END
			,awinlost = CASE
							WHEN @IsUpdated = 0 THEN b.awinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.apositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.apositiontaking
						END
			,mwinlost = CASE
							WHEN @IsUpdated = 0 THEN b.mwinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.mpositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.mpositiontaking
						END
			,swinlost = CASE
							WHEN @IsUpdated = 0 THEN b.swinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.spositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.spositiontaking
						END
			,playercomm = CASE
							WHEN @IsUpdated = 0 THEN b.playercomm
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.playerdiscount
							WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.playerdiscount
							ELSE @commLostRate * b.stake * b.playerdiscount
						END
			,comm = CASE
						WHEN @IsUpdated = 0 THEN b.comm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.discount * (1-apositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.discount * (1-apositiontaking)
						ELSE @commLostRate * b.stake * b.discount * (1-apositiontaking)
					END
			,acomm = CASE
						WHEN @IsUpdated = 0 THEN b.acomm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
						ELSE @commLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
					END
			,scomm = CASE
						WHEN @IsUpdated = 0 THEN b.scomm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
						ELSE @commLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
					END
			,status = CASE 
						WHEN @IsUpdated = 0 THEN b.status
						WHEN @StatusId = 103 THEN 'Refund'
						WHEN @StatusId = 112 THEN 'WON'
						WHEN @StatusId = 111 THEN 'DRAW'
						ELSE 'LOSE'
					END
			,statuswinlost = t.statuswinlost
			--,SettlementTime = CASE 
			--					WHEN @IsUpdated = 0 THEN b.SettlementTime
			--					ELSE CASE WHEN b.winlost <> t.Winlost OR b.statusID <> @StatusId THEN @settlementTime ELSE SettlementTime END
			--					END	
			--,FcUpdateTime = CASE WHEN @statusId = 103 AND b.statusID <> 103 THEN SYSDATETIME() ELSE FcUpdateTime END
	FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tempTrans t
			ON b.transid = t.TransId
END
GO
-----------STEP 2: UPDATE bettrans VIA SP EXCREP ------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Creator: Helen
	Date: 20230403
	DB: DBCTG/bodb02

	Revisions:
		- 20230403@Helen: Resettle ticket for parlay  [Redmine:#186125]

*/
CREATE TABLE #tmpParlayBalanceBefore (transid BIGINT PRIMARY KEY, custid INT, balance money)
CREATE TABLE #tmpParlayBalanceAfter (transid BIGINT PRIMARY KEY, custid INT, balance money)
CREATE TABLE #tmpParlayBalance (custid int, balance money)
DECLARE @tmpParlayDebitPending		TVP_BalanceList
		,@tmpParlayCreditPending	TVP_BalanceList

CREATE TABLE #Result (transid BIGINT PRIMARY KEY, id INT IDENTITY (1,1))
CREATE TABLE #Result_batch (transid BIGINT PRIMARY KEY)
CREATE TABLE #Result_balance_tmp (transid BIGINT PRIMARY KEY, id INT IDENTITY (1,1))

INSERT INTO #Result (transid)
SELECT DISTINCT TransId
FROM bettrans WITH (NOLOCK) 
WHERE transid IN (101059725780582401, 101059927644045333, 101060743687831573, 101061413706924088, 101060992791740456) 
	AND SiteDBGroupID = 0

---KEEP transid for balance processing
INSERT INTO #Result_balance_tmp (transid)
SELECT transid
FROM #Result

INSERT INTO #tmpParlayBalanceBefore (transid, custid, balance)
SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
FROM	dbo.bettrans b WITH(ROWLOCK)
WHERE	b.transid IN (SELECT transid FROM #Result_balance_tmp)

------ info for deployer
DECLARE @StartRow INT = 1
		, @StopRow INT 
		, @MaxRow INT = 1 -- Keep the total row of your data
		, @Threshold INT = 2000 -- the number of each batch
		, @transidlist VARCHAR(MAX)

DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(ID) FROM #Result)

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SET @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		DELETE R
		OUTPUT DELETED.transid
		INTO #Result_batch (transid)		
		FROM #Result R
		WHERE ID BETWEEN @StartRow AND @StopRow

		SET @transidlist =STUFF((SELECT ',' + CONVERT(VARCHAR(50),transid)
					  FROM #Result_batch
					  FOR XML PATH ('')),1,1,'')
		
		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		EXEC ExecRep_NAP_Admin_07 @transidlist = @transidlist
		
		IF @StopRow > @MaxRow 
			BREAK

		WAITFOR DELAY '00:00:00.050' --optional
		TRUNCATE TABLE #Result_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

END

---- CAPTURE value BALANCE after udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
INSERT INTO #tmpParlayBalanceAfter (transid, custid, balance)
SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
FROM	dbo.bettrans b WITH(ROWLOCK)
WHERE	b.transid IN (SELECT transid FROM #Result_balance_tmp) 

INSERT INTO #tmpParlayBalance (custid, balance)
SELECT b.custid, SUM(a.balance - b.balance)
FROM #tmpParlayBalanceBefore b
	INNER JOIN #tmpParlayBalanceAfter a ON b.transid = a.transid
GROUP BY b.custid

INSERT INTO @tmpParlayDebitPending (custID, balance)
SELECT t.custid, ABS(t.balance)
FROM (
	SELECT	custID, SUM(balance) AS balance
	FROM	#tmpParlayBalance
	GROUP BY custID
) t
WHERE t.balance < 0

IF @@ROWCOUNT <> 0
	EXEC dbo.Dot_BalancePendingDebitIns
		@BalancePending = @tmpParlayDebitPending
		,@Type			= 1 -- Sports

INSERT INTO @tmpParlayCreditPending (custID, balance)
SELECT t.custid, ABS(t.balance)
FROM (
	SELECT	custID, SUM(balance) AS balance
	FROM	#tmpParlayBalance
	GROUP BY custID
) t
WHERE t.balance > 0

IF @@ROWCOUNT <> 0
	EXEC dbo.Dot_BalancePendingCreditIns
		@BalancePending = @tmpParlayCreditPending
		,@Type			= 1 -- Sports


DROP TABLE #Result
DROP TABLE #Result_balance_tmp
DROP TABLE #Result_batch
DROP TABLE #tmpParlayBalance
DROP TABLE #tmpParlayBalanceAfter
DROP TABLE #tmpParlayBalanceBefore