/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data - UM - Group 3 [Redmineid:#181595] 

		bet ticket has winlost >= 2023-08-13 and other tables

		20 tables:
			Bettrans,BettransInfo,BettransLC,BettransRnG,bettransG,Translog,Transfer
			,Transfer_Coll,TransferInfo
			,BetParlayDetail,BetParlayResult
			,BalNetPosition,CashOutSelling
			,MarkedTransaction,NetPositionCalculationLog,NetPositionTrans
			,CustLimitBet_789,CustLimitBet_MBC
			,CustLimitBetHistory_789,CustLimitBetHistory_MBC
*/

/*
	DROP TABLE Bettrans_UM
	DROP TABLE BettransInfo_UM
	DROP TABLE BettransLC_UM
	DROP TABLE BettransRnG_UM
	DROP TABLE bettransG_UM
	DROP TABLE Translog_UM
	DROP TABLE Transfer_UM
	DROP TABLE Transfer_Coll_UM
	DROP TABLE TransferInfo_UM
	DROP TABLE BetParlayDetail_UM
	DROP TABLE BetParlayResult_UM
	DROP TABLE BalNetPosition_UM
	DROP TABLE CashOutSelling_UM
	DROP TABLE MarkedTransaction_UM
	DROP TABLE NetPositionCalculationLog_UM
	DROP TABLE NetPositionTrans_UM
	DROP TABLE CustLimitBet_789_UM
	DROP TABLE CustLimitBet_MBC_UM
	DROP TABLE CustLimitBetHistory_789_UM
	DROP TABLE CustLimitBetHistory_MBC_UM
*/


---- Table Group 2

USE SiteDBtmp
GO

	DECLARE @SiteDBGroupID SMALLINT
			,@winlostDate SMALLDATETIME = '2023-08-13'
	
	SET @SiteDBGroupID = 3

	CREATE TABLE #tmp_refno
	(
		refno BIGINT PRIMARY KEY
	)

	--------------------------------------------------------------
	--Copy data bettticket has winlostdate >= @winlostDate
	--------------------------------------------------------------

	----copy data bodb02.dbo.bettrans
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, b.winlost, b.awinlost, b.mwinlost, b.playercomm, b.comm, 
			b.acomm, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.playerdiscount, b.discount, b.adiscount, b.livehomescore, b.liveawayscore, 
			b.liveindicator, b.betteam, b.creator, b.refno, b.comstatus, b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.oddsspread, b.actualrate, 
			b.matchid, b.recommend, b.mrecommend, b.ruben, b.betid, b.statuswinlost, b.modds, b.bettype, b.betdaqid, b.actual_stake, b.currency, 
			b.ip, b.transdesc, b.sdiscount, b.scomm, b.spositiontaking, b.swinlost, b.srecommend, b.Username, b.CurrencyName, b.virtualrate, b.oddstype, 
			b.statusID, b.currency2, b.balance, b.SecAcceptFlag, b.transid2, b.recommdate, b.ExtraInfo, b.WalletType, b.BonusID, b.RefCode, b.SettlementTime,
			b.epositiontaking, b.ReasonID, b.sort, b.BetSiteID, b.RepUpdateTime, b.RepDstUpdateTime, @SiteDBGroupID SiteDBGroupID, b.FcUpdateTime
	INTO bettrans_UM
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = b.custid
	WHERE b.winlostdate >= @winlostDate
		OR b.matchid = 29

	----copy data bodb02.dbo.BettransInfo
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.RepUpdateTime, binfo.ThirdTransID
	INTO BettransInfo_UM
	FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)
		INNER JOIN dbo.bettrans_UM b WITH (NOLOCK) 
			ON b.transid = binfo.transid

	----copy data bodb02.dbo.Transfer
	SELECT  b.TransId, b.CustId, b.TransDate, b.WinlostDate, b.Bettype, b.Stake, b.Actual_Stake, b.Winlost, b.AWinlost, b.MWinlost, b.SWinlost, b.PlayerComm, 
			b.Comm, b.AComm, b.SComm, b.StatusId, b.RefNo, b.TransDesc, b.Recommend, b.MRecommend, b.SRecommend, b.Username, b.Currency, b.CurrencyName, 
			b.ActualRate, b.Creator, b.Balance, b.IP, b.CheckTime, b.SerialNo, b.RepUpdateTime
	INTO Transfer_UM
	FROM bodb02.dbo.Transfer b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate >= @winlostDate

	----copy data bodb02.dbo.Transfer_Coll
	SELECT  b.CustId, b.WinlostDate, b.TransDate, b.Bettype, b.Debit, b.Credit, b.Currency, b.ActualRate, b.TransID, b.RefNo, b.Username, 
			b.Recommend, b.MRecommend, b.SRecommend, b.Creator, b.TransDesc, b.IP, b.RepUpdateTime
	INTO Transfer_Coll_UM
	FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_UM b1 WITH (NOLOCK) 
			ON b1.TransID = b.TransID

	----copy data bodb02.dbo.TransferInfo
	SELECT  b.TransId, b.APositiontaking, b.MPositiontaking, b.SPositiontaking, b.EPositiontaking, b.PlayerDiscount, b.Discount, b.ADiscount, b.SDiscount, 
			b.WalletType, b.BonusID, b.Amount, b.CheckerId, b.CheckerName, b.IsCollection, b.IsDel, b.RepUpdateTime
	INTO TransferInfo_UM
	FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_UM b1 WITH (NOLOCK) 
			ON b1.TransID = b.TransID	

	----copy data bodb02.dbo.bettransG
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			@SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransG_UM
	FROM bodb02.dbo.bettransG b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate >= @winlostDate

	----copy data bodb02.dbo.bettransLC
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.SiteID, b.epositiontaking, @SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransLC_UM
	FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate >= @winlostDate

	----copy data bodb02.dbo.bettransRnG
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, 
			b.Transdate3rd, b.SiteID, b.Additional, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.RepUpdateTime
	INTO bettransRnG_UM
	FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate >= @winlostDate

	----copy data bodb02.dbo.translog
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, b.checkCount, b.SiteId, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.LicenseeTransId, b.RepUpdateTime
	INTO translog_UM
	FROM bodb02.dbo.translog b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate >= @winlostDate

	--------------------------------------------------------------
	--Copy all data for remaining tables
	--------------------------------------------------------------

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT b.refno
	FROM dbo.bettrans_BeforeUM b WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM dbo.bettrans14_BeforeUM  WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT b.refno
	FROM dbo.bettrans_UM b WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	----copy data bodb02.dbo.BetParlayDetail
	SELECT	bpd.RefNo, bpd.Serial, bpd.transid, bpd.winlostdate, bpd.statuswinlost, bpd.statusid, bpd.matchid, bpd.bettype, bpd.stake, bpd.odds, bpd.betteam, bpd.hdp1, bpd.hdp2, 
			bpd.livehomescore, bpd.liveawayscore, bpd.liveindicator, bpd.betcheck, bpd.transdesc
	INTO BetParlayDetail_UM
	FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp 
			ON tmp.refno = bpd.refno

	------copy data bodb02.dbo.BetParlayResult
	SELECT	bpr.rID, bpr.RefNo, bpr.Serial, bpr.transid, bpr.winlostdate, bpr.statusid, bpr.stake, bpr.Odds, bpr.mOdds, bpr.winlost, bpr.awinlost, bpr.mwinlost, bpr.swinlost, bpr.playercomm, bpr.comm, bpr.acomm, bpr.scomm
	INTO BetParlayResult_UM
	FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp 
			ON tmp.refno = bpr.refno

	----copy data bodb02.dbo.BalNetPosition
	SELECT bal.CustID, bal.MatchID, bal.Bettype, bal.Debit, bal.Credit, bal.CreatedDate, bal.ModifiedDate
	INTO BalNetPosition_UM
	FROM bodb02.dbo.BalNetPosition bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.CashOutSelling 
	SELECT	cosell.TransID, cosell.MatchID, cosell.Bettype, cosell.Custid, cosell.CashOutStatus, cosell.Winlost, cosell.PriceInfo, cosell.CheckTime, 
			cosell.CreateDate, cosell.ChangeDate, cosell.IsTest, cosell.VirtualRate, cosell.CashOutExtraInfo
	INTO CashOutSelling_UM
	FROM bodb02.dbo.CashOutSelling cosell WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = cosell.custid

	----copy data bodb02.dbo.MarkedTransaction
	SELECT mt.TransId, mt.MatchId, mt.CustId, mt.bettype, mt.UserId, mt.CreatedDate, mt.MarkType
	INTO MarkedTransaction_UM
	FROM bodb02.dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = mt.custid

	----copy data bodb02.dbo.NetPositionCalculationLog
	SELECT	npcl.NPCalculationLogID, npcl.CustID, npcl.MatchID, npcl.Bettype, npcl.AccumNPDebit, npcl.AccumNPCredit, npcl.NPAdjust, 
			npcl.IsLatest, npcl.CreatedDate, npcl.ModifiedDate
	INTO NetPositionCalculationLog_UM
	FROM bodb02.dbo.NetPositionCalculationLog npcl WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = npcl.custid

	----copy data bodb02.dbo.NetPositionTrans
	SELECT	npt.TransID, npt.CustID, npt.MatchID, npt.Bettype, npt.Actual_stake, npt.Payout1, npt.Payoutx, npt.Payout2, npt.SyncStatus, 
			npt.isSettled, npt.CreatedDate, npt.ModifiedDate
	INTO NetPositionTrans_UM
	FROM bodb02.dbo.NetPositionTrans npt WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = npt.custid
	
	----copy data bodb02.dbo.CustLimitBet_789
	SELECT cb.Matchid ,cb.CustID ,cb.AccumTurnover ,cb.AccumPayout ,cb.EventTypeID	,cb.LastQueueID	,cb.ModifiedDate
	INTO CustLimitBet_789_UM
	FROM bodb02.dbo.CustLimitBet_789 cb WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cb.custid
	
	----copy data bodb02.dbo.CustLimitBet_MBC
	SELECT cbm.Matchid , cbm.CustID , cbm.AccumTurnover , cbm.AccumPayout , cbm.EventTypeID	, cbm.LastQueueID	, cbm.ModifiedDate
	INTO CustLimitBet_MBC_UM
	FROM bodb02.dbo.CustLimitBet_MBC cbm WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cbm.custid
	
	----copy data bodb02.dbo.CustLimitBetHistory_789
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate
	INTO CustLimitBetHistory_789_UM
	FROM bodb02.dbo.CustLimitBetHistory_789 cbh  WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cbh.custid

	----copy data bodb02.dbo.CustLimitBetHistory_MBC
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate
	INTO CustLimitBetHistory_MBC_UM
	FROM bodb02.dbo.CustLimitBetHistory_MBC cbh WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = cbh.custid

	DROP TABLE #tmp_refno


























