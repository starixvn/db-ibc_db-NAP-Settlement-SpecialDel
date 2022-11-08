/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB01tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#180033] 
							 All but not (bettrans, transfer, bettransm, bettrans14, bettransm14, BetParlayDetail)
								
*/

USE SiteDB01tmp
GO

------------------------------------------------
/*****************Copy Stucture of Tables************************/
SELECT TOP 1 *
INTO bettransG_delete
FROM bodb02.dbo.bettransG b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransG14_delete
FROM bodb02.dbo.bettransG14 b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransLC_delete
FROM bodb02.dbo.bettransLC b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransLC14_delete
FROM bodb02.dbo.bettransLC14 b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransRnG_delete
FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransRnG14_delete
FROM bodb02.dbo.bettransRnG14 b WITH (NOLOCK)

SELECT TOP 1 *
INTO translog_delete
FROM bodb02.dbo.translog b WITH (NOLOCK)

SELECT TOP 1 *
INTO translog14_delete
FROM bodb02.dbo.translog14 b WITH (NOLOCK)

SELECT TOP 1 *
INTO BetParlayResult_delete
FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)

SELECT TOP 1 *
INTO zzzbettrans_delete
FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)

SELECT TOP 1 *
INTO zzzbettransm_delete
FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)

--------------------------------------------

SELECT TOP 1 *
INTO BalCreditCasino_delete
FROM bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditOthers_delete
FROM bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditSports_delete
FROM bodb02.dbo.BalCreditSports bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditTransfer_delete
FROM bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitCasino_delete
FROM bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitOthers_delete
FROM bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitSports_delete 
FROM bodb02.dbo.BalDebitSports bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitTransfer_delete
FROM bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalNetPosition_delete
FROM bodb02.dbo.BalNetPosition bal WITH (NOLOCK)

SELECT TOP 1 *
INTO balanceTable_delete
FROM bodb02.dbo.balanceTable bal WITH (NOLOCK)

SELECT TOP 1 *
INTO balanceTable_tmp_delete
FROM bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)

SELECT TOP 1 *
INTO BalanceTable_tmp_cal_delete
FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)

----------------------------------------------------------

SELECT TOP 1 *
INTO Bonus_sum_winloss_delete
FROM bodb02.dbo.Bonus_sum_winloss bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusAdjustmentTransfer_delete
FROM bodb02.dbo.BonusAdjustmentTransfer bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusTrans_delete
FROM bodb02.dbo.BonusTrans bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusWalletCredit_delete
FROM bodb02.dbo.BonusWalletCredit bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusWalletDebit_delete
FROM bodb02.dbo.BonusWalletDebit bon WITH (NOLOCK)

SELECT TOP 1 *
INTO BonusWalletPending_delete
FROM bodb02.dbo.BonusWalletPending bon WITH (NOLOCK)

SELECT TOP 1 *
INTO CashOutSelling_delete
FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)

SELECT TOP 1 *
INTO CustLimitBet_LIC_delete
FROM bodb02.dbo.CustLimitBet_LIC clb WITH (NOLOCK)

SELECT TOP 1 * 
INTO CustLimitBetHistory_LIC_delete
FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (NOLOCK)


SELECT TOP 1 *
INTO Task_bettransLC14_IP2Country_delete
FROM bodb02.dbo.Task_bettransLC14_IP2Country tbip WITH (NOLOCK)

SELECT TOP 1 *
INTO Task_bettransRNG14_IP2Country_delete
FROM bodb02.dbo.Task_bettransRNG14_IP2Country tbip WITH (NOLOCK)

----------------------------------------------------------------

SELECT TOP 1 * 
INTO BalancePendingCreditGame_delete
FROM bodb02.dbo.BalancePendingCreditGame bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalancePendingDebitGame_delete
FROM bodb02.dbo.BalancePendingDebitGame bd WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditCasinoPending_delete
FROM bodb02.dbo.BalCreditCasinoPending bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditOthersPending_delete
FROM bodb02.dbo.BalCreditOthersPending bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalCreditSportsPending_delete
FROM bodb02.dbo.BalCreditSportsPending bc WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitCasinoPending_delete
FROM bodb02.dbo.BalDebitCasinoPending bd WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitOthersPending_delete
FROM bodb02.dbo.BalDebitOthersPending bd WITH (NOLOCK)

SELECT TOP 1 *
INTO BalDebitSportsPending_delete
FROM bodb02.dbo.BalDebitSportsPending bd WITH (NOLOCK)

