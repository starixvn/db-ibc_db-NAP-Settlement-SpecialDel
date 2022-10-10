/*<info serverAlias="DBSIG-SiteDB02tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB02
    DB: DBCTG-SiteDB02tmp

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

USE SiteDB02tmp
GO
-- Group 3: all but not (bettrans, transfer, bettransm, bettrans14, bettransm14, BetParlayDetail)

DECLARE @SiteDBGroupID SMALLINT
DECLARE @debug_message VARCHAR(500)
	
SET @SiteDBGroupID = 2

CREATE TABLE #tmp_refno
(
	refno BIGINT PRIMARY KEY
)

--bodb02_tmp.dbo.bettransG
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
		b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
		b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
		b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
		@SiteDBGroupID SiteDBGroupID , b.[RepUpdateTime]
INTO bettransG_20221006
FROM bodb02_tmp.dbo.bettransG b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.bettransG14
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
		b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
		b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
		b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
		@SiteDBGroupID SiteDBGroupID
INTO bettransG14_20221006
FROM bodb02_tmp.dbo.bettransG14 b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.bettransLC
SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
		b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
		b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
		b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
		b.[scomm], b.[Transdate3rd], b.[NetStake], b.[SiteID], b.[epositiontaking], @SiteDBGroupID SiteDBGroupID , b.[RepUpdateTime]
INTO bettransLC_20221006
FROM bodb02_tmp.dbo.bettransLC b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.bettransLC14
SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
		b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
		b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
		b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
		b.[scomm], b.[Transdate3rd], b.[NetStake], b.[epositiontaking], b.[SiteID], @SiteDBGroupID SiteDBGroupID
INTO bettransLC14_20221006
FROM bodb02_tmp.dbo.bettransLC14 b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.bettransRnG
SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
		b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
		b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
		b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], b.[scomm], 
		b.[Transdate3rd], b.[SiteID], b.[Additional], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
		b.[epositiontaking], @SiteDBGroupID SiteDBGroupID, b.[RepUpdateTime]
INTO bettransRnG_20221006
FROM bodb02_tmp.dbo.bettransRnG b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.bettransRnG14
SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
		b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
		b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
		b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], 
		b.[acomm], b.[scomm], b.[Transdate3rd], b.[Additional], b.[Siteid], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
		b.[epositiontaking], @SiteDBGroupID SiteDBGroupID
INTO bettransRnG14_20221006
FROM bodb02_tmp.dbo.bettransRnG14 b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.translog
SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
		b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
		b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
		b.[gameID], b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], b.[checkCount], b.[SiteId], 
		b.[epositiontaking], @SiteDBGroupID SiteDBGroupID, b.[LicenseeTransId], b.[RepUpdateTime]
INTO translog_20221006
FROM bodb02_tmp.dbo.translog b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02_tmp.dbo.translog14
SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
		b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
		b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
		b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], @SiteDBGroupID SiteDBGroupID
INTO translog14_20221006
FROM bodb02_tmp.dbo.translog14 b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid
	
--#tmp_refno
INSERT INTO #tmp_refno (refno)
SELECT DISTINCT refno
FROM bodb02_tmp.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

INSERT INTO #tmp_refno (refno)
SELECT DISTINCT refno
FROM bodb02_tmp.dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

--bodb02_tmp.dbo.BetParlayResult
SELECT	bpr.[RefNo], bpr.[Serial], bpr.[transid], bpr.[winlostdate], bpr.[statusid], bpr.[stake], bpr.[Odds], bpr.[mOdds], bpr.[winlost], bpr.[awinlost], bpr.[mwinlost], bpr.[swinlost], bpr.[playercomm], bpr.[comm], bpr.[acomm], bpr.[scomm]
INTO BetParlayResult_20221006
FROM bodb02_tmp.dbo.BetParlayResult bpr WITH (NOLOCK)
	INNER JOIN #tmp_refno tmp ON tmp.refno = bpr.refno

--bodb02_tmp.dbo.zzzbettrans
SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
		z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
		z.[VoidingHistoryId], z.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
INTO zzzbettrans_20221006
FROM bodb02_tmp.dbo.zzzbettrans z WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = z.custid
		
--bodb02_tmp.dbo.zzzbettransm
SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
		z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
		z.[VoidingHistoryId], z.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
INTO zzzbettransm_20221006
FROM bodb02_tmp.dbo.zzzbettransm z WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = z.custid


/********************Tables Balance*************************/

