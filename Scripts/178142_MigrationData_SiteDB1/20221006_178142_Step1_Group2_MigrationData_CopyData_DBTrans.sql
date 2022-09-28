/*<info serverAlias="DBSIG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee
    DB: DBCTG-SiteDBtmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#178142] 
							 Bet tickets tables:
								1.  bodb02_tmp.dbo.bettrans				2.  bodb02_tmp.dbo.bettrans14
								3.  bodb02_tmp.dbo.bettransG			4.  bodb02_tmp.dbo.bettransG14
								5.  bodb02_tmp.dbo.BettransInfo			6.  bodb02_tmp.dbo.BettransInfo14
								7.  bodb02_tmp.dbo.bettransLC			8.  bodb02_tmp.dbo.bettransLC14
								9.  bodb02_tmp.dbo.bettransm			10. bodb02_tmp.dbo.bettransm14
								11. bodb02_tmp.dbo.bettransRnG			12. bodb02_tmp.dbo.bettransRnG14
								13. bodb02_tmp.dbo.translog				14. bodb02_tmp.dbo.translog14
								15. bodb02_tmp.dbo.zzzbettrans			16. bodb02_tmp.dbo.zzzbettransm
								17. bodb02_tmp.dbo.Transfer				18. bodb02_tmp.dbo.Transfer_Coll		19. bodb02_tmp.dbo.TransferInfo
								20. bodb02_tmp.dbo.BetParlayDetail		21. bodb02_tmp.dbo.BetParlayResult
							 Tables balance:
								1.  bodb02_tmp.dbo.BalCreditCasino
								2.  bodb02_tmp.dbo.BalCreditOthers
								3.  bodb02_tmp.dbo.BalCreditSports
								4.  bodb02_tmp.dbo.BalCreditTransfer
								5.  bodb02_tmp.dbo.BalDebitCasino
								6.  bodb02_tmp.dbo.BalDebitOthers
								7.  bodb02_tmp.dbo.BalDebitSports
								8.  bodb02_tmp.dbo.BalDebitTransfer
								9.  bodb02_tmp.dbo.BalNetPosition
								10. bodb02_tmp.dbo.balanceTable
								11. bodb02_tmp.dbo.balanceTable_tmp
								12. bodb02_tmp.dbo.BalanceTable_tmp_cal
							 Other tables:
								1.  bodb02_tmp.dbo.Bonus_sum_winloss
								2.  bodb02_tmp.dbo.BonusAdjustmentTransfer
								3.  bodb02_tmp.dbo.BonusTrans
								4.  bodb02_tmp.dbo.BonusWalletCredit
								5.  bodb02_tmp.dbo.BonusWalletDebit
								6.  bodb02_tmp.dbo.BonusWalletPending
								7.  bodb02_tmp.dbo.CashOutSelling
								8.  bodb02_tmp.dbo.CustLimitBet_LIC
								9.  bodb02_tmp.dbo.CustLimitBetHistory_LIC
								10. bodb02_tmp.dbo.Task_bettrans14_IP2Country
								11. bodb02_tmp.dbo.Task_bettransLC14_IP2Country
								12. bodb02_tmp.dbo.Task_bettransRNG14_IP2Country
							 TW Tables list:
								1.  bodb02_tmp.dbo.BalancePendingCreditGame
								2.  bodb02_tmp.dbo.BalancePendingDebitGame
								3.  bodb02_tmp.dbo.BalCreditCasinoPending
								4.  bodb02_tmp.dbo.BalCreditOthersPending
								5.  bodb02_tmp.dbo.BalCreditSportsPending
								6.  bodb02_tmp.dbo.BalDebitCasinoPending
								7.  bodb02_tmp.dbo.BalDebitOthersPending
								8.  bodb02_tmp.dbo.BalDebitSportsPending
								9.  bodb02_tmp.dbo.Intg_GameRoundBetStake
								10. bodb02_tmp.dbo.LastBetTime
								11. bodb02_tmp.dbo.LastBetTime_Agent
								12. bodb02_tmp.dbo.MarkedTransaction
								13. bodb02_tmp.dbo.NetPositionCalculationLog
								14. bodb02_tmp.dbo.NetPositionTrans
								15. bodb02_tmp.dbo.Task_Cust_CheckBalance_Exception
								16. bodb02_tmp.dbo.Task_Cust_BalanceProblem1
								
*/

USE SiteDBtmp
GO
-- Group 2: bettrans, transfer, bettransm, BettransInfo, Transfer_Coll, TransferInfo
DECLARE @SiteDBGroupID SMALLINT
DECLARE @debug_message VARCHAR(500)
	
SET @SiteDBGroupID = 1

/*******************Bet Tickets Tables**********************/
--bodb02_tmp.dbo.bettrans
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
		b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
		b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
		b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
		b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
		b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
		b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], b.[RepDstUpdateTime], @SiteDBGroupID SiteDBGroupID, b.[FcUpdateTime]
INTO bettrans_20221006
FROM bodb02_tmp.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.BettransInfo
SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[RepUpdateTime], binfo.[ThirdTransID]
INTO BettransInfo_20221006
FROM bodb02_tmp.dbo.BettransInfo binfo WITH (NOLOCK)
	INNER JOIN dbo.bettrans_20221006 b WITH (NOLOCK) ON b.transid = binfo.transid

--bodb02_tmp.dbo.bettransm
-- since there is no index on custid for bettransm, need to join via refno
SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
		bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], bm.[apositiontaking], 
		bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], 
		bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], 
		bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
INTO bettransm_20221006
FROM bodb02_tmp.dbo.bettransm bm WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bm.custid

--bodb02_tmp.dbo.Transfer
SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
		b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
		b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
INTO Transfer_20221006
FROM bodb02_tmp.dbo.Transfer b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.Transfer_Coll
SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
		b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
INTO Transfer_Coll_20221006
FROM bodb02_tmp.dbo.Transfer_Coll b WITH (NOLOCK)
	INNER JOIN dbo.Transfer_20221006 b1 WITH (NOLOCK) ON b1.TransID = b.TransID

--bodb02_tmp.dbo.TransferInfo
SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
		b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
INTO TransferInfo_20221006
FROM bodb02_tmp.dbo.TransferInfo b WITH (NOLOCK)
	INNER JOIN dbo.Transfer_20221006 b1 WITH (NOLOCK) ON b1.TransID = b.TransID	

------------------------------------------------
--DROP TABLE #tmp_cust


	