/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data - UM - Group 3 [Redmineid:#181595] 

*/

/*
	DROP TABLE bettransm_UM
	DROP TABLE zzzbettrans_UM
	DROP TABLE zzzbettransm_UM

*/

USE SiteDBtmp
GO

	DECLARE @SiteDBGroupID			SMALLINT
			,@MaxKey_zzzbettrans	INT
			,@MaxKey_zzzbettransm	INT
	
	SET @SiteDBGroupID = 3

	----copy data bodb02.dbo.bettransm
	SELECT  bm.transid, bm.custid, bm.transdate, bm.oddsid, bm.hdp1, bm.hdp2, bm.odds, bm.stake, bm.status, bm.winlost, bm.livehomescore, bm.liveawayscore, 
			bm.liveindicator, bm.betteam, bm.creator, bm.refno, bm.comstatus, bm.winlostdate, bm.betfrom, bm.betcheck, bm.checktime, bm.oddsspread, bm.apositiontaking, 
			bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost, bm.playerdiscount, bm.discount, bm.adiscount, bm.playercomm, bm.comm, bm.acomm, 
			bm.actualrate, bm.matchid, bm.matchdate, bm.finalodds, bm.isfinish, bm.statuswinlost, bm.ruben, bm.bettype, bm.spositiontaking, bm.swinlost, bm.sdiscount, 
			bm.scomm, bm.statusID, bm.recommdate, bm.transdesc, bm.SecAcceptFlag, bm.SecAcceptTime, bm.LiveBetAcceptTime, bm.ReasonIDm, bm.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO bettransm_UM
	FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bm.custid


	----copy data bodb02.dbo.zzzbettrans
	SELECT @MaxKey_zzzbettrans = ( SELECT MAX(keyid) FROM dbo.zzzbettrans_beforeUM WITH(NOLOCK) )

	SELECT  z.keyid, z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettrans_UM
	FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid
	WHERE z.keyid > @MaxKey_zzzbettrans

	----copy data bodb02.dbo.zzzbettransm
	SELECT @MaxKey_zzzbettransm = ( SELECT MAX(keyid) FROM dbo.zzzbettransm_beforeUM WITH(NOLOCK) )

	SELECT  z.keyid, z.transid, z.custid, z.transdate, z.oddsid, z.hdp1, z.hdp2, z.odds, z.stake, z.status, z.winlost, z.livehomescore, z.liveawayscore, 
			z.liveindicator, z.betteam, z.creator, z.refno, z.comstatus, z.winlostdate, z.betfrom, z.betcheck, z.checktime, z.matchid, z.bettype, 
			z.VoidingHistoryId, z.RepUpdateTime, @SiteDBGroupID SiteDBGroupID
	INTO zzzbettransm_UM
	FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = z.custid
	WHERE z.keyid > @MaxKey_zzzbettransm