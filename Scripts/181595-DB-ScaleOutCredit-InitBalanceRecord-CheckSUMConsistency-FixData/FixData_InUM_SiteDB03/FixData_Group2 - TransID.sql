--Group 2 - In UM - fix data
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: fix data on sitedb03 [Redmineid:#181595] 

		1) Bettrans
		2) BettransInfo
		3) BettransLC
		4) BettransRnG
		5) bettransG
		6) Translog
		7) Transfer
		8) Transfer_Coll
		9) TransferInfo

*/
----------correct tickets---------------------------------
/* find text and replace by list of wrong recommends for table need to fix data
1) Bettrans -> bettrans_TransIDList
2) BettransInfo -> bettransInfo_TransIDList
3) BettransLC -> bettransLC_TransIDList
4) BettransRnG -> bettransRnG_TransIDList
5) bettransG -> bettransG_TransIDList
6) Translog -> Translog_translogidList
7) Transfer -> Transfer_transidList
8) Transfer_Coll -> Transfer_Coll_recommendList
9) TransferInfo -> Transfer_Coll_transidList

*/
BEGIN--------1) bettrans  --------------------------------------

	SELECT * 
	INTO #temp_bettrans 
	FROM DBCTG.bodb02.dbo.bettrans  WITH (NOLOCK)
	WHERE transid IN (bettrans_TransIDList)

	UPDATE b 
		SET
			[custid]	=	g.[custid],
			[transdate]	=	g.[transdate],
			[oddsid]	=	g.[oddsid],
			[hdp1]	=	g.[hdp1],
			[hdp2]	=	g.[hdp2],
			[odds]	=	g.[odds],
			[stake]	=	g.[stake],
			[status]	=	g.[status],
			[winlost]	=	g.[winlost],
			[awinlost]	=	g.[awinlost],
			[mwinlost]	=	g.[mwinlost],
			[playercomm]	=	g.[playercomm],
			[comm]	=	g.[comm],
			[acomm]	=	g.[acomm],
			[apositiontaking]	=	g.[apositiontaking],
			[mpositiontaking]	=	g.[mpositiontaking],
			[tpositiontaking]	=	g.[tpositiontaking],
			[playerdiscount]	=	g.[playerdiscount],
			[discount]	=	g.[discount],
			[adiscount]	=	g.[adiscount],
			[livehomescore]	=	g.[livehomescore],
			[liveawayscore]	=	g.[liveawayscore],
			[liveindicator]	=	g.[liveindicator],
			[betteam]	=	g.[betteam],
			[creator]	=	g.[creator],
			[refno]	=	g.[refno],
			[comstatus]	=	g.[comstatus],
			[winlostdate]	=	g.[winlostdate],
			[betfrom]	=	g.[betfrom],
			[betcheck]	=	g.[betcheck],
			[checktime]	=	g.[checktime],
			[oddsspread]	=	g.[oddsspread],
			[actualrate]	=	g.[actualrate],
			[matchid]	=	g.[matchid],
			[recommend]	=	g.[recommend],
			[mrecommend]	=	g.[mrecommend],
			[ruben]	=	g.[ruben],
			[betid]	=	g.[betid],
			[statuswinlost]	=	g.[statuswinlost],
			[modds]	=	g.[modds],
			[bettype]	=	g.[bettype],
			[betdaqid]	=	g.[betdaqid],
			[actual_stake]	=	g.[actual_stake],
			[currency]	=	g.[currency],
			[ip]	=	g.[ip],
			[transdesc]	=	g.[transdesc],
			[sdiscount]	=	g.[sdiscount],
			[scomm]	=	g.[scomm],
			[spositiontaking]	=	g.[spositiontaking],
			[swinlost]	=	g.[swinlost],
			[srecommend]	=	g.[srecommend],
			[Username]	=	g.[Username],
			[CurrencyName]	=	g.[CurrencyName],
			[virtualrate]	=	g.[virtualrate],
			[oddstype]	=	g.[oddstype],
			[statusID]	=	g.[statusID],
			[currency2]	=	g.[currency2],
			[balance]	=	g.[balance],
			[SecAcceptFlag]	=	g.[SecAcceptFlag],
			[transid2]	=	g.[transid2],
			[recommdate]	=	g.[recommdate],
			[ExtraInfo]	=	g.[ExtraInfo],
			[WalletType]	=	g.[WalletType],
			[BonusID]	=	g.[BonusID],
			[RefCode]	=	g.[RefCode],
			[epositiontaking]	=	g.[epositiontaking],
			[ReasonID]	=	g.[ReasonID],
			[sort]	=	g.[sort],
			[BetSiteID]	=	g.[BetSiteID]

	FROM bettrans b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_bettrans g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (bettrans_TransIDList)

