/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230918@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230918@Louisa: Migrate missing data - table group 3 [Redmineid:#181595] 
		
*/

---- Note: Run on SITEDB03 only

USE bodb02
GO

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
	FROM DBCTG.SiteDBtmp.dbo.bettransG_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.bettransG s WITH(NOLOCK) 
			ON b.transid = s.transid
	WHERE s.transid IS NULL

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
	FROM DBCTG.SiteDBtmp.dbo.bettransG14_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.bettransG14 s WITH(NOLOCK) 
			ON b.transid = s.transid
	WHERE s.transid IS NULL

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
	FROM DBCTG.SiteDBtmp.dbo.bettransLC_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.bettransLC s WITH(NOLOCK) 
			ON b.transid = s.transid
	WHERE s.transid IS NULL

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
	FROM DBCTG.SiteDBtmp.dbo.bettransLC14_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.bettransLC14 s WITH(NOLOCK) 
			ON b.transid = s.transid
	WHERE s.transid IS NULL

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
	FROM DBCTG.SiteDBtmp.dbo.bettransRnG_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.bettransRnG s WITH(NOLOCK) 
			ON b.transid = s.transid
	WHERE s.transid IS NULL

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
	FROM DBCTG.SiteDBtmp.dbo.bettransRnG14_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.bettransRnG14 s WITH(NOLOCK) 
			ON b.transid = s.transid
	WHERE s.transid IS NULL

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
	FROM DBCTG.SiteDBtmp.dbo.translog_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.translog s WITH(NOLOCK) 
			ON b.translogid = s.translogid
	WHERE s.translogid IS NULL

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
			b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, b.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.translog14_20230626 b WITH (NOLOCK)
		LEFT JOIN dbo.translog14 s WITH(NOLOCK) 
			ON b.translogid = s.translogid
	WHERE s.translogid IS NULL
	
	--BetParlayResult
	INSERT INTO dbo.BetParlayResult (RefNo, Serial, transid, winlostdate, statusid, stake, Odds, mOdds, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm)
	SELECT	bpr.RefNo, bpr.Serial, bpr.transid, bpr.winlostdate, bpr.statusid, bpr.stake, bpr.Odds, bpr.mOdds, bpr.winlost, bpr.awinlost, bpr.mwinlost, bpr.swinlost, bpr.playercomm, bpr.comm, bpr.acomm, bpr.scomm
	FROM DBCTG.SiteDBtmp.dbo.BetParlayResult_20230626 bpr WITH (NOLOCK)
		LEFT JOIN dbo.BetParlayResult s WITH(NOLOCK) 
			ON bpr.refno = s.refno AND bpr.Serial = s.Serial
	WHERE s.refno IS NULL

	--zzzbettrans
	INSERT INTO dbo.zzzbettrans	
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, 
		VoidingHistoryId, RepUpdateTime, SiteDBGroupID
	)
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, z.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.zzzbettrans_20230626 z WITH (NOLOCK)
		LEFT JOIN dbo.zzzbettrans s WITH(NOLOCK) 
			ON z.transid = s.transid
	WHERE s.transid IS NULL

	--zzzbettransm
	INSERT INTO dbo.zzzbettransm 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, 
		VoidingHistoryId, RepUpdateTime, SiteDBGroupID
	)
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, z.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.zzzbettransm_20230626 z WITH (NOLOCK)
		LEFT JOIN dbo.zzzbettrans s WITH(NOLOCK) 
			ON z.transid = s.transid
	WHERE s.transid IS NULL
	
	/********************Tables Balance*************************/
	-- BalCreditCasino
	INSERT INTO dbo.BalCreditCasino (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditCasino_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalCreditCasino s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalCreditOthers
	INSERT INTO dbo.BalCreditOthers (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditOthers_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalCreditOthers s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalCreditSports
	INSERT INTO dbo.BalCreditSports (custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditSports_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalCreditSports s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalCreditTransfer
	INSERT INTO  dbo.BalCreditTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalCreditTransfer_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalCreditTransfer s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalDebitCasino
	INSERT INTO  dbo.BalDebitCasino(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitCasino_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalDebitCasino s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalDebitOthers
	INSERT INTO dbo.BalDebitOthers(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitOthers_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalDebitOthers s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalDebitSports
	INSERT INTO dbo.BalDebitSports(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitSports_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalDebitSports s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalDebitTransfer
	INSERT INTO dbo.BalDebitTransfer(custid, Balance)
	SELECT bal.custid, bal.Balance
	FROM DBCTG.SiteDBtmp.dbo.BalDebitTransfer_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalDebitTransfer s WITH(NOLOCK) 
			ON bal.custid = s.custid
	WHERE s.custid IS NULL

	-- BalNetPosition
	INSERT INTO dbo.BalNetPosition(CustID, MatchID, Bettype, Debit, Credit, CreatedDate, ModifiedDate)
	SELECT bal.CustID, bal.MatchID, bal.Bettype, bal.Debit, bal.Credit, bal.CreatedDate, bal.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.BalNetPosition_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.BalNetPosition s WITH(NOLOCK) 
			ON bal.CustID = s.CustID AND bal.MatchID = s.MatchID AND bal.Bettype = s.Bettype
	WHERE s.custid IS NULL

	-- balanceTable
	INSERT INTO dbo.balanceTable
	(	custid, roleid, amount, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, recommend, mrecommend, 
		srecommend, currency, UserName, CurrencyName, actualrate, TicketCount, balTicketCount
	)
	SELECT  bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	FROM DBCTG.SiteDBtmp.dbo.balanceTable_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.balanceTable s WITH(NOLOCK) 
			ON bal.CustID = s.CustID
	WHERE s.custid IS NULL

	--  balanceTable_tmp
	INSERT INTO dbo.balanceTable_tmp
	(	winlostdate, custid, roleid, amount, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, recommend, mrecommend, 
		srecommend, currency, UserName, CurrencyName, actualrate, TicketCount, balTicketCount
	)
	SELECT  bal.winlostdate, bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	FROM DBCTG.SiteDBtmp.dbo.balanceTable_tmp_20230626 bal WITH (NOLOCK)
		LEFT JOIN dbo.balanceTable_tmp s WITH(NOLOCK) 
			ON bal.CustID = s.CustID
	WHERE s.custid IS NULL


	/*******************Other Tables**********************/ 

	-- dbo.CashOutSelling
	INSERT INTO dbo.CashOutSelling 
	(	TransID, MatchID, Bettype, Custid, CashOutStatus, Winlost, PriceInfo, CheckTime, 
		CreateDate, ChangeDate, IsTest, VirtualRate, CashOutExtraInfo
	)
	SELECT	cosell.TransID, cosell.MatchID, cosell.Bettype, cosell.Custid, cosell.CashOutStatus, cosell.Winlost, cosell.PriceInfo, cosell.CheckTime, 
			cosell.CreateDate, cosell.ChangeDate, cosell.IsTest, cosell.VirtualRate, cosell.CashOutExtraInfo
	FROM DBCTG.SiteDBtmp.dbo.CashOutSelling_20230626 cosell WITH (NOLOCK)
		LEFT JOIN dbo.CashOutSelling s WITH(NOLOCK) 
			ON cosell.TransID = s.TransID
	WHERE s.TransID IS NULL

	-- dbo.Task_bettransLC14_IP2Country
	INSERT INTO dbo.Task_bettransLC14_IP2Country (transid, winlostdate, CountryShort, IPArchive)
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	FROM DBCTG.SiteDBtmp.dbo.Task_bettransLC14_IP2Country_20230626 tbip WITH (NOLOCK)
		LEFT JOIN dbo.Task_bettransLC14_IP2Country s WITH(NOLOCK) 
			ON tbip.TransID = s.TransID
	WHERE s.TransID IS NULL

	-- dbo.Task_bettransRNG14_IP2Country
	INSERT INTO dbo.Task_bettransRNG14_IP2Country (transid, winlostdate, CountryShort, IPArchive)
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	FROM DBCTG.SiteDBtmp.dbo.Task_bettransRNG14_IP2Country_20230626 tbip WITH (NOLOCK)
		LEFT JOIN dbo.Task_bettransLC14_IP2Country s WITH(NOLOCK) 
			ON tbip.TransID = s.TransID
	WHERE s.TransID IS NULL
 
	-- dbo.MarkedTransaction
	INSERT INTO dbo.MarkedTransaction (TransId, MatchId, CustId, bettype, UserId, CreatedDate, MarkType)
	SELECT mt.TransId, mt.MatchId, mt.CustId, mt.bettype, mt.UserId, mt.CreatedDate, mt.MarkType
	FROM DBCTG.SiteDBtmp.dbo.MarkedTransaction_20230626 mt WITH (NOLOCK)
		LEFT JOIN dbo.MarkedTransaction s WITH(NOLOCK) 
			ON mt.TransID = s.TransID AND mt.MatchId = s.MatchId
	WHERE s.TransID IS NULL

	-- dbo.NetPositionTrans
	INSERT INTO dbo.NetPositionTrans (	TransID, CustID, MatchID, Bettype, Actual_stake, Payout1, Payoutx, Payout2, SyncStatus, 
											isSettled, CreatedDate, ModifiedDate)
	SELECT	npt.TransID, npt.CustID, npt.MatchID, npt.Bettype, npt.Actual_stake, npt.Payout1, npt.Payoutx, npt.Payout2, npt.SyncStatus, 
			npt.isSettled, npt.CreatedDate, npt.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.NetPositionTrans_20230626 npt WITH (NOLOCK)
		LEFT JOIN dbo.NetPositionTrans s WITH(NOLOCK) 
			ON npt.TransID = s.TransID
	WHERE s.TransID IS NULL

	-- dbo.Task_Cust_CheckBalance_Exception
	INSERT INTO dbo.Task_Cust_CheckBalance_Exception (custid, Remark)
	SELECT	tce.custid, tce.Remark
	FROM DBCTG.SiteDBtmp.dbo.Task_Cust_CheckBalance_Exception_20230626 tce WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT TOP (1) 1 FROM Task_Cust_CheckBalance_Exception a WITH (NOLOCK) WHERE a.custid = tce.custid)
	 
	-- dbo.CustLimitBet_789
	INSERT INTO CustLimitBet_789 ( Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate )
	SELECT cb.Matchid ,cb.CustID ,cb.AccumTurnover ,cb.AccumPayout ,cb.EventTypeID	,cb.LastQueueID	,cb.ModifiedDate
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBet_789_20230626 cb WITH (NOLOCK)
		LEFT JOIN dbo.CustLimitBet_789 s WITH(NOLOCK) 
			ON cb.Matchid = s.Matchid AND cb.CustID = s.CustID AND cb.EventTypeID = s.EventTypeID
	WHERE s.Matchid IS NULL
	
	-- dbo.CustLimitBet_MBC
	INSERT INTO CustLimitBet_MBC ( Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate )
	SELECT cbm.Matchid, cbm.CustID, cbm.AccumTurnover, cbm.AccumPayout, cbm.EventTypeID, cbm.LastQueueID, cbm.ModifiedDate 
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBet_MBC_20230626 cbm WITH (NOLOCK) 
		LEFT JOIN dbo.CustLimitBet_MBC s WITH(NOLOCK) 
			ON cbm.Matchid = s.Matchid AND cbm.CustID = s.CustID AND cbm.EventTypeID = s.EventTypeID
	WHERE s.Matchid IS NULL
	
	-- dbo.CustLimitBetHistory_789
	INSERT INTO CustLimitBetHistory_789 ( Matchid, CustID, Transid , TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate 
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBetHistory_789_20230626 cbh WITH (NOLOCK) 
		LEFT JOIN dbo.CustLimitBetHistory_789 s WITH(NOLOCK) 
			ON cbh.Matchid = s.Matchid AND cbh.CustID = s.CustID AND cbh.transid = s.transid AND cbh.CreatedDate = s.CreatedDate
	WHERE s.Matchid IS NULL

	-- dbo.CustLimitBetHistory_MBC
	INSERT INTO CustLimitBetHistory_MBC ( Matchid, CustID, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
	SELECT cbh.Matchid ,cbh.CustID ,cbh.Transid ,cbh.TurnoverAdjust ,cbh.PayoutAdjust ,cbh.EventTypeID ,cbh.CreatedDate 
	FROM DBCTG.SiteDBtmp.dbo.CustLimitBetHistory_MBC_20230626 cbh WITH (NOLOCK) 
		LEFT JOIN dbo.CustLimitBetHistory_MBC s WITH(NOLOCK) 
			ON cbh.Matchid = s.Matchid AND cbh.CustID = s.CustID AND cbh.transid = s.transid AND cbh.CreatedDate = s.CreatedDate
	WHERE s.Matchid IS NULL

	-- dbo.ProcessingCustList
	INSERT INTO ProcessingCustList (CustId)
	SELECT pcl.CustId 
	FROM DBCTG.SiteDBtmp.dbo.ProcessingCustList_20230626 pcl WITH(NOLOCK) 
		LEFT JOIN dbo.ProcessingCustList s WITH(NOLOCK) 
			ON pcl.CustID = s.CustID
	WHERE s.CustID IS NULL



	

