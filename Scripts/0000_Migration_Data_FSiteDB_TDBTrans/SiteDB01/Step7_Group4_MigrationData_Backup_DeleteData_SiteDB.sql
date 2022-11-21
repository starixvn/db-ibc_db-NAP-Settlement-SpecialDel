/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB01tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#180033] 
								
*/

USE SiteDB01tmp
GO

------------------------------------------------
/*****************Copy Stucture of Tables************************/
-- 12 Tables
SELECT TOP 1 *
INTO BalCreditCasino_delete
FROM bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditOthers_delete
FROM bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditSports_delete
FROM bodb02.dbo.BalCreditSports bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditTransfer_delete
FROM bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitCasino_delete
FROM bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitOthers_delete
FROM bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitSports_delete 
FROM bodb02.dbo.BalDebitSports bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitTransfer_delete
FROM bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalNetPosition_delete
FROM bodb02.dbo.BalNetPosition bal WITH (NOLOCK)

SELECT TOP 1 *
INTO balanceTable_delete
FROM bodb02.dbo.balanceTable bal WITH (NOLOCK)

SELECT TOP 1 *
INTO balanceTable_tmp_delete
FROM bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalanceTable_tmp_cal_delete
FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)

----------------------------------------------------------
-- 9 Tables
SELECT TOP 1 *
INTO Bonus_sum_winloss_delete
FROM bodb02.dbo.Bonus_sum_winloss bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusAdjustmentTransfer_delete
FROM bodb02.dbo.BonusAdjustmentTransfer bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusTrans_delete
FROM bodb02.dbo.BonusTrans bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusWalletCredit_delete
FROM bodb02.dbo.BonusWalletCredit bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusWalletDebit_delete
FROM bodb02.dbo.BonusWalletDebit bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusWalletPending_delete
FROM bodb02.dbo.BonusWalletPending bon WITH (NOLOCK)

SELECT TOP 1 *
INTO CashOutSelling_delete
FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)

SELECT TOP 1 *
INTO CustLimitBet_LIC_delete
FROM bodb02.dbo.CustLimitBet_LIC clb WITH (NOLOCK)

SELECT TOP 1 * 
INTO CustLimitBetHistory_LIC_delete
FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (NOLOCK)

----------------------------------------------------------------
--16 Tables
SELECT TOP 1 * 
INTO BalancePendingCreditGame_delete
FROM bodb02.dbo.BalancePendingCreditGame bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalancePendingDebitGame_delete
FROM bodb02.dbo.BalancePendingDebitGame bd WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditCasinoPending_delete
FROM bodb02.dbo.BalCreditCasinoPending bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditOthersPending_delete
FROM bodb02.dbo.BalCreditOthersPending bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditSportsPending_delete
FROM bodb02.dbo.BalCreditSportsPending bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitCasinoPending_delete
FROM bodb02.dbo.BalDebitCasinoPending bd WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitOthersPending_delete
FROM bodb02.dbo.BalDebitOthersPending bd WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitSportsPending_delete
FROM bodb02.dbo.BalDebitSportsPending bd WITH (NOLOCK)

SELECT TOP 1 *
INTO Intg_GameRoundBetStake_delete
FROM bodb02.dbo.Intg_GameRoundBetStake igr WITH (NOLOCK)

SELECT TOP 1 *
INTO LastBetTime_delete
FROM bodb02.dbo.LastBetTime lb WITH (NOLOCK)

SELECT TOP 1 *
INTO LastBetTime_Agent_delete
FROM bodb02.dbo.LastBetTime_Agent lba WITH (NOLOCK)

SELECT TOP 1 *
INTO MarkedTransaction_delete
FROM bodb02.dbo.MarkedTransaction mt WITH (NOLOCK)

SELECT TOP 1 *
INTO NetPositionCalculationLog_delete
FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)

SELECT TOP 1 *
INTO NetPositionTrans_delete
FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)

SELECT TOP 1 *
INTO Task_Cust_CheckBalance_Exception_delete
FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)

SELECT TOP 1 *
INTO Task_Cust_BalanceProblem1_delete
FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)

