/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - in UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Migrate data for SiteDB3 - Batch 1 - in UM Settlement [Redmineid:#181595]
		
*/

---- Note: Run on SITEDB03 only

USE bodb02
GO

	--------------------------------------------------------------
	-- insert data bettticket has winlostdate >= '2023-08-14'
	--------------------------------------------------------------

	--bettrans
	INSERT INTO dbo.bettrans 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, comm, 
		acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, 
		matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, 
		ip, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, Username, CurrencyName, virtualrate, oddstype, 
		statusID, currency2, balance, SecAcceptFlag, transid2, recommdate, ExtraInfo, WalletType, BonusID, RefCode, SettlementTime,
		epositiontaking, ReasonID, sort, BetSiteID, RepUpdateTime, RepDstUpdateTime, SiteDBGroupID, FcUpdateTime
	)
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, b.winlost, b.awinlost, b.mwinlost, b.playercomm, b.comm, 
			b.acomm, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.playerdiscount, b.discount, b.adiscount, b.livehomescore, b.liveawayscore, 
			b.liveindicator, b.betteam, b.creator, b.refno, b.comstatus, b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.oddsspread, b.actualrate, 
			b.matchid, b.recommend, b.mrecommend, b.ruben, b.betid, b.statuswinlost, b.modds, b.bettype, b.betdaqid, b.actual_stake, b.currency, 
			b.ip, b.transdesc, b.sdiscount, b.scomm, b.spositiontaking, b.swinlost, b.srecommend, b.Username, b.CurrencyName, b.virtualrate, b.oddstype, 
			b.statusID, b.currency2, b.balance, b.SecAcceptFlag, b.transid2, b.recommdate, b.ExtraInfo, b.WalletType, b.BonusID, b.RefCode, b.SettlementTime,
			b.epositiontaking, b.ReasonID, b.sort, b.BetSiteID, b.RepUpdateTime, b.RepDstUpdateTime, b.SiteDBGroupID, b.FcUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.bettrans_UM b WITH (NOLOCK)

	--bettransm
	INSERT INTO dbo.bettransm 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, apositiontaking, 
		mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount, playercomm, comm, acomm, 
		actualrate, matchid, matchdate, finalodds, isfinish, statuswinlost, ruben, bettype, spositiontaking, swinlost, sdiscount, 
		scomm, statusID, recommdate, transdesc, SecAcceptFlag, SecAcceptTime, LiveBetAcceptTime, ReasonIDm, RepUpdateTime, SiteDBGroupID
	)
	SELECT  bm.transid, bm.custid, bm.transdate, bm.oddsid, bm.hdp1, bm.hdp2, bm.odds, bm.stake, bm.status, bm.winlost, bm.livehomescore, bm.liveawayscore, 
			bm.liveindicator, bm.betteam, bm.creator, bm.refno, bm.comstatus, bm.winlostdate, bm.betfrom, bm.betcheck, bm.checktime, bm.oddsspread, bm.apositiontaking, 
			bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost, bm.playerdiscount, bm.discount, bm.adiscount, bm.playercomm, bm.comm, bm.acomm, 
			bm.actualrate, bm.matchid, bm.matchdate, bm.finalodds, bm.isfinish, bm.statuswinlost, bm.ruben, bm.bettype, bm.spositiontaking, bm.swinlost, bm.sdiscount, 
			bm.scomm, bm.statusID, bm.recommdate, bm.transdesc, bm.SecAcceptFlag, bm.SecAcceptTime, bm.LiveBetAcceptTime, bm.ReasonIDm, bm.RepUpdateTime, bm.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettransm_UM bm WITH (NOLOCK)

	--bettransLC
	INSERT INTO dbo.bettransLC 
	(	transid, custid, transdate, odds, stake, status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, 
		playerdiscount, discount, adiscount, sdiscount, creator, winlostdate, betfrom, virtualrate, actualrate, actual_stake, 
		currency, CurrencyName, recommend, mrecommend, srecommend, ip, statusID, balance, Username, transdesc, productID, 
		gameID, vendorID, GameId3rd, TranId3rd, RefNo, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, 
		scomm, Transdate3rd, NetStake, SiteID, epositiontaking, SiteDBGroupID, RepUpdateTime
	)
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.SiteID, b.epositiontaking, b.SiteDBGroupID , b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.bettransLC_UM b WITH (NOLOCK)

	--bettransRnG
	INSERT INTO dbo.bettransRnG 
	(	transid, custid, transdate, odds, stake, status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, 
		playerdiscount, discount, adiscount, sdiscount, creator, winlostdate, betfrom, virtualrate, actualrate, actual_stake, 
		currency, CurrencyName, recommend, mrecommend, srecommend, ip, statusID, balance, Username, transdesc, productID, gameID, 
		vendorID, GameId3rd, TranId3rd, RefNo, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, 
		Transdate3rd, SiteID, Additional, JackpotInfo, RefNo2, ContributionRate, BetStake, ContributionStake3rd, 
		epositiontaking, SiteDBGroupID, RepUpdateTime
	)
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, 
			b.Transdate3rd, b.SiteID, b.Additional, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, b.SiteDBGroupID, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.bettransRnG_UM b WITH (NOLOCK)

	--bettransG
	INSERT INTO dbo.bettransG 
	(	transid, custid, transdate, oddsid, odds, stake, status, winlost, betteam, creator, refno, winlostdate, betfrom, 
		checktime, apositiontaking, mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount, 
		playercomm, comm, acomm, actualrate, matchid, matchdate, statuswinlost, ruben, bettype, spositiontaking, swinlost, 
		sdiscount, scomm, statusID, virtualrate, SiteID, transdesc, BetID3rd, epositiontaking, actual_stake, netstake, 
		SiteDBGroupID, RepUpdateTime
	)
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			b.SiteDBGroupID , b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.bettransG_UM b WITH (NOLOCK)

	--translog
	INSERT INTO dbo.translog	
	(	translogid, custid, transdate, odds, stake, status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, 
		playerdiscount, discount, adiscount, sdiscount, creator, winlostdate, betfrom, virtualrate, actualrate, actual_stake, 
		currency, CurrencyName, recommend, mrecommend, srecommend, ip, statusID, balance, Username, transdesc, productID, 
		gameID, eventID, vendorID, GameId3rd, TranId3rd, custom1, custom2, custom3, LiveIndicator, checkCount, SiteId, 
		epositiontaking, SiteDBGroupID, LicenseeTransId, RepUpdateTime
	)
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, b.checkCount, b.SiteId, 
			b.epositiontaking, b.SiteDBGroupID, b.LicenseeTransId, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.translog_UM b WITH (NOLOCK)

	--Transfer
	INSERT INTO dbo.Transfer	
	(	TransId, CustId, TransDate, WinlostDate, Bettype, Stake, Actual_Stake, Winlost, AWinlost, MWinlost, SWinlost, PlayerComm, 
		Comm, AComm, SComm, StatusId, RefNo, TransDesc, Recommend, MRecommend, SRecommend, Username, Currency, CurrencyName, 
		ActualRate, Creator, Balance, IP, CheckTime, SerialNo, RepUpdateTime
	)
	SELECT  b.TransId, b.CustId, b.TransDate, b.WinlostDate, b.Bettype, b.Stake, b.Actual_Stake, b.Winlost, b.AWinlost, b.MWinlost, b.SWinlost, b.PlayerComm, 
			b.Comm, b.AComm, b.SComm, b.StatusId, b.RefNo, b.TransDesc, b.Recommend, b.MRecommend, b.SRecommend, b.Username, b.Currency, b.CurrencyName, 
			b.ActualRate, b.Creator, b.Balance, b.IP, b.CheckTime, b.SerialNo, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.Transfer_UM b WITH (NOLOCK)

	--Transfer_Coll
	INSERT INTO dbo.Transfer_Coll	
	(	CustId, WinlostDate, TransDate, Bettype, Debit, Credit, Currency, ActualRate, TransID, RefNo, Username, 
		Recommend, MRecommend, SRecommend, Creator, TransDesc, IP, RepUpdateTime
	)
	SELECT  b.CustId, b.WinlostDate, b.TransDate, b.Bettype, b.Debit, b.Credit, b.Currency, b.ActualRate, b.TransID, b.RefNo, b.Username, 
			b.Recommend, b.MRecommend, b.SRecommend, b.Creator, b.TransDesc, b.IP, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.Transfer_Coll_UM b WITH (NOLOCK)

	--TransferInfo
	INSERT INTO dbo.TransferInfo
	(	TransId, APositiontaking, MPositiontaking, SPositiontaking, EPositiontaking, PlayerDiscount, Discount, ADiscount, SDiscount, 
		WalletType, BonusID, Amount, CheckerId, CheckerName, IsCollection, IsDel, RepUpdateTime
	)
	SELECT  b.TransId, b.APositiontaking, b.MPositiontaking, b.SPositiontaking, b.EPositiontaking, b.PlayerDiscount, b.Discount, b.ADiscount, b.SDiscount, 
			b.WalletType, b.BonusID, b.Amount, b.CheckerId, b.CheckerName, b.IsCollection, b.IsDel, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.TransferInfo_UM b WITH (NOLOCK)

	--bettransm
	INSERT INTO dbo.bettransm 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, apositiontaking, 
		mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount, playercomm, comm, acomm, 
		actualrate, matchid, matchdate, finalodds, isfinish, statuswinlost, ruben, bettype, spositiontaking, swinlost, sdiscount, 
		scomm, statusID, recommdate, transdesc, SecAcceptFlag, SecAcceptTime, LiveBetAcceptTime, ReasonIDm, RepUpdateTime, SiteDBGroupID
	)
	SELECT  bm.transid, bm.custid, bm.transdate, bm.oddsid, bm.hdp1, bm.hdp2, bm.odds, bm.stake, bm.status, bm.winlost, bm.livehomescore, bm.liveawayscore, 
			bm.liveindicator, bm.betteam, bm.creator, bm.refno, bm.comstatus, bm.winlostdate, bm.betfrom, bm.betcheck, bm.checktime, bm.oddsspread, bm.apositiontaking, 
			bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost, bm.playerdiscount, bm.discount, bm.adiscount, bm.playercomm, bm.comm, bm.acomm, 
			bm.actualrate, bm.matchid, bm.matchdate, bm.finalodds, bm.isfinish, bm.statuswinlost, bm.ruben, bm.bettype, bm.spositiontaking, bm.swinlost, bm.sdiscount, 
			bm.scomm, bm.statusID, bm.recommdate, bm.transdesc, bm.SecAcceptFlag, bm.SecAcceptTime, bm.LiveBetAcceptTime, bm.ReasonIDm, bm.RepUpdateTime, bm.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettransm_UM bm WITH (NOLOCK)

	--zzzbettrans
	INSERT INTO dbo.zzzbettrans	
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, 
		VoidingHistoryId, RepUpdateTime, SiteDBGroupID
	)
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, z.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.zzzbettrans_UM z WITH (NOLOCK)

	--zzzbettransm
	INSERT INTO dbo.zzzbettransm 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, 
		VoidingHistoryId, RepUpdateTime, SiteDBGroupID
	)
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, z.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.zzzbettransm_UM z WITH (NOLOCK)
	
	------------------------------------------------------------------------------------------
	--insert data 8 table balances
	------------------------------------------------------------------------------------------

	-- BalDebitCasino
	INSERT INTO  dbo.BalDebitCasino(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitCasino_UM bal WITH (NOLOCK)

	-- BalDebitOthers
	INSERT INTO dbo.BalDebitOthers(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitOthers_UM bal WITH (NOLOCK)

	-- BalDebitSports
	INSERT INTO dbo.BalDebitSports(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitSports_UM bal WITH (NOLOCK)

	-- BalDebitTransfer
	INSERT INTO dbo.BalDebitTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitTransfer_UM bal WITH (NOLOCK)

	-- BalCreditCasino
	INSERT INTO dbo.BalCreditCasino (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditCasino_UM bal WITH (NOLOCK)

	-- BalCreditOthers
	INSERT INTO dbo.BalCreditOthers (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditOthers_UM bal WITH (NOLOCK)

	-- BalCreditSports
	INSERT INTO dbo.BalCreditSports (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditSports_UM bal WITH (NOLOCK)

	-- BalCreditTransfer
	INSERT INTO  dbo.BalCreditTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditTransfer_UM bal WITH (NOLOCK)

	--------------------------------------------------------------
	--insert for remaining tables
	--------------------------------------------------------------

	--BetParlayDetail
	INSERT INTO dbo.BetParlayDetail 
	(	RefNo, Serial, transid, winlostdate, statuswinlost, statusid, matchid, bettype, stake, odds, betteam, hdp1, hdp2, 
		livehomescore, liveawayscore, liveindicator, betcheck, transdesc
	)
	SELECT	bpd.RefNo, bpd.Serial, bpd.transid, bpd.winlostdate, bpd.statuswinlost, bpd.statusid, bpd.matchid, bpd.bettype, bpd.stake, bpd.odds, bpd.betteam, bpd.hdp1, bpd.hdp2, 
			bpd.livehomescore, bpd.liveawayscore, bpd.liveindicator, bpd.betcheck, bpd.transdesc
	FROM DBCTG.SiteDBtmp.dbo.BetParlayDetail_UM bpd WITH (NOLOCK)

	--BetParlayResult
	INSERT INTO dbo.BetParlayResult (RefNo, Serial, transid, winlostdate, statusid, stake, Odds, mOdds, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm)
	SELECT	bpr.RefNo, bpr.Serial, bpr.transid, bpr.winlostdate, bpr.statusid, bpr.stake, bpr.Odds, bpr.mOdds, bpr.winlost, bpr.awinlost, bpr.mwinlost, bpr.swinlost, bpr.playercomm, bpr.comm, bpr.acomm, bpr.scomm
	FROM DBCTG.SiteDBtmp.dbo.BetParlayResult_UM bpr WITH (NOLOCK)

	-- BalNetPosition
	INSERT INTO dbo.BalNetPosition(CustID, MatchID, Bettype, Debit, Credit, CreatedDate, ModifiedDate)
	SELECT bal.CustID, bal.MatchID, bal.Bettype, bal.Debit, bal.Credit, bal.CreatedDate, bal.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.BalNetPosition_UM bal WITH (NOLOCK)

	-- dbo.CashOutSelling
	INSERT INTO dbo.CashOutSelling 
	(	TransID, MatchID, Bettype, Custid, CashOutStatus, Winlost, PriceInfo, CheckTime, 
		CreateDate, ChangeDate, IsTest, VirtualRate, CashOutExtraInfo
	)
	SELECT	cosell.TransID, cosell.MatchID, cosell.Bettype, cosell.Custid, cosell.CashOutStatus, cosell.Winlost, cosell.PriceInfo, cosell.CheckTime, 
			cosell.CreateDate, cosell.ChangeDate, cosell.IsTest, cosell.VirtualRate, cosell.CashOutExtraInfo
	FROM DBCTG.SiteDBtmp.dbo.CashOutSelling_UM cosell WITH (NOLOCK)

	-- dbo.MarkedTransaction
	INSERT INTO dbo.MarkedTransaction (TransId, MatchId, CustId, bettype, UserId, CreatedDate, MarkType)
	SELECT mt.TransId, mt.MatchId, mt.CustId, mt.bettype, mt.UserId, mt.CreatedDate, mt.MarkType
	FROM DBCTG.SiteDBtmp.dbo.MarkedTransaction_UM mt WITH (NOLOCK)

	-- dbo.NetPositionCalculationLog
	SET IDENTITY_INSERT NetPositionCalculationLog ON

	INSERT INTO dbo.NetPositionCalculationLog (	NPCalculationLogID, CustID, MatchID, Bettype, AccumNPDebit, AccumNPCredit, NPAdjust, 
													IsLatest, CreatedDate, ModifiedDate)
	SELECT	npcl.NPCalculationLogID, npcl.CustID, npcl.MatchID, npcl.Bettype, npcl.AccumNPDebit, npcl.AccumNPCredit, npcl.NPAdjust, 
			npcl.IsLatest, npcl.CreatedDate, npcl.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.NetPositionCalculationLog_UM npcl WITH (NOLOCK)

	SET IDENTITY_INSERT NetPositionCalculationLog OFF

	-- dbo.NetPositionTrans
	INSERT INTO dbo.NetPositionTrans (	TransID, CustID, MatchID, Bettype, Actual_stake, Payout1, Payoutx, Payout2, SyncStatus, 
											isSettled, CreatedDate, ModifiedDate)
	SELECT	npt.TransID, npt.CustID, npt.MatchID, npt.Bettype, npt.Actual_stake, npt.Payout1, npt.Payoutx, npt.Payout2, npt.SyncStatus, 
			npt.isSettled, npt.CreatedDate, npt.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.NetPositionTrans_UM npt WITH (NOLOCK)

	-- dbo.CustLimitBet_789
	INSERT INTO CustLimitBet_789 ( Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate )
	SELECT cb.Matchid ,cb.CustID ,cb.AccumTurnover ,cb.AccumPayout ,cb.EventTypeID	,cb.LastQueueID	,cb.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBet_789_UM cb WITH (NOLOCK) 
	
	-- dbo.CustLimitBet_MBC
	INSERT INTO CustLimitBet_MBC ( Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate )
	SELECT cbm.Matchid, cbm.CustID, cbm.AccumTurnover, cbm.AccumPayout, cbm.EventTypeID, cbm.LastQueueID, cbm.ModifiedDate 
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBet_MBC_UM cbm WITH (NOLOCK) 
	
	-- dbo.CustLimitBetHistory_789
	INSERt INTO CustLimitBetHistory_789 ( Matchid, CustID, Transid , TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate 
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBetHistory_789_UM cbh WITH (NOLOCK) 

	-- dbo.CustLimitBetHistory_MBC
	INSERT INTO CustLimitBetHistory_MBC ( Matchid, CustID, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate 
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBetHistory_MBC_UM cbh WITH (NOLOCK) 














