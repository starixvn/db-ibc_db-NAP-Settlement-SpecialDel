/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220812@Victoria
    Task: Data Migration for SiteDB - Existing Licensee
    DB: DBSIG-bodb02

	 Revisions:
		- 20220812@Victoria: INSERT/TRUNCATE for TW List Tables [Redmineid:#176350]
							 INSERT data for the following tables:
								1.  dbo.BalancePendingCreditGame
								2.  dbo.BalancePendingDebitGame
								3.  dbo.BalCreditCasinoPending
								4.  dbo.BalCreditOthersPending
								5.  dbo.BalCreditSportsPending
								6.  dbo.BalDebitCasinoPending
								7.  dbo.BalDebitOthersPending
								8.  dbo.BalDebitSportsPending
								9.  dbo.Intg_GameRoundBetStake
								10. dbo.LastBetTime
								11. dbo.LastBetTime_Agent
								12. dbo.MarkedTransaction
								13. dbo.NetPositionCalculationLog
								14. dbo.NetPositionTrans
								15. dbo.Task_Cust_CheckBalance_Exception

							 TRUNCATE for the following tables:
								1.  dbo.Task_Cust_CheckBalanceVerify1
								2.  dbo.NetPositionTrans_UAT
								3.  dbo.RejectTicketLog
								4.  dbo.Task_Cust_BalanceProblem1
								5.  dbo.NetPositionCalculationLog_UAT
								6.  dbo.NetPositionQueue_UAT
								7.  dbo.CS_CustSuper
								8.  dbo.AcceptTicketLog
								9.  dbo.BalanceErr
								10. dbo.CustLimitBet_QueueRetry
								11. dbo.IntgUserLog

*/

	USE bodb02
	GO
	
	CREATE TABLE #tmp_cust
	(
		custid INT PRIMARY KEY
	)

	------------------------------------------------
	INSERT INTO #tmp_cust (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer WITH (NOLOCK)
	WHERE site IN ('Athena000','SampleSite')
	------------------------------------------------

	/*******PART 1 - INSERT DATA*******/
	--1.  dbo.BalancePendingCreditGame
	--There is no index on custid for table BalancePendingCreditGame, has only an index on rn

	--INSERT INTO [dbo].[BalancePendingCreditGame] ([rn], [custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	SELECT bc.[rn], bc.[custid], bc.[winlostdate], bc.[Balance], bc.[bettype], bc.[GameTypeID]
	INTO BalancePendingCreditGame_old20220825
	FROM [dbo].[BalancePendingCreditGame] bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--2.  dbo.BalancePendingDebitGame
	--There is no index on custid for table BalancePendingDebitGame, has only an index on rn

	--INSERT INTO [dbo].[BalancePendingDebitGame] ([rn], [custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	SELECT bd.[rn], bd.[custid], bd.[winlostdate], bd.[Balance], bd.[bettype], bd.[GameTypeID]
	INTO BalancePendingDebitGame_old20220825
	FROM [dbo].[BalancePendingDebitGame] bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--3.  dbo.BalCreditCasinoPending
	--There is no index on custid for table BalCreditCasinoPending, has only an index on rn

	--INSERT INTO [dbo].[BalCreditCasinoPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	INTO BalCreditCasinoPending_old20220825
	FROM [dbo].[BalCreditCasinoPending] bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--4.  dbo.BalCreditOthersPending
	--There is no index on custid for table BalCreditOthersPending, has only an index on rn

	--INSERT INTO [dbo].[BalCreditOthersPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	INTO BalCreditOthersPending_old20220825
	FROM [dbo].[BalCreditOthersPending] bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--5.  dbo.BalCreditSportsPending
	--There is no index on custid for table BalCreditSportsPending, has only an index on rn

	--INSERT INTO [dbo].[BalCreditSportsPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	INTO BalCreditSportsPending_old20220825
	FROM [dbo].[BalCreditSportsPending] bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--6.  dbo.BalDebitCasinoPending
	--There is no index on custid for table BalDebitCasinoPending, has only an index on rn

	--INSERT INTO [dbo].[BalDebitCasinoPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	INTO BalDebitCasinoPending_old20220825
	FROM [dbo].[BalDebitCasinoPending] bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--7.  dbo.BalDebitOthersPending
	--There is no index on custid for table BalDebitOthersPending, has only an index on rn

	--INSERT INTO [dbo].[BalDebitOthersPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	INTO BalDebitOthersPending_old20220825
	FROM [dbo].[BalDebitOthersPending] bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--8.  dbo.BalDebitSportsPending
	--There is no index on custid for table BalDebitSportsPending, has only an index on rn

	--INSERT INTO [dbo].[BalDebitSportsPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	INTO BalDebitSportsPending_old20220825
	FROM [dbo].[BalDebitSportsPending] bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--9. dbo.Intg_GameRoundBetStake
	--There is no index on custid for table Intg_GameRoundBetStake
	--INSERT INTO [dbo].[Intg_GameRoundBetStake] ([VendorId], [BetId], [GameRound], [GameType], [BetChoice], [CustId], [Stake], [CreateDate])
	SELECT igr.[VendorId], igr.[BetId], igr.[GameRound], igr.[GameType], igr.[BetChoice], igr.[CustId], igr.[Stake], igr.[CreateDate]
	INTO Intg_GameRoundBetStake_old20220825
	FROM [dbo].[Intg_GameRoundBetStake] igr WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = igr.custid

	--10. dbo.LastBetTime
	--INSERT INTO [dbo].[LastBetTime] ([custid], [transdate])
	SELECT lb.[custid], lb.[transdate]
	INTO LastBetTime_old20220825
	FROM [dbo].[LastBetTime] lb WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = lb.custid

	--11. dbo.LastBetTime_Agent
	--INSERT INTO [dbo].[LastBetTime_Agent] ([CustID], [MatchID], [BetType], [CustomerClass], [Platform], [TransDate])
	SELECT lba.[CustID], lba.[MatchID], lba.[BetType], lba.[CustomerClass], lba.[Platform], lba.[TransDate]
	INTO LastBetTime_Agent_old20220825
	FROM [dbo].[LastBetTime_Agent] lba WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = lba.custid

	--12. dbo.MarkedTransaction
	--INSERT INTO [dbo].[MarkedTransaction] ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
	SELECT mt.[TransId], mt.[MatchId], mt.[CustId], mt.[bettype], mt.[UserId], mt.[CreatedDate], mt.[MarkType]
	INTO MarkedTransaction_old20220825
	FROM [dbo].[MarkedTransaction] mt WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = mt.custid

	--13. dbo.NetPositionCalculationLog

	--INSERT INTO [dbo].[NetPositionCalculationLog] (	[NPCalculationLogID], [CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], 
													--[IsLatest], [CreatedDate], [ModifiedDate])
	SELECT	npcl.[NPCalculationLogID], npcl.[CustID], npcl.[MatchID], npcl.[Bettype], npcl.[AccumNPDebit], npcl.[AccumNPCredit], npcl.[NPAdjust], 
			npcl.[IsLatest], npcl.[CreatedDate], npcl.[ModifiedDate]
	INTO NetPositionCalculationLog_old20220825
	FROM [dbo].[NetPositionCalculationLog] npcl WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = npcl.custid

	--14. dbo.NetPositionTrans

	--INSERT INTO [dbo].[NetPositionTrans] (	[TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], 
											--[isSettled], [CreatedDate], [ModifiedDate])
	SELECT	npt.[TransID], npt.[CustID], npt.[MatchID], npt.[Bettype], npt.[Actual_stake], npt.[Payout1], npt.[Payoutx], npt.[Payout2], npt.[SyncStatus], 
			npt.[isSettled], npt.[CreatedDate], npt.[ModifiedDate]
	INTO NetPositionTrans_old20220825
	FROM [dbo].[NetPositionTrans] npt WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = npt.custid

	--15. dbo.Task_Cust_CheckBalance_Exception
	--INSERT INTO [dbo].[Task_Cust_CheckBalance_Exception] ([custid], [Remark])
	SELECT	tce.[custid], tce.[Remark]
	INTO Task_Cust_CheckBalance_Exception_old20220825
	FROM [dbo].[Task_Cust_CheckBalance_Exception] tce WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = tce.custid
	------------------------------------------------
	DROP TABLE #tmp_cust

GO
TRUNCATE TABLE [dbo].[BalancePendingCreditGame]
TRUNCATE TABLE [dbo].[BalancePendingDebitGame]
TRUNCATE TABLE [dbo].[BalCreditCasinoPending]
TRUNCATE TABLE [dbo].[BalCreditOthersPending]
TRUNCATE TABLE [dbo].[BalCreditSportsPending]
TRUNCATE TABLE [dbo].[BalDebitCasinoPending]
TRUNCATE TABLE [dbo].[BalDebitOthersPending]
TRUNCATE TABLE [dbo].[BalDebitSportsPending]
TRUNCATE TABLE [dbo].[Intg_GameRoundBetStake]
TRUNCATE TABLE [dbo].[LastBetTime]
TRUNCATE TABLE [dbo].[LastBetTime_Agent]
TRUNCATE TABLE [dbo].[MarkedTransaction]
TRUNCATE TABLE [dbo].[NetPositionCalculationLog]
TRUNCATE TABLE [dbo].[NetPositionTrans]
TRUNCATE TABLE [dbo].[Task_Cust_CheckBalance_Exception]
GO

	
	--1.  dbo.BalancePendingCreditGame
	--There is no index on custid for table BalancePendingCreditGame, has only an index on rn
	SET IDENTITY_INSERT BalancePendingCreditGame ON

	INSERT INTO [dbo].[BalancePendingCreditGame] ([rn], [custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	SELECT bc.[rn], bc.[custid], bc.[winlostdate], bc.[Balance], bc.[bettype], bc.[GameTypeID]
	FROM [dbo].[BalancePendingCreditGame_old20220825] bc WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	SET IDENTITY_INSERT BalancePendingCreditGame OFF

	--2.  dbo.BalancePendingDebitGame
	--There is no index on custid for table BalancePendingDebitGame, has only an index on rn
	SET IDENTITY_INSERT BalancePendingDebitGame ON

	INSERT INTO [dbo].[BalancePendingDebitGame] ([rn], [custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	SELECT bd.[rn], bd.[custid], bd.[winlostdate], bd.[Balance], bd.[bettype], bd.[GameTypeID]
	FROM [dbo].[BalancePendingDebitGame_old20220825] bd WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	SET IDENTITY_INSERT BalancePendingDebitGame OFF

	--3.  dbo.BalCreditCasinoPending
	--There is no index on custid for table BalCreditCasinoPending, has only an index on rn
	SET IDENTITY_INSERT BalCreditCasinoPending ON

	INSERT INTO [dbo].[BalCreditCasinoPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	FROM [dbo].[BalCreditCasinoPending_old20220825] bc WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	SET IDENTITY_INSERT BalCreditCasinoPending OFF

	--4.  dbo.BalCreditOthersPending
	--There is no index on custid for table BalCreditOthersPending, has only an index on rn
	SET IDENTITY_INSERT BalCreditOthersPending ON

	INSERT INTO [dbo].[BalCreditOthersPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	FROM [dbo].[BalCreditOthersPending_old20220825] bc WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	SET IDENTITY_INSERT BalCreditOthersPending OFF

	--5.  dbo.BalCreditSportsPending
	--There is no index on custid for table BalCreditSportsPending, has only an index on rn
	SET IDENTITY_INSERT BalCreditSportsPending ON

	INSERT INTO [dbo].[BalCreditSportsPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	FROM [dbo].[BalCreditSportsPending_old20220825] bc WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	SET IDENTITY_INSERT BalCreditSportsPending OFF

	--6.  dbo.BalDebitCasinoPending
	--There is no index on custid for table BalDebitCasinoPending, has only an index on rn
	SET IDENTITY_INSERT BalDebitCasinoPending ON

	INSERT INTO [dbo].[BalDebitCasinoPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	FROM [dbo].[BalDebitCasinoPending_old20220825] bd WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	SET IDENTITY_INSERT BalDebitCasinoPending OFF

	--7.  dbo.BalDebitOthersPending
	--There is no index on custid for table BalDebitOthersPending, has only an index on rn
	SET IDENTITY_INSERT BalDebitOthersPending ON

	INSERT INTO [dbo].[BalDebitOthersPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	FROM [dbo].[BalDebitOthersPending_old20220825] bd WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	SET IDENTITY_INSERT BalDebitOthersPending OFF

	--8.  dbo.BalDebitSportsPending
	--There is no index on custid for table BalDebitSportsPending, has only an index on rn
	SET IDENTITY_INSERT BalDebitSportsPending ON

	INSERT INTO [dbo].[BalDebitSportsPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	FROM [dbo].[BalDebitSportsPending_old20220825] bd WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	SET IDENTITY_INSERT BalDebitSportsPending OFF

	--9. dbo.Intg_GameRoundBetStake
	--There is no index on custid for table Intg_GameRoundBetStake
	INSERT INTO [dbo].[Intg_GameRoundBetStake] ([VendorId], [BetId], [GameRound], [GameType], [BetChoice], [CustId], [Stake], [CreateDate])
	SELECT igr.[VendorId], igr.[BetId], igr.[GameRound], igr.[GameType], igr.[BetChoice], igr.[CustId], igr.[Stake], igr.[CreateDate]
	FROM [dbo].[Intg_GameRoundBetStake_old20220825] igr WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = igr.custid

	--10. dbo.LastBetTime
	INSERT INTO [dbo].[LastBetTime] ([custid], [transdate])
	SELECT lb.[custid], lb.[transdate]
	FROM [dbo].[LastBetTime_old20220825] lb WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = lb.custid

	--11. dbo.LastBetTime_Agent
	INSERT INTO [dbo].[LastBetTime_Agent] ([CustID], [MatchID], [BetType], [CustomerClass], [Platform], [TransDate])
	SELECT lba.[CustID], lba.[MatchID], lba.[BetType], lba.[CustomerClass], lba.[Platform], lba.[TransDate]
	FROM [dbo].[LastBetTime_Agent_old20220825] lba WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = lba.custid

	--12. dbo.MarkedTransaction
	INSERT INTO [dbo].[MarkedTransaction] ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
	SELECT mt.[TransId], mt.[MatchId], mt.[CustId], mt.[bettype], mt.[UserId], mt.[CreatedDate], mt.[MarkType]
	FROM [dbo].[MarkedTransaction_old20220825] mt WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = mt.custid

	--13. dbo.NetPositionCalculationLog
	SET IDENTITY_INSERT NetPositionCalculationLog ON

	INSERT INTO [dbo].[NetPositionCalculationLog] (	[NPCalculationLogID], [CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], 
													[IsLatest], [CreatedDate], [ModifiedDate])
	SELECT	npcl.[NPCalculationLogID], npcl.[CustID], npcl.[MatchID], npcl.[Bettype], npcl.[AccumNPDebit], npcl.[AccumNPCredit], npcl.[NPAdjust], 
			npcl.[IsLatest], npcl.[CreatedDate], npcl.[ModifiedDate]
	FROM [dbo].[NetPositionCalculationLog_old20220825] npcl WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = npcl.custid

	SET IDENTITY_INSERT NetPositionCalculationLog OFF

	--14. dbo.NetPositionTrans
	SET IDENTITY_INSERT NetPositionTrans ON

	INSERT INTO [dbo].[NetPositionTrans] (	[TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], 
											[isSettled], [CreatedDate], [ModifiedDate])
	SELECT	npt.[TransID], npt.[CustID], npt.[MatchID], npt.[Bettype], npt.[Actual_stake], npt.[Payout1], npt.[Payoutx], npt.[Payout2], npt.[SyncStatus], 
			npt.[isSettled], npt.[CreatedDate], npt.[ModifiedDate]
	FROM [dbo].[NetPositionTrans_old20220825] npt WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = npt.custid
	
	SET IDENTITY_INSERT NetPositionTrans OFF

	--15. dbo.Task_Cust_CheckBalance_Exception
	INSERT INTO [dbo].[Task_Cust_CheckBalance_Exception] ([custid], [Remark])
	SELECT	tce.[custid], tce.[Remark]
	FROM [dbo].[Task_Cust_CheckBalance_Exception_old20220825] tce WITH (NOLOCK)
		--INNER JOIN #tmp_cust tmp ON tmp.custid = tce.custid

	/*******PART 2 - TRUNCATE TABLE*******/
	TRUNCATE TABLE [dbo].[Task_Cust_CheckBalanceVerify1]
	TRUNCATE TABLE [dbo].[NetPositionTrans_UAT]
	TRUNCATE TABLE [dbo].[RejectTicketLog]
	TRUNCATE TABLE [dbo].[Task_Cust_BalanceProblem1]
	TRUNCATE TABLE [dbo].[NetPositionCalculationLog_UAT]
	TRUNCATE TABLE [dbo].[NetPositionQueue_UAT]
	TRUNCATE TABLE [dbo].[CS_CustSuper]
	TRUNCATE TABLE [dbo].[AcceptTicketLog]
	TRUNCATE TABLE [dbo].[BalanceErr]
	TRUNCATE TABLE [dbo].[CustLimitBet_QueueRetry]
	TRUNCATE TABLE [dbo].[IntgUserLog]