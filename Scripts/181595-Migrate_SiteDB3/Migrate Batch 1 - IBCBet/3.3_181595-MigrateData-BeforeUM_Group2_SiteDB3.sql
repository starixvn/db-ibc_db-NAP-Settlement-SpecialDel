/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Migrate data for SiteDB3 - before UM - Group 2 [Redmineid:#181595]

		2 tables: 	
			zzzbettrans
			zzzbettransm
*/

---- Note: Run on SITEDB03 only

USE bodb02
GO

	--zzzbettrans
	INSERT INTO dbo.zzzbettrans	
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, 
		VoidingHistoryId, RepUpdateTime, SiteDBGroupID
	)
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, z.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.zzzbettrans_BeforeUM z WITH (NOLOCK)

	--zzzbettransm
	INSERT INTO dbo.zzzbettransm 
	(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, livehomescore, liveawayscore, 
		liveindicator, betteam, creator, refno, comstatus, winlostdate, betfrom, betcheck, checktime, matchid, bettype, 
		VoidingHistoryId, RepUpdateTime, SiteDBGroupID
	)
	SELECT  z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, z.SiteDBGroupID
	FROM DBCTG.SiteDBtmp.dbo.zzzbettransm_BeforeUM z WITH (NOLOCK)
	


































