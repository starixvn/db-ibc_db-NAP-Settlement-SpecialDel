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
-- Group 1: bettrans14, bettransm14, BetParlayDetail
------------------------------------------------
/*******************Bet Tickets Tables**********************/
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
