/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 2022926@Victoria
    Task: Data Migration - Real Licensee
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: INSERT from the copy all data of the following tables [Redmineid:#178142] 
							 Bet tickets tables:
								1.  SiteDBtmp.dbo.bettrans_20221006				2.  SiteDBtmp.dbo.bettrans14_20221006
								3.  SiteDBtmp.dbo.bettransG_20221006			4.  SiteDBtmp.dbo.bettransG14_20221006
								5.  SiteDBtmp.dbo.BettransInfo_20221006			6.  SiteDBtmp.dbo.BettransInfo14_20221006
								7.  SiteDBtmp.dbo.bettransLC_20221006			8.  SiteDBtmp.dbo.bettransLC14_20221006
								9.  SiteDBtmp.dbo.bettransm_20221006			10. SiteDBtmp.dbo.bettransm14_20221006
								11. SiteDBtmp.dbo.bettransRnG_20221006			12. SiteDBtmp.dbo.bettransRnG14_20221006
								13. SiteDBtmp.dbo.translog_20221006				14. SiteDBtmp.dbo.translog14_20221006
								15. SiteDBtmp.dbo.zzzbettrans_20221006			16. SiteDBtmp.dbo.zzzbettransm_20221006
								17. SiteDBtmp.dbo.Transfer_20221006				18. SiteDBtmp.dbo.Transfer_Coll_20221006		19. SiteDBtmp.dbo.TransferInfo_20221006
								20. SiteDBtmp.dbo.BetParlayDetail_20221006		21. SiteDBtmp.dbo.BetParlayResult_20221006
							 Tables balance:
								1.  SiteDBtmp.dbo.BalCreditCasino_20221006
								2.  SiteDBtmp.dbo.BalCreditOthers_20221006
								3.  SiteDBtmp.dbo.BalCreditSports_20221006
								4.  SiteDBtmp.dbo.BalCreditTransfer_20221006
								5.  SiteDBtmp.dbo.BalDebitCasino_20221006
								6.  SiteDBtmp.dbo.BalDebitOthers_20221006
								7.  SiteDBtmp.dbo.BalDebitSports_20221006
								8.  SiteDBtmp.dbo.BalDebitTransfer_20221006
								9.  SiteDBtmp.dbo.BalNetPosition_20221006
								10. SiteDBtmp.dbo.balanceTable_20221006
								11. SiteDBtmp.dbo.balanceTable_tmp_20221006
								12. SiteDBtmp.dbo.BalanceTable_tmp_cal_20221006
							 Other tables:
								1.  SiteDBtmp.dbo.Bonus_sum_winloss_20221006
								2.  SiteDBtmp.dbo.BonusAdjustmentTransfer_20221006
								3.  SiteDBtmp.dbo.BonusTrans_20221006
								4.  SiteDBtmp.dbo.BonusWalletCredit_20221006
								5.  SiteDBtmp.dbo.BonusWalletDebit_20221006
								6.  SiteDBtmp.dbo.BonusWalletPending_20221006
								7.  SiteDBtmp.dbo.CashOutSelling_20221006
								8.  SiteDBtmp.dbo.CustLimitBet_LIC_20221006
								9.  SiteDBtmp.dbo.CustLimitBetHistory_LIC_20221006
								10. SiteDBtmp.dbo.Task_bettrans14_IP2Country_20221006
								11. SiteDBtmp.dbo.Task_bettransLC14_IP2Country_20221006
								12. SiteDBtmp.dbo.Task_bettransRNG14_IP2Country_20221006
							 TW Tables list:
								1.  SiteDBtmp.dbo.BalancePendingCreditGame_20221006
								2.  SiteDBtmp.dbo.BalancePendingDebitGame_20221006
								3.  SiteDBtmp.dbo.BalCreditCasinoPending_20221006
								4.  SiteDBtmp.dbo.BalCreditOthersPending_20221006
								5.  SiteDBtmp.dbo.BalCreditSportsPending_20221006
								6.  SiteDBtmp.dbo.BalDebitCasinoPending_20221006
								7.  SiteDBtmp.dbo.BalDebitOthersPending_20221006
								8.  SiteDBtmp.dbo.BalDebitSportsPending_20221006
								9.  SiteDBtmp.dbo.Intg_GameRoundBetStake_20221006
								10. SiteDBtmp.dbo.LastBetTime_20221006
								11. SiteDBtmp.dbo.LastBetTime_Agent_20221006
								12. SiteDBtmp.dbo.MarkedTransaction_20221006
								13. SiteDBtmp.dbo.NetPositionCalculationLog_20221006
								14. SiteDBtmp.dbo.NetPositionTrans_20221006
								15. SiteDBtmp.dbo.Task_Cust_CheckBalance_Exception_20221006
								16. SiteDBtmp.dbo.Task_Cust_BalanceProblem1_20221006
*/

USE bodb02
GO
---------------------hey pontus dep trai -> run sitedb01 nhe------------------------------------
-- Group 2: bettrans, transfer, bettransm, BettransInfo, Transfer_Coll, TransferInfo
------------bettrans
--//drop
DROP INDEX [IX_custid] ON [dbo].[bettrans]
GO
DROP INDEX [IX_customerinfo] ON [dbo].[bettrans]
GO
DROP INDEX [IX_FcUpdateTime] ON [dbo].[bettrans]
GO
DROP INDEX [IX_recommend] ON [dbo].[bettrans]
GO
DROP INDEX [IX_RepUpdateTime] ON [dbo].[bettrans]
GO
ALTER TABLE [dbo].[bettrans] DROP CONSTRAINT [PK_bettrans]
GO
DROP INDEX [CIX_matchid_bettype] ON [dbo].[bettrans] WITH ( ONLINE = OFF )
GO

------------------bettransm
--//drop
DROP INDEX [IX_bettransm_1] ON [dbo].[bettransm]
GO
DROP INDEX [IX_matchid] ON [dbo].[bettransm]
GO
DROP INDEX [IX_RepUpdateTime] ON [dbo].[bettransm]
GO
DROP INDEX [IX_winlostdate] ON [dbo].[bettransm]
GO
ALTER TABLE [dbo].[bettransm] DROP CONSTRAINT [PK_bettransm]
GO
DROP INDEX [IX_refno] ON [dbo].[bettransm] WITH ( ONLINE = OFF )
GO

----------------------transfer
--//drop
DROP INDEX [IX_CustId] ON [dbo].[Transfer]
GO
DROP INDEX [IX_Recommend] ON [dbo].[Transfer]
GO
DROP INDEX [IX_RepUpdateTime] ON [dbo].[Transfer]
GO
DROP INDEX [IX_WinlostDate] ON [dbo].[Transfer]
GO
ALTER TABLE [dbo].[Transfer] DROP CONSTRAINT [PK_Transfer] WITH ( ONLINE = OFF )
GO

------------------------------------------------
/*******************Bet Tickets Tables**********************/
--TransferInfo
INSERT INTO dbo.TransferInfo	([TransId], [APositiontaking], [MPositiontaking], [SPositiontaking], [EPositiontaking], [PlayerDiscount], [Discount], [ADiscount], [SDiscount], 
								[WalletType], [BonusID], [Amount], [CheckerId], [CheckerName], [IsCollection], [IsDel], [RepUpdateTime])
SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
		b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
FROM SiteDBtmp.dbo.TransferInfo_20221006 b WITH (NOLOCK)

--BettransInfo
INSERT INTO dbo.BettransInfo ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [RepUpdateTime], [ThirdTransID])
SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[RepUpdateTime], binfo.[ThirdTransID]
FROM SiteDBtmp.dbo.BettransInfo_20221006 binfo WITH (NOLOCK)

