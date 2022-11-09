/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 Bonus_sum_winloss,BonusAdjustmentTransfer,BonusTrans,BonusWalletCredit,BonusWalletDebit,BonusWalletPending,
							 BalancePendingCreditGame,BalancePendingDebitGame,BalCreditCasinoPending,BalCreditOthersPending,
							 BalCreditSportsPending,BalDebitCasinoPending,BalDebitOthersPending,BalDebitSportsPending,MarkedTransaction,NetPositionCalculationLog,
							 NetPositionTrans,Task_Cust_CheckBalance_Exception,Task_Cust_BalanceProblem1
*/

USE bodb02
GO
------------------------------------------------
--Bonus_sum_winloss
SELECT *
INTO #Bonus_sum_winloss_tmp
FROM DBSIG01.SiteDB01tmp.dbo.Bonus_sum_winloss_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #Bonus_sum_winloss_tmp_update
FROM #Bonus_sum_winloss_tmp tmp
	INNER JOIN [dbo].[Bonus_sum_winloss] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 

SELECT tmp.*
INTO #Bonus_sum_winloss_tmp_insert
FROM #Bonus_sum_winloss_tmp tmp
	LEFT JOIN [dbo].[Bonus_sum_winloss] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 
WHERE main.CustId IS NULL AND main.BonusId IS NULL 

UPDATE main
SET [Amount]=tmp.[Amount], [winlostdate] = tmp.[winlostdate]
FROM [dbo].[Bonus_sum_winloss] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #Bonus_sum_winloss_tmp_update tmp ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 

INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
SELECT tmp.[CustId], tmp.[BonusId], tmp.[winlostdate], tmp.[Amount]
FROM #Bonus_sum_winloss_tmp_insert tmp 

--DROP TABLE #Bonus_sum_winloss_tmp
--DROP TABLE #Bonus_sum_winloss_tmp_update
--DROP TABLE #Bonus_sum_winloss_tmp_insert

------------------------------------------------
--BonusAdjustmentTransfer
SELECT *
INTO #BonusAdjustmentTransfer_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BonusAdjustmentTransfer_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BonusAdjustmentTransfer_tmp_update
FROM #BonusAdjustmentTransfer_tmp tmp
	INNER JOIN [dbo].[BonusAdjustmentTransfer] main WITH (NOLOCK) ON main.CustID = tmp.CustID

SELECT tmp.*
INTO #BonusAdjustmentTransfer_tmp_insert
FROM #BonusAdjustmentTransfer_tmp tmp
	LEFT JOIN [dbo].[BonusAdjustmentTransfer] main WITH (NOLOCK) ON main.CustID = tmp.CustID
WHERE main.CustID IS NULL

UPDATE main
SET [LogDate]=tmp.[LogDate],[ExecDate]=tmp.[ExecDate],[MatchID]=tmp.[MatchID],
	[BonusID]=tmp.[BonusID],[StatusID]=tmp.[StatusID],[Amount]=tmp.[Amount],[isTransferred]=tmp.[isTransferred]
FROM [dbo].[BonusAdjustmentTransfer] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #BonusAdjustmentTransfer_tmp_update tmp ON main.CustID = tmp.CustID

