/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230626@Louisa:Prepare data to migrate - table group 1 [Redmineid:#181595] 
		
*/

----5 tables: BetParlayDetail,bettrans14,BettransInfo14,bettransm14,Task_bettrans14_IP2Country

USE SiteDBtmp
GO

/* ----DROP tables to re-use script for test
	
	IF OBJECT_ID('tempdb..#tmp_refno') IS NOT NULL
		DROP TABLE #tmp_refno

	IF OBJECT_ID('bettrans14_20230626') IS NOT NULL 
		DROP TABLE bettrans14_20230626

	IF OBJECT_ID('BettransInfo14_20230626') IS NOT NULL 
		DROP TABLE BettransInfo14_20230626

	IF OBJECT_ID('bettransm14_20230626') IS NOT NULL 
		DROP TABLE bettransm14_20230626

	IF OBJECT_ID('BetParlayDetail_20230626') IS NOT NULL 
		DROP TABLE BetParlayDetail_20230626

	IF OBJECT_ID('Task_bettrans14_IP2Country_20230626') IS NOT NULL 
		DROP TABLE Task_bettrans14_IP2Country_20230626

*/

	DECLARE @SiteDBGroupID SMALLINT
	DECLARE @debug_message VARCHAR(500)
	
	SET @SiteDBGroupID = 3

	CREATE TABLE #tmp_refno
	(
		refno BIGINT PRIMARY KEY
	)

	----copy data bodb02.dbo.bettrans14
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, b.winlost, b.awinlost, b.mwinlost, b.playercomm, 
			b.comm, b.acomm, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.playerdiscount, b.discount, b.adiscount, b.livehomescore, 
			b.liveawayscore, b.liveindicator, b.betteam, b.creator, b.refno, b.comstatus, b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.oddsspread, 
			b.actualrate, b.matchid, b.recommend, b.mrecommend, b.ruben, b.betid, b.statuswinlost, b.modds, b.bettype, b.betdaqid, 
			b.actual_stake, b.currency, b.ip, b.transdesc, b.sdiscount, b.scomm, b.spositiontaking, b.swinlost, b.srecommend, b.virtualrate, b.Username, 
			b.CurrencyName, b.oddstype, b.statusID, b.currency2, b.balance, b.SecAcceptFlag, b.transid2, b.recommdate, b.ExtraInfo, b.WalletType, b.BonusID, 
			b.RefCode, b.SettlementTime, b.epositiontaking, b.ReasonID, b.sort, @SiteDBGroupID SiteDBGroupID
	INTO bettrans14_20230626
	FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.BettransInfo14
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.ThirdTransID
	INTO BettransInfo14_20230626
	FROM bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_20230626 b WITH (NOLOCK) 
			ON binfo.transid = b.transid 

	----copy data bodb02.dbo.bettransm14
	SELECT  bm.transid, bm.custid, bm.transdate, bm.oddsid, bm.hdp1, bm.hdp2, bm.odds, bm.stake, bm.status, bm.winlost, bm.livehomescore, bm.liveawayscore, 
			bm.liveindicator, bm.betteam, bm.creator, bm.refno, bm.comstatus, bm.winlostdate, bm.betfrom, bm.betcheck, bm.checktime, bm.oddsspread, 
			bm.apositiontaking, bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost, bm.playerdiscount, bm.discount, bm.adiscount, 
			bm.playercomm, bm.comm, bm.acomm, bm.actualrate, bm.matchid, bm.matchdate, bm.finalodds, bm.isfinish, bm.statuswinlost, bm.ruben, bm.bettype, 
			bm.spositiontaking, bm.swinlost, bm.sdiscount, bm.scomm, bm.statusID, bm.recommdate, bm.transdesc, bm.SecAcceptFlag, bm.SecAcceptTime, 
			bm.LiveBetAcceptTime, bm.ReasonIDm, @SiteDBGroupID SiteDBGroupID
	INTO bettransm14_20230626
	FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bm.custid

	--#tmp_refno
	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT b.refno
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM dbo.bettrans14_20230626  WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29
	
	----copy data bodb02.dbo.BetParlayDetail
	SELECT	bpd.RefNo, bpd.Serial, bpd.transid, bpd.winlostdate, bpd.statuswinlost, bpd.statusid, bpd.matchid, bpd.bettype, bpd.stake, bpd.odds, bpd.betteam, bpd.hdp1, bpd.hdp2, 
			bpd.livehomescore, bpd.liveawayscore, bpd.liveindicator, bpd.betcheck, bpd.transdesc
	INTO BetParlayDetail_20230626
	FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp 
			ON tmp.refno = bpd.refno

	----copy data bodb02.dbo.Task_bettrans14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettrans14_IP2Country_20230626
	FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_20230626 b WITH (NOLOCK) 
			ON b.transid = tbip.transid


	DROP TABLE #tmp_refno



	
