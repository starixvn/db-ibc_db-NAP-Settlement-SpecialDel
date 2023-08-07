/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595]

		27 tables: 	
			 Bettrans, BettransInfo 
			,BettransLC	,BettransRnG,bettransG,Translog
			,Transfer,Transfer_Coll	,TransferInfo  
			,BalDebitOthers	,BalDebitSports	,BalDebitTransfer,BalCreditCasino,BalCreditOthers,BalCreditSports,BalCreditTransfer	,BalDebitCasino
			,Bettrans14,BettransInfo14,bettransm14,BettransLC14,BettransRnG14,bettransG14,Translog14
			,Task_bettrans14_IP2Country,Task_bettransRNG14_IP2Country,Task_bettransLC14_IP2Country
			,balanceTable,balanceTable_tmp,BalanceTable_tmp_cal,Task_Cust_CheckBalance_Exception,Task_Cust_BalanceProblem1,ProcessingCustList,Task_Cust_BalanceProblem1_Manually,sum_winloss
*/

---- Note: Run on SITEDB03 only

USE bodb02
GO

	--------------------------------------------------------------
	-- insert data bettticket has winlostdate < '2023-08-13'
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
	FROM DBCTG.SiteDBtmp.dbo.bettrans_BeforeUM b WITH (NOLOCK)

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
	FROM DBCTG.SiteDBtmp.dbo.bettransLC_BeforeUM b WITH (NOLOCK)

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
	FROM DBCTG.SiteDBtmp.dbo.bettransRnG_BeforeUM b WITH (NOLOCK)

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
	FROM DBCTG.SiteDBtmp.dbo.bettransG_BeforeUM b WITH (NOLOCK)

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
	FROM DBCTG.SiteDBtmp.dbo.translog_BeforeUM b WITH (NOLOCK)

	--Transfer
	INSERT INTO dbo.Transfer	
	(	TransId, CustId, TransDate, WinlostDate, Bettype, Stake, Actual_Stake, Winlost, AWinlost, MWinlost, SWinlost, PlayerComm, 
		Comm, AComm, SComm, StatusId, RefNo, TransDesc, Recommend, MRecommend, SRecommend, Username, Currency, CurrencyName, 
		ActualRate, Creator, Balance, IP, CheckTime, SerialNo, RepUpdateTime
	)
	SELECT  b.TransId, b.CustId, b.TransDate, b.WinlostDate, b.Bettype, b.Stake, b.Actual_Stake, b.Winlost, b.AWinlost, b.MWinlost, b.SWinlost, b.PlayerComm, 
			b.Comm, b.AComm, b.SComm, b.StatusId, b.RefNo, b.TransDesc, b.Recommend, b.MRecommend, b.SRecommend, b.Username, b.Currency, b.CurrencyName, 
			b.ActualRate, b.Creator, b.Balance, b.IP, b.CheckTime, b.SerialNo, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.Transfer_BeforeUM b WITH (NOLOCK)

	--Transfer_Coll
	INSERT INTO dbo.Transfer_Coll	
	(	CustId, WinlostDate, TransDate, Bettype, Debit, Credit, Currency, ActualRate, TransID, RefNo, Username, 
		Recommend, MRecommend, SRecommend, Creator, TransDesc, IP, RepUpdateTime
	)
	SELECT  b.CustId, b.WinlostDate, b.TransDate, b.Bettype, b.Debit, b.Credit, b.Currency, b.ActualRate, b.TransID, b.RefNo, b.Username, 
			b.Recommend, b.MRecommend, b.SRecommend, b.Creator, b.TransDesc, b.IP, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.Transfer_Coll_BeforeUM b WITH (NOLOCK)

	--TransferInfo
	INSERT INTO dbo.TransferInfo
	(	TransId, APositiontaking, MPositiontaking, SPositiontaking, EPositiontaking, PlayerDiscount, Discount, ADiscount, SDiscount, 
		WalletType, BonusID, Amount, CheckerId, CheckerName, IsCollection, IsDel, RepUpdateTime
	)
	SELECT  b.TransId, b.APositiontaking, b.MPositiontaking, b.SPositiontaking, b.EPositiontaking, b.PlayerDiscount, b.Discount, b.ADiscount, b.SDiscount, 
			b.WalletType, b.BonusID, b.Amount, b.CheckerId, b.CheckerName, b.IsCollection, b.IsDel, b.RepUpdateTime
	FROM DBCTG.SiteDBtmp.dbo.TransferInfo_BeforeUM b WITH (NOLOCK)
	
	--------------------------------------------------------------
	--insert all data range 14
	--------------------------------------------------------------

	--bettrans14
	INSERT INTO dbo.bettrans14 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost, playercomm, 
		comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount, discount, adiscount, livehomescore, 
		liveawayscore, liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, 
		actualrate, matchid, recommend, mrecommend, ruben, betid, statuswinlost, modds, bettype, betdaqid, 
		actual_stake, currency, ip, transdesc, sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, Username, 
		CurrencyName, oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, recommdate, ExtraInfo, WalletType, BonusID, 
		RefCode, SettlementTime, epositiontaking, ReasonID, sort, SiteDBGroupID
	)
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, b.winlost, b.awinlost, b.mwinlost, b.playercomm, 
			b.comm, b.acomm, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.playerdiscount, b.discount, b.adiscount, b.livehomescore, 
			b.liveawayscore, b.liveindicator, b.betteam, b.creator, b.refno, b.comstatus, b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.oddsspread, 
			b.actualrate, b.matchid, b.recommend, b.mrecommend, b.ruben, b.betid, b.statuswinlost, b.modds, b.bettype, b.betdaqid, 
			b.actual_stake, b.currency, b.ip, b.transdesc, b.sdiscount, b.scomm, b.spositiontaking, b.swinlost, b.srecommend, b.virtualrate, b.Username, 
			b.CurrencyName, b.oddstype, b.statusID, b.currency2, b.balance, b.SecAcceptFlag, b.transid2, b.recommdate, b.ExtraInfo, b.WalletType, b.BonusID, 
			b.RefCode, b.SettlementTime, b.epositiontaking, b.ReasonID, b.sort, b.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettrans14_BeforeUM b WITH (NOLOCK)
	
	--BettransInfo14
	INSERT INTO dbo.BettransInfo14 (transid, SecAcceptTime, LiveBetAcceptTime, OriginalOdds, ThirdTransID)
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.ThirdTransID
	FROM DBCTG.SiteDBtmp.dbo.BettransInfo14_BeforeUM binfo WITH (NOLOCK)

	--bettransm14
	INSERT INTO dbo.bettransm14		
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, oddsspread, 
		apositiontaking, mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount, 
		playercomm, comm, acomm, actualrate, matchid, matchdate, finalodds, isfinish, statuswinlost, ruben, bettype, 
		spositiontaking, swinlost, sdiscount, scomm, statusID, recommdate, transdesc, SecAcceptFlag, SecAcceptTime, 
		LiveBetAcceptTime, ReasonIDm, SiteDBGroupID
	)
	SELECT  bm.transid, bm.custid, bm.transdate, bm.oddsid, bm.hdp1, bm.hdp2, bm.odds, bm.stake, bm.status, bm.winlost, bm.livehomescore, bm.liveawayscore, 
			bm.liveindicator, bm.betteam, bm.creator, bm.refno, bm.comstatus, bm.winlostdate, bm.betfrom, bm.betcheck, bm.checktime, bm.oddsspread, 
			bm.apositiontaking, bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost, bm.playerdiscount, bm.discount, bm.adiscount, 
			bm.playercomm, bm.comm, bm.acomm, bm.actualrate, bm.matchid, bm.matchdate, bm.finalodds, bm.isfinish, bm.statuswinlost, bm.ruben, bm.bettype, 
			bm.spositiontaking, bm.swinlost, bm.sdiscount, bm.scomm, bm.statusID, bm.recommdate, bm.transdesc, bm.SecAcceptFlag, bm.SecAcceptTime, 
			bm.LiveBetAcceptTime, bm.ReasonIDm, bm.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettransm14_BeforeUM bm WITH (NOLOCK)

	--bettransLC14
	INSERT INTO dbo.bettransLC14	
	(	transid, custid, transdate, odds, stake, status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, 
		playerdiscount, discount, adiscount, sdiscount, creator, winlostdate, betfrom, virtualrate, actualrate, actual_stake, 
		currency, CurrencyName, recommend, mrecommend, srecommend, ip, statusID, balance, Username, transdesc, productID, 
		gameID, vendorID, GameId3rd, TranId3rd, RefNo, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, 
		scomm, Transdate3rd, NetStake, epositiontaking, SiteID, SiteDBGroupID
	)
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.epositiontaking, b.SiteID, b.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettransLC14_BeforeUM b WITH (NOLOCK)

	--bettransRnG14
	INSERT INTO dbo.bettransRnG14 
	(	transid, custid, transdate, odds, stake, status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, 
		playerdiscount, discount, adiscount, sdiscount, creator, winlostdate, betfrom, virtualrate, actualrate, actual_stake, 
		currency, CurrencyName, recommend, mrecommend, srecommend, ip, statusID, balance, Username, transdesc, productID, 
		gameID, vendorID, GameId3rd, TranId3rd, RefNo, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, 
		acomm, scomm, Transdate3rd, Additional, Siteid, JackpotInfo, RefNo2, ContributionRate, BetStake, ContributionStake3rd, 
		epositiontaking, SiteDBGroupID
	)
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, 
			b.acomm, b.scomm, b.Transdate3rd, b.Additional, b.Siteid, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, b.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettransRnG14_BeforeUM b WITH (NOLOCK)

	--bettransG14
	INSERT INTO dbo.bettransG14 
	(	transid, custid, transdate, oddsid, odds, stake, status, winlost, betteam, creator, refno, winlostdate, betfrom, 
		checktime, apositiontaking, mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount, 
		playercomm, comm, acomm, actualrate, matchid, matchdate, statuswinlost, ruben, bettype, spositiontaking, swinlost, 
		sdiscount, scomm, statusID, virtualrate, SiteID, transdesc, BetID3rd, epositiontaking, actual_stake, netstake, 
		SiteDBGroupID
	)
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			b.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.bettransG14_BeforeUM b WITH (NOLOCK)

	--translog14
	INSERT INTO dbo.translog14	
	(	translogid, custid, transdate, odds, stake, status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, 
		playerdiscount, discount, adiscount, sdiscount, creator, winlostdate, betfrom, virtualrate, actualrate, actual_stake, 
		currency, CurrencyName, recommend, mrecommend, srecommend, ip, statusID, balance, Username, transdesc, productID, gameID, 
		eventID, vendorID, GameId3rd, TranId3rd, custom1, custom2, custom3, LiveIndicator, SiteDBGroupID
	)
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID,
			b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.translog14_BeforeUM b WITH (NOLOCK)

	--Task_bettrans14_IP2Country
	INSERT INTO dbo.Task_bettrans14_IP2Country (transid, winlostdate, CountryShort, IPArchive)
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	FROM DBCTG.SiteDBtmp.dbo.Task_bettrans14_IP2Country_BeforeUM tbip WITH (NOLOCK)

	-- dbo.Task_bettransRNG14_IP2Country
	INSERT INTO dbo.Task_bettransRNG14_IP2Country (transid, winlostdate, CountryShort, IPArchive)
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	FROM DBCTG.SiteDBtmp.dbo.Task_bettransRNG14_IP2Country_BeforeUM tbip WITH (NOLOCK)
	
	-- dbo.Task_bettransLC14_IP2Country
	INSERT INTO dbo.Task_bettransLC14_IP2Country (transid, winlostdate, CountryShort, IPArchive)
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	FROM DBCTG.SiteDBtmp.dbo.Task_bettransLC14_IP2Country_BeforeUM tbip WITH (NOLOCK)

	------------------------------------------------------------------------------------------
	--insert for others tables
	------------------------------------------------------------------------------------------

	-- balanceTable
	INSERT INTO dbo.balanceTable
	(	custid, roleid, amount, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, recommend, mrecommend, 
		srecommend, currency, UserName, CurrencyName, actualrate, TicketCount, balTicketCount
	)
	SELECT  bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	FROM DBCTG.SiteDBtmp.dbo.balanceTable_BeforeUM bal WITH (NOLOCK)

	--  balanceTable_tmp
	INSERT INTO dbo.balanceTable_tmp
	(	winlostdate, custid, roleid, amount, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, recommend, mrecommend, 
		srecommend, currency, UserName, CurrencyName, actualrate, TicketCount, balTicketCount
	)
	SELECT  bal.winlostdate, bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	FROM DBCTG.SiteDBtmp.dbo.balanceTable_tmp_BeforeUM bal WITH (NOLOCK)

	-- BalanceTable_tmp_cal
	INSERT INTO dbo.BalanceTable_tmp_cal 
	(	dow, roleid, custid, recommend, mrecommend, srecommend, 
		amt1, tcnt1, amt2, tcnt2, amt3, tcnt3, amt4, tcnt4
		)
	SELECT	bal.dow, bal.roleid, bal.custid, bal.recommend, bal.mrecommend, bal.srecommend, 
			bal.amt1, bal.tcnt1, bal.amt2, bal.tcnt2, bal.amt3, bal.tcnt3, bal.amt4, bal.tcnt4
	FROM DBCTG.SiteDBtmp.dbo.BalanceTable_tmp_cal_BeforeUM bal WITH (NOLOCK)

	-- dbo.Task_Cust_CheckBalance_Exception
	INSERT INTO dbo.Task_Cust_CheckBalance_Exception (custid, Remark)
	SELECT	tce.custid, tce.Remark
	FROM DBCTG.SiteDBtmp.dbo.Task_Cust_CheckBalance_Exception_BeforeUM tce WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT TOP (1) 1 FROM Task_Cust_CheckBalance_Exception a WITH (NOLOCK) WHERE a.custid = tce.custid)

	-- bodb02.dbo.Task_Cust_BalanceProblem1
	--SET IDENTITY_INSERT Task_Cust_BalanceProblem1 ON

	INSERT INTO dbo.Task_Cust_BalanceProblem1 (UserName, custid, DiffBalance, LogDate, IsFixed, Remark)
	SELECT tcb.UserName, tcb.custid, tcb.DiffBalance, tcb.LogDate, tcb.IsFixed, tcb.Remark
	FROM DBCTG.SiteDBtmp.dbo.Task_Cust_BalanceProblem1_BeforeUM tcb WITH (NOLOCK)

	-- dbo.ProcessingCustList
	INSERT INTO ProcessingCustList (CustId)
	SELECT pcl.CustId 
	FROM DBCTG.SiteDBtmp.dbo.ProcessingCustList_BeforeUM pcl WITH(NOLOCK) 

	-- dbo.Task_Cust_BalanceProblem1_Manually
	-- indentity = keyID
	SET IDENTITY_INSERT Task_Cust_BalanceProblem1_Manually ON

	INSERT INTO Task_Cust_BalanceProblem1_Manually ( keyID, UserName, custid, DiffBalance, LogDate, IsFixed, Remark)
	SELECT tp.keyID ,tp.UserName ,tp.custid ,tp.DiffBalance ,tp.LogDate ,tp.IsFixed ,tp.Remark 
	FROM DBCTG.SiteDBtmp.dbo.Task_Cust_BalanceProblem1_Manually_BeforeUM tp WITH(NOLOCK) 
	
	SET IDENTITY_INSERT Task_Cust_BalanceProblem1_Manually OFF

	-- dbo.sum_winloss
	SET IDENTITY_INSERT sum_winloss ON

	INSERT INTO sum_winloss ( keyid,winlostdate,username,custid,roleid,recommend,mrecommend,srecommend,turnover
			,winlost,awinlost,mwinlost,swinlost
			,playercomm,comm,acomm,scomm,BetCount,grosscomm,sporttype,bettype,netTurnover
			,TunroverNoDraw,ExtraWinloss,ExtraComm,leagueGroupID,ticketType )
	SELECT  keyid,winlostdate,username,custid,roleid,recommend,mrecommend,srecommend,turnover
			,winlost,awinlost,mwinlost,swinlost
			,playercomm,comm,acomm,scomm,BetCount,grosscomm,sporttype,bettype,netTurnover
			,TunroverNoDraw,ExtraWinloss,ExtraComm,leagueGroupID,ticketType
	FROM DBCTG.SiteDBtmp.dbo.sum_winloss_BeforeUM sw WITH(NOLOCK) 
	
	SET IDENTITY_INSERT sum_winloss OFF
	


