INSERT INTO [dbo].[BonusAdjustmentTransfer] ([LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
SELECT tmp.[LogDate], tmp.[ExecDate], tmp.[CustID], tmp.[MatchID], tmp.[BonusID], tmp.[StatusID], tmp.[Amount], tmp.[isTransferred]
FROM #BonusAdjustmentTransfer_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BonusAdjustmentTransfer_tmp
--DROP TABLE #BonusAdjustmentTransfer_tmp_update
--DROP TABLE #BonusAdjustmentTransfer_tmp_insert

------------------------------------------------
--BonusTrans
SELECT *
INTO #BonusTrans_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BonusTrans_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BonusTrans_tmp_update
FROM #BonusTrans_tmp tmp
	INNER JOIN [dbo].[BonusTrans] main WITH (NOLOCK) ON main.CustID = tmp.CustID

SELECT tmp.*
INTO #BonusTrans_tmp_insert
FROM #BonusTrans_tmp tmp
	LEFT JOIN [dbo].[BonusTrans] main WITH (NOLOCK) ON main.CustID = tmp.CustID
WHERE main.CustID IS NULL

UPDATE main
SET [Recommend]=tmp.[Recommend],[Mrecommend]=tmp.[Mrecommend],[Srecommend]=tmp.[Srecommend],[Amount]=tmp.[Amount],
	[StatusId]=tmp.[StatusId],[Creator]=tmp.[Creator],[CreatedDate]=tmp.[CreatedDate],[PaymentDate]=tmp.[PaymentDate],[IsComplained]=tmp.[IsComplained]
FROM [dbo].[BonusTrans] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #BonusTrans_tmp_update tmp ON main.CustID = tmp.CustID

INSERT INTO [dbo].[BonusTrans] ([CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], [PaymentDate], [IsComplained])
SELECT tmp.[CustID], tmp.[Recommend], tmp.[Mrecommend], tmp.[Srecommend], tmp.[Amount], tmp.[StatusId], tmp.[Creator], tmp.[CreatedDate], tmp.[PaymentDate], tmp.[IsComplained]
FROM #BonusTrans_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BonusTrans_tmp
--DROP TABLE #BonusTrans_tmp_update
--DROP TABLE #BonusTrans_tmp_insert

------------------------------------------------
--BonusWalletCredit
SELECT *
INTO #BonusWalletCredit_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BonusWalletCredit_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BonusWalletCredit_tmp_update
FROM #BonusWalletCredit_tmp tmp
	INNER JOIN [dbo].[BonusWalletCredit] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 

SELECT tmp.*
INTO #BonusWalletCredit_tmp_insert
FROM #BonusWalletCredit_tmp tmp
	LEFT JOIN [dbo].[BonusWalletCredit] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 
WHERE main.CustId IS NULL AND main.BonusId IS NULL 

UPDATE main
SET [initBonus]=tmp.[initBonus],[LockedAmt]=tmp.[LockedAmt],[Amount]=tmp.[Amount],[StatusID] = tmp.[StatusID]
FROM [dbo].[BonusWalletCredit] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #BonusWalletCredit_tmp_update tmp ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 

INSERT INTO [dbo].[BonusWalletCredit] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
SELECT tmp.[CustID], tmp.[BonusID], tmp.[StatusID], tmp.[initBonus], tmp.[LockedAmt], tmp.[Amount]
FROM #BonusWalletCredit_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BonusWalletCredit_tmp
--DROP TABLE #BonusWalletCredit_tmp_update
--DROP TABLE #BonusWalletCredit_tmp_insert

------------------------------------------------
--BonusWalletDebit
SELECT *
INTO #BonusWalletDebit_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BonusWalletDebit_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BonusWalletDebit_tmp_update
FROM #BonusWalletDebit_tmp tmp
	INNER JOIN [dbo].[BonusWalletDebit] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 

SELECT tmp.*
INTO #BonusWalletDebit_tmp_insert
FROM #BonusWalletDebit_tmp tmp
	LEFT JOIN [dbo].[BonusWalletDebit] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 
WHERE main.CustId IS NULL AND main.BonusId IS NULL 

UPDATE main
SET [Amount]=tmp.[Amount]
FROM [dbo].[BonusWalletDebit] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #BonusWalletDebit_tmp_update tmp ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId 

INSERT INTO [dbo].[BonusWalletDebit] ([CustID], [BonusID], [Amount])
SELECT tmp.[CustID], tmp.[BonusID], tmp.[Amount]
FROM #BonusWalletDebit_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BonusWalletDebit_tmp
--DROP TABLE #BonusWalletDebit_tmp_update
--DROP TABLE #BonusWalletDebit_tmp_insert

------------------------------------------------
--BonusWalletPending
SELECT *
INTO #BonusWalletPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BonusWalletPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BonusWalletPending_tmp_insert
FROM #BonusWalletPending_tmp tmp
	LEFT JOIN [dbo].[BonusWalletPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL

INSERT INTO [dbo].[BonusWalletPending] ([CustID], [BonusID], [Amount])
SELECT tmp.[CustID], tmp.[BonusID], tmp.[Amount]
FROM #BonusWalletPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BonusWalletPending_tmp
--DROP TABLE #BonusWalletPending_tmp_insert

------------------------------------------------
--BalancePendingCreditGame
SELECT *
INTO #BalancePendingCreditGame_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalancePendingCreditGame_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalancePendingCreditGame_tmp_insert
FROM #BalancePendingCreditGame_tmp tmp
	LEFT JOIN [dbo].[BalancePendingCreditGame] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL

INSERT INTO [dbo].[BalancePendingCreditGame] ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
SELECT tmp.[custid],tmp.[winlostdate],tmp.[Balance],tmp.[bettype],tmp.[GameTypeID]
FROM #BalancePendingCreditGame_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalancePendingCreditGame_tmp
--DROP TABLE #BalancePendingCreditGame_tmp_insert

------------------------------------------------
--BalancePendingDebitGame
SELECT *
INTO #BalancePendingDebitGame_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalancePendingDebitGame_Copy bon WITH (NOLOCK) 

SELECT tmp.*
INTO #BalancePendingDebitGame_tmp_insert
FROM #BalancePendingDebitGame_tmp tmp
	LEFT JOIN [dbo].[BalancePendingDebitGame] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalancePendingDebitGame] ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
SELECT tmp.[custid],tmp.[winlostdate],tmp.[Balance],tmp.[bettype],tmp.[GameTypeID]
FROM #BalancePendingDebitGame_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalancePendingDebitGame_tmp
--DROP TABLE #BalancePendingDebitGame_tmp_update
--DROP TABLE #BalancePendingDebitGame_tmp_insert

------------------------------------------------
--BalCreditCasinoPending
SELECT *
INTO #BalCreditCasinoPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditCasinoPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalCreditCasinoPending_tmp_insert
FROM #BalCreditCasinoPending_tmp tmp
	LEFT JOIN [dbo].[BalCreditCasinoPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalCreditCasinoPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM #BalCreditCasinoPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalCreditCasinoPending_tmp
--DROP TABLE #BalCreditCasinoPending_tmp_update
--DROP TABLE #BalCreditCasinoPending_tmp_insert

------------------------------------------------
--BalCreditOthersPending
SELECT *
INTO #BalCreditOthersPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditOthersPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalCreditOthersPending_tmp_insert
FROM #BalCreditOthersPending_tmp tmp
	LEFT JOIN [dbo].[BalCreditOthersPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalCreditOthersPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM #BalCreditOthersPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalCreditOthersPending_tmp
--DROP TABLE #BalCreditOthersPending_tmp_update
--DROP TABLE #BalCreditOthersPending_tmp_insert

------------------------------------------------
--BalCreditSportsPending
SELECT *
INTO #BalCreditSportsPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditSportsPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalCreditSportsPending_tmp_insert
FROM #BalCreditSportsPending_tmp tmp
	LEFT JOIN [dbo].[BalCreditSportsPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalCreditSportsPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM #BalCreditSportsPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalCreditSportsPending_tmp
--DROP TABLE #BalCreditSportsPending_tmp_insert

------------------------------------------------
--BalDebitCasinoPending
SELECT *
INTO #BalDebitCasinoPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitCasinoPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalDebitCasinoPending_tmp_insert
FROM #BalDebitCasinoPending_tmp tmp
	LEFT JOIN [dbo].[BalDebitCasinoPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalDebitCasinoPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM #BalDebitCasinoPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalDebitCasinoPending_tmp
--DROP TABLE #BalDebitCasinoPending_tmp_insert

------------------------------------------------
--BalDebitOthersPending
SELECT *
INTO #BalDebitOthersPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitOthersPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalDebitOthersPending_tmp_insert
FROM #BalDebitOthersPending_tmp tmp
	LEFT JOIN [dbo].[BalDebitOthersPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalDebitOthersPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM #BalDebitOthersPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalDebitOthersPending_tmp
--DROP TABLE #BalDebitOthersPending_tmp_insert

------------------------------------------------
--BalDebitSportsPending
SELECT *
INTO #BalDebitSportsPending_tmp
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitSportsPending_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #BalDebitSportsPending_tmp_insert
FROM #BalDebitSportsPending_tmp tmp
	LEFT JOIN [dbo].[BalDebitSportsPending] main WITH (NOLOCK) ON main.CustID = tmp.CustID 
WHERE main.CustID IS NULL 

INSERT INTO [dbo].[BalDebitSportsPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM #BalDebitSportsPending_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #BalDebitSportsPending_tmp
--DROP TABLE #BalDebitSportsPending_tmp_insert
------------------------------------------------
--MarkedTransaction

CREATE TABLE #MarkedTransaction_tmp(
	[TransId] [bigint] NOT NULL,
	[MatchId] [int] NOT NULL,
	[CustId] [int] NOT NULL,
	[bettype] [smallint] NOT NULL,
	[UserId] [int] NOT NULL,
	[CreatedDate] [datetime] NULL,
	[MarkType] [tinyint] NULL,
	rid INT IDENTITY (1,1) PRIMARY KEY
)

INSERT INTO #MarkedTransaction_tmp ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
SELECT bon.[TransId], bon.[MatchId], bon.[CustId], bon.[bettype], bon.[UserId], bon.[CreatedDate], bon.[MarkType]
FROM DBSIG01.SiteDB01tmp.dbo.MarkedTransaction_Copy bon WITH (NOLOCK)

-- START to insert ONLY
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
SET @MaxRow = (SELECT MAX(rid) FROM #MarkedTransaction_tmp)
SET @Threshold = 2000
IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	INSERT INTO [dbo].[MarkedTransaction] ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
	SELECT tmp.[TransId], tmp.[MatchId], tmp.[CustId], tmp.[bettype], tmp.[UserId], tmp.[CreatedDate], tmp.[MarkType]
	FROM #MarkedTransaction_tmp tmp WITH (NOLOCK)
	WHERE tmp.rid BETWEEN @StartRow AND @StopRow 

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.010' --optional
	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
		SET @StopRow = @MaxRow

END

--DROP TABLE #MarkedTransaction_tmp

------------------------------------------------
--NetPositionCalculationLog
SELECT *
INTO #NetPositionCalculationLog_tmp
FROM DBSIG01.SiteDB01tmp.dbo.NetPositionCalculationLog_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #NetPositionCalculationLog_tmp_update
FROM #NetPositionCalculationLog_tmp tmp
	INNER JOIN [dbo].[NetPositionCalculationLog] main WITH (NOLOCK) ON main.NPCalculationLogID = tmp.NPCalculationLogID

SELECT tmp.*
INTO #NetPositionCalculationLog_tmp_insert
FROM #NetPositionCalculationLog_tmp tmp
	LEFT JOIN [dbo].[NetPositionCalculationLog] main WITH (NOLOCK) ON main.NPCalculationLogID = tmp.NPCalculationLogID
WHERE main.NPCalculationLogID IS NULL

UPDATE main
SET [CustID]=tmp.[CustID],[MatchID]=tmp.[MatchID],[Bettype]=tmp.[Bettype],[AccumNPDebit]=tmp.[AccumNPDebit],[AccumNPCredit]=tmp.[AccumNPCredit],[NPAdjust]=tmp.[NPAdjust],[IsLatest]=tmp.[IsLatest],[CreatedDate]=tmp.[CreatedDate],[ModifiedDate]=tmp.[ModifiedDate]
FROM [dbo].[NetPositionCalculationLog] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #NetPositionCalculationLog_tmp_update tmp ON main.NPCalculationLogID = tmp.NPCalculationLogID

INSERT INTO [dbo].[NetPositionCalculationLog] ([CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], [IsLatest], [CreatedDate], [ModifiedDate])
SELECT tmp.[CustID], tmp.[MatchID], tmp.[Bettype], tmp.[AccumNPDebit], tmp.[AccumNPCredit], tmp.[NPAdjust], tmp.[IsLatest], tmp.[CreatedDate], tmp.[ModifiedDate]
FROM #NetPositionCalculationLog_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #NetPositionCalculationLog_tmp
--DROP TABLE #NetPositionCalculationLog_tmp_update
--DROP TABLE #NetPositionCalculationLog_tmp_insert
------------------------------------------------
--NetPositionTrans
SELECT *
INTO #NetPositionTrans_tmp
FROM DBSIG01.SiteDB01tmp.dbo.NetPositionTrans_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #NetPositionTrans_tmp_update
FROM #NetPositionTrans_tmp tmp
	INNER JOIN [dbo].[NetPositionTrans] main WITH (NOLOCK) ON main.TransID = tmp.TransID

SELECT tmp.*
INTO #NetPositionTrans_tmp_insert
FROM #NetPositionTrans_tmp tmp
	LEFT JOIN [dbo].[NetPositionTrans] main WITH (NOLOCK) ON main.TransID = tmp.TransID
WHERE main.TransID IS NULL

UPDATE main
SET [CustID]=tmp.[CustID],[MatchID]=tmp.[MatchID],[Bettype]=tmp.[Bettype],[Actual_stake]=tmp.[Actual_stake],[Payout1]=tmp.[Payout1],[Payoutx]=tmp.[Payoutx],[Payout2]=tmp.[Payout2],[SyncStatus]=tmp.[SyncStatus],[isSettled]=tmp.[isSettled],[CreatedDate]=tmp.[CreatedDate],[ModifiedDate]=tmp.[ModifiedDate]
FROM [dbo].[NetPositionTrans] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #NetPositionTrans_tmp_update tmp ON main.TransID = tmp.TransID

INSERT INTO [dbo].[NetPositionTrans] ([TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], [isSettled], [CreatedDate], [ModifiedDate])
SELECT tmp.[TransID], tmp.[CustID], tmp.[MatchID], tmp.[Bettype], tmp.[Actual_stake], tmp.[Payout1], tmp.[Payoutx], tmp.[Payout2], tmp.[SyncStatus], tmp.[isSettled], tmp.[CreatedDate], tmp.[ModifiedDate]
FROM #NetPositionTrans_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #NetPositionTrans_tmp
--DROP TABLE #NetPositionTrans_tmp_update
--DROP TABLE #NetPositionTrans_tmp_insert
------------------------------------------------
--Task_Cust_CheckBalance_Exception
SELECT *
INTO #Task_Cust_CheckBalance_Exception_tmp
FROM DBSIG01.SiteDB01tmp.dbo.Task_Cust_CheckBalance_Exception_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #Task_Cust_CheckBalance_Exception_tmp_update
FROM #Task_Cust_CheckBalance_Exception_tmp tmp
	INNER JOIN [dbo].[Task_Cust_CheckBalance_Exception] main WITH (NOLOCK) ON main.CustID = tmp.CustID

SELECT tmp.*
INTO #Task_Cust_CheckBalance_Exception_tmp_insert
FROM #Task_Cust_CheckBalance_Exception_tmp tmp
	LEFT JOIN [dbo].[Task_Cust_CheckBalance_Exception] main WITH (NOLOCK) ON main.CustID = tmp.CustID
WHERE main.CustID IS NULL

UPDATE main
SET [custid] = tmp.[custid], [Remark] = tmp.[Remark]
FROM [dbo].[Task_Cust_CheckBalance_Exception] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #Task_Cust_CheckBalance_Exception_tmp_update tmp ON main.CustID = tmp.CustID

INSERT INTO [dbo].[Task_Cust_CheckBalance_Exception] ([custid], [Remark])
SELECT tmp.[custid], tmp.[Remark]
FROM #Task_Cust_CheckBalance_Exception_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #Task_Cust_CheckBalance_Exception_tmp
--DROP TABLE #Task_Cust_CheckBalance_Exception_tmp_update
--DROP TABLE #Task_Cust_CheckBalance_Exception_tmp_insert

------------------------------------------------
--Task_Cust_BalanceProblem1
SELECT *
INTO #Task_Cust_BalanceProblem1_tmp
FROM DBSIG01.SiteDB01tmp.dbo.Task_Cust_BalanceProblem1_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #Task_Cust_BalanceProblem1_tmp_update
FROM #Task_Cust_BalanceProblem1_tmp tmp
	INNER JOIN [dbo].[Task_Cust_BalanceProblem1] main WITH (NOLOCK) ON main.CustID = tmp.CustID

SELECT tmp.*
INTO #Task_Cust_BalanceProblem1_tmp_insert
FROM #Task_Cust_BalanceProblem1_tmp tmp
	LEFT JOIN [dbo].[Task_Cust_BalanceProblem1] main WITH (NOLOCK) ON main.CustID = tmp.CustID
WHERE main.CustID IS NULL

UPDATE main
SET [UserName]=tmp.[UserName],[DiffBalance]=tmp.[DiffBalance],[LogDate]=tmp.[LogDate],[IsFixed]=tmp.[IsFixed],[Remark]=tmp.[Remark]
FROM [dbo].[Task_Cust_BalanceProblem1] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #Task_Cust_BalanceProblem1_tmp_update tmp ON main.CustID = tmp.CustID

INSERT INTO [dbo].[Task_Cust_BalanceProblem1] ([UserName], [custid], [DiffBalance], [LogDate], [IsFixed], [Remark])
SELECT tmp.[UserName], tmp.[custid], tmp.[DiffBalance], tmp.[LogDate], tmp.[IsFixed], tmp.[Remark]
FROM #Task_Cust_BalanceProblem1_tmp_insert tmp WITH (NOLOCK)

--DROP TABLE #Task_Cust_BalanceProblem1_tmp
--DROP TABLE #Task_Cust_BalanceProblem1_tmp_update
--DROP TABLE #Task_Cust_BalanceProblem1_tmp_insert