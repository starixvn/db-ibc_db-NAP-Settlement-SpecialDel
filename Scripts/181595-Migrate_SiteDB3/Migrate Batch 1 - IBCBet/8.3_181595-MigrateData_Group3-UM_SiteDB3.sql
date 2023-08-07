/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - in UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Migrate data for SiteDB3 Batch 1 - Table group 3 [Redmineid:#181595]
		
*/

---- Note: Run on SITEDB03 only


USE bodb02
GO


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






