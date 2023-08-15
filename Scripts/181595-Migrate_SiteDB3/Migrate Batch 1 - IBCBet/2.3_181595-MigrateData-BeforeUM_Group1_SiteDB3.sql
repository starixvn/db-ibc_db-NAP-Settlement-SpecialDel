/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - before UM - Group 1 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Migrate data for SiteDB3 - before UM - Group 1 [Redmineid:#181595]

		9 tables: 	
			 Bettrans, BettransInfo 
			,BettransLC	,BettransRnG,bettransG,Translog
			,Transfer,Transfer_Coll	,TransferInfo 
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

	--BettransInfo
	INSERT INTO dbo.BettransInfo (transid, SecAcceptTime, LiveBetAcceptTime, OriginalOdds, RepUpdateTime, ThirdTransID)
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.RepUpdateTime, binfo.ThirdTransID
	FROM DBCTG.SiteDBtmp.dbo.BettransInfo_BeforeUM binfo WITH (NOLOCK)

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
	
	























