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
-- Group 1: bettrans14, bettransm14, BetParlayDetail, BettransInfo14, Task_bettrans14_IP2Country
-----------bettrans14
--//drop
DROP INDEX [bettrans1423] ON [dbo].[bettrans14]
GO
DROP INDEX [IX_matchid_refno] ON [dbo].[bettrans14]
GO
ALTER TABLE [dbo].[bettrans14] DROP CONSTRAINT [PK_bettrans14]
GO
DROP INDEX [IX_bettrans14] ON [dbo].[bettrans14] WITH ( ONLINE = OFF )
GO

-----------------bettransm14
--//drop
ALTER TABLE [dbo].[bettransm14] DROP CONSTRAINT [PK_bettransm14]
GO
DROP INDEX [IX_bettransm14] ON [dbo].[bettransm14] WITH ( ONLINE = OFF )
GO

-----------------BetParlayDetail
--//drop
DROP INDEX [IX_transid] ON [dbo].[BetParlayDetail]
GO
DROP INDEX [CIX_RefNo_Serial] ON [dbo].[BetParlayDetail] WITH ( ONLINE = OFF )
GO

------------------------------------------------
/*******************Bet Tickets Tables**********************/
--BettransInfo14
INSERT INTO dbo.BettransInfo14 ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [ThirdTransID])
SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[ThirdTransID]
FROM SiteDBtmp.dbo.BettransInfo14_20221006 binfo WITH (NOLOCK)

--10. dbo.Task_bettrans14_IP2Country
INSERT INTO [dbo].[Task_bettrans14_IP2Country] ([transid], [winlostdate], [CountryShort], [IPArchive])
SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
FROM SiteDBtmp.dbo.Task_bettrans14_IP2Country_20221006 tbip WITH (NOLOCK)

--bettrans14
INSERT INTO dbo.bettrans14 ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], 
							[comm], [acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], 
							[liveawayscore], [liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], 
							[actualrate], [matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], 
							[actual_stake], [currency], [ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [virtualrate], [Username], 
							[CurrencyName], [oddstype], [statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], 
							[RefCode], [SettlementTime], [epositiontaking], [ReasonID], [sort], [SiteDBGroupID])
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], 
		b.[comm], b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], 
		b.[liveawayscore], b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], 
		b.[actualrate], b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], 
		b.[actual_stake], b.[currency], b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[virtualrate], b.[Username], 
		b.[CurrencyName], b.[oddstype], b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], 
		b.[RefCode], b.[SettlementTime], b.[epositiontaking], b.[ReasonID], b.[sort], b.[SiteDBGroupID]
FROM SiteDBtmp.dbo.bettrans14_20221006 b WITH (NOLOCK)

--bettransm14
INSERT INTO dbo.bettransm14		([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], 
								[apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
								[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], 
								[spositiontaking], [swinlost], [sdiscount], [scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], 
								[LiveBetAcceptTime], [ReasonIDm], [SiteDBGroupID])
SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
		bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], 
		bm.[apositiontaking], bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], 
		bm.[playercomm], bm.[comm], bm.[acomm], bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], 
		bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], 
		bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[SiteDBGroupID]
FROM SiteDBtmp.dbo.bettransm14_20221006 bm WITH (NOLOCK)
	
--BetParlayDetail
INSERT INTO dbo.BetParlayDetail ([RefNo], [Serial], [transid], [winlostdate], [statuswinlost], [statusid], [matchid], [bettype], [stake], [odds], [betteam], [hdp1], [hdp2], 
								[livehomescore], [liveawayscore], [liveindicator], [betcheck], [transdesc])
SELECT	bpd.[RefNo], bpd.[Serial], bpd.[transid], bpd.[winlostdate], bpd.[statuswinlost], bpd.[statusid], bpd.[matchid], bpd.[bettype], bpd.[stake], bpd.[odds], bpd.[betteam], bpd.[hdp1], bpd.[hdp2], 
		bpd.[livehomescore], bpd.[liveawayscore], bpd.[liveindicator], bpd.[betcheck], bpd.[transdesc]
FROM SiteDBtmp.dbo.BetParlayDetail_20221006 bpd WITH (NOLOCK)

GO

--//create
CREATE CLUSTERED INDEX [CIX_RefNo_Serial] ON [dbo].[BetParlayDetail]
(
	[RefNo] ASC,
	[Serial] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_table]
GO

CREATE NONCLUSTERED INDEX [IX_transid] ON [dbo].[BetParlayDetail]
(
	[transid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM_index]
GO


--//create
CREATE CLUSTERED INDEX [IX_bettrans14] ON [dbo].[bettrans14]
(
	[winlostdate] ASC,
	[custid] ASC,
	[matchid] ASC,
	[bettype] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans14_table]
GO

ALTER TABLE [dbo].[bettrans14] ADD  CONSTRAINT [PK_bettrans14] PRIMARY KEY NONCLUSTERED 
(
	[transid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans14_index]
GO
CREATE NONCLUSTERED INDEX [IX_matchid_refno] ON [dbo].[bettrans14]
(
	[matchid] ASC,
	[refno] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans14_index]
GO

CREATE NONCLUSTERED INDEX [bettrans1423] ON [dbo].[bettrans14]
(
	[custid] ASC,
	[matchid] ASC,
	[ruben] ASC,
	[bettype] ASC,
	[winlost] ASC,
	[awinlost] ASC,
	[mwinlost] ASC,
	[actual_stake] ASC,
	[currency] ASC,
	[scomm] ASC,
	[swinlost] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Bettrans14_index]
GO

--//create
CREATE CLUSTERED INDEX [IX_bettransm14] ON [dbo].[bettransm14]
(
	[refno] ASC,
	[custid] ASC,
	[matchid] ASC,
	[oddsid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM14_table]
GO

ALTER TABLE [dbo].[bettransm14] ADD  CONSTRAINT [PK_bettransm14] PRIMARY KEY NONCLUSTERED 
(
	[transid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [BettransM14_index]
GO