--1. bodb02_tmp.dbo.BalCreditCasino
SELECT bal.[custid], bal.[Balance]
INTO [BalCreditCasino_20221006]
FROM bodb02_tmp.dbo.BalCreditCasino bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--2. bodb02_tmp.dbo.BalCreditOthers
SELECT bal.[custid], bal.[Balance]
INTO [BalCreditOthers_20221006]
FROM bodb02_tmp.dbo.BalCreditOthers bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--3. bodb02_tmp.dbo.BalCreditSports
SELECT bal.[custid], bal.[Balance]
INTO [BalCreditSports_20221006]
FROM bodb02_tmp.dbo.BalCreditSports bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--4. BalCreditTransfer
SELECT bal.[custid], bal.[Balance]
INTO [BalCreditTransfer_20221006]
FROM bodb02_tmp.dbo.BalCreditTransfer bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--5. bodb02_tmp.dbo.BalDebitCasino
SELECT bal.[custid], bal.[Balance]
INTO [BalDebitCasino_20221006]
FROM bodb02_tmp.dbo.BalDebitCasino bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--6. bodb02_tmp.dbo.BalDebitOthers
SELECT bal.[custid], bal.[Balance]
INTO [BalDebitOthers_20221006]
FROM bodb02_tmp.dbo.BalDebitOthers bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--7. bodb02_tmp.dbo.BalDebitSports
SELECT bal.[custid], bal.[Balance]
INTO [BalDebitSports_20221006]
FROM bodb02_tmp.dbo.BalDebitSports bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--8. bodb02_tmp.dbo.BalDebitTransfer
SELECT bal.[custid], bal.[Balance]
INTO [BalDebitTransfer_20221006]
FROM bodb02_tmp.dbo.BalDebitTransfer bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--9. bodb02_tmp.dbo.BalNetPosition
SELECT bal.[CustID], bal.[MatchID], bal.[Bettype], bal.[Debit], bal.[Credit], bal.[CreatedDate], bal.[ModifiedDate]
INTO [BalNetPosition_20221006]
FROM bodb02_tmp.dbo.BalNetPosition bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--10. bodb02_tmp.dbo.balanceTable
SELECT  bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
		bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
INTO [balanceTable_20221006]
FROM bodb02_tmp.dbo.balanceTable bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--11. bodb02_tmp.dbo.balanceTable_tmp
SELECT  bal.[winlostdate], bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
		bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
INTO [balanceTable_tmp_20221006]
FROM bodb02_tmp.dbo.balanceTable_tmp bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--12. bodb02_tmp.dbo.BalanceTable_tmp_cal
SELECT	bal.[dow], bal.[roleid], bal.[custid], bal.[recommend], bal.[mrecommend], bal.[srecommend], 
		bal.[amt1], bal.[tcnt1], bal.[amt2], bal.[tcnt2], bal.[amt3], bal.[tcnt3], bal.[amt4], bal.[tcnt4]
INTO [BalanceTable_tmp_cal_20221006]
FROM bodb02_tmp.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bal.custid

/*******************Other Tables**********************/
--1. bodb02_tmp.dbo.Bonus_sum_winloss
SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
INTO [Bonus_sum_winloss_20221006]
FROM bodb02_tmp.dbo.Bonus_sum_winloss bon WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--2. bodb02_tmp.dbo.BonusAdjustmentTransfer
-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
SELECT bon.[ExecID], bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
INTO [BonusAdjustmentTransfer_20221006]
FROM bodb02_tmp.dbo.BonusAdjustmentTransfer bon WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--3. bodb02_tmp.dbo.BonusTrans
SELECT  bon.[BonusTransId], bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
		bon.[PaymentDate], bon.[IsComplained]
