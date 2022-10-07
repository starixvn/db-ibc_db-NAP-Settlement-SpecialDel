/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 2022926@Victoria
    Task: Data Migration - Real Licensee - PRO - ON SITEDB02
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: INSERT from the copy all data of the following tables [Redmineid:#178142] 
							 Bet tickets tables:
								1.  SiteDB02tmp.dbo.bettrans_20221012				2.  SiteDB02tmp.dbo.bettrans14_20221012
								3.  SiteDB02tmp.dbo.bettransG_20221012			4.  SiteDB02tmp.dbo.bettransG14_20221012
								5.  SiteDB02tmp.dbo.BettransInfo_20221012			6.  SiteDB02tmp.dbo.BettransInfo14_20221012
								7.  SiteDB02tmp.dbo.bettransLC_20221012			8.  SiteDB02tmp.dbo.bettransLC14_20221012
								9.  SiteDB02tmp.dbo.bettransm_20221012			10. SiteDB02tmp.dbo.bettransm14_20221012
								11. SiteDB02tmp.dbo.bettransRnG_20221012			12. SiteDB02tmp.dbo.bettransRnG14_20221012
								13. SiteDB02tmp.dbo.translog_20221012				14. SiteDB02tmp.dbo.translog14_20221012
								15. SiteDB02tmp.dbo.zzzbettrans_20221012			16. SiteDB02tmp.dbo.zzzbettransm_20221012
								17. SiteDB02tmp.dbo.Transfer_20221012				18. SiteDB02tmp.dbo.Transfer_Coll_20221012		19. SiteDB02tmp.dbo.TransferInfo_20221012
								20. SiteDB02tmp.dbo.BetParlayDetail_20221012		21. SiteDB02tmp.dbo.BetParlayResult_20221012
							 Tables balance:
								1.  SiteDB02tmp.dbo.BalCreditCasino_20221012
								2.  SiteDB02tmp.dbo.BalCreditOthers_20221012
								3.  SiteDB02tmp.dbo.BalCreditSports_20221012
								4.  SiteDB02tmp.dbo.BalCreditTransfer_20221012
								5.  SiteDB02tmp.dbo.BalDebitCasino_20221012
								6.  SiteDB02tmp.dbo.BalDebitOthers_20221012
								7.  SiteDB02tmp.dbo.BalDebitSports_20221012
								8.  SiteDB02tmp.dbo.BalDebitTransfer_20221012
								9.  SiteDB02tmp.dbo.BalNetPosition_20221012
								10. SiteDB02tmp.dbo.balanceTable_20221012
								11. SiteDB02tmp.dbo.balanceTable_tmp_20221012
								12. SiteDB02tmp.dbo.BalanceTable_tmp_cal_20221012
							 Other tables:
								1.  SiteDB02tmp.dbo.Bonus_sum_winloss_20221012
								2.  SiteDB02tmp.dbo.BonusAdjustmentTransfer_20221012
								3.  SiteDB02tmp.dbo.BonusTrans_20221012
								4.  SiteDB02tmp.dbo.BonusWalletCredit_20221012
								5.  SiteDB02tmp.dbo.BonusWalletDebit_20221012
								6.  SiteDB02tmp.dbo.BonusWalletPending_20221012
								7.  SiteDB02tmp.dbo.CashOutSelling_20221012
								8.  SiteDB02tmp.dbo.CustLimitBet_LIC_20221012
								9.  SiteDB02tmp.dbo.CustLimitBetHistory_LIC_20221012
								10. SiteDB02tmp.dbo.Task_bettrans14_IP2Country_20221012
								11. SiteDB02tmp.dbo.Task_bettransLC14_IP2Country_20221012
								12. SiteDB02tmp.dbo.Task_bettransRNG14_IP2Country_20221012
							 TW Tables list:
								1.  SiteDB02tmp.dbo.BalancePendingCreditGame_20221012
								2.  SiteDB02tmp.dbo.BalancePendingDebitGame_20221012
								3.  SiteDB02tmp.dbo.BalCreditCasinoPending_20221012
								4.  SiteDB02tmp.dbo.BalCreditOthersPending_20221012
								5.  SiteDB02tmp.dbo.BalCreditSportsPending_20221012
								6.  SiteDB02tmp.dbo.BalDebitCasinoPending_20221012
								7.  SiteDB02tmp.dbo.BalDebitOthersPending_20221012
								8.  SiteDB02tmp.dbo.BalDebitSportsPending_20221012
								9.  SiteDB02tmp.dbo.Intg_GameRoundBetStake_20221012
								10. SiteDB02tmp.dbo.LastBetTime_20221012
								11. SiteDB02tmp.dbo.LastBetTime_Agent_20221012
								12. SiteDB02tmp.dbo.MarkedTransaction_20221012
								13. SiteDB02tmp.dbo.NetPositionCalculationLog_20221012
								14. SiteDB02tmp.dbo.NetPositionTrans_20221012
								15. SiteDB02tmp.dbo.Task_Cust_CheckBalance_Exception_20221012
								16. SiteDB02tmp.dbo.Task_Cust_BalanceProblem1_20221012
*/

	USE bodb02
	GO
	---------------------hey pontus dep trai -> run on sitedb02 nhe------------------------------------
	------------------------------------------------
	/*******************Bet Tickets Tables**********************/
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
	FROM SiteDB02tmp.dbo.bettrans_20221012 b WITH (NOLOCK)

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
	FROM SiteDB02tmp.dbo.bettrans14_20221012 b WITH (NOLOCK)

	--bettransG
	INSERT INTO dbo.bettransG (	[transid], [custid], [transdate], [oddsid], [odds], [stake], [status], [winlost], [betteam], [creator], [refno], [winlostdate], [betfrom], 
								[checktime], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
								[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], 
								[sdiscount], [scomm], [statusID], [virtualrate], [SiteID], [transdesc], [BetID3rd], [epositiontaking], [actual_stake], [netstake], 
								[SiteDBGroupID], [RepUpdateTime])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
			b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
			b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
			b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
			b.[SiteDBGroupID] , b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.bettransG_20221012 b WITH (NOLOCK)

	--bettransG14
	INSERT INTO dbo.bettransG14 ([transid], [custid], [transdate], [oddsid], [odds], [stake], [status], [winlost], [betteam], [creator], [refno], [winlostdate], [betfrom], 
								[checktime], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
								[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], 
								[sdiscount], [scomm], [statusID], [virtualrate], [SiteID], [transdesc], [BetID3rd], [epositiontaking], [actual_stake], [netstake], 
								[SiteDBGroupID])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
			b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
			b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
			b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
			b.[SiteDBGroupID]
	FROM SiteDB02tmp.dbo.bettransG14_20221012 b WITH (NOLOCK)

	--BettransInfo
	INSERT INTO dbo.BettransInfo ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [RepUpdateTime], [ThirdTransID])
	SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[RepUpdateTime], binfo.[ThirdTransID]
	FROM SiteDB02tmp.dbo.BettransInfo_20221012 binfo WITH (NOLOCK)

	--BettransInfo14
	INSERT INTO dbo.BettransInfo14 ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [ThirdTransID])
	SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[ThirdTransID]
	FROM SiteDB02tmp.dbo.BettransInfo14_20221012 binfo WITH (NOLOCK)

	--bettransLC
	INSERT INTO dbo.bettransLC ([transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
								[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], 
								[scomm], [Transdate3rd], [NetStake], [SiteID], [epositiontaking], [SiteDBGroupID], [RepUpdateTime])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
			b.[scomm], b.[Transdate3rd], b.[NetStake], b.[SiteID], b.[epositiontaking], b.[SiteDBGroupID] , b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.bettransLC_20221012 b WITH (NOLOCK)

	--bettransLC14
	INSERT INTO dbo.bettransLC14	([transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
									[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
									[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
									[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], 
									[scomm], [Transdate3rd], [NetStake], [epositiontaking], [SiteID], [SiteDBGroupID])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
			b.[scomm], b.[Transdate3rd], b.[NetStake], b.[epositiontaking], b.[SiteID], b.[SiteDBGroupID]
	FROM SiteDB02tmp.dbo.bettransLC14_20221012 b WITH (NOLOCK)

	--bettransRnG
	INSERT INTO dbo.bettransRnG ([transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], 
								[vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], 
								[Transdate3rd], [SiteID], [Additional], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd], 
								[epositiontaking], [SiteDBGroupID], [RepUpdateTime])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
			b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], b.[scomm], 
			b.[Transdate3rd], b.[SiteID], b.[Additional], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
			b.[epositiontaking], b.[SiteDBGroupID], b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.bettransRnG_20221012 b WITH (NOLOCK)

	--bettransRnG14
	INSERT INTO dbo.bettransRnG14 ([transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
									[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
									[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
									[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], 
									[acomm], [scomm], [Transdate3rd], [Additional], [Siteid], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd], 
									[epositiontaking], [SiteDBGroupID])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], 
			b.[acomm], b.[scomm], b.[Transdate3rd], b.[Additional], b.[Siteid], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
			b.[epositiontaking], b.[SiteDBGroupID]
	FROM SiteDB02tmp.dbo.bettransRnG14_20221012 b WITH (NOLOCK)

	--translog
	INSERT INTO dbo.translog	([translogid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
								[gameID], [eventID], [vendorID], [GameId3rd], [TranId3rd], [custom1], [custom2], [custom3], [LiveIndicator], [checkCount], [SiteId], 
								[epositiontaking], [SiteDBGroupID], [LicenseeTransId], [RepUpdateTime])
	SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], b.[checkCount], b.[SiteId], 
			b.[epositiontaking], b.[SiteDBGroupID], b.[LicenseeTransId], b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.translog_20221012 b WITH (NOLOCK)

	--translog14
	INSERT INTO dbo.translog14	([translogid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], 
								[eventID], [vendorID], [GameId3rd], [TranId3rd], [custom1], [custom2], [custom3], [LiveIndicator], [SiteDBGroupID])
	SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
			b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], b.[SiteDBGroupID]
	FROM SiteDB02tmp.dbo.translog14_20221012 b WITH (NOLOCK)
	
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
	FROM SiteDB02tmp.dbo.bettransm_20221012 bm WITH (NOLOCK)

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
	FROM SiteDB02tmp.dbo.bettransm14_20221012 bm WITH (NOLOCK)
	
   --BetParlayDetail
   INSERT INTO dbo.BetParlayDetail ([RefNo], [Serial], [transid], [winlostdate], [statuswinlost], [statusid], [matchid], [bettype], [stake], [odds], [betteam], [hdp1], [hdp2], 
									[livehomescore], [liveawayscore], [liveindicator], [betcheck], [transdesc])
	SELECT	bpd.[RefNo], bpd.[Serial], bpd.[transid], bpd.[winlostdate], bpd.[statuswinlost], bpd.[statusid], bpd.[matchid], bpd.[bettype], bpd.[stake], bpd.[odds], bpd.[betteam], bpd.[hdp1], bpd.[hdp2], 
			bpd.[livehomescore], bpd.[liveawayscore], bpd.[liveindicator], bpd.[betcheck], bpd.[transdesc]
	FROM SiteDB02tmp.dbo.BetParlayDetail_20221012 bpd WITH (NOLOCK)

	--BetParlayResult
	INSERT INTO dbo.BetParlayResult ([RefNo], [Serial], [transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm])
	SELECT	bpr.[RefNo], bpr.[Serial], bpr.[transid], bpr.[winlostdate], bpr.[statusid], bpr.[stake], bpr.[Odds], bpr.[mOdds], bpr.[winlost], bpr.[awinlost], bpr.[mwinlost], bpr.[swinlost], bpr.[playercomm], bpr.[comm], bpr.[acomm], bpr.[scomm]
	FROM SiteDB02tmp.dbo.BetParlayResult_20221012 bpr WITH (NOLOCK)

	--zzzbettrans
	--SET IDENTITY_INSERT zzzbettrans ON

	INSERT INTO dbo.zzzbettrans	([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [matchid], [bettype], 
								[VoidingHistoryId], [RepUpdateTime], [SiteDBGroupID])
	SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
			z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
			z.[VoidingHistoryId], z.[RepUpdateTime], z.[SiteDBGroupID]
	FROM SiteDB02tmp.dbo.zzzbettrans_20221012 z WITH (NOLOCK)

	--SET IDENTITY_INSERT zzzbettrans OFF	

	--zzzbettransm
	--SET IDENTITY_INSERT zzzbettransm ON

	INSERT INTO dbo.zzzbettransm (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
									[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [matchid], [bettype], 
									[VoidingHistoryId], [RepUpdateTime], [SiteDBGroupID])
	SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
			z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
			z.[VoidingHistoryId], z.[RepUpdateTime], z.[SiteDBGroupID]
	FROM SiteDB02tmp.dbo.zzzbettransm_20221012 z WITH (NOLOCK)

	--SET IDENTITY_INSERT zzzbettransm OFF

	--Transfer
	INSERT INTO dbo.Transfer	([TransId], [CustId], [TransDate], [WinlostDate], [Bettype], [Stake], [Actual_Stake], [Winlost], [AWinlost], [MWinlost], [SWinlost], [PlayerComm], 
								[Comm], [AComm], [SComm], [StatusId], [RefNo], [TransDesc], [Recommend], [MRecommend], [SRecommend], [Username], [Currency], [CurrencyName], 
								[ActualRate], [Creator], [Balance], [IP], [CheckTime], [SerialNo], [RepUpdateTime])
	SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
			b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
			b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.Transfer_20221012 b WITH (NOLOCK)

	
	--Transfer_Coll
	INSERT INTO dbo.Transfer_Coll	([CustId], [WinlostDate], [TransDate], [Bettype], [Debit], [Credit], [Currency], [ActualRate], [TransID], [RefNo], [Username], 
									[Recommend], [MRecommend], [SRecommend], [Creator], [TransDesc], [IP], [RepUpdateTime])
	SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
			b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.Transfer_Coll_20221012 b WITH (NOLOCK)

	--TransferInfo
	INSERT INTO dbo.TransferInfo	([TransId], [APositiontaking], [MPositiontaking], [SPositiontaking], [EPositiontaking], [PlayerDiscount], [Discount], [ADiscount], [SDiscount], 
									[WalletType], [BonusID], [Amount], [CheckerId], [CheckerName], [IsCollection], [IsDel], [RepUpdateTime])
	SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
			b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
	FROM SiteDB02tmp.dbo.TransferInfo_20221012 b WITH (NOLOCK)

	/********************Tables Balance*************************/
	--1. BalCreditCasino
	INSERT INTO [dbo].[BalCreditCasino] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditCasino_20221012 bal WITH (NOLOCK)

	--2. BalCreditOthers
	INSERT INTO [dbo].[BalCreditOthers] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditOthers_20221012 bal WITH (NOLOCK)

	--3. BalCreditSports
	INSERT INTO [dbo].[BalCreditSports] ([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditSports_20221012 bal WITH (NOLOCK)

	--4. BalCreditTransfer
	INSERT INTO  [dbo].[BalCreditTransfer]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditTransfer_20221012 bal WITH (NOLOCK)

	--5. BalDebitCasino
	INSERT INTO  [dbo].[BalDebitCasino]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitCasino_20221012 bal WITH (NOLOCK)

	--6. BalDebitOthers
	INSERT INTO [dbo].[BalDebitOthers]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitOthers_20221012 bal WITH (NOLOCK)

	--7. BalDebitSports
	INSERT INTO [dbo].[BalDebitSports]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitSports_20221012 bal WITH (NOLOCK)

	--8. BalDebitTransfer
	INSERT INTO [dbo].[BalDebitTransfer]([custid], [Balance])
	SELECT bal.[custid], bal.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitTransfer_20221012 bal WITH (NOLOCK)

	--9. BalNetPosition
	INSERT INTO [dbo].[BalNetPosition]([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
	SELECT bal.[CustID], bal.[MatchID], bal.[Bettype], bal.[Debit], bal.[Credit], bal.[CreatedDate], bal.[ModifiedDate]
	FROM SiteDB02tmp.dbo.BalNetPosition_20221012 bal WITH (NOLOCK)

	--10. balanceTable
	--There is no index for table balanceTable
	INSERT INTO [dbo].[balanceTable](	[custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
										[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
	SELECT  bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
			bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
	FROM SiteDB02tmp.dbo.balanceTable_20221012 bal WITH (NOLOCK)

	--11. balanceTable_tmp
	INSERT INTO [dbo].[balanceTable_tmp](	[winlostdate], [custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
											[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
	SELECT  bal.[winlostdate], bal.[custid], bal.[roleid], bal.[amount], bal.[awinlost], bal.[mwinlost], bal.[swinlost], bal.[playercomm], bal.[comm], bal.[acomm], bal.[scomm], bal.[recommend], bal.[mrecommend], 
			bal.[srecommend], bal.[currency], bal.[UserName], bal.[CurrencyName], bal.[actualrate], bal.[TicketCount], bal.[balTicketCount]
	FROM SiteDB02tmp.dbo.balanceTable_tmp_20221012 bal WITH (NOLOCK)

	--12. BalanceTable_tmp_cal
	--There is no index for table balanceTable
	INSERT INTO [dbo].[BalanceTable_tmp_cal] (	[dow], [roleid], [custid], [recommend], [mrecommend], [srecommend], 
												[amt1], [tcnt1], [amt2], [tcnt2], [amt3], [tcnt3], [amt4], [tcnt4])
	SELECT	bal.[dow], bal.[roleid], bal.[custid], bal.[recommend], bal.[mrecommend], bal.[srecommend], 
			bal.[amt1], bal.[tcnt1], bal.[amt2], bal.[tcnt2], bal.[amt3], bal.[tcnt3], bal.[amt4], bal.[tcnt4]
	FROM SiteDB02tmp.dbo.BalanceTable_tmp_cal_20221012 bal WITH (NOLOCK)

	/*******************Other Tables**********************/

	--1. Bonus_sum_winloss
	INSERT INTO [dbo].[Bonus_sum_winloss] ([CustId], [BonusId], [winlostdate], [Amount])
	SELECT bon.[CustId], bon.[BonusId], bon.[winlostdate], bon.[Amount]
	FROM SiteDB02tmp.dbo.Bonus_sum_winloss_20221012 bon WITH (NOLOCK)

	--2. BonusAdjustmentTransfer
	-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
	SET IDENTITY_INSERT BonusAdjustmentTransfer ON

	INSERT INTO [dbo].[BonusAdjustmentTransfer] ([ExecID], [LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
	SELECT bon.[ExecID], bon.[LogDate], bon.[ExecDate], bon.[CustID], bon.[MatchID], bon.[BonusID], bon.[StatusID], bon.[Amount], bon.[isTransferred]
	FROM SiteDB02tmp.dbo.BonusAdjustmentTransfer_20221012 bon WITH (NOLOCK)

	SET IDENTITY_INSERT BonusAdjustmentTransfer OFF

	--3. BonusTrans
	SET IDENTITY_INSERT BonusTrans ON

	INSERT INTO [dbo].[BonusTrans] ([BonusTransId], [CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
									[PaymentDate], [IsComplained])
	SELECT  bon.[BonusTransId], bon.[CustID], bon.[Recommend], bon.[Mrecommend], bon.[Srecommend], bon.[Amount], bon.[StatusId], bon.[Creator], bon.[CreatedDate], 
			bon.[PaymentDate], bon.[IsComplained]
	FROM SiteDB02tmp.dbo.BonusTrans_20221012 bon WITH (NOLOCK)

	SET IDENTITY_INSERT BonusTrans OFF

	--4. BonusWalletCredit
	INSERT INTO [dbo].[BonusWalletCredit] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[StatusID], bon.[initBonus], bon.[LockedAmt], bon.[Amount]
	FROM SiteDB02tmp.dbo.BonusWalletCredit_20221012 bon WITH (NOLOCK)

	--5. BonusWalletDebit
	INSERT INTO [dbo].[BonusWalletDebit] ([CustID], [BonusID], [Amount])
	SELECT  bon.[CustID], bon.[BonusID], bon.[Amount]
	FROM SiteDB02tmp.dbo.BonusWalletDebit_20221012 bon WITH (NOLOCK)

	--6. BonusWalletPending
	-- There is no index on custid for table BonusWalletPending, has only an index on Rn
	SET IDENTITY_INSERT BonusWalletPending ON

	INSERT INTO [dbo].[BonusWalletPending] ([Rn], [CustID], [BonusID], [Amount])
	SELECT  bon.[Rn], bon.[CustID], bon.[BonusID], bon.[Amount]
	FROM SiteDB02tmp.dbo.BonusWalletPending_20221012 bon WITH (NOLOCK)

	SET IDENTITY_INSERT BonusWalletPending OFF

	--7. CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID
	INSERT INTO [dbo].[CashOutSelling] ([TransID], [MatchID], [Bettype], [Custid], [CashOutStatus], [Winlost], [PriceInfo], [CheckTime], 
										[CreateDate], [ChangeDate], [IsTest], [VirtualRate], [CashOutExtraInfo])
	SELECT	cosell.[TransID], cosell.[MatchID], cosell.[Bettype], cosell.[Custid], cosell.[CashOutStatus], cosell.[Winlost], cosell.[PriceInfo], cosell.[CheckTime], 
			cosell.[CreateDate], cosell.[ChangeDate], cosell.[IsTest], cosell.[VirtualRate], cosell.[CashOutExtraInfo]
	FROM SiteDB02tmp.dbo.CashOutSelling_20221012 cosell WITH (NOLOCK)

	--8. CustLimitBet_LIC
	INSERT INTO [dbo].[CustLimitBet_LIC] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
	SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
	FROM SiteDB02tmp.dbo.CustLimitBet_LIC_20221012 clb WITH (NOLOCK)

	--9. CustLimitBetHistory_LIC
	INSERT INTO [dbo].[CustLimitBetHistory_LIC] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
	SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
	FROM SiteDB02tmp.dbo.CustLimitBetHistory_LIC_20221012 clbh WITH (NOLOCK)

	--10. dbo.Task_bettrans14_IP2Country
	INSERT INTO [dbo].[Task_bettrans14_IP2Country] ([transid], [winlostdate], [CountryShort], [IPArchive])
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	FROM SiteDB02tmp.dbo.Task_bettrans14_IP2Country_20221012 tbip WITH (NOLOCK)
		
	--11. dbo.Task_bettransLC14_IP2Country
	INSERT INTO [dbo].[Task_bettransLC14_IP2Country] ([transid], [winlostdate], [CountryShort], [IPArchive])
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	FROM SiteDB02tmp.dbo.Task_bettransLC14_IP2Country_20221012 tbip WITH (NOLOCK)

	--12. dbo.Task_bettransRNG14_IP2Country
	INSERT INTO [dbo].[Task_bettransRNG14_IP2Country] ([transid], [winlostdate], [CountryShort], [IPArchive])
	SELECT	tbip.[transid], tbip.[winlostdate], tbip.[CountryShort], tbip.[IPArchive]
	FROM SiteDB02tmp.dbo.Task_bettransRNG14_IP2Country_20221012 tbip WITH (NOLOCK)

	/*******************Other tables - TW list**********************/

	--1.  dbo.BalancePendingCreditGame
	--There is no index on custid for table BalancePendingCreditGame, has only an index on rn
	SET IDENTITY_INSERT BalancePendingCreditGame ON

	INSERT INTO [dbo].[BalancePendingCreditGame] ([rn], [custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	SELECT bc.[rn], bc.[custid], bc.[winlostdate], bc.[Balance], bc.[bettype], bc.[GameTypeID]
	FROM SiteDB02tmp.dbo.BalancePendingCreditGame_20221012 bc WITH (NOLOCK)

	SET IDENTITY_INSERT BalancePendingCreditGame OFF

	--2.  dbo.BalancePendingDebitGame
	--There is no index on custid for table BalancePendingDebitGame, has only an index on rn
	SET IDENTITY_INSERT BalancePendingDebitGame ON

	INSERT INTO [dbo].[BalancePendingDebitGame] ([rn], [custid], [winlostdate], [Balance], [bettype], [GameTypeID])
	SELECT bd.[rn], bd.[custid], bd.[winlostdate], bd.[Balance], bd.[bettype], bd.[GameTypeID]
	FROM SiteDB02tmp.dbo.BalancePendingDebitGame_20221012 bd WITH (NOLOCK)

	SET IDENTITY_INSERT BalancePendingDebitGame OFF

	--3.  dbo.BalCreditCasinoPending
	--There is no index on custid for table BalCreditCasinoPending, has only an index on rn
	SET IDENTITY_INSERT BalCreditCasinoPending ON

	INSERT INTO [dbo].[BalCreditCasinoPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditCasinoPending_20221012 bc WITH (NOLOCK)

	SET IDENTITY_INSERT BalCreditCasinoPending OFF

	--4.  dbo.BalCreditOthersPending
	--There is no index on custid for table BalCreditOthersPending, has only an index on rn
	SET IDENTITY_INSERT BalCreditOthersPending ON

	INSERT INTO [dbo].[BalCreditOthersPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditOthersPending_20221012 bc WITH (NOLOCK)

	SET IDENTITY_INSERT BalCreditOthersPending OFF

	--5.  dbo.BalCreditSportsPending
	--There is no index on custid for table BalCreditSportsPending, has only an index on rn
	SET IDENTITY_INSERT BalCreditSportsPending ON

	INSERT INTO [dbo].[BalCreditSportsPending] ([rn], [custid], [Balance])
	SELECT bc.[rn], bc.[custid], bc.[Balance]
	FROM SiteDB02tmp.dbo.BalCreditSportsPending_20221012 bc WITH (NOLOCK)

	SET IDENTITY_INSERT BalCreditSportsPending OFF

	--6.  dbo.BalDebitCasinoPending
	--There is no index on custid for table BalDebitCasinoPending, has only an index on rn
	SET IDENTITY_INSERT BalDebitCasinoPending ON

	INSERT INTO [dbo].[BalDebitCasinoPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitCasinoPending_20221012 bd WITH (NOLOCK)

	SET IDENTITY_INSERT BalDebitCasinoPending OFF

	--7.  dbo.BalDebitOthersPending
	--There is no index on custid for table BalDebitOthersPending, has only an index on rn
	SET IDENTITY_INSERT BalDebitOthersPending ON

	INSERT INTO [dbo].[BalDebitOthersPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitOthersPending_20221012 bd WITH (NOLOCK)

	SET IDENTITY_INSERT BalDebitOthersPending OFF

	--8.  dbo.BalDebitSportsPending
	--There is no index on custid for table BalDebitSportsPending, has only an index on rn
	SET IDENTITY_INSERT BalDebitSportsPending ON

	INSERT INTO [dbo].[BalDebitSportsPending] ([rn], [custid], [Balance])
	SELECT bd.[rn], bd.[custid], bd.[Balance]
	FROM SiteDB02tmp.dbo.BalDebitSportsPending_20221012 bd WITH (NOLOCK)

	SET IDENTITY_INSERT BalDebitSportsPending OFF

	--9. dbo.Intg_GameRoundBetStake
	--There is no index on custid for table Intg_GameRoundBetStake
	INSERT INTO [dbo].[Intg_GameRoundBetStake] ([VendorId], [BetId], [GameRound], [GameType], [BetChoice], [CustId], [Stake], [CreateDate])
	SELECT igr.[VendorId], igr.[BetId], igr.[GameRound], igr.[GameType], igr.[BetChoice], igr.[CustId], igr.[Stake], igr.[CreateDate]
	FROM SiteDB02tmp.dbo.Intg_GameRoundBetStake_20221012 igr WITH (NOLOCK)

	--10. dbo.LastBetTime
	INSERT INTO [dbo].[LastBetTime] ([custid], [transdate])
	SELECT lb.[custid], lb.[transdate]
	FROM SiteDB02tmp.dbo.LastBetTime_20221012 lb WITH (NOLOCK)

	--11. dbo.LastBetTime_Agent
	INSERT INTO [dbo].[LastBetTime_Agent] ([CustID], [MatchID], [BetType], [CustomerClass], [Platform], [TransDate])
	SELECT lba.[CustID], lba.[MatchID], lba.[BetType], lba.[CustomerClass], lba.[Platform], lba.[TransDate]
	FROM SiteDB02tmp.dbo.LastBetTime_Agent_20221012 lba WITH (NOLOCK)

	--12. dbo.MarkedTransaction
	INSERT INTO [dbo].[MarkedTransaction] ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
	SELECT mt.[TransId], mt.[MatchId], mt.[CustId], mt.[bettype], mt.[UserId], mt.[CreatedDate], mt.[MarkType]
	FROM SiteDB02tmp.dbo.MarkedTransaction_20221012 mt WITH (NOLOCK)

	--13. dbo.NetPositionCalculationLog
	SET IDENTITY_INSERT NetPositionCalculationLog ON

	INSERT INTO [dbo].[NetPositionCalculationLog] (	[NPCalculationLogID], [CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], 
													[IsLatest], [CreatedDate], [ModifiedDate])
	SELECT	npcl.[NPCalculationLogID], npcl.[CustID], npcl.[MatchID], npcl.[Bettype], npcl.[AccumNPDebit], npcl.[AccumNPCredit], npcl.[NPAdjust], 
			npcl.[IsLatest], npcl.[CreatedDate], npcl.[ModifiedDate]
	FROM SiteDB02tmp.dbo.NetPositionCalculationLog_20221012 npcl WITH (NOLOCK)

	SET IDENTITY_INSERT NetPositionCalculationLog OFF

	--14. dbo.NetPositionTrans
	INSERT INTO [dbo].[NetPositionTrans] (	[TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], 
											[isSettled], [CreatedDate], [ModifiedDate])
	SELECT	npt.[TransID], npt.[CustID], npt.[MatchID], npt.[Bettype], npt.[Actual_stake], npt.[Payout1], npt.[Payoutx], npt.[Payout2], npt.[SyncStatus], 
			npt.[isSettled], npt.[CreatedDate], npt.[ModifiedDate]
	FROM SiteDB02tmp.dbo.NetPositionTrans_20221012 npt WITH (NOLOCK)

	--15. dbo.Task_Cust_CheckBalance_Exception
	INSERT INTO [dbo].[Task_Cust_CheckBalance_Exception] ([custid], [Remark])
	SELECT	tce.[custid], tce.[Remark]
	FROM SiteDB02tmp.dbo.Task_Cust_CheckBalance_Exception_20221012 tce WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT TOP (1) 1 FROM Task_Cust_CheckBalance_Exception a WITH (NOLOCK) WHERE a.custid = tce.custid)
	--16. bodb02.dbo.Task_Cust_BalanceProblem1
	--There is no index on custid for table Task_Cust_BalanceProblem1, has only an index on keyID
	--SET IDENTITY_INSERT Task_Cust_BalanceProblem1 ON

	INSERT INTO [dbo].[Task_Cust_BalanceProblem1] ([UserName], [custid], [DiffBalance], [LogDate], [IsFixed], [Remark])
	SELECT tcb.[UserName], tcb.[custid], tcb.[DiffBalance], tcb.[LogDate], tcb.[IsFixed], tcb.[Remark]
	FROM SiteDB02tmp.dbo.Task_Cust_BalanceProblem1_20221012 tcb WITH (NOLOCK)

	--SET IDENTITY_INSERT Task_Cust_BalanceProblem1 OFF