SELECT TOP 1 *
INTO Intg_GameRoundBetStake_delete
FROM bodb02.dbo.Intg_GameRoundBetStake igr WITH (NOLOCK)

SELECT TOP 1 *
INTO LastBetTime_delete
FROM bodb02.dbo.LastBetTime lb WITH (NOLOCK)

SELECT TOP 1 *
INTO LastBetTime_Agent_delete
FROM bodb02.dbo.LastBetTime_Agent lba WITH (NOLOCK)

SELECT TOP 1 *
INTO MarkedTransaction_delete
FROM bodb02.dbo.MarkedTransaction mt WITH (NOLOCK)

SELECT TOP 1 *
INTO NetPositionCalculationLog_delete
FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)

SELECT TOP 1 *
INTO NetPositionTrans_delete
FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)

SELECT TOP 1 *
INTO Task_Cust_CheckBalance_Exception_delete
FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)

SELECT TOP 1 *
INTO Task_Cust_BalanceProblem1_delete
FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)

/*****************Truncate Table************************/
TRUNCATE TABLE bettransG_delete
TRUNCATE TABLE bettransG14_delete
TRUNCATE TABLE bettransLC_delete
TRUNCATE TABLE bettransLC14_delete
TRUNCATE TABLE bettransRnG_delete
TRUNCATE TABLE bettransRnG14_delete
TRUNCATE TABLE translog_delete
TRUNCATE TABLE translog14_delete
TRUNCATE TABLE zzzbettrans_delete
TRUNCATE TABLE zzzbettransm_delete
------------------------------------------------------
TRUNCATE TABLE BalCreditCasino_delete
TRUNCATE TABLE BalCreditOthers_delete
TRUNCATE TABLE BalCreditSports_delete
TRUNCATE TABLE BalCreditTransfer_delete
TRUNCATE TABLE BalDebitCasino_delete
TRUNCATE TABLE BalDebitOthers_delete
TRUNCATE TABLE BalDebitSports_delete
TRUNCATE TABLE BalDebitTransfer_delete
TRUNCATE TABLE BalNetPosition_delete
TRUNCATE TABLE balanceTable_delete
TRUNCATE TABLE balanceTable_tmp_delete
TRUNCATE TABLE BalanceTable_tmp_cal_delete
------------------------------------------------------
TRUNCATE TABLE Bonus_sum_winloss_delete
TRUNCATE TABLE BonusAdjustmentTransfer_delete
TRUNCATE TABLE BonusTrans_delete
TRUNCATE TABLE BonusWalletCredit_delete
TRUNCATE TABLE BonusWalletDebit_delete
TRUNCATE TABLE BonusWalletPending_delete
TRUNCATE TABLE CashOutSelling_delete
TRUNCATE TABLE CustLimitBet_LIC_delete
TRUNCATE TABLE CustLimitBetHistory_LIC_delete
TRUNCATE TABLE Task_bettransLC14_IP2Country_delete
TRUNCATE TABLE Task_bettransRNG14_IP2Country_delete
------------------------------------------------------
TRUNCATE TABLE BalancePendingCreditGame_delete
TRUNCATE TABLE BalancePendingDebitGame_delete
TRUNCATE TABLE BalCreditCasinoPending_delete
TRUNCATE TABLE BalCreditOthersPending_delete
TRUNCATE TABLE BalCreditSportsPending_delete
TRUNCATE TABLE BalDebitCasinoPending_delete
TRUNCATE TABLE BalDebitOthersPending_delete
TRUNCATE TABLE BalDebitSportsPending_delete
TRUNCATE TABLE Intg_GameRoundBetStake_delete
TRUNCATE TABLE LastBetTime_delete
TRUNCATE TABLE LastBetTime_Agent_delete
TRUNCATE TABLE MarkedTransaction_delete
TRUNCATE TABLE NetPositionCalculationLog_delete
TRUNCATE TABLE NetPositionTrans_delete
TRUNCATE TABLE Task_Cust_CheckBalance_Exception_delete
TRUNCATE TABLE Task_Cust_BalanceProblem1_delete


