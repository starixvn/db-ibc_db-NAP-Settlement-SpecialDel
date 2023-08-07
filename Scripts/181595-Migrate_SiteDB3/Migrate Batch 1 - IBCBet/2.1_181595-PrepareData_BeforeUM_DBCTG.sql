/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data Batch 1 - before UM Settlement [Redmineid:#181595] 

		bet ticket has winlost < 2023-08-13 and related table
		27 tables: 	
			 Bettrans, BettransInfo 
			,BettransLC	,BettransRnG,bettransG,Translog
			,Transfer,Transfer_Coll	,TransferInfo
			,Bettrans14,BettransInfo14,bettransm14,BettransLC14,BettransRnG14,bettransG14,Translog14
			,Task_bettrans14_IP2Country,Task_bettransRNG14_IP2Country,Task_bettransLC14_IP2Country
			,balanceTable,balanceTable_tmp,BalanceTable_tmp_cal,Task_Cust_CheckBalance_Exception,Task_Cust_BalanceProblem1,ProcessingCustList,Task_Cust_BalanceProblem1_Manually,sum_winloss
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

	IF OBJECT_ID('Bettrans14_BeforeUM') IS NOT NULL 
	DROP TABLE Bettrans14_BeforeUM

	IF OBJECT_ID('Task_bettrans14_IP2Country_BeforeUM') IS NOT NULL 
	DROP TABLE Task_bettrans14_IP2Country_BeforeUM
	
	IF OBJECT_ID('BettransInfo14_BeforeUM') IS NOT NULL 
	DROP TABLE BettransInfo14_BeforeUM

	IF OBJECT_ID('Bettransm14_BeforeUM') IS NOT NULL 
	DROP TABLE Bettransm14_BeforeUM

	IF OBJECT_ID('BettransLC14_BeforeUM') IS NOT NULL 
	DROP TABLE BettransLC14_BeforeUM

	IF OBJECT_ID('Task_bettransLC14_IP2Country_BeforeUM') IS NOT NULL 
	DROP TABLE Task_bettransLC14_IP2Country_BeforeUM

	IF OBJECT_ID('BettransRnG14_BeforeUM') IS NOT NULL 
	DROP TABLE BettransRnG14_BeforeUM

	IF OBJECT_ID('Task_bettransRNG14_IP2Country_BeforeUM') IS NOT NULL 
	DROP TABLE Task_bettransRNG14_IP2Country_BeforeUM

	IF OBJECT_ID('bettransG14_BeforeUM') IS NOT NULL 
	DROP TABLE bettransG14_BeforeUM

	IF OBJECT_ID('Translog14_BeforeUM') IS NOT NULL 
	DROP TABLE Translog14_BeforeUM
	------
	IF OBJECT_ID('balanceTable_BeforeUM') IS NOT NULL 
	DROP TABLE balanceTable_BeforeUM

	IF OBJECT_ID('balanceTable_tmp_BeforeUM') IS NOT NULL 
	DROP TABLE balanceTable_tmp_BeforeUM

	IF OBJECT_ID('BalanceTable_tmp_cal_BeforeUM') IS NOT NULL 
	DROP TABLE BalanceTable_tmp_cal_BeforeUM

	IF OBJECT_ID('Task_Cust_CheckBalance_Exception_BeforeUM') IS NOT NULL 
	DROP TABLE Task_Cust_CheckBalance_Exception_BeforeUM

	IF OBJECT_ID('Task_Cust_BalanceProblem1_BeforeUM') IS NOT NULL 
	DROP TABLE Task_Cust_BalanceProblem1_BeforeUM

	IF OBJECT_ID('ProcessingCustList_BeforeUM') IS NOT NULL 
	DROP TABLE ProcessingCustList_BeforeUM

	IF OBJECT_ID('Task_Cust_BalanceProblem1_Manually_BeforeUM') IS NOT NULL 
	DROP TABLE Task_Cust_BalanceProblem1_Manually_BeforeUM

	IF OBJECT_ID('sum_winloss_BeforeUM') IS NOT NULL 
	DROP TABLE sum_winloss_BeforeUM

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
		AND b.matchid <> 29

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

	--------------------------------------------------------------
	--Copy all data range 14
	--------------------------------------------------------------

	----copy data bodb02.dbo.bettrans14
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, b.winlost, b.awinlost, b.mwinlost, b.playercomm, 
			b.comm, b.acomm, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.playerdiscount, b.discount, b.adiscount, b.livehomescore, 
			b.liveawayscore, b.liveindicator, b.betteam, b.creator, b.refno, b.comstatus, b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.oddsspread, 
			b.actualrate, b.matchid, b.recommend, b.mrecommend, b.ruben, b.betid, b.statuswinlost, b.modds, b.bettype, b.betdaqid, 
			b.actual_stake, b.currency, b.ip, b.transdesc, b.sdiscount, b.scomm, b.spositiontaking, b.swinlost, b.srecommend, b.virtualrate, b.Username, 
			b.CurrencyName, b.oddstype, b.statusID, b.currency2, b.balance, b.SecAcceptFlag, b.transid2, b.recommdate, b.ExtraInfo, b.WalletType, b.BonusID, 
			b.RefCode, b.SettlementTime, b.epositiontaking, b.ReasonID, b.sort, @SiteDBGroupID SiteDBGroupID
	INTO bettrans14_BeforeUM
	FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid
	
	----copy data bodb02.dbo.Task_bettrans14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettrans14_IP2Country_BeforeUM
	FROM bodb02.dbo.Task_bettrans14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_BeforeUM b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	----copy data bodb02.dbo.BettransInfo14
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.ThirdTransID
	INTO BettransInfo14_BeforeUM
	FROM bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)
		INNER JOIN dbo.bettrans14_BeforeUM b WITH (NOLOCK) 
			ON binfo.transid = b.transid 

	----copy data bodb02.dbo.bettransm14
	SELECT  bm.transid, bm.custid, bm.transdate, bm.oddsid, bm.hdp1, bm.hdp2, bm.odds, bm.stake, bm.status, bm.winlost, bm.livehomescore, bm.liveawayscore, 
			bm.liveindicator, bm.betteam, bm.creator, bm.refno, bm.comstatus, bm.winlostdate, bm.betfrom, bm.betcheck, bm.checktime, bm.oddsspread, 
			bm.apositiontaking, bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost, bm.playerdiscount, bm.discount, bm.adiscount, 
			bm.playercomm, bm.comm, bm.acomm, bm.actualrate, bm.matchid, bm.matchdate, bm.finalodds, bm.isfinish, bm.statuswinlost, bm.ruben, bm.bettype, 
			bm.spositiontaking, bm.swinlost, bm.sdiscount, bm.scomm, bm.statusID, bm.recommdate, bm.transdesc, bm.SecAcceptFlag, bm.SecAcceptTime, 
			bm.LiveBetAcceptTime, bm.ReasonIDm, @SiteDBGroupID SiteDBGroupID
	INTO bettransm14_BeforeUM
	FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bm.custid

	----copy data bodb02.dbo.bettransLC14
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, b.acomm, 
			b.scomm, b.Transdate3rd, b.NetStake, b.epositiontaking, b.SiteID, @SiteDBGroupID SiteDBGroupID
	INTO bettransLC14_BeforeUM
	FROM bodb02.dbo.bettransLC14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.Task_bettransLC14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettransLC14_IP2Country_BeforeUM
	FROM bodb02.dbo.Task_bettransLC14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransLC14_BeforeUM b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	----copy data bodb02.dbo.bettransRnG14
	SELECT  b.transid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, 
			b.gameID, b.vendorID, b.GameId3rd, b.TranId3rd, b.RefNo, b.IsSum, b.winlost, b.awinlost, b.mwinlost, b.swinlost, b.playercomm, b.comm, 
			b.acomm, b.scomm, b.Transdate3rd, b.Additional, b.Siteid, b.JackpotInfo, b.RefNo2, b.ContributionRate, b.BetStake, b.ContributionStake3rd, 
			b.epositiontaking, @SiteDBGroupID SiteDBGroupID
	INTO bettransRnG14_BeforeUM
	FROM bodb02.dbo.bettransRnG14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.Task_bettransRNG14_IP2Country
	SELECT	tbip.transid, tbip.winlostdate, tbip.CountryShort, tbip.IPArchive
	INTO Task_bettransRNG14_IP2Country_BeforeUM
	FROM bodb02.dbo.Task_bettransRNG14_IP2Country tbip WITH (NOLOCK)
		INNER JOIN dbo.bettransRnG14_BeforeUM b WITH (NOLOCK) 
			ON b.transid = tbip.transid

	----copy data bodb02.dbo.bettransG14
	SELECT  b.transid, b.custid, b.transdate, b.oddsid, b.odds, b.stake, b.status, b.winlost, b.betteam, b.creator, b.refno, b.winlostdate, b.betfrom, 
			b.checktime, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.awinlost, b.mwinlost, b.playerdiscount, b.discount, b.adiscount, 
			b.playercomm, b.comm, b.acomm, b.actualrate, b.matchid, b.matchdate, b.statuswinlost, b.ruben, b.bettype, b.spositiontaking, b.swinlost, 
			b.sdiscount, b.scomm, b.statusID, b.virtualrate, b.SiteID, b.transdesc, b.BetID3rd, b.epositiontaking, b.actual_stake, b.netstake, 
			@SiteDBGroupID SiteDBGroupID
	INTO bettransG14_BeforeUM
	FROM bodb02.dbo.bettransG14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	----copy data bodb02.dbo.translog14
	SELECT  b.translogid, b.custid, b.transdate, b.odds, b.stake, b.status, b.apositiontaking, b.mpositiontaking, b.tpositiontaking, b.spositiontaking, 
			b.playerdiscount, b.discount, b.adiscount, b.sdiscount, b.creator, b.winlostdate, b.betfrom, b.virtualrate, b.actualrate, b.actual_stake, 
			b.currency, b.CurrencyName, b.recommend, b.mrecommend, b.srecommend, b.ip, b.statusID, b.balance, b.Username, b.transdesc, b.productID, b.gameID, 
			b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, @SiteDBGroupID SiteDBGroupID
	INTO translog14_BeforeUM
	FROM bodb02.dbo.translog14 b WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = b.custid

	------------------------------------------------------------------------------------------------------------
	-- Other table
	------------------------------------------------------------------------------------------------------------

	--copy data bodb02.dbo.balanceTable
	SELECT  bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	INTO balanceTable_BeforeUM
	FROM bodb02.dbo.balanceTable bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.balanceTable_tmp
	SELECT  bal.winlostdate, bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	INTO balanceTable_tmp_BeforeUM
	FROM bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	--copy data bodb02.dbo.BalanceTable_tmp_cal
	SELECT	bal.dow, bal.roleid, bal.custid, bal.recommend, bal.mrecommend, bal.srecommend, 
			bal.amt1, bal.tcnt1, bal.amt2, bal.tcnt2, bal.amt3, bal.tcnt3, bal.amt4, bal.tcnt4
	INTO BalanceTable_tmp_cal_BeforeUM
	FROM bodb02.dbo.BalanceTable_tmp_cal bal WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = bal.custid

	----copy data bodb02.dbo.Task_Cust_CheckBalance_Exception
	SELECT	tce.custid, tce.Remark
	INTO Task_Cust_CheckBalance_Exception_BeforeUM
	FROM bodb02.dbo.Task_Cust_CheckBalance_Exception tce WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = tce.custid

	----copy data bodb02.dbo.Task_Cust_BalanceProblem1
	SELECT tcb.keyid, tcb.UserName, tcb.custid, tcb.DiffBalance, tcb.LogDate, tcb.IsFixed, tcb.Remark
	INTO Task_Cust_BalanceProblem1_BeforeUM
	FROM bodb02.dbo.Task_Cust_BalanceProblem1 tcb WITH (NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK) 
			ON tmp.custid = tcb.custid

	----copy data bodb02.dbo.ProcessingCustList
	SELECT pcl.CustId
	INTO ProcessingCustList_BeforeUM
	FROM bodb02.dbo.ProcessingCustList pcl WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = pcl.custid

	----copy data bodb02.dbo.Task_Cust_BalanceProblem1_Manually
	-- indentity = keyID
	SELECT tp.keyID ,tp.UserName ,tp.custid ,tp.DiffBalance ,tp.LogDate ,tp.IsFixed ,tp.Remark
	INTO Task_Cust_BalanceProblem1_Manually_BeforeUM
	FROM bodb02.dbo.Task_Cust_BalanceProblem1_Manually tp WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = tp.custid

	----Copy data bodb02.dbo.sum_winloss 
	SELECT  sw.keyid, sw.winlostdate, sw.username, sw.custid, sw.roleid, sw.recommend, sw.mrecommend, sw.srecommend, sw.turnover
			,sw.winlost, sw.awinlost, sw.mwinlost, sw.swinlost
			,sw.playercomm, sw.comm, sw.acomm, sw.scomm, sw.BetCount, sw.grosscomm, sw.sporttype, sw.bettype, sw.netTurnover
			,sw.TunroverNoDraw, sw.ExtraWinloss, sw.ExtraComm, sw.leagueGroupID, sw.ticketType
	INTO sum_winloss_BeforeUM
	FROM bodb02.dbo.sum_winloss sw WITH(NOLOCK)
		INNER JOIN CustSiteDB3_20230626 tmp WITH (NOLOCK)
			ON tmp.custid = sw.custid