--Transfer_Coll
INSERT INTO dbo.Transfer_Coll	([CustId], [WinlostDate], [TransDate], [Bettype], [Debit], [Credit], [Currency], [ActualRate], [TransID], [RefNo], [Username], 
								[Recommend], [MRecommend], [SRecommend], [Creator], [TransDesc], [IP], [RepUpdateTime])
SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
		b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
FROM SiteDBtmp.dbo.Transfer_Coll_20221006 b WITH (NOLOCK)


--bettrans
INSERT INTO dbo.bettrans (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], 
							[acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [actualrate], 
							[matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], 
							[ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [virtualrate], [oddstype], 
							[statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], [RefCode], [SettlementTime],
							[epositiontaking], [ReasonID], [sort], [BetSiteID], [RepUpdateTime], [RepDstUpdateTime], [SiteDBGroupID], [FcUpdateTime])
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
		b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
		b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
		b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
		b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
		b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
		b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], b.[RepDstUpdateTime], b.[SiteDBGroupID], b.[FcUpdateTime]
FROM SiteDBtmp.dbo.bettrans_20221006 b WITH (NOLOCK)

--bettransm
-- since there is no index on custid for bettransm, need to join via refno
INSERT INTO dbo.bettransm ( [transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], 
							[mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], 
							[actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], 
							[scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm], [RepUpdateTime], [SiteDBGroupID])
SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
		bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], bm.[apositiontaking], 
		bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], 
		bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], 
		bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[RepUpdateTime], bm.[SiteDBGroupID]
FROM SiteDBtmp.dbo.bettransm_20221006 bm WITH (NOLOCK)

--Transfer
INSERT INTO dbo.Transfer	([TransId], [CustId], [TransDate], [WinlostDate], [Bettype], [Stake], [Actual_Stake], [Winlost], [AWinlost], [MWinlost], [SWinlost], [PlayerComm], 
							[Comm], [AComm], [SComm], [StatusId], [RefNo], [TransDesc], [Recommend], [MRecommend], [SRecommend], [Username], [Currency], [CurrencyName], 
							[ActualRate], [Creator], [Balance], [IP], [CheckTime], [SerialNo], [RepUpdateTime])
SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
		b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
		b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
FROM SiteDBtmp.dbo.Transfer_20221006 b WITH (NOLOCK)

go

--//create
ALTER TABLE [dbo].[Transfer] ADD  CONSTRAINT [PK_Transfer] PRIMARY KEY CLUSTERED 
(
	[TransId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Transfer_Table]
GO
CREATE NONCLUSTERED INDEX [IX_WinlostDate] ON [dbo].[Transfer]
(
	[WinlostDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Transfer_Index]
GO

CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[Transfer]
(
	[RepUpdateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Transfer_Index]
GO

CREATE NONCLUSTERED INDEX [IX_Recommend] ON [dbo].[Transfer]
(
	[Recommend] ASC,
	[WinlostDate] ASC,
	[Bettype] ASC
)
INCLUDE([MRecommend],[CustId],[Winlost],[Actual_Stake],[PlayerComm],[AWinlost],[MWinlost],[AComm],[Comm]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Transfer_Index]
GO

CREATE NONCLUSTERED INDEX [IX_CustId] ON [dbo].[Transfer]
(
	[CustId] ASC,
	[WinlostDate] ASC,
	[Bettype] ASC
)
INCLUDE([Winlost],[Actual_Stake],[PlayerComm]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Transfer_Index]
GO


--//create
CREATE CLUSTERED INDEX [CIX_matchid_bettype] ON [dbo].[bettrans]
(
	[matchid] ASC,
	[custid] ASC,
	[bettype] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_table]
GO

ALTER TABLE [dbo].[bettrans] ADD  CONSTRAINT [PK_bettrans] PRIMARY KEY NONCLUSTERED 
(
	[transid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_index3]
GO

CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettrans]
(
	[RepUpdateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_index1]
GO

CREATE NONCLUSTERED INDEX [IX_recommend] ON [dbo].[bettrans]
(
	[recommend] ASC,
	[winlostdate] ASC,
	[bettype] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_index2]
GO

CREATE NONCLUSTERED INDEX [IX_FcUpdateTime] ON [dbo].[bettrans]
(
	[FcUpdateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_index4]
GO

CREATE NONCLUSTERED INDEX [IX_customerinfo] ON [dbo].[bettrans]
(
	[custid] ASC,
	[winlostdate] ASC
)
INCLUDE([transid],[statusID],[transdate],[winlost],[playercomm],[ruben],[actual_stake],[refno],[checktime],[SecAcceptFlag],[stake]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_index2]
GO

CREATE NONCLUSTERED INDEX [IX_custid] ON [dbo].[bettrans]
(
	[custid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans_index1]
GO

--//create
CREATE CLUSTERED INDEX [IX_refno] ON [dbo].[bettransm]
(
	[refno] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_table]
GO

ALTER TABLE [dbo].[bettransm] ADD  CONSTRAINT [PK_bettransm] PRIMARY KEY NONCLUSTERED 
(
	[transid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_index]
GO
CREATE NONCLUSTERED INDEX [IX_winlostdate] ON [dbo].[bettransm]
(
	[winlostdate] ASC
)
INCLUDE([custid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_index]
GO
CREATE NONCLUSTERED INDEX [IX_RepUpdateTime] ON [dbo].[bettransm]
(
	[RepUpdateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_index]
GO

CREATE NONCLUSTERED INDEX [IX_matchid] ON [dbo].[bettransm]
(
	[matchid] ASC,
	[bettype] ASC,
	[statusID] ASC
)
INCLUDE([statuswinlost],[transdate],[checktime],[SecAcceptFlag],[liveindicator],[transid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_index]
GO
CREATE NONCLUSTERED INDEX [IX_bettransm_1] ON [dbo].[bettransm]
(
	[matchid] ASC,
	[oddsid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_index]
GO