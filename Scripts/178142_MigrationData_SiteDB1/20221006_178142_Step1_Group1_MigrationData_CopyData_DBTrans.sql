/*<info serverAlias="DBSIG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee
    DB: DBCTG-SiteDBtmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#178142] 
							 Bet tickets tables:
								1.  bodb02.dbo.bettrans				2.  bodb02.dbo.bettrans14
								3.  bodb02.dbo.bettransG			4.  bodb02.dbo.bettransG14
								5.  bodb02.dbo.BettransInfo			6.  bodb02.dbo.BettransInfo14
								7.  bodb02.dbo.bettransLC			8.  bodb02.dbo.bettransLC14
								9.  bodb02.dbo.bettransm			10. bodb02.dbo.bettransm14
								11. bodb02.dbo.bettransRnG			12. bodb02.dbo.bettransRnG14
								13. bodb02.dbo.translog				14. bodb02.dbo.translog14
								15. bodb02.dbo.zzzbettrans			16. bodb02.dbo.zzzbettransm
								17. bodb02.dbo.Transfer				18. bodb02.dbo.Transfer_Coll		19. bodb02.dbo.TransferInfo
								20. bodb02.dbo.BetParlayDetail		21. bodb02.dbo.BetParlayResult
							 Tables balance:
								1.  bodb02.dbo.BalCreditCasino
								2.  bodb02.dbo.BalCreditOthers
								3.  bodb02.dbo.BalCreditSports
								4.  bodb02.dbo.BalCreditTransfer
								5.  bodb02.dbo.BalDebitCasino
								6.  bodb02.dbo.BalDebitOthers
								7.  bodb02.dbo.BalDebitSports
								8.  bodb02.dbo.BalDebitTransfer
								9.  bodb02.dbo.BalNetPosition
								10. bodb02.dbo.balanceTable
								11. bodb02.dbo.balanceTable_tmp
								12. bodb02.dbo.BalanceTable_tmp_cal
							 Other tables:
								1.  bodb02.dbo.Bonus_sum_winloss
								2.  bodb02.dbo.BonusAdjustmentTransfer
								3.  bodb02.dbo.BonusTrans
								4.  bodb02.dbo.BonusWalletCredit
								5.  bodb02.dbo.BonusWalletDebit
								6.  bodb02.dbo.BonusWalletPending
								7.  bodb02.dbo.CashOutSelling
								8.  bodb02.dbo.CustLimitBet_LIC
								9.  bodb02.dbo.CustLimitBetHistory_LIC
								10. bodb02.dbo.Task_bettrans14_IP2Country
								11. bodb02.dbo.Task_bettransLC14_IP2Country
								12. bodb02.dbo.Task_bettransRNG14_IP2Country
							 TW Tables list:
								1.  bodb02.dbo.BalancePendingCreditGame
								2.  bodb02.dbo.BalancePendingDebitGame
								3.  bodb02.dbo.BalCreditCasinoPending
								4.  bodb02.dbo.BalCreditOthersPending
								5.  bodb02.dbo.BalCreditSportsPending
								6.  bodb02.dbo.BalDebitCasinoPending
								7.  bodb02.dbo.BalDebitOthersPending
								8.  bodb02.dbo.BalDebitSportsPending
								9.  bodb02.dbo.Intg_GameRoundBetStake
								10. bodb02.dbo.LastBetTime
								11. bodb02.dbo.LastBetTime_Agent
								12. bodb02.dbo.MarkedTransaction
								13. bodb02.dbo.NetPositionCalculationLog
								14. bodb02.dbo.NetPositionTrans
								15. bodb02.dbo.Task_Cust_CheckBalance_Exception
								16. bodb02.dbo.Task_Cust_BalanceProblem1
								
*/

USE SiteDBtmp
GO

-- Group 1: bettrans14, bettransm14, BetParlayDetail, BettransInfo14, Task_bettrans14_IP2Country

DECLARE @SiteDBGroupID SMALLINT
DECLARE @debug_message VARCHAR(500)
	
SET @SiteDBGroupID = 1

CREATE TABLE #tmp_refno
(
	refno BIGINT PRIMARY KEY
)

------------------------------------------------
/*******************Bet Tickets Tables**********************/
--bodb02.dbo.bettrans14
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], 
		b.[comm], b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], 
		b.[liveawayscore], b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], 
		b.[actualrate], b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], 
		b.[actual_stake], b.[currency], b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[virtualrate], b.[Username], 
		b.[CurrencyName], b.[oddstype], b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], 
		b.[RefCode], b.[SettlementTime], b.[epositiontaking], b.[ReasonID], b.[sort], @SiteDBGroupID SiteDBGroupID
INTO bettrans14_20221006
FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.BettransInfo14
SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[ThirdTransID]
INTO BettransInfo14_20221006
FROM bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)
	INNER JOIN dbo.bettrans14_20221006 b WITH (NOLOCK) ON binfo.transid = b.transid 

--bodb02.dbo.bettransm14
SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
		bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], 
		bm.[apositiontaking], bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], 
		bm.[playercomm], bm.[comm], bm.[acomm], bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], 
		bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], 
		bm.[LiveBetAcceptTime], bm.[ReasonIDm], @SiteDBGroupID SiteDBGroupID
INTO bettransm14_20221006
FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = bm.custid

--#tmp_refno
INSERT INTO #tmp_refno (refno)
SELECT DISTINCT b.refno
FROM bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN cust_20221006 tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

INSERT INTO #tmp_refno (refno)
SELECT DISTINCT refno
FROM dbo.bettrans14_20221006  WITH (NOLOCK)
WHERE bettype = 29 AND matchid = 29
	
--bodb02.dbo.BetParlayDetail
SELECT	bpd.[RefNo], bpd.[Serial], bpd.[transid], bpd.[winlostdate], bpd.[statuswinlost], bpd.[statusid], bpd.[matchid], bpd.[bettype], bpd.[stake], bpd.[odds], bpd.[betteam], bpd.[hdp1], bpd.[hdp2], 
		bpd.[livehomescore], bpd.[liveawayscore], bpd.[liveindicator], bpd.[betcheck], bpd.[transdesc]
INTO BetParlayDetail_20221006
FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)
	INNER JOIN #tmp_refno tmp ON tmp.refno = bpd.refno

--10. bodb02.dbo.Task_bettrans14_IP2Country
SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
INTO [Task_bettrans14_IP2Country_20221006]
FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (NOLOCK)
	INNER JOIN dbo.bettrans14_20221006 b WITH (NOLOCK) ON b.transid = tbip.transid
------------------------------------------------
--DROP TABLE #tmp_cust
DROP TABLE #tmp_refno

	