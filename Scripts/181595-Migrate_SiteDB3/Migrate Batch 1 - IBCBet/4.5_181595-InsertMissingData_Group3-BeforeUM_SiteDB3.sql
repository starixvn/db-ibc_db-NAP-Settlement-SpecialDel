/*<info serverAlias="DBSIC-bodb02" EXECuters="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Insert missing data - before UM - Group 3  [Redmineid:#181595]

		14 tables: 
			1) Bettrans14	
			2) BettransInfo14	
			3) bettransm14	
			4) BettransLC14	
			5) BettransRnG14	
			6) bettransG14	
			7) Translog14	
			8) Task_bettrans14_IP2Country	
			9) Task_bettransRNG14_IP2Country	
			10) Task_bettransLC14_IP2Country	
			11) balanceTable_tmp	
			12) sum_winloss
*/

USE bodb02
GO

DECLARE @TableName NVARCHAR(50) = '' --input table name
		,@__sqlCmd NVARCHAR(max) = ''



DROP TABLE IF exists #transid --Bettrans14,BettransInfo14,bettransm14,BettransLC14,BettransRnG14,bettransG14,Translog14	,Task_bettrans14_IP2Country	,Task_bettransRNG14_IP2Country,Task_bettransLC14_IP2Country	
DROP TABLE IF exists #custid --balanceTable_tmp
DROP TABLE IF exists #keyid--sum_winloss

CREATE TABLE #transid (TransId INT PRIMARY KEY)
CREATE TABLE #custid (custid INT PRIMARY KEY)
CREATE TABLE #keyid (keyid INT PRIMARY KEY)

IF @TableName IN ( 'Bettrans14'
					,'BettransInfo14'
					,'bettransm14'
					,'BettransLC14'
					,'BettransRnG14'
					,'bettransG14'	
					,'Task_bettrans14_IP2Country'	
					,'Task_bettransRNG14_IP2Country'
					,'Task_bettransLC14_IP2Country'
				)
BEGIN
	SET @__sqlCmd = N'SELECT b.transid
					FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
					INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
					LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_beforeUM t WITH(NOLOCK)  ON b.transid = t.transid
					WHERE t.transid IS NULL '
	
	SELECT @__sqlCmd

	INSERT INTO #transid (TransId )
	EXEC DBCTG.bodb02.sys.sp_executesql @__sqlCmd

	SELECT * FROM #transid

	IF @@ROWCOUNT = 0
	RETURN

	----bettrans14
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
	FROM DBCTG.bodb02.dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN #transid t ON b.transid = t.TransId

	--BettransInfo14
	INSERT INTO dbo.BettransInfo14 (transid, SecAcceptTime, LiveBetAcceptTime, OriginalOdds, ThirdTransID)
	SELECT binfo.transid, binfo.SecAcceptTime, binfo.LiveBetAcceptTime, binfo.OriginalOdds, binfo.ThirdTransID
	FROM DBCTG.bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)
		INNER JOIN #transid t ON binfo.transid = t.TransId

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
	FROM DBCTG.bodb02.dbo.bettransm14 bm WITH (NOLOCK)
		INNER JOIN #transid t ON bm.transid = t.TransId

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
	FROM DBCTG.bodb02.dbo.bettransLC14 b WITH (NOLOCK)
		INNER JOIN #transid t ON b.transid = t.TransId

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
	FROM DBCTG.bodb02.dbo.bettransRnG14 b WITH (NOLOCK)
		INNER JOIN #transid t ON b.transid = t.TransId

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
	FROM DBCTG.bodb02.dbo.bettransG14 b WITH (NOLOCK)
		INNER JOIN #transid t ON b.transid = t.TransId

END


