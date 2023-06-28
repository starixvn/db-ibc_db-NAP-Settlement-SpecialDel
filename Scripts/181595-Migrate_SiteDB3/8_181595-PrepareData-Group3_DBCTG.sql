/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230626@Louisa:Prepare data to migrate - table group 3 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

----38 tables

 /*	---- DROP tables to re-use script for test

	IF OBJECT_ID('tempdb..#tmp_refno') IS NOT NULL
		DROP TABLE #tmp_refno
	IF OBJECT_ID('bettransG_20230626') IS NOT NULL
		DROP TABLE bettransG_20230626
	IF OBJECT_ID('bettransG14_20230626') IS NOT NULL
		DROP TABLE bettransG14_20230626
	IF OBJECT_ID('bettransLC_20230626') IS NOT NULL
		DROP TABLE bettransLC_20230626
	IF OBJECT_ID('bettransLC14_20230626') IS NOT NULL
		DROP TABLE bettransLC14_20230626
	IF OBJECT_ID('bettransRnG_20230626') IS NOT NULL
		DROP TABLE bettransRnG_20230626
	IF OBJECT_ID('bettransRnG14_20230626') IS NOT NULL
		DROP TABLE bettransRnG14_20230626
	IF OBJECT_ID('translog_20230626') IS NOT NULL
		DROP TABLE translog_20230626
	IF OBJECT_ID('translog14_20230626') IS NOT NULL
		DROP TABLE translog14_20230626
	IF OBJECT_ID('BetParlayResult_20230626') IS NOT NULL
		DROP TABLE BetParlayResult_20230626
	IF OBJECT_ID('zzzbettrans_20230626') IS NOT NULL
		DROP TABLE zzzbettrans_20230626
	IF OBJECT_ID('zzzbettransm_20230626') IS NOT NULL
		DROP TABLE zzzbettransm_20230626
	IF OBJECT_ID('BalCreditCasino_20230626') IS NOT NULL
		DROP TABLE BalCreditCasino_20230626
	IF OBJECT_ID('BalCreditOthers_20230626') IS NOT NULL
		DROP TABLE BalCreditOthers_20230626
	IF OBJECT_ID('BalCreditSports_20230626') IS NOT NULL
		DROP TABLE BalCreditSports_20230626
	IF OBJECT_ID('BalCreditTransfer_20230626') IS NOT NULL
		DROP TABLE BalCreditTransfer_20230626
	IF OBJECT_ID('BalDebitCasino_20230626') IS NOT NULL
		DROP TABLE BalDebitCasino_20230626
	IF OBJECT_ID('BalDebitOthers_20230626') IS NOT NULL
		DROP TABLE BalDebitOthers_20230626
	IF OBJECT_ID('BalDebitSports_20230626') IS NOT NULL
		DROP TABLE BalDebitSports_20230626
	IF OBJECT_ID('BalDebitTransfer_20230626') IS NOT NULL
		DROP TABLE BalDebitTransfer_20230626
	IF OBJECT_ID('BalNetPosition_20230626') IS NOT NULL
		DROP TABLE BalNetPosition_20230626
	IF OBJECT_ID('balanceTable_20230626') IS NOT NULL
		DROP TABLE balanceTable_20230626
	IF OBJECT_ID('balanceTable_tmp_20230626') IS NOT NULL
		DROP TABLE balanceTable_tmp_20230626
	IF OBJECT_ID('BalanceTable_tmp_cal_20230626') IS NOT NULL
		DROP TABLE BalanceTable_tmp_cal_20230626
	IF OBJECT_ID('CashOutSelling_20230626') IS NOT NULL
		DROP TABLE CashOutSelling_20230626
	IF OBJECT_ID('Task_bettransLC14_IP2Country_20230626') IS NOT NULL
		DROP TABLE Task_bettransLC14_IP2Country_20230626
	IF OBJECT_ID('Task_bettransRNG14_IP2Country_20230626') IS NOT NULL
		DROP TABLE Task_bettransRNG14_IP2Country_20230626
	IF OBJECT_ID('MarkedTransaction_20230626') IS NOT NULL
		DROP TABLE MarkedTransaction_20230626
	IF OBJECT_ID('NetPositionCalculationLog_20230626') IS NOT NULL
		DROP TABLE NetPositionCalculationLog_20230626
	IF OBJECT_ID('NetPositionTrans_20230626') IS NOT NULL
		DROP TABLE NetPositionTrans_20230626
	IF OBJECT_ID('Task_Cust_CheckBalance_Exception_20230626') IS NOT NULL
		DROP TABLE Task_Cust_CheckBalance_Exception_20230626
	IF OBJECT_ID('Task_Cust_BalanceProblem1_20230626') IS NOT NULL
		DROP TABLE Task_Cust_BalanceProblem1_20230626 
	IF OBJECT_ID('CustLimitBet_789_20230626') IS NOT NULL
		DROP TABLE CustLimitBet_789_20230626
	IF OBJECT_ID('CustLimitBet_MBC_20230626') IS NOT NULL
		DROP TABLE CustLimitBet_MBC_20230626
	IF OBJECT_ID('CustLimitBetHistory_789_20230626') IS NOT NULL
		DROP TABLE CustLimitBetHistory_789_20230626
	IF OBJECT_ID('CustLimitBetHistory_MBC_20230626') IS NOT NULL
		DROP TABLE CustLimitBetHistory_MBC_20230626
	IF OBJECT_ID('ProcessingCustList_20230626') IS NOT NULL
		DROP TABLE ProcessingCustList_20230626
	IF OBJECT_ID('Task_Cust_BalanceProblem_20230626') IS NOT NULL
		DROP TABLE Task_Cust_BalanceProblem_20230626
	IF OBJECT_ID('Task_Cust_BalanceProblem1_Manually_20230626') IS NOT NULL
		DROP TABLE Task_Cust_BalanceProblem1_Manually_20230626

*/

	DECLARE @SiteDBGroupID SMALLINT
	DECLARE @debug_message VARCHAR(500)
	
	SET @SiteDBGroupID = 3

	CREATE TABLE #tmp_refno
	(
		refno BIGINT PRIMARY KEY
	)

	----copy data bodb02.dbo.bettransG
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			@SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransG_20230626
	FROM bodb02.dbo.bettransG b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransG14
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			@SiteDBGroupID SiteDBGroupID
	INTO bettransG14_20230626
	FROM bodb02.dbo.bettransG14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransLC
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.SiteID, b.epositiontaking, @SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransLC_20230626
	FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransLC14
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.epositiontaking, b.SiteID, @SiteDBGroupID SiteDBGroupID
	INTO bettransLC14_20230626
	FROM bodb02.dbo.bettransLC14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransRnG
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, 
			b.Transdate3rd, b.SiteID, b.Additional, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.RepUpdateTime
	INTO bettransRnG_20230626
	FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransRnG14
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, 
			b.acomm, b.scomm, b.Transdate3rd, b.Additional, b.Siteid, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID
	INTO bettransRnG14_20230626
	FROM bodb02.dbo.bettransRnG14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.translog
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, b.checkCount, b.SiteId, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.LicenseeTransId, b.RepUpdateTime
	INTO translog_20230626
	FROM bodb02.dbo.translog b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.translog14
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, @SiteDBGroupID SiteDBGroupID
	INTO translog14_20230626
	FROM bodb02.dbo.translog14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	
	--#tmp_refno
	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM bettrans_20230626 b WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM bettrans14_20230626 b WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	----copy data bodb02.dbo.BetParlayResult
	SELECT	bpr.RefNo, bpr.Serial, bpr.transid, bpr.winlostdate, bpr.statusid, bpr.stake, bpr.Odds, bpr.mOdds, bpr.winlost, bpr.awinlost, bpr.mwinlost, bpr.swinlost, bpr.playercomm, bpr.comm, bpr.acomm, bpr.scomm
	INTO BetParlayResult_20230626
	FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp 
			ON tmp.refno = bpr.refno

	----copy data bodb02.dbo.zzzbettrans
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettrans_20230626
	FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid
		
	----copy data bodb02.dbo.zzzbettransm
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettransm_20230626
	FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid


	/********************Tables Balance*************************/

	--copy data bodb02.dbo.BalCreditCasino
	SELECT bal.custid, bal.Balance
	INTO BalCreditCasino_20230626
	FROM bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalCreditOthers
	SELECT bal.custid, bal.Balance
	INTO BalCreditOthers_20230626
	FROM bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalCreditSports
	SELECT bal.custid, bal.Balance
	INTO BalCreditSports_20230626
	FROM bodb02.dbo.BalCreditSports bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalCreditTransfer
	SELECT bal.custid, bal.Balance
	INTO BalCreditTransfer_20230626
	FROM bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalDebitCasino
	SELECT bal.custid, bal.Balance
	INTO BalDebitCasino_20230626
	FROM bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalDebitOthers
	SELECT bal.custid, bal.Balance
	INTO BalDebitOthers_20230626
	FROM bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalDebitSports
	SELECT bal.custid, bal.Balance
	INTO BalDebitSports_20230626
	FROM bodb02.dbo.BalDebitSports bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalDebitTransfer
	SELECT bal.custid, bal.Balance
	INTO BalDebitTransfer_20230626
	FROM bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalNetPosition
	SELECT bal.CustID, bal.MatchID, bal.Bettype, bal.Debit, bal.Credit, bal.CreatedDate, bal.ModifiedDate
	INTO BalNetPosition_20230626
	FROM bodb02.dbo.BalNetPosition bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.balanceTable
	SELECT  bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	INTO balanceTable_20230626
	FROM bodb02.dbo.balanceTable bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.balanceTable_tmp
	SELECT  bal.winlostdate, bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	INTO balanceTable_tmp_20230626
	FROM bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalanceTable_tmp_cal
	SELECT	bal.dow, bal.roleid, bal.custid, bal.recommend, bal.mrecommend, bal.srecommend, 
			bal.amt1, bal.tcnt1, bal.amt2, bal.tcnt2, bal.amt3, bal.tcnt3, bal.amt4, bal.tcnt4
	INTO BalanceTable_tmp_cal_20230626
	FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid


	/*******************Other Tables**********************/
 
	--copy data bodb02.dbo.CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID 
	SELECT	cosell.TransID, cosell.MatchID, cosell.Bettype, cosell.Custid, cosell.CashOutStatus, cosell.Winlost, cosell.PriceInfo, cosell.CheckTime, 
			cosell.CreateDate, cosell.ChangeDate, cosell.IsTest, cosell.VirtualRate, cosell.CashOutExtraInfo
	INTO CashOutSelling_20230626
	FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = cosell.custid
  
	--copy data bodb02.dbo.Task_bettransLC14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettransLC14_IP2Country_20230626
	FROM bodb02.dbo.Task_bettransLC14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransLC14_20230626 b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	--copy data bodb02.dbo.Task_bettransRNG14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettransRNG14_IP2Country_20230626
	FROM bodb02.dbo.Task_bettransRNG14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransRnG14_20230626 b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	--copy data bodb02.dbo.MarkedTransaction
	SELECT mt.TransId, mt.MatchId, mt.CustId, mt.bettype, mt.UserId, mt.CreatedDate, mt.MarkType
	INTO MarkedTransaction_20230626
	FROM bodb02.dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = mt.custid

	--copy data bodb02.dbo.NetPositionCalculationLog
	SELECT	npcl.NPCalculationLogID, npcl.CustID, npcl.MatchID, npcl.Bettype, npcl.AccumNPDebit, npcl.AccumNPCredit, npcl.NPAdjust, 
			npcl.IsLatest, npcl.CreatedDate, npcl.ModifiedDate
	INTO NetPositionCalculationLog_20230626
	FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = npcl.custid

	--copy data bodb02.dbo.NetPositionTrans
	SELECT	npt.TransID, npt.CustID, npt.MatchID, npt.Bettype, npt.Actual_stake, npt.Payout1, npt.Payoutx, npt.Payout2, npt.SyncStatus, 
			npt.isSettled, npt.CreatedDate, npt.ModifiedDate
	INTO NetPositionTrans_20230626
	FROM bodb02.dbo.NetPositionTrans npt WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = npt.custid

	--copy data bodb02.dbo.Task_Cust_CheckBalance_Exception
	SELECT	tce.custid, tce.Remark
	INTO Task_Cust_CheckBalance_Exception_20230626
	FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = tce.custid

	--copy data bodb02.dbo.Task_Cust_BalanceProblem1
	SELECT tcb.UserName, tcb.custid, tcb.DiffBalance, tcb.LogDate, tcb.IsFixed, tcb.Remark
	INTO Task_Cust_BalanceProblem1_20230626 
	FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = tcb.custid
	
	--copy data bodb02.dbo.CustLimitBet_789
	SELECT cb.Matchid ,cb.CustID ,cb.AccumTurnover ,cb.AccumPayout ,cb.EventTypeID	,cb.LastQueueID	,cb.ModifiedDate
	INTO CustLimitBet_789_20230626
	FROM bodb02.dbo.CustLimitBet_789 cb WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cb.custid
	
	--copy data bodb02.dbo.CustLimitBet_MBC
	SELECT cbm.Matchid , cbm.CustID , cbm.AccumTurnover , cbm.AccumPayout , cbm.EventTypeID	, cbm.LastQueueID	, cbm.ModifiedDate
	INTO CustLimitBet_MBC_20230626
	FROM bodb02.dbo.CustLimitBet_MBC cbm WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cbm.custid
	
	--copy data bodb02.dbo.CustLimitBetHistory_789
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate
	INTO CustLimitBetHistory_789_20230626
	FROM bodb02.dbo.CustLimitBetHistory_789 cbh  WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cbh.custid

	--copy data bodb02.dbo.CustLimitBetHistory_MBC
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate
	INTO CustLimitBetHistory_MBC_20230626
	FROM bodb02.dbo.CustLimitBetHistory_MBC cbh WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cbh.custid

	--copy data bodb02.dbo.ProcessingCustList
	SELECT pcl.CustId
	INTO ProcessingCustList_20230626
	FROM bodb02.dbo.ProcessingCustList pcl WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = pcl.custid
	
	--copy data bodb02.dbo.Task_Cust_BalanceProblem
	-- indentity = keyID
	SELECT tp.keyID ,tp.UserName ,tp.custid ,tp.DiffBalance ,tp.LogDate ,tp.IsFixed ,tp.Remark
	INTO Task_Cust_BalanceProblem_20230626
	FROM bodb02.dbo.Task_Cust_BalanceProblem tp WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = tp.custid
	
	--copy data bodb02.dbo.Task_Cust_BalanceProblem1_Manually
	-- indentity = keyID
	SELECT tp.keyID ,tp.UserName ,tp.custid ,tp.DiffBalance ,tp.LogDate ,tp.IsFixed ,tp.Remark
	INTO Task_Cust_BalanceProblem1_Manually_20230626
	FROM bodb02.dbo.Task_Cust_BalanceProblem1_Manually tp WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = tp.custid

	DROP TABLE #tmp_refno
	