INTO [BonusTrans_20221006]
FROM bodb02_tmp.dbo.BonusTrans bon WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--4. bodb02_tmp.dbo.BonusWalletCredit
SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
INTO [BonusWalletCredit_20221006]
FROM bodb02_tmp.dbo.BonusWalletCredit bon WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--5. bodb02_tmp.dbo.BonusWalletDebit
SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
INTO [BonusWalletDebit_20221006]
FROM bodb02_tmp.dbo.BonusWalletDebit bon WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--6. bodb02_tmp.dbo.BonusWalletPending
-- There is no index on custid for table BonusWalletPending, has only an index on Rn
SELECT  bon.[Rn], bon.[CustID], bon.[BonusID], bon.[Amount]
INTO [BonusWalletPending_20221006]
FROM bodb02_tmp.dbo.BonusWalletPending bon WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--7. bodb02_tmp.dbo.CashOutSelling
-- There is no index on custid for table CashOutSelling, has only an index on TransID
SELECT	cosell.[TransID], cosell.[MatchID], cosell.[Bettype], cosell.[Custid], cosell.[CashOutStatus], cosell.[Winlost], cosell.[PriceInfo], cosell.[CheckTime], 
		cosell.[CreateDate], cosell.[ChangeDate], cosell.[IsTest], cosell.[VirtualRate], cosell.[CashOutExtraInfo]
INTO [CashOutSelling_20221006]
FROM bodb02_tmp.dbo.CashOutSelling cosell WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = cosell.custid

--8. bodb02_tmp.dbo.CustLimitBet_LIC
SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
INTO [CustLimitBet_LIC_20221006]
FROM bodb02_tmp.dbo.CustLimitBet_LIC clb WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = clb.custid

--9. bodb02_tmp.dbo.CustLimitBetHistory_LIC
SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
INTO [CustLimitBetHistory_LIC_20221006]
FROM bodb02_tmp.dbo.CustLimitBetHistory_LIC clbh WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = clbh.custid

--11. bodb02_tmp.dbo.Task_bettransLC14_IP2Country
SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
INTO [Task_bettransLC14_IP2Country_20221006]
FROM bodb02_tmp.dbo.Task_bettransLC14_IP2Country tbip WITH (NOLOCK)
	INNER JOIN dbo.bettransLC14_20221006 b WITH (NOLOCK) ON b.transid = tbip.transid

--12. bodb02_tmp.dbo.Task_bettransRNG14_IP2Country
SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
INTO [Task_bettransRNG14_IP2Country_20221006]
FROM bodb02_tmp.dbo.Task_bettransRNG14_IP2Country tbip WITH (NOLOCK)
	INNER JOIN dbo.bettransRnG14_20221006 b WITH (NOLOCK) ON b.transid = tbip.transid

/*******************Other tables - TW list**********************/

--1.  bodb02_tmp.dbo.BalancePendingCreditGame
--There is no index on custid for table BalancePendingCreditGame, has only an index on rn
SELECT bc.[rn], bc.[custid], bc.[winlostdate], bc.[Balance], bc.[bettype], bc.[GameTypeID]
INTO BalancePendingCreditGame_20221006
FROM bodb02_tmp.dbo.BalancePendingCreditGame bc WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--2.  bodb02_tmp.dbo.BalancePendingDebitGame
--There is no index on custid for table BalancePendingDebitGame, has only an index on rn
SELECT bd.[rn], bd.[custid], bd.[winlostdate], bd.[Balance], bd.[bettype], bd.[GameTypeID]
INTO BalancePendingDebitGame_20221006
FROM bodb02_tmp.dbo.BalancePendingDebitGame bd WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--3.  bodb02_tmp.dbo.BalCreditCasinoPending
--There is no index on custid for table BalCreditCasinoPending, has only an index on rn
SELECT bc.[rn], bc.[custid], bc.[Balance]
INTO BalCreditCasinoPending_20221006
FROM bodb02_tmp.dbo.BalCreditCasinoPending bc WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--4.  bodb02_tmp.dbo.BalCreditOthersPending
--There is no index on custid for table BalCreditOthersPending, has only an index on rn
SELECT bc.[rn], bc.[custid], bc.[Balance]
INTO BalCreditOthersPending_20221006
FROM bodb02_tmp.dbo.BalCreditOthersPending bc WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--5.  bodb02_tmp.dbo.BalCreditSportsPending
--There is no index on custid for table BalCreditSportsPending, has only an index on rn
SELECT bc.[rn], bc.[custid], bc.[Balance]
INTO BalCreditSportsPending_20221006
FROM bodb02_tmp.dbo.BalCreditSportsPending bc WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--6.  bodb02_tmp.dbo.BalDebitCasinoPending
--There is no index on custid for table BalDebitCasinoPending, has only an index on rn
SELECT bd.[rn], bd.[custid], bd.[Balance]
INTO BalDebitCasinoPending_20221006
FROM bodb02_tmp.dbo.BalDebitCasinoPending bd WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--7.  bodb02_tmp.dbo.BalDebitOthersPending
--There is no index on custid for table BalDebitOthersPending, has only an index on rn
SELECT bd.[rn], bd.[custid], bd.[Balance]
INTO BalDebitOthersPending_20221006
FROM bodb02_tmp.dbo.BalDebitOthersPending bd WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--8.  bodb02_tmp.dbo.BalDebitSportsPending
--There is no index on custid for table BalDebitSportsPending, has only an index on rn
SELECT bd.[rn], bd.[custid], bd.[Balance]
INTO BalDebitSportsPending_20221006
FROM bodb02_tmp.dbo.BalDebitSportsPending bd WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--9. bodb02_tmp.dbo.Intg_GameRoundBetStake
--There is no index on custid for table Intg_GameRoundBetStake
SELECT igr.[VendorId], igr.[BetId], igr.[GameRound], igr.[GameType], igr.[BetChoice], igr.[CustId], igr.[Stake], igr.[CreateDate]
INTO Intg_GameRoundBetStake_20221006
FROM bodb02_tmp.dbo.Intg_GameRoundBetStake igr WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = igr.custid