IF @TableName = 'Translog14'
BEGIN
	SET @__sqlCmd = N'SELECT b.translogid
					FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
					INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
					LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_beforeUM t WITH(NOLOCK)  ON b.translogid = t.translogid
					WHERE t.translogid IS NULL '
	
	SELECT @__sqlCmd

	INSERT INTO #transid (TransId )
	EXEC DBCTG.bodb02.sys.sp_executesql @__sqlCmd

	SELECT * FROM #transid

	IF @@ROWCOUNT = 0
	RETURN

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
			b.eventID, b.vendorID, b.GameId3rd, b.TranId3rd, b.custom1, b.custom2, b.custom3, b.LiveIndicator, SiteDBGroupID
	FROM DBCTG.bodb02.dbo.translog14 b WITH (NOLOCK)
		INNER JOIN #transid t ON b.translogid = t.TransId

END


IF @TableName = 'balanceTable_tmp'
BEGIN
	SET @__sqlCmd = N'SELECT b.custid
					FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
					INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
					LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_beforeUM t WITH(NOLOCK)  ON b.custid = t.custid
					WHERE t.custid IS NULL '
	
	SELECT @__sqlCmd

	INSERT INTO #custid (custid )
	EXEC DBCTG.bodb02.sys.sp_executesql @__sqlCmd

	SELECT * FROM #custid

	IF @@ROWCOUNT = 0
	RETURN

	--  balanceTable_tmp
	INSERT INTO dbo.balanceTable_tmp
	(	winlostdate, custid, roleid, amount, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, recommend, mrecommend, 
		srecommend, currency, UserName, CurrencyName, actualrate, TicketCount, balTicketCount
	)
	SELECT  bal.winlostdate, bal.custid, bal.roleid, bal.amount, bal.awinlost, bal.mwinlost, bal.swinlost, bal.playercomm, bal.comm, bal.acomm, bal.scomm, bal.recommend, bal.mrecommend, 
			bal.srecommend, bal.currency, bal.UserName, bal.CurrencyName, bal.actualrate, bal.TicketCount, bal.balTicketCount
	FROM DBCTG.bodb02.dbo.balanceTable_tmp bal WITH (NOLOCK)
		INNER JOIN #custid c ON bal.custid = c.custid

END


IF @TableName IN ( 'sum_winloss')
BEGIN
	SET @__sqlCmd = N'SELECT b.custid
				FROM bodb02.dbo.' + @TableName + ' b WITH(NOLOCK)
				INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c  WITH(NOLOCK) ON c.custid = b.custid
				LEFT JOIN SiteDBtmp.dbo.' + @TableName + '_beforeUM t WITH(NOLOCK)  ON b.keyid = t.keyid
				WHERE t.keyid IS NULL '
	
	SELECT @__sqlCmd

	INSERT INTO #keyid (keyid )
	EXEC DBCTG.bodb02.sys.sp_executesql @__sqlCmd

	SELECT * FROM #keyid

	IF @@ROWCOUNT = 0
	RETURN

	-- dbo.sum_winloss
	SET IDENTITY_INSERT sum_winloss ON

	INSERT INTO sum_winloss ( keyid,winlostdate,username,custid,roleid,recommend,mrecommend,srecommend,turnover
			,winlost,awinlost,mwinlost,swinlost
			,playercomm,comm,acomm,scomm,BetCount,grosscomm,sporttype,bettype,netTurnover
			,TunroverNoDraw,ExtraWinloss,ExtraComm,leagueGroupID,ticketType )
	SELECT  sw.keyid,sw.winlostdate,sw.username,sw.custid,sw.roleid,sw.recommend,sw.mrecommend,sw.srecommend,sw.turnover
			,sw.winlost,sw.awinlost,sw.mwinlost,sw.swinlost
			,sw.playercomm,sw.comm,sw.acomm,sw.scomm,sw.BetCount,sw.grosscomm,sw.sporttype,sw.bettype,sw.netTurnover
			,sw.TunroverNoDraw,sw.ExtraWinloss,sw.ExtraComm,sw.leagueGroupID,sw.ticketType
	FROM DBCTG.bodb02.dbo.sum_winloss sw WITH(NOLOCK)
		INNER JOIN #keyid k ON sw.keyid = k.keyid
	
	SET IDENTITY_INSERT sum_winloss OFF

END