/*******************BACKUP & DELETE Data**********************/
/*******************Bet Ticket tables**********************/
--bodb02.dbo.bettransG
DELETE b
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[winlostdate], deleted.[betfrom], 
		deleted.[checktime], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[awinlost], deleted.[mwinlost], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], 
		deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[actualrate], deleted.[matchid], deleted.[matchdate], deleted.[statuswinlost], deleted.[ruben], deleted.[bettype], deleted.[spositiontaking], deleted.[swinlost], 
		deleted.[sdiscount], deleted.[scomm], deleted.[statusID], deleted.[virtualrate], deleted.[SiteID], deleted.[transdesc], deleted.[BetID3rd], deleted.[epositiontaking], deleted.[actual_stake], deleted.[netstake], 
		deleted.[SiteDBGroupID], deleted.[RepUpdateTime]
INTO bettransG_delete (	[transid], [custid], [transdate], [oddsid], [odds], [stake], [status], [winlost], [betteam], [creator], [refno], [winlostdate], [betfrom], 
							[checktime], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
							[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], 
							[sdiscount], [scomm], [statusID], [virtualrate], [SiteID], [transdesc], [BetID3rd], [epositiontaking], [actual_stake], [netstake], 
							[SiteDBGroupID], [RepUpdateTime])
FROM bodb02.dbo.bettransG b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.bettransG14
DELETE b
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[winlostdate], deleted.[betfrom], 
		deleted.[checktime], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[awinlost], deleted.[mwinlost], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], 
		deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[actualrate], deleted.[matchid], deleted.[matchdate], deleted.[statuswinlost], deleted.[ruben], deleted.[bettype], deleted.[spositiontaking], deleted.[swinlost], 
		deleted.[sdiscount], deleted.[scomm], deleted.[statusID], deleted.[virtualrate], deleted.[SiteID], deleted.[transdesc], deleted.[BetID3rd], deleted.[epositiontaking], deleted.[actual_stake], deleted.[netstake], 
		deleted.[SiteDBGroupID]
INTO bettransG14_delete (	[transid], [custid], [transdate], [oddsid], [odds], [stake], [status], [winlost], [betteam], [creator], [refno], [winlostdate], [betfrom], 
							[checktime], [apositiontaking], [mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], 
							[playercomm], [comm], [acomm], [actualrate], [matchid], [matchdate], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], 
							[sdiscount], [scomm], [statusID], [virtualrate], [SiteID], [transdesc], [BetID3rd], [epositiontaking], [actual_stake], [netstake], 
							[SiteDBGroupID])
FROM bodb02.dbo.bettransG14 b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.bettransLC
DELETE b
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
		deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
		deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], 
		deleted.[gameID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[RefNo], deleted.[IsSum], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], 
		deleted.[scomm], deleted.[Transdate3rd], deleted.[NetStake], deleted.[SiteID], deleted.[epositiontaking], deleted.[SiteDBGroupID] , deleted.[RepUpdateTime]