--10. bodb02_tmp.dbo.LastBetTime
SELECT lb.[custid], lb.[transdate]
INTO LastBetTime_20221006
FROM bodb02_tmp.dbo.LastBetTime lb WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = lb.custid

--11. bodb02_tmp.dbo.LastBetTime_Agent
SELECT lba.[CustID], lba.[MatchID], lba.[BetType], lba.[CustomerClass], lba.[Platform], lba.[TransDate]
INTO LastBetTime_Agent_20221006
FROM bodb02_tmp.dbo.LastBetTime_Agent lba WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = lba.custid

--12. bodb02_tmp.dbo.MarkedTransaction
SELECT mt.[TransId], mt.[MatchId], mt.[CustId], mt.[bettype], mt.[UserId], mt.[CreatedDate], mt.[MarkType]
INTO MarkedTransaction_20221006
FROM bodb02_tmp.dbo.MarkedTransaction mt WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = mt.custid

--13. bodb02_tmp.dbo.NetPositionCalculationLog
SELECT	npcl.[NPCalculationLogID], npcl.[CustID], npcl.[MatchID], npcl.[Bettype], npcl.[AccumNPDebit], npcl.[AccumNPCredit], npcl.[NPAdjust], 
		npcl.[IsLatest], npcl.[CreatedDate], npcl.[ModifiedDate]
INTO NetPositionCalculationLog_20221006
FROM bodb02_tmp.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = npcl.custid

--14. bodb02_tmp.dbo.NetPositionTrans
SELECT	npt.[TransID], npt.[CustID], npt.[MatchID], npt.[Bettype], npt.[Actual_stake], npt.[Payout1], npt.[Payoutx], npt.[Payout2], npt.[SyncStatus], 
		npt.[isSettled], npt.[CreatedDate], npt.[ModifiedDate]
INTO NetPositionTrans_20221006
FROM bodb02_tmp.dbo.NetPositionTrans npt WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = npt.custid

--15. bodb02_tmp.dbo.Task_Cust_CheckBalance_Exception
SELECT	tce.[custid], tce.[Remark]
INTO Task_Cust_CheckBalance_Exception_20221006
FROM bodb02_tmp.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = tce.custid

--16. bodb02_tmp.dbo.Task_Cust_BalanceProblem1
--There is no index on custid for table Task_Cust_BalanceProblem1, has only an index on keyID
SELECT tcb.[UserName], tcb.[custid], tcb.[DiffBalance], tcb.[LogDate], tcb.[IsFixed], tcb.[Remark]
INTO Task_Cust_BalanceProblem1_20221006 
FROM bodb02_tmp.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = tcb.custid

------------------------------------------------
--DROP TABLE #tmp_cust
DROP TABLE #tmp_refno

	