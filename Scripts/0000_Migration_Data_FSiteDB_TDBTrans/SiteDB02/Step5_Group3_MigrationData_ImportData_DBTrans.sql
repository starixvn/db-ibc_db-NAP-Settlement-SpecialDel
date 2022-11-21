/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 Bonus_sum_winloss,BonusWalletCredit,BonusWalletDebit,BonusWalletPending,
							 BalancePendingCreditGame,BalancePendingDebitGame,BalCreditCasinoPending,BalCreditOthersPending,
							 BalCreditSportsPending,BalDebitCasinoPending,BalDebitOthersPending,BalDebitSportsPending,NetPositionCalculationLog,
							 NetPositionTrans,Task_Cust_CheckBalance_Exception,Task_Cust_BalanceProblem1
*/

USE bodb02
GO
------------------------------------------------
--Bonus_sum_winloss
SELECT *
INTO #Bonus_sum_winloss_tmp
FROM DBSIG02.SiteDB02tmp.dbo.Bonus_sum_winloss_Copy bon WITH (NOLOCK)

SELECT tmp.*
INTO #Bonus_sum_winloss_tmp_update
FROM #Bonus_sum_winloss_tmp tmp
	INNER JOIN [dbo].[Bonus_sum_winloss] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId AND main.winlostdate = tmp.winlostdate

SELECT tmp.*
INTO #Bonus_sum_winloss_tmp_insert
FROM #Bonus_sum_winloss_tmp tmp
	LEFT JOIN [dbo].[Bonus_sum_winloss] main WITH (NOLOCK) ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId AND main.winlostdate = tmp.winlostdate
WHERE main.CustId IS NULL --AND main.BonusId IS NULL 

UPDATE main
SET [Amount]=tmp.[Amount], [winlostdate] = tmp.[winlostdate]
FROM [dbo].[Bonus_sum_winloss] main WITH (UPDLOCK,ROWLOCK)
	INNER JOIN #Bonus_sum_winloss_tmp_update tmp ON main.CustId = tmp.CustId AND main.BonusId = tmp.BonusId AND main.winlostdate = tmp.winlostdate

INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
SELECT tmp.[CustId], tmp.[BonusId], tmp.[winlostdate], tmp.[Amount]
FROM #Bonus_sum_winloss_tmp_insert tmp 

--DROP TABLE #Bonus_sum_winloss_tmp
--DROP TABLE #Bonus_sum_winloss_tmp_update
--DROP TABLE #Bonus_sum_winloss_tmp_insert

------------------------------------------------
--BonusWalletCredit
SELECT *
INTO #BonusWalletCredit_tmp
FROM DBSIG02.SiteDB02tmp.dbo.BonusWalletCredit_Copy bon WITH (NOLOCK)

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
FROM #BonusWalletCredit_tmp_insert tmp

--DROP TABLE #BonusWalletCredit_tmp
--DROP TABLE #BonusWalletCredit_tmp_update
--DROP TABLE #BonusWalletCredit_tmp_insert

------------------------------------------------
--BonusWalletDebit
SELECT *
INTO #BonusWalletDebit_tmp
FROM DBSIG02.SiteDB02tmp.dbo.BonusWalletDebit_Copy bon WITH (NOLOCK)

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
FROM #BonusWalletDebit_tmp_insert tmp

--DROP TABLE #BonusWalletDebit_tmp
--DROP TABLE #BonusWalletDebit_tmp_update
--DROP TABLE #BonusWalletDebit_tmp_insert

------------------------------------------------
--BonusWalletPending

INSERT INTO [dbo].[BonusWalletPending] ([CustID], [BonusID], [Amount])
SELECT tmp.[CustID], tmp.[BonusID], tmp.[Amount]
FROM DBSIG02.SiteDB02tmp.dbo.BonusWalletPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalancePendingCreditGame

INSERT INTO [dbo].[BalancePendingCreditGame] ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
SELECT tmp.[custid],tmp.[winlostdate],tmp.[Balance],tmp.[bettype],tmp.[GameTypeID]
FROM DBSIG02.SiteDB02tmp.dbo.BalancePendingCreditGame_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalancePendingDebitGame

INSERT INTO [dbo].[BalancePendingDebitGame] ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
SELECT tmp.[custid],tmp.[winlostdate],tmp.[Balance],tmp.[bettype],tmp.[GameTypeID]
FROM DBSIG02.SiteDB02tmp.dbo.BalancePendingDebitGame_Copy tmp WITH (NOLOCK) 

------------------------------------------------
--BalCreditCasinoPending

INSERT INTO [dbo].[BalCreditCasinoPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditCasinoPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalCreditOthersPending

INSERT INTO [dbo].[BalCreditOthersPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditOthersPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalCreditSportsPending

INSERT INTO [dbo].[BalCreditSportsPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM DBSIG02.SiteDB02tmp.dbo.BalCreditSportsPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalDebitCasinoPending

INSERT INTO [dbo].[BalDebitCasinoPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitCasinoPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalDebitOthersPending

INSERT INTO [dbo].[BalDebitOthersPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitOthersPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--BalDebitSportsPending

INSERT INTO [dbo].[BalDebitSportsPending] ([custid], [Balance])
SELECT tmp.[custid],tmp.[Balance]
FROM DBSIG02.SiteDB02tmp.dbo.BalDebitSportsPending_Copy tmp WITH (NOLOCK)

------------------------------------------------
--NetPositionCalculationLog

INSERT INTO [dbo].[NetPositionCalculationLog] ([CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], [IsLatest], [CreatedDate], [ModifiedDate])
SELECT tmp.[CustID], tmp.[MatchID], tmp.[Bettype], tmp.[AccumNPDebit], tmp.[AccumNPCredit], tmp.[NPAdjust], tmp.[IsLatest], tmp.[CreatedDate], tmp.[ModifiedDate]
FROM DBSIG02.SiteDB02tmp.dbo.NetPositionCalculationLog_Copy tmp WITH (NOLOCK)

------------------------------------------------
--NetPositionTrans

INSERT INTO [dbo].[NetPositionTrans] ([TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], [isSettled], [CreatedDate], [ModifiedDate])
SELECT tmp.[TransID], tmp.[CustID], tmp.[MatchID], tmp.[Bettype], tmp.[Actual_stake], tmp.[Payout1], tmp.[Payoutx], tmp.[Payout2], tmp.[SyncStatus], tmp.[isSettled], tmp.[CreatedDate], tmp.[ModifiedDate]
FROM DBSIG02.SiteDB02tmp.dbo.NetPositionTrans_Copy tmp WITH (NOLOCK)

------------------------------------------------
--Task_Cust_CheckBalance_Exception
SELECT *
INTO #Task_Cust_CheckBalance_Exception_tmp
FROM DBSIG02.SiteDB02tmp.dbo.Task_Cust_CheckBalance_Exception_Copy bon WITH (NOLOCK)

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
FROM #Task_Cust_CheckBalance_Exception_tmp_insert tmp

--DROP TABLE #Task_Cust_CheckBalance_Exception_tmp
--DROP TABLE #Task_Cust_CheckBalance_Exception_tmp_update
--DROP TABLE #Task_Cust_CheckBalance_Exception_tmp_insert

------------------------------------------------
--Task_Cust_BalanceProblem1

SELECT *
INTO #Task_Cust_BalanceProblem1_tmp
FROM DBSIG02.SiteDB02tmp.dbo.Task_Cust_BalanceProblem1_Copy WITH (NOLOCK)

SELECT tmp.* 
INTO #Task_Cust_BalanceProblem1_tmp_insert
FROM #Task_Cust_BalanceProblem1_tmp tmp
	LEFT JOIN [dbo].[Task_Cust_BalanceProblem1] main WITH (NOLOCK) ON main.custid = tmp.custid AND main.LogDate = tmp.LogDate
WHERE main.custid IS NULL

INSERT INTO [dbo].[Task_Cust_BalanceProblem1] ([UserName], [custid], [DiffBalance], [LogDate], [IsFixed], [Remark])
SELECT tmp.[UserName], tmp.[custid], tmp.[DiffBalance], tmp.[LogDate], tmp.[IsFixed], tmp.[Remark]
FROM #Task_Cust_BalanceProblem1_tmp_insert tmp

--DROP TABLE #Task_Cust_BalanceProblem1_tmp
--DROP TABLE #Task_Cust_BalanceProblem1_tmp_insert