END
BEGIN--------2) bettransInfo  --------------------------------------
	SELECT * 
	INTO #temp_bettransInfo
	FROM DBCTG.bodb02.dbo.bettransInfo  WITH (NOLOCK)
	WHERE transid IN (bettransInfo_TransIDList)

	UPDATE b	
		SET 
		[SecAcceptTime]	=	g.[SecAcceptTime],
		[LiveBetAcceptTime]	=	g.[LiveBetAcceptTime],
		[OriginalOdds]	=	g.[OriginalOdds],
		[ThirdTransID]	=	g.[ThirdTransID]

	FROM bettransInfo b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_bettransInfo g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (bettransInfo_TransIDList)

END

BEGIN--------3) bettransLC  --------------------------------------
	SELECT * 
	INTO #temp_bettransLC
	FROM DBCTG.bodb02.dbo.bettransLC  WITH (NOLOCK)
	WHERE transid IN (bettransLC_TransIDList)

	UPDATE b 
		SET
			[custid]	=	g.[custid],
			[transdate]	=	g.[transdate],
			[odds]	=	g.[odds],
			[stake]	=	g.[stake],
			[status]	=	g.[status],
			[apositiontaking]	=	g.[apositiontaking],
			[mpositiontaking]	=	g.[mpositiontaking],
			[tpositiontaking]	=	g.[tpositiontaking],
			[spositiontaking]	=	g.[spositiontaking],
			[playerdiscount]	=	g.[playerdiscount],
			[discount]	=	g.[discount],
			[adiscount]	=	g.[adiscount],
			[sdiscount]	=	g.[sdiscount],
			[creator]	=	g.[creator],
			[winlostdate]	=	g.[winlostdate],
			[betfrom]	=	g.[betfrom],
			[virtualrate]	=	g.[virtualrate],
			[actualrate]	=	g.[actualrate],
			[actual_stake]	=	g.[actual_stake],
			[currency]	=	g.[currency],
			[CurrencyName]	=	g.[CurrencyName],
			[recommend]	=	g.[recommend],
			[mrecommend]	=	g.[mrecommend],
			[srecommend]	=	g.[srecommend],
			[ip]	=	g.[ip],
			[statusID]	=	g.[statusID],
			[balance]	=	g.[balance],
			[Username]	=	g.[Username],
			[transdesc]	=	g.[transdesc],
			[productID]	=	g.[productID],
			[gameID]	=	g.[gameID],
			[vendorID]	=	g.[vendorID],
			[GameId3rd]	=	g.[GameId3rd],
			[TranId3rd]	=	g.[TranId3rd],
			[RefNo]	=	g.[RefNo],
			[IsSum]	=	g.[IsSum],
			[winlost]	=	g.[winlost],
			[awinlost]	=	g.[awinlost],
			[mwinlost]	=	g.[mwinlost],
			[swinlost]	=	g.[swinlost],
			[playercomm]	=	g.[playercomm],
			[comm]	=	g.[comm],
			[acomm]	=	g.[acomm],
			[scomm]	=	g.[scomm],
			[Transdate3rd]	=	g.[Transdate3rd],
			[NetStake]	=	g.[NetStake],
			[SiteID]	=	g.[SiteID],
			[epositiontaking]	=	g.[epositiontaking]

	FROM bettransLC b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_bettransLC g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (bettransLC_TransIDList)

END