INTO bettransLC_delete (	[transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
							[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
							[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
							[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], 
							[scomm], [Transdate3rd], [NetStake], [SiteID], [epositiontaking], [SiteDBGroupID] , [RepUpdateTime])
FROM bodb02.dbo.bettransLC b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.bettransLC14
DELETE b
OUTPUT	deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
		deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
		deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], 
		deleted.[gameID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[RefNo], deleted.[IsSum], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], 
		deleted.[scomm], deleted.[Transdate3rd], deleted.[NetStake], deleted.[epositiontaking], deleted.[SiteID], deleted.[SiteDBGroupID]
INTO bettransLC14_delete ([transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
							[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
							[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
							[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], 
							[scomm], [Transdate3rd], [NetStake], [epositiontaking], [SiteID], [SiteDBGroupID])
FROM bodb02.dbo.bettransLC14 b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.bettransRnG
DELETE b
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
		deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
		deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], deleted.[gameID], 
		deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[RefNo], deleted.[IsSum], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm], 
		deleted.[Transdate3rd], deleted.[SiteID], deleted.[Additional], deleted.[JackpotInfo], deleted.[RefNo2], deleted.[ContributionRate], deleted.[BetStake], deleted.[ContributionStake3rd], 
		deleted.[epositiontaking], deleted.[SiteDBGroupID], deleted.[RepUpdateTime]
INTO bettransRnG_delete (	[transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
							[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
							[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], 
							[vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], 
							[Transdate3rd], [SiteID], [Additional], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd], 
							[epositiontaking], [SiteDBGroupID], [RepUpdateTime])
FROM bodb02.dbo.bettransRnG b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.bettransRnG14
DELETE b
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
		deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
		deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], 
		deleted.[gameID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[RefNo], deleted.[IsSum], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], 
		deleted.[acomm], deleted.[scomm], deleted.[Transdate3rd], deleted.[Additional], deleted.[Siteid], deleted.[JackpotInfo], deleted.[RefNo2], deleted.[ContributionRate], deleted.[BetStake], deleted.[ContributionStake3rd], 
		deleted.[epositiontaking], deleted.[SiteDBGroupID]
INTO bettransRnG14_delete (	[transid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
								[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
								[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
								[gameID], [vendorID], [GameId3rd], [TranId3rd], [RefNo], [IsSum], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], 
								[acomm], [scomm], [Transdate3rd], [Additional], [Siteid], [JackpotInfo], [RefNo2], [ContributionRate], [BetStake], [ContributionStake3rd], 
								[epositiontaking], [SiteDBGroupID])
FROM bodb02.dbo.bettransRnG14 b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.translog
DELETE b
OUTPUT deleted.[translogid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
		deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
		deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], 
		deleted.[gameID], deleted.[eventID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[custom1], deleted.[custom2], deleted.[custom3], deleted.[LiveIndicator], deleted.[checkCount], deleted.[SiteId], 
		deleted.[epositiontaking], deleted.[SiteDBGroupID], deleted.[LicenseeTransId], deleted.[RepUpdateTime]
INTO translog_delete ([translogid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
						[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
						[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], 
						[gameID], [eventID], [vendorID], [GameId3rd], [TranId3rd], [custom1], [custom2], [custom3], [LiveIndicator], [checkCount], [SiteId], 
						[epositiontaking], [SiteDBGroupID], [LicenseeTransId], [RepUpdateTime])
FROM bodb02.dbo.translog b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.translog14
DELETE b
OUTPUT  deleted.[translogid], deleted.[custid], deleted.[transdate], deleted.[odds], deleted.[stake], deleted.[status], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[spositiontaking], 
		deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[sdiscount], deleted.[creator], deleted.[winlostdate], deleted.[betfrom], deleted.[virtualrate], deleted.[actualrate], deleted.[actual_stake], 
		deleted.[currency], deleted.[CurrencyName], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], deleted.[ip], deleted.[statusID], deleted.[balance], deleted.[Username], deleted.[transdesc], deleted.[productID], deleted.[gameID], 
		deleted.[eventID], deleted.[vendorID], deleted.[GameId3rd], deleted.[TranId3rd], deleted.[custom1], deleted.[custom2], deleted.[custom3], deleted.[LiveIndicator], deleted.[SiteDBGroupID]
INTO translog14_delete (	[translogid], [custid], [transdate], [odds], [stake], [status], [apositiontaking], [mpositiontaking], [tpositiontaking], [spositiontaking], 
							[playerdiscount], [discount], [adiscount], [sdiscount], [creator], [winlostdate], [betfrom], [virtualrate], [actualrate], [actual_stake], 
							[currency], [CurrencyName], [recommend], [mrecommend], [srecommend], [ip], [statusID], [balance], [Username], [transdesc], [productID], [gameID], 
							[eventID], [vendorID], [GameId3rd], [TranId3rd], [custom1], [custom2], [custom3], [LiveIndicator], [SiteDBGroupID])
FROM bodb02.dbo.translog14 b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.BetParlayResult
DELETE bpr
OUTPUT	deleted.[RefNo], deleted.[Serial], deleted.[transid], deleted.[winlostdate], deleted.[statusid], deleted.[stake], deleted.[Odds], deleted.[mOdds], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm]
INTO BetParlayResult_delete ([RefNo], [Serial], [transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm])
FROM bodb02.dbo.BetParlayResult bpr WITH (ROWLOCK)
	INNER JOIN refno_delete tmp WITH (NOLOCK) ON tmp.refno = bpr.refno

--bodb02.dbo.zzzbettrans
DELETE z
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[livehomescore], deleted.[liveawayscore], 
		deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[matchid], deleted.[bettype], 
		deleted.[VoidingHistoryId], deleted.[RepUpdateTime], deleted.[SiteDBGroupID]
INTO zzzbettrans_delete ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [matchid], [bettype], 
							[VoidingHistoryId], [RepUpdateTime], [SiteDBGroupID])
FROM bodb02.dbo.zzzbettrans z WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = z.custid
		
--bodb02.dbo.zzzbettransm
DELETE z
OUTPUT	deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[livehomescore], deleted.[liveawayscore], 
		deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[matchid], deleted.[bettype], 
		deleted.[VoidingHistoryId], deleted.[RepUpdateTime], deleted.[SiteDBGroupID]
INTO zzzbettransm_delete ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [matchid], [bettype], 
							[VoidingHistoryId], [RepUpdateTime], [SiteDBGroupID])
FROM bodb02.dbo.zzzbettransm z WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = z.custid

/********************Tables Balance*************************/

--1. bodb02.dbo.BalCreditCasino
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalCreditCasino_delete] ([custid], [Balance])
FROM bodb02.dbo.BalCreditCasino bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--2. bodb02.dbo.BalCreditOthers
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalCreditOthers_delete] ([custid], [Balance])
FROM bodb02.dbo.BalCreditOthers bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--3. bodb02.dbo.BalCreditSports
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalCreditSports_delete] ([custid], [Balance])
FROM bodb02.dbo.BalCreditSports bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--4. BalCreditTransfer
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalCreditTransfer_delete] ([custid], [Balance])
FROM bodb02.dbo.BalCreditTransfer bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--5. bodb02.dbo.BalDebitCasino
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalDebitCasino_delete] ([custid], [Balance])
FROM bodb02.dbo.BalDebitCasino bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--6. bodb02.dbo.BalDebitOthers
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalDebitOthers_delete] ([custid], [Balance])
FROM bodb02.dbo.BalDebitOthers bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--7. bodb02.dbo.BalDebitSports
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalDebitSports_delete] ([custid], [Balance])
FROM bodb02.dbo.BalDebitSports bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--8. bodb02.dbo.BalDebitTransfer
DELETE bal
OUTPUT deleted.[custid], deleted.[Balance]
INTO [BalDebitTransfer_delete] ([custid], [Balance])
FROM bodb02.dbo.BalDebitTransfer bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--9. bodb02.dbo.BalNetPosition
DELETE bal
OUTPUT deleted.[CustID], deleted.[MatchID], deleted.[Bettype], deleted.[Debit], deleted.[Credit], deleted.[CreatedDate], deleted.[ModifiedDate]
INTO [BalNetPosition_delete] ([CustID], [MatchID], [Bettype], [Debit], [Credit], [CreatedDate], [ModifiedDate])
FROM bodb02.dbo.BalNetPosition bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--10. bodb02.dbo.balanceTable
DELETE bal
OUTPUT  deleted.[custid], deleted.[roleid], deleted.[amount], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm], deleted.[recommend], deleted.[mrecommend], 
		deleted.[srecommend], deleted.[currency], deleted.[UserName], deleted.[CurrencyName], deleted.[actualrate], deleted.[TicketCount], deleted.[balTicketCount]
