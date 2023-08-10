/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data - before UM - group 1 [Redmineid:#181595] 

		bet ticket has winlost < 2023-08-13 and related table
		9 tables: 	
			 Bettrans, BettransInfo 
			,BettransLC	,BettransRnG,bettransG,Translog
			,Transfer,Transfer_Coll	,TransferInfo
*/

USE SiteDBtmp
GO

/*	----DROP tables to re-use script for test

	IF OBJECT_ID('Bettrans_BeforeUM') IS NOT NULL 
	DROP TABLE Bettrans_BeforeUM

	IF OBJECT_ID('BettransInfo_BeforeUM') IS NOT NULL 
	DROP TABLE BettransInfo_BeforeUM

	IF OBJECT_ID('BettransLC_BeforeUM') IS NOT NULL 
	DROP TABLE BettransLC_BeforeUM

	IF OBJECT_ID('BettransRnG_BeforeUM') IS NOT NULL 
	DROP TABLE BettransRnG_BeforeUM

	IF OBJECT_ID('bettransG_BeforeUM') IS NOT NULL 
	DROP TABLE bettransG_BeforeUM

	IF OBJECT_ID('Translog_BeforeUM') IS NOT NULL 
	DROP TABLE Translog_BeforeUM

	IF OBJECT_ID('Transfer_BeforeUM') IS NOT NULL 
	DROP TABLE Transfer_BeforeUM

	IF OBJECT_ID('Transfer_Coll_BeforeUM') IS NOT NULL 
	DROP TABLE Transfer_Coll_BeforeUM

	IF OBJECT_ID('TransferInfo_BeforeUM') IS NOT NULL 
	DROP TABLE TransferInfo_BeforeUM

*/

	DECLARE @SiteDBGroupID SMALLINT
			,@winlostDate SMALLDATETIME = '2023-08-13'

	SET @SiteDBGroupID = 3

	--------------------------------------------------------------
	--Copy data bettticket has winlostdate < @winlostDate
	--------------------------------------------------------------

	----copy data bodb02.dbo.bettrans
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, b.winlost, b.awinlost, b.mwinlost, b.playercomm, b.comm, 
			b.acomm, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.playerdiscount, b.discount, b.adiscount, b.livehomescore, b.liveawayscore, 
			b.liveindicator, b.betteam, b.creator, b.refno, b.comstatus, b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.oddsspread, b.actualrate, 
			b.matchid, b.recommend, b.mrecommend, b.ruben, b.betid, b.statuswinlost, b.modds, b.bettype, b.betdaqid, b.actual_stake, b.currency, 
			b.ip, b.transdesc, b.sdiscount, b.scomm, b.spositiontaking, b.swinlost, b.srecommend, b.Username, b.CurrencyName, b.virtualrate, b.oddstype, 
			b.statusID, b.currency2, b.balance, b.SecAcceptFlag, b.transid2, b.recommdate, b.ExtraInfo, b.WalletType, b.BonusID, b.RefCode, b.SettlementTime,
			b.epositiontaking, b.ReasonID, b.sort, b.BetSiteID, b.RepUpdateTime, b.RepDstUpdateTime, @SiteDBGroupID SiteDBGroupID, b.FcUpdateTime
	INTO bettrans_BeforeUM
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate < @winlostDate
		AND b.matchid NOT IN (29, 2799)

	--copy data bodb02.dbo.BettransInfo
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.RepUpdateTime, binfo.ThirdTransID
	INTO BettransInfo_BeforeUM
	FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)
		INNER JOIN dbo.bettrans_BeforeUM b WITH (NOLOCK) 
			ON b.transid = binfo.transid

	----copy data bodb02.dbo.bettransLC
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.SiteID, b.epositiontaking, @SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransLC_BeforeUM
	FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate < @winlostDate

	----copy data bodb02.dbo.bettransRnG
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, b.scomm, 
			b.Transdate3rd, b.SiteID, b.Additional, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.RepUpdateTime
	INTO bettransRnG_BeforeUM
	FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate < @winlostDate

	----copy data bodb02.dbo.bettransG
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			@SiteDBGroupID SiteDBGroupID , b.RepUpdateTime
	INTO bettransG_BeforeUM
	FROM bodb02.dbo.bettransG b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate < @winlostDate

	----copy data bodb02.dbo.translog
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, b.checkCount, b.SiteId, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID, b.LicenseeTransId, b.RepUpdateTime
	INTO translog_BeforeUM
	FROM bodb02.dbo.translog b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate < @winlostDate

	----copy data bodb02.dbo.Transfer
	SELECT  b.TransId, b.CustId, b.TransDate, b.WinlostDate, b.Bettype, b.Stake, b.Actual_Stake, b.Winlost, b.AWinlost, b.MWinlost, b.SWinlost, b.PlayerComm, 
			b.Comm, b.AComm, b.SComm, b.StatusId, b.RefNo, b.TransDesc, b.Recommend, b.MRecommend, b.SRecommend, b.Username, b.Currency, b.CurrencyName, 
			b.ActualRate, b.Creator, b.Balance, b.IP, b.CheckTime, b.SerialNo, b.RepUpdateTime
	INTO Transfer_BeforeUM
	FROM bodb02.dbo.Transfer b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	WHERE b.winlostdate < @winlostDate

	----copy data bodb02.dbo.Transfer_Coll
	SELECT  b.CustId, b.WinlostDate, b.TransDate, b.Bettype, b.Debit, b.Credit, b.Currency, b.ActualRate, b.TransID, b.RefNo, b.Username, 
			b.Recommend, b.MRecommend, b.SRecommend, b.Creator, b.TransDesc, b.IP, b.RepUpdateTime
	INTO Transfer_Coll_BeforeUM
	FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_BeforeUM b1 WITH (NOLOCK) 
			ON b1.TransID = b.TransID

	----copy data bodb02.dbo.TransferInfo
	SELECT  b.TransId, b.APositiontaking, b.MPositiontaking, b.SPositiontaking, b.EPositiontaking, b.PlayerDiscount, b.Discount, b.ADiscount, b.SDiscount, 
			b.WalletType, b.BonusID, b.Amount, b.CheckerId, b.CheckerName, b.IsCollection, b.IsDel, b.RepUpdateTime
	INTO TransferInfo_BeforeUM
	FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_BeforeUM b1 WITH (NOLOCK) 
			ON b1.TransID = b.TransID	