BEGIN-------- 4) BettransRnG  --------------------------------------

	SELECT * 
	INTO #temp_bettransRnG
	FROM DBCTG.bodb02.dbo.bettransRnG  WITH (NOLOCK)
	WHERE transid IN (bettransRnG_TransIDList)

	UPDATE b 
		SET
			[custid]	=	g.[custid],
			[transdate]	=	g.[transdate],
			[odds]	=	g.[odds],
			[stake]	=	g.[stake],
			[status]	=	g.[status],
			[apositiontaking]	=	g.[apositiontaking],
			[mpositiontaking]	=	g.[mpositiontaking],
			[tpositiontaking]	=	g.[tpositiontaking],
			[spositiontaking]	=	g.[spositiontaking],
			[playerdiscount]	=	g.[playerdiscount],
			[discount]	=	g.[discount],
			[adiscount]	=	g.[adiscount],
			[sdiscount]	=	g.[sdiscount],
			[creator]	=	g.[creator],
			[winlostdate]	=	g.[winlostdate],
			[betfrom]	=	g.[betfrom],
			[virtualrate]	=	g.[virtualrate],
			[actualrate]	=	g.[actualrate],
			[actual_stake]	=	g.[actual_stake],
			[currency]	=	g.[currency],
			[CurrencyName]	=	g.[CurrencyName],
			[recommend]	=	g.[recommend],
			[mrecommend]	=	g.[mrecommend],
			[srecommend]	=	g.[srecommend],
			[ip]	=	g.[ip],
			[statusID]	=	g.[statusID],
			[balance]	=	g.[balance],
			[Username]	=	g.[Username],
			[transdesc]	=	g.[transdesc],
			[productID]	=	g.[productID],
			[gameID]	=	g.[gameID],
			[vendorID]	=	g.[vendorID],
			[GameId3rd]	=	g.[GameId3rd],
			[TranId3rd]	=	g.[TranId3rd],
			[RefNo]	=	g.[RefNo],
			[IsSum]	=	g.[IsSum],
			[winlost]	=	g.[winlost],
			[awinlost]	=	g.[awinlost],
			[mwinlost]	=	g.[mwinlost],
			[swinlost]	=	g.[swinlost],
			[playercomm]	=	g.[playercomm],
			[comm]	=	g.[comm],
			[acomm]	=	g.[acomm],
			[scomm]	=	g.[scomm],
			[Transdate3rd]	=	g.[Transdate3rd],
			[SiteID]	=	g.[SiteID],
			[Additional]	=	g.[Additional],
			[JackpotInfo]	=	g.[JackpotInfo],
			[RefNo2]	=	g.[RefNo2],
			[ContributionRate]	=	g.[ContributionRate],
			[BetStake]	=	g.[BetStake],
			[ContributionStake3rd]	=	g.[ContributionStake3rd],
			[epositiontaking]	=	g.[epositiontaking]	

	FROM bettransRnG b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_bettransRnG g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (bettransRnG_TransIDList)

END
BEGIN-------- 5) bettransG  --------------------------------------

	SELECT * 
	INTO #temp_bettransG
	FROM DBCTG.bodb02.dbo.bettransG  WITH (NOLOCK)
	WHERE transid IN (bettransG_TransIDList)

	UPDATE b 
		SET
			[custid]	=	g.[custid],
			[transdate]	=	g.[transdate],
			[oddsid]	=	g.[oddsid],
			[odds]	=	g.[odds],
			[stake]	=	g.[stake],
			[status]	=	g.[status],
			[winlost]	=	g.[winlost],
			[betteam]	=	g.[betteam],
			[creator]	=	g.[creator],
			[refno]	=	g.[refno],
			[winlostdate]	=	g.[winlostdate],
			[betfrom]	=	g.[betfrom],
			[checktime]	=	g.[checktime],
			[apositiontaking]	=	g.[apositiontaking],
			[mpositiontaking]	=	g.[mpositiontaking],
			[tpositiontaking]	=	g.[tpositiontaking],
			[awinlost]	=	g.[awinlost],
			[mwinlost]	=	g.[mwinlost],
			[playerdiscount]	=	g.[playerdiscount],
			[discount]	=	g.[discount],
			[adiscount]	=	g.[adiscount],
			[playercomm]	=	g.[playercomm],
			[comm]	=	g.[comm],
			[acomm]	=	g.[acomm],
			[actualrate]	=	g.[actualrate],
			[matchid]	=	g.[matchid],
			[matchdate]	=	g.[matchdate],
			[statuswinlost]	=	g.[statuswinlost],
			[ruben]	=	g.[ruben],
			[bettype]	=	g.[bettype],
			[spositiontaking]	=	g.[spositiontaking],
			[swinlost]	=	g.[swinlost],
			[sdiscount]	=	g.[sdiscount],
			[scomm]	=	g.[scomm],
			[statusID]	=	g.[statusID],
			[virtualrate]	=	g.[virtualrate],
			[SiteID]	=	g.[SiteID],
			[transdesc]	=	g.[transdesc],
			[BetID3rd]	=	g.[BetID3rd],
			[epositiontaking]	=	g.[epositiontaking],
			[actual_stake]	=	g.[actual_stake],
			[netstake]	=	g.[netstake]
	FROM bettransG b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_bettransG g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (bettransG_TransIDList)

