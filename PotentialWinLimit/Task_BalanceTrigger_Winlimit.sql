/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  
ALTER PROCEDURE [dbo].[Task_BalanceTrigger_Winlimit] 
AS
/*
    Created: 20250513@Louisa
    DB: DBSIC/bodb02
   
   Revisions:
		- 20250513@Louisa: Alpha - Potential Winning Limit/Threshold [Redmine:226060]
	
	CustWinLimitBet_History.ActionType
	/*
	0: running ticket (insert ticket waiting or running)
	1: running to settle (won/lose/draw/refund)
	2: running/waiting to Reject
	3: running to VOID
	4: settle to running
	5: Result Amendment (settle to settle)
	6: Settle to VOID
	7: VOID to running
	8: VOID to Settle
	100: Reset
	*/

*/
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @maxValue BIGINT
			,@LastRow	BIGINT
			, @Batch	INT = 2000
			, @Error_MissingHistoryTransID VARCHAR(MAX) = ''
			, @Error_NegativeToWinList VARCHAR(MAX) = ''
			, @maxBatch BIGINT
			
	CREATE TABLE #winlimit_balancetrigger (rowID BIGINT, CustID INT, transid BIGINT,bef_statusid TINYINT, StatusId TINYINT , bef_winlost MONEY, winlost MONEY, adjToWin MONEY,adjWinLoss MONEY, Running_ToWin MONEY, isMissingHistory BIT
			, ActionType TINYINT, LatestResetDate datetime2, actionDate DATETIME, actual_stake MONEY
			, sporttype SMALLINT, bettype INT
			)
	
	SET @LastRow= (SELECT VValue FROM [bodb02].[dbo].SystemSettings WITH (NOLOCK) WHERE VName = 'CustWinLimitBet')
	SET @maxValue = (SELECT MAX(RowID) FROM [bodb02].[dbo].[BalanceTrigger] WITH(NOLOCK))
	WAITFOR DELAY '00:00:00.500'
	
	INSERT INTO #winlimit_balancetrigger (rowID, CustID, transid, bef_statusid, StatusId, bef_winlost, winlost, Running_ToWin
						, isMissingHistory, LatestResetDate, actionDate
						, adjToWin, adjWinLoss,ActionType,actual_stake
						, sporttype	, bettype
						)
	SELECT TOP(@Batch) rowID,custid, transid, bef_statusid, StatusId, bef_winlost, winlost, t1.running_ToWin
						, CASE WHEN t1.running_ToWin IS NULL THEN 1 ELSE 0 END AS isMissingHistory,  t2.LatestResetDate, b.ActionDate 
						-- capture adj ToWin/WinLoss for normal case from running to settle/void/reject
						, AdjToWin = CASE WHEN Running_ToWin IS NOT NULL AND StatusId > 1 AND b.bef_statusid IN (0,1) THEN -Running_ToWin ELSE NULL END
						, adjwinloss = CASE WHEN StatusId > 1 AND b.bef_statusid IN (0,1) THEN winlost - actual_stake ELSE NULL END
						, ActionType = CASE WHEN StatusId > 1 AND b.bef_statusid IN (0,1) 
												THEN CASE 
														WHEN statusid NOT IN (102, 101) THEN 1
														WHEN statusid = 101 THEN 2	
														WHEN statusid = 102 THEN 3	
													END	
											ELSE NULL
										END 
						, b.actual_stake
						, t1.Sporttype, t1.Bettype
	FROM [bodb02].[dbo].[BalanceTrigger] b WITH(NOLOCK)
		-- sportsbook only
		CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
					WHERE m.bettype = b.bettype 
						AND m.SportType < 99
						) AS bt
		OUTER APPLY (SELECT TOP 1 AdjToWin AS running_ToWin, Sporttype, bettype-- get ToWin of running and also check missing to insert history
					FROM CustWinLimitBet_History c WITH (NOLOCK) 
					WHERE c.CustID = b.CustID AND c.ActionType = 0 AND b.transid = c.Transid -- insert bet row
					) AS t1
		OUTER APPLY (SELECT MAX(c.RepUpdateTime) AS LatestResetDate
					FROM CustWinLimitBet_History c WITH (NOLOCK) 
					WHERE c.CustID = b.CustID AND c.ActionType = 100 -- latest reset
					) AS t2
	WHERE RowID <= @maxValue AND RowID > @LastRow AND b.bettype NOT IN (29,38) -- exclude parlay
		AND ((bef_statusid <> StatusId AND bef_statusid <> 1)	OR winlost <> bef_winlost)
		AND (bef_winlost IS NOT NULL AND bef_statusid IS NOT NULL) ---ignore action insert bet in balancetrigger
	ORDER BY RowID ASC
	
	IF @@ROWCOUNT < @Batch 
		SET @maxBatch = @maxValue
	ELSE 
		SET @maxBatch = (SELECT MAX(rowID) FROM #winlimit_balancetrigger)
	
	IF EXISTS (SELECT TOP (1) 1 FROM #winlimit_balancetrigger WHERE isMissingHistory = 1)
	BEGIN
		UPDATE t
			SET Running_ToWin = ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - t.actual_stake
				-- in case of missing history (actiontype =0) & placing bet after reset date, we will ignore to check reset condition (consider as it's normal case) to adjust towin/winlost to adapt case 1.2 & 3.2
				,LatestResetDate = CASE WHEN b.transdate >= t.LatestResetDate THEN NULL ELSE t.LatestResetDate END
		FROM #winlimit_balancetrigger t
			INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = t.transid
		WHERE isMissingHistory = 1
		-- insert into table CustWinLimitBet_Errors

		SELECT @Error_MissingHistoryTransID = STRING_AGG(CONVERT(VARCHAR(MAX),transId), ',') 
		FROM(
			SELECT DISTINCT transId
			FROM #winlimit_balancetrigger 
			WHERE isMissingHistory = 1
		) AS tmp

		INSERT INTO dbo.CustWinLimitBet_Errors (ErrName,ExtraInfo,CreatedDate )
		SELECT 'Missing History by transid list', @Error_MissingHistoryTransID, GETDATE()

	END
	
	--CASE 1: To running: UNDO, RECOVER
	-- complex case 1.1 (place bet before reset): running (placebet) --> settle --> reset --> running:no adjust winloss --> settle --> running: adjust winloss
	-- complex case 1.2 (place bet after reset): reset --> running (placebet) --> settle --> running: adjust winloss
	IF EXISTS (SELECT TOP (1) 1 FROM #winlimit_balancetrigger WHERE StatusId = 0)
	BEGIN
		UPDATE b
			SET AdjToWin = b.Running_ToWin
			, adjwinloss = CASE WHEN actionDate >= LatestResetDate AND t.IsAdjustWinLoss IS NULL THEN 0 ELSE -(bef_winlost - actual_stake) END
			, ActionType = CASE WHEN bef_statusid = 102 THEN 7 ELSE 4 END -- 4: settle to running, 7: VOID to running
		FROM #winlimit_balancetrigger b
			-- CHECK exist running between reset action and current settle status
			OUTER APPLY (SELECT TOP 1 1 AS IsAdjustWinLoss 
						FROM CustWinLimitBet_History c WITH (NOLOCK) 
						WHERE c.CustID = b.CustID AND c.ActionType IN (4,7,0) AND b.transid = c.Transid
							 AND c.RepUpdateTime BETWEEN b.LatestResetDate and b.actionDate
							 ) AS t
		WHERE b.StatusId = 0
	END
	--CASE 2: RUNNING TO SETTLE/VOID/REJECT: Already processed when insert data into #winlimit_balancetrigger BUT missing history case related to adjToWin
	IF EXISTS (SELECT TOP (1) 1 FROM #winlimit_balancetrigger WHERE StatusId > 1 AND bef_statusid IN (0,1) AND isMissingHistory = 1)
	BEGIN
		UPDATE b
			SET AdjToWin = -b.Running_ToWin
		FROM #winlimit_balancetrigger b
		WHERE b.StatusId > 1 AND b.bef_statusid IN (0,1) AND isMissingHistory = 1  
	END
	--CASE 3: settle/void to settle/void
	-- complex case 3.1: running (placebet) --> settle --> reset --> resettle:no adjust winloss/towin --> running --> settle --> settle: adjust winloss
	-- complex case 3.2: reset - running (placebet) --> settle --> resettle: adjust winloss/towin --> running --> settle --> settle: adjust winloss
	-- complex case 3.3: running (placebet) --->reset --> settle --> resettle: adjust winloss
	IF EXISTS (SELECT TOP (1) 1 FROM #winlimit_balancetrigger WHERE StatusId > 1 AND bef_statusid > 1)
	BEGIN
		UPDATE b
			SET AdjToWin = 0
			, adjwinloss = CASE WHEN LatestResetDate IS NULL OR t1.IsAdjustWinLoss = 1 OR t2.IsAdjustWinLoss = 1 THEN winlost - bef_winlost ELSE 0 END
			, ActionType = CASE WHEN StatusId = 102 THEN 6 -- Settle to VOID
								WHEN bef_StatusId = 102 THEN 8
								ELSE 5 -- 5: Result Amendment (settle to settle)
							END 
		FROM #winlimit_balancetrigger b
			-- CHECK exist running before reset action and after reset action
			OUTER APPLY (SELECT TOP (1) 1 AS IsAdjustWinLoss
						FROM CustWinLimitBet_History c WITH (NOLOCK) 
						WHERE c.CustID = b.CustID AND b.transid = c.Transid  AND b.actionDate > b.LatestResetDate AND c.ActionType IN (4,7,0)
							 AND c.RepUpdateTime > b.LatestResetDate
						ORDER BY c.RepUpdateTime ASC
							 ) AS t1
			OUTER APPLY (SELECT TOP (1) CASE WHEN c.ActionType IN (4,7,0) THEN 1 ELSE 0 END AS IsAdjustWinLoss 
						FROM CustWinLimitBet_History c WITH (NOLOCK) 
						WHERE c.CustID = b.CustID AND b.transid = c.Transid  AND b.actionDate > b.LatestResetDate  
							 AND c.RepUpdateTime < b.LatestResetDate
						ORDER BY c.RepUpdateTime DESC
							 ) AS t2
		WHERE b.StatusId > 1 AND b.bef_statusid > 1 
	END
	
	UPDATE c
		SET AccumToWin =  CASE WHEN AccumToWin + t.adjToWin_total < 0 THEN 0 ELSE AccumToWin + t.adjToWin_total END
			,AccumWinLoss = AccumWinLoss + t.adjWinLoss_total
			, @Error_NegativeToWinList = @Error_NegativeToWinList + CASE WHEN AccumToWin + t.adjToWin_total < 0 THEN ',' + CONVERT(VARCHAR(20), c.custid) ELSE '' END
			, RepUpdateTime = [dbo].[f_GetDateTime2]()
	FROM CustWinLimitBet C WITH (ROWLOCK, UPDLOCK)
		CROSS APPLY (SELECT SUM (b.adjToWin) AS adjToWin_total, SUM(b.adjWinLoss) AS adjWinLoss_total
					FROM #winlimit_balancetrigger b
					WHERE b.CustID = c.CustID
					GROUP BY b.CustID
					) AS t
	UPDATE s
		SET VValue = @maxBatch
	FROM SystemSettings s WITH (ROWLOCK,UPDLOCK)
	WHERE VName = 'CustWinLimitBet'

	INSERT INTO CustWinLimitBet_History ([CustID], [Sporttype], [Bettype], [Transid], [AdjToWin], [AdjWinLoss], [ActionType], [RepUpdateTime]) 
	SELECT [CustID], sporttype, bettype, [Transid], [AdjToWin], [AdjWinLoss], [ActionType],[dbo].[f_GetDateTime2]()
	FROM #winlimit_balancetrigger
	ORDER BY rowID ASC

	SET @Error_NegativeToWinList =  STUFF (@Error_NegativeToWinList,1,1,'')

	IF ISNULL(@Error_NegativeToWinList,'') <> ''
	BEGIN
		INSERT INTO dbo.CustWinLimitBet_Errors (ErrName,ExtraInfo,CreatedDate )
		SELECT 'Negative ToWin by custid list', @Error_NegativeToWinList, GETDATE()
	END

	DROP TABLE #winlimit_balancetrigger

END
