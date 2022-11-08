/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 Bonus_sum_winloss,BonusAdjustmentTransfer,BonusTrans,BonusWalletCredit,BonusWalletDebit,BonusWalletPending,
							 BalancePendingCreditGame,BalancePendingDebitGame,BalCreditCasinoPending,BalCreditOthersPending,
							 BalCreditSportsPending,BalDebitCasinoPending,BalDebitOthersPending,BalDebitSportsPending,Intg_GameRoundBetStake,
							 LastBetTime,LastBetTime_Agent,MarkedTransaction,NetPositionCalculationLog,
							 NetPositionTrans
*/

USE bodb02
GO
------------------------------------------------
/*********UPDATE DATA IF ALREADY EXISTS****************/


/*********INSERT DATA IF NOT EXISTS****************/
--Bonus_sum_winloss
INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
FROM DBSIG01.SiteDB01tmp.dbo.Bonus_sum_winloss_Copy bon WITH (NOLOCK)
	LEFT JOIN [dbo].[Bonus_sum_winloss] main WITH (NOLOCK) ON main.CustId = bon.CustId
WHERE main.CustId IS NULL

--BonusAdjustmentTransfer
INSERT INTO [dbo].[BonusAdjustmentTransfer] ([LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
SELECT bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
FROM DBSIG01.SiteDB01tmp.dbo.BonusAdjustmentTransfer_Copy bon WITH (NOLOCK)
	LEFT JOIN [dbo].[BonusAdjustmentTransfer] main WITH (NOLOCK) ON main.CustId = bon.CustId
WHERE main.CustId IS NULL

--BonusTrans
INSERT INTO [dbo].[BonusTrans] ([CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
								[PaymentDate], [IsComplained])
SELECT  bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
		bon.[PaymentDate], bon.[IsComplained]
FROM DBSIG01.SiteDB01tmp.dbo.BonusTrans_Copy bon WITH (NOLOCK)
	LEFT JOIN [dbo].[BonusTrans] main WITH (NOLOCK) ON main.CustId = bon.CustId
WHERE main.CustId IS NULL

--BonusWalletCredit
INSERT INTO [dbo].[BonusWalletCredit] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
FROM DBSIG01.SiteDB01tmp.dbo.BonusWalletCredit_Copy bon WITH (NOLOCK)
	LEFT JOIN [dbo].[BonusWalletCredit] main WITH (NOLOCK) ON main.CustId = bon.CustId
WHERE main.CustId IS NULL

--BonusWalletDebit
INSERT INTO [dbo].[BonusWalletDebit] ([CustID], [BonusID], [Amount])
SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
FROM DBSIG01.SiteDB01tmp.dbo.BonusWalletDebit_Copy bon WITH (NOLOCK)
	LEFT JOIN [dbo].[BonusWalletDebit] main WITH (NOLOCK) ON main.CustId = bon.CustId
WHERE main.CustId IS NULL

--BonusWalletPending
INSERT INTO [dbo].[BonusWalletPending] ([CustID], [BonusID], [Amount])
SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
FROM DBSIG01.SiteDB01tmp.dbo.BonusWalletPending_Copy bon WITH (NOLOCK)
	LEFT JOIN [dbo].[BonusWalletPending] main WITH (NOLOCK) ON main.CustId = bon.CustId
WHERE main.CustId IS NULL

--BalancePendingCreditGame
INSERT INTO [dbo].[BalancePendingCreditGame] ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
SELECT bc.[custid], bc.[winlostdate], bc.[Balance], bc.[bettype], bc.[GameTypeID]
FROM DBSIG01.SiteDB01tmp.dbo.BalancePendingCreditGame_Copy bc WITH (NOLOCK)
	LEFT JOIN [dbo].[BalancePendingCreditGame] main WITH (NOLOCK) ON main.CustId = bc.CustId
WHERE main.CustId IS NULL

--BalancePendingDebitGame
INSERT INTO [dbo].[BalancePendingDebitGame] ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
SELECT bd.[custid], bd.[winlostdate], bd.[Balance], bd.[bettype], bd.[GameTypeID]
FROM DBSIG01.SiteDB01tmp.dbo.BalancePendingDebitGame_Copy bd WITH (NOLOCK)
	LEFT JOIN [dbo].[BalancePendingDebitGame] main WITH (NOLOCK) ON main.CustId = bd.CustId
WHERE main.CustId IS NULL

--BalCreditCasinoPending
INSERT INTO [dbo].[BalCreditCasinoPending] ([custid], [Balance])
SELECT bc.[custid], bc.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditCasinoPending_Copy bc WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditCasinoPending] main WITH (NOLOCK) ON main.CustId = bc.CustId
WHERE main.CustId IS NULL

--BalCreditOthersPending
INSERT INTO [dbo].[BalCreditOthersPending] ([custid], [Balance])
SELECT bc.[custid], bc.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditOthersPending_Copy bc WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditOthersPending] main WITH (NOLOCK) ON main.CustId = bc.CustId
WHERE main.CustId IS NULL

--BalCreditSportsPending
INSERT INTO [dbo].[BalCreditSportsPending] ([custid], [Balance])
SELECT bc.[custid], bc.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalCreditSportsPending_Copy bc WITH (NOLOCK)
	LEFT JOIN [dbo].[BalCreditSportsPending] main WITH (NOLOCK) ON main.CustId = bc.CustId
WHERE main.CustId IS NULL

--BalDebitCasinoPending
INSERT INTO [dbo].[BalDebitCasinoPending] ([custid], [Balance])
SELECT bd.[custid], bd.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitCasinoPending_Copy bd WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitCasinoPending] main WITH (NOLOCK) ON main.CustId = bd.CustId
WHERE main.CustId IS NULL