END
BEGIN-------- 6) Translog  --------------------------------------

	SELECT * 
	INTO #temp_Translog
	FROM DBCTG.bodb02.dbo.Translog  WITH (NOLOCK)
	WHERE translogid IN (Translog_translogidList)

	UPDATE b 
		SET
			[custid]	=	g.[custid],
			[transdate]	=	g.[transdate],
			[odds]	=	g.[odds],
			[stake]	=	g.[stake],
			[status]	=	g.[status],
			[apositiontaking]	=	g.[apositiontaking],
			[mpositiontaking]	=	g.[mpositiontaking],
			[tpositiontaking]	=	g.[tpositiontaking],
			[spositiontaking]	=	g.[spositiontaking],
			[playerdiscount]	=	g.[playerdiscount],
			[discount]	=	g.[discount],
			[adiscount]	=	g.[adiscount],
			[sdiscount]	=	g.[sdiscount],
			[creator]	=	g.[creator],
			[winlostdate]	=	g.[winlostdate],
			[betfrom]	=	g.[betfrom],
			[virtualrate]	=	g.[virtualrate],
			[actualrate]	=	g.[actualrate],
			[actual_stake]	=	g.[actual_stake],
			[currency]	=	g.[currency],
			[CurrencyName]	=	g.[CurrencyName],
			[recommend]	=	g.[recommend],
			[mrecommend]	=	g.[mrecommend],
			[srecommend]	=	g.[srecommend],
			[ip]	=	g.[ip],
			[statusID]	=	g.[statusID],
			[balance]	=	g.[balance],
			[Username]	=	g.[Username],
			[transdesc]	=	g.[transdesc],
			[productID]	=	g.[productID],
			[gameID]	=	g.[gameID],
			[eventID]	=	g.[eventID],
			[vendorID]	=	g.[vendorID],
			[GameId3rd]	=	g.[GameId3rd],
			[TranId3rd]	=	g.[TranId3rd],
			[custom1]	=	g.[custom1],
			[custom2]	=	g.[custom2],
			[custom3]	=	g.[custom3],
			[LiveIndicator]	=	g.[LiveIndicator],
			[checkCount]	=	g.[checkCount],
			[SiteId]	=	g.[SiteId],
			[epositiontaking]	=	g.[epositiontaking],
			[LicenseeTransId]	=	g.[LicenseeTransId]
	FROM Translog b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_Translog g WITH (NOLOCK) ON b.translogid  = g.translogid
	WHERE b.translogid IN (Translog_translogidList)

END
BEGIN-------- 7) Transfer  --------------------------------------

	SELECT * 
	INTO #temp_Transfer
	FROM DBCTG.bodb02.dbo.Transfer  WITH (NOLOCK)
	WHERE transid IN (Transfer_transidList)

	UPDATE b 
		SET
			[CustId]	=	g.[CustId],
			[TransDate]	=	g.[TransDate],
			[WinlostDate]	=	g.[WinlostDate],
			[Bettype]	=	g.[Bettype],
			[Stake]	=	g.[Stake],
			[Actual_Stake]	=	g.[Actual_Stake],
			[Winlost]	=	g.[Winlost],
			[AWinlost]	=	g.[AWinlost],
			[MWinlost]	=	g.[MWinlost],
			[SWinlost]	=	g.[SWinlost],
			[PlayerComm]	=	g.[PlayerComm],
			[Comm]	=	g.[Comm],
			[AComm]	=	g.[AComm],
			[SComm]	=	g.[SComm],
			[StatusId]	=	g.[StatusId],
			[RefNo]	=	g.[RefNo],
			[TransDesc]	=	g.[TransDesc],
			[Recommend]	=	g.[Recommend],
			[MRecommend]	=	g.[MRecommend],
			[SRecommend]	=	g.[SRecommend],
			[Username]	=	g.[Username],
			[Currency]	=	g.[Currency],
			[CurrencyName]	=	g.[CurrencyName],
			[ActualRate]	=	g.[ActualRate],
			[Creator]	=	g.[Creator],
			[Balance]	=	g.[Balance],
			[IP]	=	g.[IP],
			[CheckTime]	=	g.[CheckTime],
			[SerialNo]	=	g.[SerialNo],
			[RepUpdateTime]	=	g.[RepUpdateTime]
	FROM Transfer b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_Transfer g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (Transfer_transidList)

END
BEGIN-------- 8) Transfer_Coll  --------------------------------------
	SELECT * 
	INTO #temp_Transfer_Coll
	FROM DBCTG.bodb02.dbo.Transfer_Coll  WITH (NOLOCK)
	WHERE transid IN (Transfer_Coll_transidList)

	UPDATE b 
		SET
			[CustId]	=	g.[CustId],
			[WinlostDate]	=	g.[WinlostDate],
			[TransDate]	=	g.[TransDate],
			[Bettype]	=	g.[Bettype],
			[Debit]	=	g.[Debit],
			[Credit]	=	g.[Credit],
			[Currency]	=	g.[Currency],
			[ActualRate]	=	g.[ActualRate],
			[RefNo]	=	g.[RefNo],
			[Username]	=	g.[Username],
			[Recommend]	=	g.[Recommend],
			[MRecommend]	=	g.[MRecommend],
			[SRecommend]	=	g.[SRecommend],
			[Creator]	=	g.[Creator],
			[TransDesc]	=	g.[TransDesc],
			[IP]	=	g.[IP]
	FROM Transfer_Coll b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_Transfer_Coll g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (Transfer_Coll_transidList)

END

