/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230602@Louisa
    Task: Migrate 12Bet from DBTrans to SiteDB2 Redmineid:#188707 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230602@Louisa: Prepare data to migrate - table group 3 Redmineid:#188707 					
								
*/

USE SiteDBtmp
GO

	DECLARE @SiteDBGroupID SMALLINT
	DECLARE @debug_message VARCHAR(500)
	
	SET @SiteDBGroupID = 2

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
	INTO bettransG_20230602
	FROM bodb02.dbo.bettransG b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransG14
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			@SiteDBGroupID SiteDBGroupID
	INTO bettransG14_20230602
	FROM bodb02.dbo.bettransG14 b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransLC
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.SiteID, b.epositiontaking, @SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransLC_20230602
	FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransLC14
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.epositiontaking, b.SiteID, @SiteDBGroupID SiteDBGroupID
	INTO bettransLC14_20230602
	FROM bodb02.dbo.bettransLC14 b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransRnG
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, 
			b.Transdate3rd, b.SiteID, b.Additional, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.RepUpdateTime
	INTO bettransRnG_20230602
	FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.bettransRnG14
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, 
			b.acomm, b.scomm, b.Transdate3rd, b.Additional, b.Siteid, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID
	INTO bettransRnG14_20230602
	FROM bodb02.dbo.bettransRnG14 b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.translog
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, b.checkCount, b.SiteId, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.LicenseeTransId, b.RepUpdateTime
	INTO translog_20230602
	FROM bodb02.dbo.translog b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.translog14
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, @SiteDBGroupID SiteDBGroupID
	INTO translog14_20230602
	FROM bodb02.dbo.translog14 b WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	
	--#tmp_refno
	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM bettrans_20230602 b WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM bettrans14_20230602 b WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	----copy data bodb02.dbo.BetParlayResult
	SELECT	bpr.RefNo, bpr.Serial, bpr.transid, bpr.winlostdate, bpr.statusid, bpr.stake, bpr.Odds, bpr.mOdds, bpr.winlost, bpr.awinlost, bpr.mwinlost, bpr.swinlost, bpr.playercomm, bpr.comm, bpr.acomm, bpr.scomm
	INTO BetParlayResult_20230602
	FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp 
			ON tmp.refno = bpr.refno

	----copy data bodb02.dbo.zzzbettrans
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake}, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettrans_20230602
	FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid
		
	----copy data bodb02.dbo.zzzbettransm
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettransm_20230602
	FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid


	/********************Tables Balance*************************/

	--1. copy data bodb02.dbo.BalCreditCasino
	SELECT bal.custid, bal.Balance
	INTO BalCreditCasino_20230602
	FROM bodb02.dbo.BalCreditCasino bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--2. copy data bodb02.dbo.BalCreditOthers
	SELECT bal.custid, bal.Balance
	INTO BalCreditOthers_20230602
	FROM bodb02.dbo.BalCreditOthers bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--3. copy data bodb02.dbo.BalCreditSports
	SELECT bal.custid, bal.Balance
	INTO BalCreditSports_20230602
	FROM bodb02.dbo.BalCreditSports bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--4. copy data BalCreditTransfer
	SELECT bal.custid, bal.Balance
	INTO BalCreditTransfer_20230602
	FROM bodb02.dbo.BalCreditTransfer bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--5. copy data bodb02.dbo.BalDebitCasino
	SELECT bal.custid, bal.Balance
	INTO BalDebitCasino_20230602
	FROM bodb02.dbo.BalDebitCasino bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--6. copy data bodb02.dbo.BalDebitOthers
	SELECT bal.custid, bal.Balance
	INTO BalDebitOthers_20230602
	FROM bodb02.dbo.BalDebitOthers bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--7. copy data bodb02.dbo.BalDebitSports
	SELECT bal.custid, bal.Balance
	INTO BalDebitSports_20230602
	FROM bodb02.dbo.BalDebitSports bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--8. copy data bodb02.dbo.BalDebitTransfer
	SELECT bal.custid, bal.Balance
	INTO BalDebitTransfer_20230602
	FROM bodb02.dbo.BalDebitTransfer bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--9. copy data bodb02.dbo.BalNetPosition
	SELECT bal.CustID, bal.MatchID, bal.Bettype, bal.Debit, bal.Credit, bal.CreatedDate, bal.ModifiedDate
	INTO BalNetPosition_20230602
	FROM bodb02.dbo.BalNetPosition bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--10. copy data bodb02.dbo.balanceTable
	SELECT  bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	INTO balanceTable_20230602
	FROM bodb02.dbo.balanceTable bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--11. copy data bodb02.dbo.balanceTable_tmp
	SELECT  bal.winlostdate, bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	INTO balanceTable_tmp_20230602
	FROM bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--12. copy data bodb02.dbo.BalanceTable_tmp_cal
	SELECT	bal.dow, bal.roleid, bal.custid, bal.recommend, bal.mrecommend, bal.srecommend, 
			bal.amt1, bal.tcnt1, bal.amt2, bal.tcnt2, bal.amt3, bal.tcnt3, bal.amt4, bal.tcnt4
	INTO BalanceTable_tmp_cal_20230602
	FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid


	/*******************Other Tables**********************/
	----copy data bodb02.dbo.Bonus_sum_winloss
	SELECT bon.CustId, bon.BonusId, bon.winlostdate, bon.Amount
	INTO Bonus_sum_winloss_20230602
	FROM bodb02.dbo.Bonus_sum_winloss bon WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bon.custid

	----copy data bodb02.dbo.BonusAdjustmentTransfer 
	SELECT bon.ExecID, bon.LogDate, bon.ExecDate, bon.CustID, bon.MatchID, bon.BonusID, bon.StatusID, bon.Amount, bon.isTransferred
	INTO BonusAdjustmentTransfer_20230602
	FROM bodb02.dbo.BonusAdjustmentTransfer bon WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bon.custid

	----copy data bodb02.dbo.BonusTrans
	SELECT  bon.BonusTransId, bon.CustID, bon.Recommend, bon.Mrecommend, bon.Srecommend, bon.Amount, bon.StatusId, bon.Creator, bon.CreatedDate, 
			bon.PaymentDate, bon.IsComplained
	INTO BonusTrans_20230602
	FROM bodb02.dbo.BonusTrans bon WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bon.custid

	----copy data bodb02.dbo.BonusWalletCredit
	SELECT  bon.CustID, bon.BonusID, bon.StatusID, bon.initBonus, bon.LockedAmt, bon.Amount
	INTO BonusWalletCredit_20230602
	FROM bodb02.dbo.BonusWalletCredit bon WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bon.custid

	----copy data bodb02.dbo.BonusWalletDebit
	SELECT  bon.CustID, bon.BonusID, bon.Amount
	INTO BonusWalletDebit_20230602
	FROM bodb02.dbo.BonusWalletDebit bon WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bon.custid

	----copy data bodb02.dbo.BonusWalletPending 
	SELECT  bon.Rn, bon.CustID, bon.BonusID, bon.Amount
	INTO BonusWalletPending_20230602
	FROM bodb02.dbo.BonusWalletPending bon WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bon.custid

	----copy data bodb02.dbo.CashOutSelling
	-- There is no index on custid for table CashOutSelling, has only an index on TransID 
	SELECT	cosell.TransID, cosell.MatchID, cosell.Bettype, cosell.Custid, cosell.CashOutStatus, cosell.Winlost, cosell.PriceInfo, cosell.CheckTime, 
			cosell.CreateDate, cosell.ChangeDate, cosell.IsTest, cosell.VirtualRate, cosell.CashOutExtraInfo
	INTO CashOutSelling_20230602
	FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = cosell.custid

	----copy data bodb02.dbo.CustLimitBet_LIC
	SELECT	clb.Matchid, clb.CustID, clb.AccumTurnover, clb.AccumPayout, clb.EventTypeID, clb.LastQueueID, clb.ModifiedDate
	INTO CustLimitBet_LIC_20230602
	FROM bodb02.dbo.CustLimitBet_LIC clb WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = clb.custid

	----copy data bodb02.dbo.CustLimitBetHistory_LIC
	SELECT	clbh.Matchid, clbh.CustID, clbh.Transid, clbh.TurnoverAdjust, clbh.PayoutAdjust, clbh.EventTypeID, clbh.CreatedDate
	INTO CustLimitBetHistory_LIC_20230602
	FROM bodb02.dbo.CustLimitBetHistory_LIC clbh WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = clbh.custid

	----copy data bodb02.dbo.Task_bettransLC14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettransLC14_IP2Country_20230602
	FROM bodb02.dbo.Task_bettransLC14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransLC14_20230602 b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	----copy data bodb02.dbo.Task_bettransRNG14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettransRNG14_IP2Country_20230602
	FROM bodb02.dbo.Task_bettransRNG14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransRnG14_20230602 b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	/*******************Other tables - TW list**********************/

	----copy data bodb02.dbo.BalancePendingCreditGame 
	SELECT bc.rn, bc.custid, bc.winlostdate, bc.Balance, bc.bettype, bc.GameTypeID
	INTO BalancePendingCreditGame_20230602
	FROM bodb02.dbo.BalancePendingCreditGame bc WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bc.custid

	----copy data bodb02.dbo.BalancePendingDebitGame 
	SELECT bd.rn, bd.custid, bd.winlostdate, bd.Balance, bd.bettype, bd.GameTypeID
	INTO BalancePendingDebitGame_20230602
	FROM bodb02.dbo.BalancePendingDebitGame bd WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = bd.custid  

	----copy data bodb02.dbo.Intg_GameRoundBetStake 
	SELECT igr.VendorId, igr.BetId, igr.GameRound, igr.GameType, igr.BetChoice, igr.CustId, igr.Stake, igr.CreateDate
	INTO Intg_GameRoundBetStake_20230602
	FROM bodb02.dbo.Intg_GameRoundBetStake igr WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = igr.custid

	----copy data bodb02.dbo.LastBetTime
	SELECT lb.custid, lb.transdate
	INTO LastBetTime_20230602
	FROM bodb02.dbo.LastBetTime lb WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = lb.custid

	----copy data bodb02.dbo.LastBetTime_Agent
	SELECT lba.CustID, lba.MatchID, lba.BetType, lba.CustomerClass, lba.Platform, lba.TransDate
	INTO LastBetTime_Agent_20230602
	FROM bodb02.dbo.LastBetTime_Agent lba WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = lba.custid

	----copy data bodb02.dbo.MarkedTransaction
	SELECT mt.TransId, mt.MatchId, mt.CustId, mt.bettype, mt.UserId, mt.CreatedDate, mt.MarkType
	INTO MarkedTransaction_20230602
	FROM bodb02.dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = mt.custid

	----copy data bodb02.dbo.NetPositionCalculationLog
	SELECT	npcl.NPCalculationLogID, npcl.CustID, npcl.MatchID, npcl.Bettype, npcl.AccumNPDebit, npcl.AccumNPCredit, npcl.NPAdjust, 
			npcl.IsLatest, npcl.CreatedDate, npcl.ModifiedDate
	INTO NetPositionCalculationLog_20230602
	FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = npcl.custid

	----copy data bodb02.dbo.NetPositionTrans
	SELECT	npt.TransID, npt.CustID, npt.MatchID, npt.Bettype, npt.Actual_stake, npt.Payout1, npt.Payoutx, npt.Payout2, npt.SyncStatus, 
			npt.isSettled, npt.CreatedDate, npt.ModifiedDate
	INTO NetPositionTrans_20230602
	FROM bodb02.dbo.NetPositionTrans npt WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = npt.custid

	----copy data bodb02.dbo.Task_Cust_CheckBalance_Exception
	SELECT	tce.custid, tce.Remark
	INTO Task_Cust_CheckBalance_Exception_20230602
	FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = tce.custid

	----copy data bodb02.dbo.Task_Cust_BalanceProblem1
	SELECT tcb.UserName, tcb.custid, tcb.DiffBalance, tcb.LogDate, tcb.IsFixed, tcb.Remark
	INTO Task_Cust_BalanceProblem1_20230602 
	FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)
		INNER JOIN Cust12B_20230602 tmp WITH (NOLOCK) 
			ON tmp.custid = tcb.custid


	DROP TABLE #tmp_refno
	
