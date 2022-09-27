/*<info serverAlias="DBCTG-SiteDB2tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Test Licensee
    DB: DBCTG-SiteDB2tmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#178145] 
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

	USE SiteDB2tmp
	GO

	DECLARE @SiteDBGroupID SMALLINT
	DECLARE @debug_message VARCHAR(500)
	
	SET @SiteDBGroupID = 2

	CREATE TABLE #tmp_cust
	(
		custid INT PRIMARY KEY
	)

	CREATE TABLE #tmp_refno
	(
		refno BIGINT PRIMARY KEY
	)

	------------------------------------------------
	INSERT INTO #tmp_cust (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer WITH (NOLOCK)
	WHERE site IN	('Bobo88')
	------------------------------------------------
	/*******************Bet Tickets Tables**********************/
	--bodb02.dbo.bettrans
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
			b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
			b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
			b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
			b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
			b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
			b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], b.[RepDstUpdateTime], @SiteDBGroupID SiteDBGroupID, b.[FcUpdateTime]
	INTO bettrans_20220929_SIT
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettrans14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], 
			b.[comm], b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], 
			b.[liveawayscore], b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], 
			b.[actualrate], b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], 
			b.[actual_stake], b.[currency], b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[virtualrate], b.[Username], 
			b.[CurrencyName], b.[oddstype], b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], 
			b.[RefCode], b.[SettlementTime], b.[epositiontaking], b.[ReasonID], b.[sort], @SiteDBGroupID SiteDBGroupID
	INTO bettrans14_20220929_SIT
	FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransG
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
			b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
			b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
			b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
			@SiteDBGroupID SiteDBGroupID , b.[RepUpdateTime]
	INTO bettransG_20220929_SIT
	FROM bodb02.dbo.bettransG b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransG14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
			b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
			b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
			b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
			@SiteDBGroupID SiteDBGroupID
	INTO bettransG14_20220929_SIT
	FROM bodb02.dbo.bettransG14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.BettransInfo
	SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[RepUpdateTime], binfo.[ThirdTransID]
	INTO BettransInfo_20220929_SIT
	FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)
		INNER JOIN dbo.bettrans_20220929_SIT b WITH (NOLOCK) ON b.transid = binfo.transid

	--bodb02.dbo.BettransInfo14
	SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[ThirdTransID]
	INTO BettransInfo14_20220929_SIT
	FROM bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_20220929_SIT b WITH (NOLOCK) ON binfo.transid = b.transid 

	--bodb02.dbo.bettransLC
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
			b.[scomm], b.[Transdate3rd], b.[NetStake], b.[SiteID], b.[epositiontaking], @SiteDBGroupID SiteDBGroupID , b.[RepUpdateTime]
	INTO bettransLC_20220929_SIT
	FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransLC14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
			b.[scomm], b.[Transdate3rd], b.[NetStake], b.[epositiontaking], b.[SiteID], @SiteDBGroupID SiteDBGroupID
	INTO bettransLC14_20220929_SIT
	FROM bodb02.dbo.bettransLC14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransRnG
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
			b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], b.[scomm], 
			b.[Transdate3rd], b.[SiteID], b.[Additional], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
			b.[epositiontaking], @SiteDBGroupID SiteDBGroupID, b.[RepUpdateTime]
	INTO bettransRnG_20220929_SIT
	FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransRnG14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], 
			b.[acomm], b.[scomm], b.[Transdate3rd], b.[Additional], b.[Siteid], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
			b.[epositiontaking], @SiteDBGroupID SiteDBGroupID
	INTO bettransRnG14_20220929_SIT
	FROM bodb02.dbo.bettransRnG14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.translog
	SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], b.[checkCount], b.[SiteId], 
			b.[epositiontaking], @SiteDBGroupID SiteDBGroupID, b.[LicenseeTransId], b.[RepUpdateTime]
	INTO translog_20220929_SIT
	FROM bodb02.dbo.translog b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.translog14
	SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
			b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], @SiteDBGroupID SiteDBGroupID
	INTO translog14_20220929_SIT
	FROM bodb02.dbo.translog14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	
	--bodb02.dbo.bettransm
	-- since there is no index on custid for bettransm, need to join via refno
	SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
			bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], bm.[apositiontaking], 
			bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], 
			bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], 
			bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
	INTO bettransm_20220929_SIT
	FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bm.custid

	--bodb02.dbo.bettransm14
	SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
			bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], 
			bm.[apositiontaking], bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], 
			bm.[playercomm], bm.[comm], bm.[acomm], bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], 
			bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], 
			bm.[LiveBetAcceptTime], bm.[ReasonIDm], @SiteDBGroupID SiteDBGroupID
	INTO bettransm14_20220929_SIT
	FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bm.custid

	--#tmp_refno
	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM dbo.bettrans_20220929_SIT WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM dbo.bettrans14_20220929_SIT  WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29
	
   --bodb02.dbo.BetParlayDetail
	SELECT	bpd.[RefNo], bpd.[Serial], bpd.[transid], bpd.[winlostdate], bpd.[statuswinlost], bpd.[statusid], bpd.[matchid], bpd.[bettype], bpd.[stake], bpd.[odds], bpd.[betteam], bpd.[hdp1], bpd.[hdp2], 
			bpd.[livehomescore], bpd.[liveawayscore], bpd.[liveindicator], bpd.[betcheck], bpd.[transdesc]
	INTO BetParlayDetail_20220929_SIT
	FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp ON tmp.refno = bpd.refno

	--bodb02.dbo.BetParlayResult
	SELECT	bpr.[RefNo], bpr.[Serial], bpr.[transid], bpr.[winlostdate], bpr.[statusid], bpr.[stake], bpr.[Odds], bpr.[mOdds], bpr.[winlost], bpr.[awinlost], bpr.[mwinlost], bpr.[swinlost], bpr.[playercomm], bpr.[comm], bpr.[acomm], bpr.[scomm]
	INTO BetParlayResult_20220929_SIT
	FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp ON tmp.refno = bpr.refno

	--bodb02.dbo.zzzbettrans
	SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
			z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
			z.[VoidingHistoryId], z.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
	INTO zzzbettrans_20220929_SIT
	FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = z.custid
		
	--bodb02.dbo.zzzbettransm
	SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
			z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
			z.[VoidingHistoryId], z.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
	INTO zzzbettransm_20220929_SIT
	FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = z.custid

	--bodb02.dbo.Transfer
	SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
			b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
			b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
	INTO Transfer_20220929_SIT
	FROM bodb02.dbo.Transfer b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.Transfer_Coll
	SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
			b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
	INTO Transfer_Coll_20220929_SIT
	FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_20220929_SIT b1 WITH (NOLOCK) ON b1.TransID = b.TransID

	--bodb02.dbo.TransferInfo
	SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
			b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
	INTO TransferInfo_20220929_SIT
	FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_20220929_SIT b1 WITH (NOLOCK) ON b1.TransID = b.TransID

	/********************Tables Balance*************************/

	--1. bodb02.dbo.BalCreditCasino
	SELECT bal.[custid], bal.[Balance]
	INTO [BalCreditCasino_20220929_SIT]
	FROM bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--2. bodb02.dbo.BalCreditOthers
	SELECT bal.[custid], bal.[Balance]
	INTO [BalCreditOthers_20220929_SIT]
	FROM bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--3. bodb02.dbo.BalCreditSports
	SELECT bal.[custid], bal.[Balance]
	INTO [BalCreditSports_20220929_SIT]
	FROM bodb02.dbo.BalCreditSports bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--4. BalCreditTransfer
	SELECT bal.[custid], bal.[Balance]
	INTO [BalCreditTransfer_20220929_SIT]
	FROM bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--5. bodb02.dbo.BalDebitCasino
	SELECT bal.[custid], bal.[Balance]
	INTO [BalDebitCasino_20220929_SIT]
	FROM bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--6. bodb02.dbo.BalDebitOthers
	SELECT bal.[custid], bal.[Balance]
	INTO [BalDebitOthers_20220929_SIT]
	FROM bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--7. bodb02.dbo.BalDebitSports
	SELECT bal.[custid], bal.[Balance]
	INTO [BalDebitSports_20220929_SIT]
	FROM bodb02.dbo.BalDebitSports bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--8. bodb02.dbo.BalDebitTransfer
	SELECT bal.[custid], bal.[Balance]
	INTO [BalDebitTransfer_20220929_SIT]
	FROM bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--9. bodb02.dbo.BalNetPosition
	SELECT bal.[CustID], bal.[MatchID], bal.[Bettype], bal.[Debit], bal.[Credit], bal.[CreatedDate], bal.[ModifiedDate]
	INTO [BalNetPosition_20220929_SIT]
	FROM bodb02.dbo.BalNetPosition bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--10. bodb02.dbo.balanceTable
	SELECT  bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
			bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
	INTO [balanceTable_20220929_SIT]
	FROM bodb02.dbo.balanceTable bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--11. bodb02.dbo.balanceTable_tmp
	SELECT  bal.[winlostdate], bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
			bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
	INTO [balanceTable_tmp_20220929_SIT]
	FROM bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	--12. bodb02.dbo.BalanceTable_tmp_cal
	SELECT	bal.[dow], bal.[roleid], bal.[custid], bal.[recommend], bal.[mrecommend], bal.[srecommend], 
			bal.[amt1], bal.[tcnt1], bal.[amt2], bal.[tcnt2], bal.[amt3], bal.[tcnt3], bal.[amt4], bal.[tcnt4]
	INTO [BalanceTable_tmp_cal_20220929_SIT]
	FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bal.custid

	/*******************Other Tables**********************/
	--1. bodb02.dbo.Bonus_sum_winloss
	SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
	INTO [Bonus_sum_winloss_20220929_SIT]
	FROM bodb02.dbo.Bonus_sum_winloss bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--2. bodb02.dbo.BonusAdjustmentTransfer
	-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
	SELECT bon.[ExecID], bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
	INTO [BonusAdjustmentTransfer_20220929_SIT]
	FROM bodb02.dbo.BonusAdjustmentTransfer bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--3. bodb02.dbo.BonusTrans
	SELECT  bon.[BonusTransId], bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
			bon.[PaymentDate], bon.[IsComplained]
	INTO [BonusTrans_20220929_SIT]
	FROM bodb02.dbo.BonusTrans bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--4. bodb02.dbo.BonusWalletCredit
	SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
	INTO [BonusWalletCredit_20220929_SIT]
	FROM bodb02.dbo.BonusWalletCredit bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--5. bodb02.dbo.BonusWalletDebit
	SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
	INTO [BonusWalletDebit_20220929_SIT]
	FROM bodb02.dbo.BonusWalletDebit bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--6. bodb02.dbo.BonusWalletPending
	-- There is no index on custid for table BonusWalletPending, has only an index on Rn
	SELECT  bon.[Rn], bon.[CustID], bon.[BonusID], bon.[Amount]
	INTO [BonusWalletPending_20220929_SIT]
	FROM bodb02.dbo.BonusWalletPending bon WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bon.custid

	--7. bodb02.dbo.CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID
	SELECT	cosell.[TransID], cosell.[MatchID], cosell.[Bettype], cosell.[Custid], cosell.[CashOutStatus], cosell.[Winlost], cosell.[PriceInfo], cosell.[CheckTime], 
			cosell.[CreateDate], cosell.[ChangeDate], cosell.[IsTest], cosell.[VirtualRate], cosell.[CashOutExtraInfo]
	INTO [CashOutSelling_20220929_SIT]
	FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = cosell.custid

	--8. bodb02.dbo.CustLimitBet_LIC
	SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
	INTO [CustLimitBet_LIC_20220929_SIT]
	FROM bodb02.dbo.CustLimitBet_LIC clb WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = clb.custid

	--9. bodb02.dbo.CustLimitBetHistory_LIC
	SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
	INTO [CustLimitBetHistory_LIC_20220929_SIT]
	FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = clbh.custid

	--10. bodb02.dbo.Task_bettrans14_IP2Country
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	INTO [Task_bettrans14_IP2Country_20220929_SIT]
	FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_20220929_SIT b WITH (NOLOCK) ON b.transid = tbip.transid
		
	--11. bodb02.dbo.Task_bettransLC14_IP2Country
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	INTO [Task_bettransLC14_IP2Country_20220929_SIT]
	FROM bodb02.dbo.Task_bettransLC14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransLC14_20220929_SIT b WITH (NOLOCK) ON b.transid = tbip.transid

	--12. bodb02.dbo.Task_bettransRNG14_IP2Country
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	INTO [Task_bettransRNG14_IP2Country_20220929_SIT]
	FROM bodb02.dbo.Task_bettransRNG14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransRnG14_20220929_SIT b WITH (NOLOCK) ON b.transid = tbip.transid

	/*******************Other tables - TW list**********************/

	--1.  bodb02.dbo.BalancePendingCreditGame
	--There is no index on custid for table BalancePendingCreditGame, has only an index on rn
	SELECT bc.[rn], bc.[custid], bc.[winlostdate], bc.[Balance], bc.[bettype], bc.[GameTypeID]
	INTO BalancePendingCreditGame_20220929_SIT
	FROM bodb02.dbo.BalancePendingCreditGame bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--2.  bodb02.dbo.BalancePendingDebitGame
	--There is no index on custid for table BalancePendingDebitGame, has only an index on rn
	SELECT bd.[rn], bd.[custid], bd.[winlostdate], bd.[Balance], bd.[bettype], bd.[GameTypeID]
	INTO BalancePendingDebitGame_20220929_SIT
	FROM bodb02.dbo.BalancePendingDebitGame bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--3.  bodb02.dbo.BalCreditCasinoPending
	--There is no index on custid for table BalCreditCasinoPending, has only an index on rn
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	INTO BalCreditCasinoPending_20220929_SIT
	FROM bodb02.dbo.BalCreditCasinoPending bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--4.  bodb02.dbo.BalCreditOthersPending
	--There is no index on custid for table BalCreditOthersPending, has only an index on rn
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	INTO BalCreditOthersPending_20220929_SIT
	FROM bodb02.dbo.BalCreditOthersPending bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--5.  bodb02.dbo.BalCreditSportsPending
	--There is no index on custid for table BalCreditSportsPending, has only an index on rn
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	INTO BalCreditSportsPending_20220929_SIT
	FROM bodb02.dbo.BalCreditSportsPending bc WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bc.custid

	--6.  bodb02.dbo.BalDebitCasinoPending
	--There is no index on custid for table BalDebitCasinoPending, has only an index on rn
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	INTO BalDebitCasinoPending_20220929_SIT
	FROM bodb02.dbo.BalDebitCasinoPending bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--7.  bodb02.dbo.BalDebitOthersPending
	--There is no index on custid for table BalDebitOthersPending, has only an index on rn
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	INTO BalDebitOthersPending_20220929_SIT
	FROM bodb02.dbo.BalDebitOthersPending bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--8.  bodb02.dbo.BalDebitSportsPending
	--There is no index on custid for table BalDebitSportsPending, has only an index on rn
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	INTO BalDebitSportsPending_20220929_SIT
	FROM bodb02.dbo.BalDebitSportsPending bd WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bd.custid

	--9. bodb02.dbo.Intg_GameRoundBetStake
	--There is no index on custid for table Intg_GameRoundBetStake
	SELECT igr.[VendorId], igr.[BetId], igr.[GameRound], igr.[GameType], igr.[BetChoice], igr.[CustId], igr.[Stake], igr.[CreateDate]
	INTO Intg_GameRoundBetStake_20220929_SIT
	FROM bodb02.dbo.Intg_GameRoundBetStake igr WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = igr.custid

	--10. bodb02.dbo.LastBetTime
	SELECT lb.[custid], lb.[transdate]
	INTO LastBetTime_20220929_SIT
	FROM bodb02.dbo.LastBetTime lb WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = lb.custid

	--11. bodb02.dbo.LastBetTime_Agent
	SELECT lba.[CustID], lba.[MatchID], lba.[BetType], lba.[CustomerClass], lba.[Platform], lba.[TransDate]
	INTO LastBetTime_Agent_20220929_SIT
	FROM bodb02.dbo.LastBetTime_Agent lba WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = lba.custid

	--12. bodb02.dbo.MarkedTransaction
	SELECT mt.[TransId], mt.[MatchId], mt.[CustId], mt.[bettype], mt.[UserId], mt.[CreatedDate], mt.[MarkType]
	INTO MarkedTransaction_20220929_SIT
	FROM bodb02.dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = mt.custid

	--13. bodb02.dbo.NetPositionCalculationLog
	SELECT	npcl.[NPCalculationLogID], npcl.[CustID], npcl.[MatchID], npcl.[Bettype], npcl.[AccumNPDebit], npcl.[AccumNPCredit], npcl.[NPAdjust], 
			npcl.[IsLatest], npcl.[CreatedDate], npcl.[ModifiedDate]
	INTO NetPositionCalculationLog_20220929_SIT
	FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = npcl.custid

	--14. bodb02.dbo.NetPositionTrans
	SELECT	npt.[TransID], npt.[CustID], npt.[MatchID], npt.[Bettype], npt.[Actual_stake], npt.[Payout1], npt.[Payoutx], npt.[Payout2], npt.[SyncStatus], 
			npt.[isSettled], npt.[CreatedDate], npt.[ModifiedDate]
	INTO NetPositionTrans_20220929_SIT
	FROM bodb02.dbo.NetPositionTrans npt WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = npt.custid

	--15. bodb02.dbo.Task_Cust_CheckBalance_Exception
	SELECT	tce.[custid], tce.[Remark]
	INTO Task_Cust_CheckBalance_Exception_20220929_SIT
	FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = tce.custid

	--16. bodb02.dbo.Task_Cust_BalanceProblem1
	--There is no index on custid for table Task_Cust_BalanceProblem1, has only an index on keyID
	SELECT tcb.[UserName], tcb.[custid], tcb.[DiffBalance], tcb.[LogDate], tcb.[IsFixed], tcb.[Remark]
	INTO Task_Cust_BalanceProblem1_20220929_SIT 
	FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = tcb.custid

	------------------------------------------------
	DROP TABLE #tmp_cust
	DROP TABLE #tmp_refno

	