/*****************Truncate Table************************/
--12 Tables
TRUNCATE TABLE BalCreditCasino_delete
TRUNCATE TABLE BalCreditOthers_delete
TRUNCATE TABLE BalCreditSports_delete
TRUNCATE TABLE BalCreditTransfer_delete
TRUNCATE TABLE BalDebitCasino_delete
TRUNCATE TABLE BalDebitOthers_delete
TRUNCATE TABLE BalDebitSports_delete
TRUNCATE TABLE BalDebitTransfer_delete
TRUNCATE TABLE BalNetPosition_delete
TRUNCATE TABLE balanceTable_delete
TRUNCATE TABLE balanceTable_tmp_delete
TRUNCATE TABLE BalanceTable_tmp_cal_delete
--9 Tables
TRUNCATE TABLE Bonus_sum_winloss_delete
TRUNCATE TABLE BonusAdjustmentTransfer_delete
TRUNCATE TABLE BonusTrans_delete
TRUNCATE TABLE BonusWalletCredit_delete
TRUNCATE TABLE BonusWalletDebit_delete
TRUNCATE TABLE BonusWalletPending_delete
TRUNCATE TABLE CashOutSelling_delete
TRUNCATE TABLE CustLimitBet_LIC_delete
TRUNCATE TABLE CustLimitBetHistory_LIC_delete
--16 Tables
TRUNCATE TABLE BalancePendingCreditGame_delete
TRUNCATE TABLE BalancePendingDebitGame_delete
TRUNCATE TABLE BalCreditCasinoPending_delete
TRUNCATE TABLE BalCreditOthersPending_delete
TRUNCATE TABLE BalCreditSportsPending_delete
TRUNCATE TABLE BalDebitCasinoPending_delete
TRUNCATE TABLE BalDebitOthersPending_delete
TRUNCATE TABLE BalDebitSportsPending_delete
TRUNCATE TABLE Intg_GameRoundBetStake_delete
TRUNCATE TABLE LastBetTime_delete
TRUNCATE TABLE LastBetTime_Agent_delete
TRUNCATE TABLE MarkedTransaction_delete
TRUNCATE TABLE NetPositionCalculationLog_delete
TRUNCATE TABLE NetPositionTrans_delete
TRUNCATE TABLE Task_Cust_CheckBalance_Exception_delete
TRUNCATE TABLE Task_Cust_BalanceProblem1_delete


/*******************BACKUP & DELETE Data**********************/
/*******************Bet Ticket tables**********************/
------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
		--, @batch INT = 2000

DECLARE @debug_message VARCHAR(500)

CREATE TABLE #TempBatch (rid INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT)

-- CashOutSelling
INSERT INTO #TempBatch (transid)
SELECT DISTINCT cosell.transid
FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = cosell.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	DELETE cosell
	OUTPUT	deleted.[TransID], deleted.[MatchID], deleted.[Bettype], deleted.[Custid], deleted.[CashOutStatus], deleted.[Winlost], deleted.[PriceInfo], deleted.[CheckTime], 
			deleted.[CreateDate], deleted.[ChangeDate], deleted.[IsTest], deleted.[VirtualRate], deleted.[CashOutExtraInfo]
	INTO [CashOutSelling_delete] ([TransID], [MatchID], [Bettype], [Custid], [CashOutStatus], [Winlost], [PriceInfo], [CheckTime], 
									[CreateDate], [ChangeDate], [IsTest], [VirtualRate], [CashOutExtraInfo])
	FROM bodb02.dbo.CashOutSelling cosell WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = cosell.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

-- CustLimitBetHistory_LIC
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT clbh.transid
FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = clbh.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	DELETE clbh
	OUTPUT	deleted.[Matchid], deleted.[CustID], deleted.[Transid], deleted.[TurnoverAdjust], deleted.[PayoutAdjust], deleted.[EventTypeID], deleted.[CreatedDate]
	INTO [CustLimitBetHistory_LIC_delete] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
	FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = clbh.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