INTO [balanceTable_delete] (	[custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
								[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
FROM bodb02.dbo.balanceTable bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--11. bodb02.dbo.balanceTable_tmp
DELETE bal
OUTPUT  deleted.[winlostdate], deleted.[custid], deleted.[roleid], deleted.[amount], deleted.[awinlost], deleted.[mwinlost], deleted.[swinlost], deleted.[playercomm], deleted.[comm], deleted.[acomm], deleted.[scomm], deleted.[recommend], deleted.[mrecommend], 
		deleted.[srecommend], deleted.[currency], deleted.[UserName], deleted.[CurrencyName], deleted.[actualrate], deleted.[TicketCount], deleted.[balTicketCount]
INTO [balanceTable_tmp_delete] (	[winlostdate], [custid], [roleid], [amount], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [recommend], [mrecommend], 
									[srecommend], [currency], [UserName], [CurrencyName], [actualrate], [TicketCount], [balTicketCount])
FROM bodb02.dbo.balanceTable_tmp bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

--12. bodb02.dbo.BalanceTable_tmp_cal
DELETE bal
OUTPUT	deleted.[dow], deleted.[roleid], deleted.[custid], deleted.[recommend], deleted.[mrecommend], deleted.[srecommend], 
		deleted.[amt1], deleted.[tcnt1], deleted.[amt2], deleted.[tcnt2], deleted.[amt3], deleted.[tcnt3], deleted.[amt4], deleted.[tcnt4]
INTO [BalanceTable_tmp_cal_delete] (	[dow], [roleid], [custid], [recommend], [mrecommend], [srecommend], 
										[amt1], [tcnt1], [amt2], [tcnt2], [amt3], [tcnt3], [amt4], [tcnt4])
FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bal.custid

/*******************Other Tables**********************/
--1. bodb02.dbo.Bonus_sum_winloss
DELETE bon
OUTPUT deleted.[CustId], deleted.[BonusId], deleted.[winlostdate], deleted.[Amount]
INTO [Bonus_sum_winloss_delete] ([CustId], [BonusId], [winlostdate], [Amount])
FROM bodb02.dbo.Bonus_sum_winloss bon WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--2. bodb02.dbo.BonusAdjustmentTransfer
-- There is no index on custid for table BonusAdjustmentTransfer, has only an index on ExecID
-- remove ExecID
DELETE bon
OUTPUT deleted.[LogDate], deleted.[ExecDate], deleted.[CustID], deleted.[MatchID], deleted.[BonusID], deleted.[StatusID], deleted.[Amount], deleted.[isTransferred]
INTO [BonusAdjustmentTransfer_delete] ([LogDate], [ExecDate], [CustID], [MatchID], [BonusID], [StatusID], [Amount], [isTransferred])
FROM bodb02.dbo.BonusAdjustmentTransfer bon WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--3. bodb02.dbo.BonusTrans
-- remove BonusTransId
DELETE bon
OUTPUT  deleted.[CustID], deleted.[Recommend], deleted.[Mrecommend], deleted.[Srecommend], deleted.[Amount], deleted.[StatusId], deleted.[Creator], deleted.[CreatedDate], 
		deleted.[PaymentDate], deleted.[IsComplained]
INTO [BonusTrans_delete] ([CustID], [Recommend], [Mrecommend], [Srecommend], [Amount], [StatusId], [Creator], [CreatedDate], 
							[PaymentDate], [IsComplained])
FROM bodb02.dbo.BonusTrans bon WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--4. bodb02.dbo.BonusWalletCredit
DELETE bon
OUTPUT  deleted.[CustID], deleted.[BonusID], deleted.[StatusID], deleted.[initBonus], deleted.[LockedAmt], deleted.[Amount]
INTO [BonusWalletCredit_delete] ([CustID], [BonusID], [StatusID], [initBonus], [LockedAmt], [Amount])
FROM bodb02.dbo.BonusWalletCredit bon WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--5. bodb02.dbo.BonusWalletDebit
DELETE bon
OUTPUT  deleted.[CustID], deleted.[BonusID], deleted.[Amount]
INTO [BonusWalletDebit_delete] ([CustID], [BonusID], [Amount])
FROM bodb02.dbo.BonusWalletDebit bon WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--6. bodb02.dbo.BonusWalletPending
-- There is no index on custid for table BonusWalletPending, has only an index on Rn
-- Remove Rn
DELETE bon
OUTPUT  deleted.[CustID], deleted.[BonusID], deleted.[Amount]
INTO [BonusWalletPending_delete] ([CustID], [BonusID], [Amount])
FROM bodb02.dbo.BonusWalletPending bon WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bon.custid

--7. bodb02.dbo.CashOutSelling
-- There is no index on custid for table CashOutSelling, has only an index on TransID
DELETE cosell
OUTPUT	deleted.[TransID], deleted.[MatchID], deleted.[Bettype], deleted.[Custid], deleted.[CashOutStatus], deleted.[Winlost], deleted.[PriceInfo], deleted.[CheckTime], 
		deleted.[CreateDate], deleted.[ChangeDate], deleted.[IsTest], deleted.[VirtualRate], deleted.[CashOutExtraInfo]
INTO [CashOutSelling_delete] ([TransID], [MatchID], [Bettype], [Custid], [CashOutStatus], [Winlost], [PriceInfo], [CheckTime], 
								[CreateDate], [ChangeDate], [IsTest], [VirtualRate], [CashOutExtraInfo])
FROM bodb02.dbo.CashOutSelling cosell WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = cosell.custid

--8. bodb02.dbo.CustLimitBet_LIC
DELETE clb
OUTPUT	deleted.[Matchid], deleted.[CustID], deleted.[AccumTurnover], deleted.[AccumPayout], deleted.[EventTypeID], deleted.[LastQueueID], deleted.[ModifiedDate]
INTO [CustLimitBet_LIC_delete] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
FROM bodb02.dbo.CustLimitBet_LIC clb WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = clb.custid

--9. bodb02.dbo.CustLimitBetHistory_LIC
DELETE clbh
OUTPUT	deleted.[Matchid], deleted.[CustID], deleted.[Transid], deleted.[TurnoverAdjust], deleted.[PayoutAdjust], deleted.[EventTypeID], deleted.[CreatedDate]
INTO [CustLimitBetHistory_LIC_delete] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = clbh.custid

--10. bodb02.dbo.Task_bettransLC14_IP2Country
DELETE tbip
OUTPUT	deleted.[transid], deleted.[winlostdate], deleted.[CountryShort], deleted.[IPArchive]
INTO [Task_bettransLC14_IP2Country_delete] ([transid], [winlostdate], [CountryShort], [IPArchive])
FROM bodb02.dbo.Task_bettransLC14_IP2Country tbip WITH (ROWLOCK)
	INNER JOIN dbo.bettransLC14_delete b WITH (NOLOCK) ON b.transid = tbip.transid

--11. bodb02.dbo.Task_bettransRNG14_IP2Country
DELETE tbip
OUTPUT	deleted.[transid], deleted.[winlostdate], deleted.[CountryShort], deleted.[IPArchive]
INTO [Task_bettransRNG14_IP2Country_delete] ([transid], [winlostdate], [CountryShort], [IPArchive])
FROM bodb02.dbo.Task_bettransRNG14_IP2Country tbip WITH (ROWLOCK)
	INNER JOIN dbo.bettransRnG14_delete b WITH (NOLOCK) ON b.transid = tbip.transid

/*******************Other tables - TW list**********************/

--1.  bodb02.dbo.BalancePendingCreditGame
--There is no index on custid for table BalancePendingCreditGame, has only an index on rn
-- Remove rn
DELETE bc
OUTPUT deleted.[custid], deleted.[winlostdate], deleted.[Balance], deleted.[bettype], deleted.[GameTypeID]
INTO BalancePendingCreditGame_delete ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
FROM bodb02.dbo.BalancePendingCreditGame bc WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--2.  bodb02.dbo.BalancePendingDebitGame
--There is no index on custid for table BalancePendingDebitGame, has only an index on rn
-- Remove rn
DELETE bd
OUTPUT deleted.[custid], deleted.[winlostdate], deleted.[Balance], deleted.[bettype], deleted.[GameTypeID]
INTO BalancePendingDebitGame_delete ([custid], [winlostdate], [Balance], [bettype], [GameTypeID])
FROM bodb02.dbo.BalancePendingDebitGame bd WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--3.  bodb02.dbo.BalCreditCasinoPending
--There is no index on custid for table BalCreditCasinoPending, has only an index on rn
-- Remove rn
DELETE bc
OUTPUT deleted.[custid], deleted.[Balance]
INTO BalCreditCasinoPending_delete ([custid], [Balance])
FROM bodb02.dbo.BalCreditCasinoPending bc WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--4.  bodb02.dbo.BalCreditOthersPending
--There is no index on custid for table BalCreditOthersPending, has only an index on rn
-- Remove rn
DELETE bc
OUTPUT deleted.[custid], deleted.[Balance]
INTO BalCreditOthersPending_delete ([custid], [Balance])
FROM bodb02.dbo.BalCreditOthersPending bc WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--5.  bodb02.dbo.BalCreditSportsPending
--There is no index on custid for table BalCreditSportsPending, has only an index on rn
-- Remove rn
DELETE bc
OUTPUT deleted.[custid], deleted.[Balance]
INTO BalCreditSportsPending_delete ([custid], [Balance])
FROM bodb02.dbo.BalCreditSportsPending bc WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bc.custid

--6.  bodb02.dbo.BalDebitCasinoPending
--There is no index on custid for table BalDebitCasinoPending, has only an index on rn
-- Remove rn
DELETE bd
OUTPUT deleted.[custid], deleted.[Balance]
INTO BalDebitCasinoPending_delete ([custid], [Balance])
FROM bodb02.dbo.BalDebitCasinoPending bd WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--7.  bodb02.dbo.BalDebitOthersPending
--There is no index on custid for table BalDebitOthersPending, has only an index on rn
-- Remove rn
DELETE bd
OUTPUT deleted.[custid], deleted.[Balance]
INTO BalDebitOthersPending_delete ([custid], [Balance])
FROM bodb02.dbo.BalDebitOthersPending bd WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--8.  bodb02.dbo.BalDebitSportsPending
--There is no index on custid for table BalDebitSportsPending, has only an index on rn
-- Remove rn
DELETE bd
OUTPUT deleted.[custid], deleted.[Balance]
INTO BalDebitSportsPending_delete ([custid], [Balance])
FROM bodb02.dbo.BalDebitSportsPending bd WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bd.custid

--9. bodb02.dbo.Intg_GameRoundBetStake
--There is no index on custid for table Intg_GameRoundBetStake
DELETE igr
OUTPUT deleted.[VendorId], deleted.[BetId], deleted.[GameRound], deleted.[GameType], deleted.[BetChoice], deleted.[CustId], deleted.[Stake], deleted.[CreateDate]
INTO Intg_GameRoundBetStake_delete ([VendorId], [BetId], [GameRound], [GameType], [BetChoice], [CustId], [Stake], [CreateDate])
FROM bodb02.dbo.Intg_GameRoundBetStake igr WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = igr.custid

--10. bodb02.dbo.LastBetTime
DELETE lb
OUTPUT deleted.[custid], deleted.[transdate]
INTO LastBetTime_delete ([custid], [transdate])
FROM bodb02.dbo.LastBetTime lb WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = lb.custid

--11. bodb02.dbo.LastBetTime_Agent
DELETE lba
OUTPUT deleted.[CustID], deleted.[MatchID], deleted.[BetType], deleted.[CustomerClass], deleted.[Platform], deleted.[TransDate]
INTO LastBetTime_Agent_delete ([CustID], [MatchID], [BetType], [CustomerClass], [Platform], [TransDate])
FROM bodb02.dbo.LastBetTime_Agent lba WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = lba.custid

--12. bodb02.dbo.MarkedTransaction
DELETE mt
OUTPUT deleted.[TransId], deleted.[MatchId], deleted.[CustId], deleted.[bettype], deleted.[UserId], deleted.[CreatedDate], deleted.[MarkType]
INTO MarkedTransaction_delete ([TransId], [MatchId], [CustId], [bettype], [UserId], [CreatedDate], [MarkType])
FROM bodb02.dbo.MarkedTransaction mt WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = mt.custid

--13. bodb02.dbo.NetPositionCalculationLog
-- Removew NPCalculationLogID
DELETE npcl
OUTPUT	deleted.[CustID], deleted.[MatchID], deleted.[Bettype], deleted.[AccumNPDebit], deleted.[AccumNPCredit], deleted.[NPAdjust], 
		deleted.[IsLatest], deleted.[CreatedDate], deleted.[ModifiedDate]
INTO NetPositionCalculationLog_delete (	[CustID], [MatchID], [Bettype], [AccumNPDebit], [AccumNPCredit], [NPAdjust], 
											[IsLatest], [CreatedDate], [ModifiedDate])
FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = npcl.custid

--14. bodb02.dbo.NetPositionTrans
DELETE npt
OUTPUT	deleted.[TransID], deleted.[CustID], deleted.[MatchID], deleted.[Bettype], deleted.[Actual_stake], deleted.[Payout1], deleted.[Payoutx], deleted.[Payout2], deleted.[SyncStatus], 
		deleted.[isSettled], deleted.[CreatedDate], deleted.[ModifiedDate]
INTO NetPositionTrans_delete ([TransID], [CustID], [MatchID], [Bettype], [Actual_stake], [Payout1], [Payoutx], [Payout2], [SyncStatus], 
								[isSettled], [CreatedDate], [ModifiedDate])
FROM bodb02.dbo.NetPositionTrans npt WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = npt.custid

--15. bodb02.dbo.Task_Cust_CheckBalance_Exception
DELETE tce
OUTPUT	deleted.[custid], deleted.[Remark]
INTO Task_Cust_CheckBalance_Exception_delete ([custid], [Remark])
FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = tce.custid

--16. bodb02.dbo.Task_Cust_BalanceProblem1
--There is no index on custid for table Task_Cust_BalanceProblem1, has only an index on keyID
DELETE tcb
OUTPUT deleted.[UserName], deleted.[custid], deleted.[DiffBalance], deleted.[LogDate], deleted.[IsFixed], deleted.[Remark]
INTO Task_Cust_BalanceProblem1_delete ([UserName], [custid], [DiffBalance], [LogDate], [IsFixed], [Remark])
FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = tcb.custid

--17. bodb02.dbo.CustLimitBetQueue
--18. bodb02.dbo.CustLimitBet_QueueRetry
--19. bodb02.dbo.Task_Cust_CheckBalanceVerify1
--20. bodb02.dbo.CS_CustSuper
--21. bodb02.dbo.BalanceErr



	