--BalDebitOthersPending
INSERT INTO [dbo].[BalDebitOthersPending] ([custid], [Balance])
SELECT bd.[custid], bd.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitOthersPending_Copy bd WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitOthersPending] main WITH (NOLOCK) ON main.CustId = bd.CustId
WHERE main.CustId IS NULL

--BalDebitSportsPending
INSERT INTO [dbo].[BalDebitSportsPending] ([custid], [Balance])
SELECT bd.[custid], bd.[Balance]
FROM DBSIG01.SiteDB01tmp.dbo.BalDebitSportsPending_Copy bd WITH (NOLOCK)
	LEFT JOIN [dbo].[BalDebitSportsPending] main WITH (NOLOCK) ON main.CustId = bd.CustId
WHERE main.CustId IS NULL

--Intg_GameRoundBetStake
INSERT INTO [dbo].[Intg_GameRoundBetStake] ([VendorId], [BetId], [GameRound], [GameType], [BetChoice], [CustId], [Stake], [CreateDate])
SELECT igr.[VendorId], igr.[BetId], igr.[GameRound], igr.[GameType], igr.[BetChoice], igr.[CustId], igr.[Stake], igr.[CreateDate]
FROM DBSIG01.SiteDB01tmp.dbo.Intg_GameRoundBetStake_Copy igr WITH (NOLOCK)
	LEFT JOIN [dbo].[Intg_GameRoundBetStake] main WITH (NOLOCK) ON main.CustId = igr.CustId
WHERE main.CustId IS NULL

--LastBetTime
INSERT INTO [dbo].[LastBetTime] ([custid], [transdate])
SELECT lb.[custid], lb.[transdate]
FROM DBSIG01.SiteDB01tmp.dbo.LastBetTime_Copy lb WITH (NOLOCK)
	LEFT JOIN [dbo].[LastBetTime] main WITH (NOLOCK) ON main.CustId = lb.CustId
WHERE main.CustId IS NULL

--LastBetTime_Agent
INSERT INTO [dbo].[LastBetTime_Agent] ([CustID], [MatchID], [BetType], [CustomerClass], [Platform], [TransDate])
SELECT lba.[CustID], lba.[MatchID], lba.[BetType], lba.[CustomerClass], lba.[Platform], lba.[TransDate]
FROM DBSIG01.SiteDB01tmp.dbo.LastBetTime_Agent_Copy lba WITH (NOLOCK)
	LEFT JOIN [dbo].[LastBetTime_Agent] main WITH (NOLOCK) ON main.CustId = lba.CustId
WHERE main.CustId IS NULL

--MarkedTransaction
INSERT INTO [dbo].[MarkedTransaction] ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
SELECT mt.[TransId], mt.[MatchId], mt.[CustId], mt.[bettype], mt.[UserId], mt.[CreatedDate], mt.[MarkType]
FROM DBSIG01.SiteDB01tmp.dbo.MarkedTransaction_Copy mt WITH (NOLOCK)
	LEFT JOIN [dbo].[MarkedTransaction] main WITH (NOLOCK) ON main.CustId = mt.CustId
WHERE main.CustId IS NULL

--NetPositionCalculationLog
INSERT INTO [dbo].[NetPositionCalculationLog] (	[CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], 
												[IsLatest], [CreatedDate], [ModifiedDate])
SELECT	npcl.[CustID], npcl.[MatchID], npcl.[Bettype], npcl.[AccumNPDebit], npcl.[AccumNPCredit], npcl.[NPAdjust], 
		npcl.[IsLatest], npcl.[CreatedDate], npcl.[ModifiedDate]
FROM DBSIG01.SiteDB01tmp.dbo.NetPositionCalculationLog_Copy npcl WITH (NOLOCK)
	LEFT JOIN [dbo].[NetPositionCalculationLog] main WITH (NOLOCK) ON main.CustId = npcl.CustId
WHERE main.CustId IS NULL

--NetPositionTrans
INSERT INTO [dbo].[NetPositionTrans] (	[TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], 
										[isSettled], [CreatedDate], [ModifiedDate])
SELECT	npt.[TransID], npt.[CustID], npt.[MatchID], npt.[Bettype], npt.[Actual_stake], npt.[Payout1], npt.[Payoutx], npt.[Payout2], npt.[SyncStatus], 
		npt.[isSettled], npt.[CreatedDate], npt.[ModifiedDate]
FROM DBSIG01.SiteDB01tmp.dbo.NetPositionTrans_Copy npt WITH (NOLOCK)
	LEFT JOIN [dbo].[NetPositionTrans] main WITH (NOLOCK) ON main.CustId = npt.CustId
WHERE main.CustId IS NULL