/********************Tables Balance AND others with using custid to process batch by batch: 100 custid per batch *************************/
CREATE TABLE #TempBatch_custid (custid INT, rid INT IDENTITY(1,1) PRIMARY KEY)
INSERT INTO #TempBatch_custid (custid)
SELECT DISTINCT custid
FROM cust_migration tmp WITH (NOLOCK) 

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch_custid)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
WHILE (@MaxRow IS NOT NULL)
BEGIN
	DELETE bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalCreditCasino_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalCreditCasino bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	DELETE  bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalCreditOthers_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalCreditOthers bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalCreditSports_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalCreditSports bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalCreditTransfer_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalCreditTransfer bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalDebitCasino_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalDebitCasino bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalDebitOthers_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalDebitOthers bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalDebitSports_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalDebitSports bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bal
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO [BalDebitTransfer_delete] ([custid], [Balance])
	FROM bodb02.dbo.BalDebitTransfer bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bal
	OUTPUT deleted.[CustID], deleted.[MatchID], deleted.[Bettype], deleted.[Debit], deleted.[Credit], deleted.[CreatedDate], deleted.[ModifiedDate]
	INTO [BalNetPosition_delete] ([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
	FROM bodb02.dbo.BalNetPosition bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bal
	OUTPUT  deleted.[custid], deleted.[roleid], deleted.[amount], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm], deleted.[recommend], deleted.[mrecommend], 
			deleted.[srecommend], deleted.[currency], deleted.[UserName], deleted.[CurrencyName], deleted.[actualrate], deleted.[TicketCount], deleted.[balTicketCount]
	INTO [balanceTable_delete] (	[custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
									[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
	FROM bodb02.dbo.balanceTable bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bal
	OUTPUT  deleted.[winlostdate], deleted.[custid], deleted.[roleid], deleted.[amount], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm], deleted.[recommend], deleted.[mrecommend], 
			deleted.[srecommend], deleted.[currency], deleted.[UserName], deleted.[CurrencyName], deleted.[actualrate], deleted.[TicketCount], deleted.[balTicketCount]
	INTO [balanceTable_tmp_delete] (	[winlostdate], [custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
										[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
	FROM bodb02.dbo.balanceTable_tmp bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bal
	OUTPUT	deleted.[dow], deleted.[roleid], deleted.[custid], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], 
			deleted.[amt1], deleted.[tcnt1], deleted.[amt2], deleted.[tcnt2], deleted.[amt3], deleted.[tcnt3], deleted.[amt4], deleted.[tcnt4]
	INTO [BalanceTable_tmp_cal_delete] (	[dow], [roleid], [custid], [recommend], [mrecommend], [srecommend], 
											[amt1], [tcnt1], [amt2], [tcnt2], [amt3], [tcnt3], [amt4], [tcnt4])
	FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bal.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bon
	OUTPUT deleted.[CustId], deleted.[BonusId], deleted.[winlostdate], deleted.[Amount]
	INTO [Bonus_sum_winloss_delete] ([CustId], [BonusId], [winlostdate], [Amount])
	FROM bodb02.dbo.Bonus_sum_winloss bon WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bon.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bon
	OUTPUT deleted.[LogDate], deleted.[ExecDate], deleted.[CustID], deleted.[MatchID], deleted.[BonusID], deleted.[StatusID], deleted.[Amount], deleted.[isTransferred]
	INTO [BonusAdjustmentTransfer_delete] ([LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
	FROM bodb02.dbo.BonusAdjustmentTransfer bon WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bon.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bon
	OUTPUT  deleted.[CustID], deleted.[Recommend], deleted.[Mrecommend], deleted.[Srecommend], deleted.[Amount], deleted.[StatusId], deleted.[Creator], deleted.[CreatedDate], 
			deleted.[PaymentDate], deleted.[IsComplained]
	INTO [BonusTrans_delete] ([CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
								[PaymentDate], [IsComplained])
	FROM bodb02.dbo.BonusTrans bon WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bon.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bon
	OUTPUT  deleted.[CustID], deleted.[BonusID], deleted.[StatusID], deleted.[initBonus], deleted.[LockedAmt], deleted.[Amount]
	INTO [BonusWalletCredit_delete] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
	FROM bodb02.dbo.BonusWalletCredit bon WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bon.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bon
	OUTPUT  deleted.[CustID], deleted.[BonusID], deleted.[Amount]
	INTO [BonusWalletDebit_delete] ([CustID], [BonusID], [Amount])
	FROM bodb02.dbo.BonusWalletDebit bon WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bon.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE bon
	OUTPUT  deleted.[CustID], deleted.[BonusID], deleted.[Amount]
	INTO [BonusWalletPending_delete] ([CustID], [BonusID], [Amount])
	FROM bodb02.dbo.BonusWalletPending bon WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bon.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE clb
	OUTPUT	deleted.[Matchid], deleted.[CustID], deleted.[AccumTurnover], deleted.[AccumPayout], deleted.[EventTypeID], deleted.[LastQueueID], deleted.[ModifiedDate]
	INTO [CustLimitBet_LIC_delete] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
	FROM bodb02.dbo.CustLimitBet_LIC clb WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = clb.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

/*******************Other tables - TW list: process by batch by custid, batch 100 for sure **********************/
SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch_custid)
SET @Threshold = 100
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	DELETE  bc
	OUTPUT deleted.[custid], deleted.[winlostdate], deleted.[Balance], deleted.[bettype], deleted.[GameTypeID]
	INTO BalancePendingCreditGame_delete ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	FROM bodb02.dbo.BalancePendingCreditGame bc WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bc.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bd
	OUTPUT deleted.[custid], deleted.[winlostdate], deleted.[Balance], deleted.[bettype], deleted.[GameTypeID]
	INTO BalancePendingDebitGame_delete ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	FROM bodb02.dbo.BalancePendingDebitGame bd WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bd.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bc
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO BalCreditCasinoPending_delete ([custid], [Balance])
	FROM bodb02.dbo.BalCreditCasinoPending bc WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bc.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bc
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO BalCreditOthersPending_delete ([custid], [Balance])
	FROM bodb02.dbo.BalCreditOthersPending bc WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bc.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bc
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO BalCreditSportsPending_delete ([custid], [Balance])
	FROM bodb02.dbo.BalCreditSportsPending bc WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bc.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bd
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO BalDebitCasinoPending_delete ([custid], [Balance])
	FROM bodb02.dbo.BalDebitCasinoPending bd WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bd.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bd
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO BalDebitOthersPending_delete ([custid], [Balance])
	FROM bodb02.dbo.BalDebitOthersPending bd WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bd.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  bd
	OUTPUT deleted.[custid], deleted.[Balance]
	INTO BalDebitSportsPending_delete ([custid], [Balance])
	FROM bodb02.dbo.BalDebitSportsPending bd WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = bd.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  igr
	OUTPUT deleted.[VendorId], deleted.[BetId], deleted.[GameRound], deleted.[GameType], deleted.[BetChoice], deleted.[CustId], deleted.[Stake], deleted.[CreateDate]
	INTO Intg_GameRoundBetStake_delete ([VendorId], [BetId], [GameRound], [GameType], [BetChoice], [CustId], [Stake], [CreateDate])
	FROM bodb02.dbo.Intg_GameRoundBetStake igr WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = igr.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  lb
	OUTPUT deleted.[custid], deleted.[transdate]
	INTO LastBetTime_delete ([custid], [transdate])
	FROM bodb02.dbo.LastBetTime lb WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = lb.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  lba
	OUTPUT deleted.[CustID], deleted.[MatchID], deleted.[BetType], deleted.[CustomerClass], deleted.[Platform], deleted.[TransDate]
	INTO LastBetTime_Agent_delete ([CustID], [MatchID], [BetType], [CustomerClass], [Platform], [TransDate])
	FROM bodb02.dbo.LastBetTime_Agent lba WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = lba.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  npcl
	OUTPUT	deleted.[CustID], deleted.[MatchID], deleted.[Bettype], deleted.[AccumNPDebit], deleted.[AccumNPCredit], deleted.[NPAdjust], 
			deleted.[IsLatest], deleted.[CreatedDate], deleted.[ModifiedDate]
	INTO NetPositionCalculationLog_delete (	[CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], 
												[IsLatest], [CreatedDate], [ModifiedDate])
	FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = npcl.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  tce
	OUTPUT	deleted.[custid], deleted.[Remark]
	INTO Task_Cust_CheckBalance_Exception_delete ([custid], [Remark])
	FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = tce.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	DELETE  tcb
	OUTPUT deleted.[UserName], deleted.[custid], deleted.[DiffBalance], deleted.[LogDate], deleted.[IsFixed], deleted.[Remark]
	INTO Task_Cust_BalanceProblem1_delete ([UserName], [custid], [DiffBalance], [LogDate], [IsFixed], [Remark])
	FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (ROWLOCK)
		INNER JOIN #TempBatch_custid t ON t.custid = tcb.custid
	WHERE t.rid BETWEEN @StartRow AND @StopRow

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow
END

-------------------------------
TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT clbh.transid
FROM bodb02.dbo.MarkedTransaction clbh WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = clbh.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	DELETE  mt
	OUTPUT deleted.[TransId], deleted.[MatchId], deleted.[CustId], deleted.[bettype], deleted.[UserId], deleted.[CreatedDate], deleted.[MarkType]
	INTO MarkedTransaction_delete ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
	FROM bodb02.dbo.MarkedTransaction mt WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = mt.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

TRUNCATE TABLE #TempBatch
INSERT INTO #TempBatch (transid)
SELECT DISTINCT clbh.transid
FROM bodb02.dbo.NetPositionTrans clbh WITH (NOLOCK)
	INNER JOIN cust_migration tmp WITH (NOLOCK) ON tmp.custid = clbh.custid

SET @MaxRow = (SELECT MAX(rid) FROM #TempBatch)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	DELETE  npt
	OUTPUT	deleted.[TransID], deleted.[CustID], deleted.[MatchID], deleted.[Bettype], deleted.[Actual_stake], deleted.[Payout1], deleted.[Payoutx], deleted.[Payout2], deleted.[SyncStatus], 
			deleted.[isSettled], deleted.[CreatedDate], deleted.[ModifiedDate]
	INTO NetPositionTrans_delete ([TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], 
									[isSettled], [CreatedDate], [ModifiedDate])
	FROM bodb02.dbo.NetPositionTrans npt WITH (ROWLOCK)
		INNER JOIN #TempBatch t ON t.transid = npt.transid
	WHERE t.rid BETWEEN @StartRow AND @StopRow
	
	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

