/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data - before UM - Group 2 [Redmineid:#181595] 
		2 tables: 	
			zzzbettrans
			zzzbettransm
*/

USE SiteDBtmp
GO

/*	----DROP tables to re-use script for test

	DROP TABLE zzzbettrans_BeforeUM
	DROP TABLE zzzbettransm_BeforeUM
	
*/

	DECLARE @SiteDBGroupID SMALLINT
	
	SET @SiteDBGroupID = 3

	----copy data bodb02.dbo.zzzbettrans
	SELECT  z.keyid, z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettrans_BeforeUM
	FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid

	----copy data bodb02.dbo.zzzbettransm
	SELECT  z.keyid, z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettransm_BeforeUM
	FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid