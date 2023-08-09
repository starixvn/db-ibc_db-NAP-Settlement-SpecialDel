/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230626@Louisa: Migrate data for SiteDB3 - table group 1 [Redmineid:#181595] 
		
*/

---- Note: Run on SITEDB03 only

USE bodb02
GO

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
	FROM DBCTG.SiteDBtmp.dbo.bettrans14_20230626 b WITH (NOLOCK)
	
	--BettransInfo14
	INSERT INTO dbo.BettransInfo14 (transid, SecAcceptTime, LiveBetAcceptTime, OriginalOdds, ThirdTransID)
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.ThirdTransID
	FROM DBCTG.SiteDBtmp.dbo.BettransInfo14_20230626 binfo WITH (NOLOCK)

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
	FROM DBCTG.SiteDBtmp.dbo.bettransm14_20230626 bm WITH (NOLOCK)
	
	--BetParlayDetail
	INSERT INTO dbo.BetParlayDetail 
	(	RefNo, Serial, transid, winlostdate, statuswinlost, statusid, matchid, bettype, stake, odds, betteam, hdp1, hdp2, 
		livehomescore, liveawayscore, liveindicator, betcheck, transdesc
	)
	SELECT	bpd.RefNo, bpd.Serial, bpd.transid, bpd.winlostdate, bpd.statuswinlost, bpd.statusid, bpd.matchid, bpd.bettype, bpd.stake, bpd.odds, bpd.betteam, bpd.hdp1, bpd.hdp2, 
			bpd.livehomescore, bpd.liveawayscore, bpd.liveindicator, bpd.betcheck, bpd.transdesc
	FROM DBCTG.SiteDBtmp.dbo.BetParlayDetail_20230626 bpd WITH (NOLOCK)

	--Task_bettrans14_IP2Country
	INSERT INTO dbo.Task_bettrans14_IP2Country (transid, winlostdate, CountryShort, IPArchive)
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	FROM DBCTG.SiteDBtmp.dbo.Task_bettrans14_IP2Country_20230626 tbip WITH (NOLOCK)



