/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220815@Victoria
    Task: Data Migration - Real Licensee
    DB: DBCTG-SiteDBtmp

	 Revisions:
		- 20220815@Victoria: SELECT data INTO new tables for the following tickets tables [Redmineid:#176350] 
								1.  bodb02.dbo.bettrans				2.  bodb02.dbo.bettrans14
								3.  bodb02.dbo.bettransG			4.  bodb02.dbo.bettransG14
								5.  bodb02.dbo.BettransInfo			6.  bodb02.dbo.BettransInfo14
								7.  bodb02.dbo.bettransLC			8.  bodb02.dbo.bettransLC14
								9.  bodb02.dbo.bettransm			10. bodb02.dbo.bettransm14
								11. bodb02.dbo.bettransRnG			12. bodb02.dbo.bettransRnG14
								13. bodb02.dbo.translog				14. bodb02.dbo.translog14
								15. bodb02.dbo.zzzbettrans			16. bodb02.dbo.zzzbettransm
								17. bodb02.dbo.Transfer				18. bodb02.dbo.Transfer_Coll		19. bodb02.dbo.TransferInfo
								20. bodb02.dbo.BetParlayDetail		21. bodb02.dbo.BetParlayResult
								
*/

	USE SiteDBtmp
	GO

	DECLARE @SiteDBGroupID SMALLINT

	SET @SiteDBGroupID = 1

	CREATE TABLE #tmp_cust
	(
		custid INT PRIMARY KEY
	)

	CREATE TABLE #tmp_refno
	(
		refno BIGINT PRIMARY KEY
	)
	------------------------------------------------
	INSERT INTO #tmp_cust (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer WITH (NOLOCK)
	WHERE site IN ('XXXXXXXX')

	------------------------------------------------
	--bodb02.dbo.bettrans
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
			b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
			b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
			b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
			b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
			b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
			b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID, b.[FcUpdateTime]
	INTO bettrans_20220915
	FROM bodb02.dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettrans14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], 
			b.[comm], b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], 
			b.[liveawayscore], b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], 
			b.[actualrate], b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], 
			b.[actual_stake], b.[currency], b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[virtualrate], b.[Username], 
			b.[CurrencyName], b.[oddstype], b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], 
			b.[RefCode], b.[SettlementTime], b.[epositiontaking], b.[ReasonID], b.[sort], @SiteDBGroupID SiteDBGroupID
	INTO bettrans14_20220915
	FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransG
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
			b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
			b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
			b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
			@SiteDBGroupID SiteDBGroupID , b.[RepUpdateTime]
	INTO bettransG_20220915
	FROM bodb02.dbo.bettransG b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransG14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[odds], b.[stake], b.[status], b.[winlost], b.[betteam], b.[creator], b.[refno], b.[winlostdate], b.[betfrom], 
			b.[checktime], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[awinlost], b.[mwinlost], b.[playerdiscount], b.[discount], b.[adiscount], 
			b.[playercomm], b.[comm], b.[acomm], b.[actualrate], b.[matchid], b.[matchdate], b.[statuswinlost], b.[ruben], b.[bettype], b.[spositiontaking], b.[swinlost], 
			b.[sdiscount], b.[scomm], b.[statusID], b.[virtualrate], b.[SiteID], b.[transdesc], b.[BetID3rd], b.[epositiontaking], b.[actual_stake], b.[netstake], 
			@SiteDBGroupID SiteDBGroupID
	INTO bettransG14_20220915
	FROM bodb02.dbo.bettransG14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.BettransInfo
	SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds]
	INTO BettransInfo_20220915
	FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettrans_20220915 b WITH (NOLOCK) ON b.transid = binfo.transid

	--bodb02.dbo.BettransInfo14
	SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds]
	INTO BettransInfo14_20220915
	FROM bodb02.dbo.BettransInfo14 binfo WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettrans14_20220915 b WITH (NOLOCK) ON binfo.transid = b.transid 

	--bodb02.dbo.bettransLC
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
			b.[scomm], b.[Transdate3rd], b.[NetStake], b.[SiteID], b.[epositiontaking], @SiteDBGroupID SiteDBGroupID , b.[RepUpdateTime]
	INTO bettransLC_20220915
	FROM bodb02.dbo.bettransLC b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransLC14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], 
			b.[scomm], b.[Transdate3rd], b.[NetStake], b.[epositiontaking], b.[SiteID], @SiteDBGroupID SiteDBGroupID
	INTO bettransLC14_20220915
	FROM bodb02.dbo.bettransLC14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransRnG
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
			b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], b.[acomm], b.[scomm], 
			b.[Transdate3rd], b.[SiteID], b.[Additional], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
			b.[epositiontaking], @SiteDBGroupID SiteDBGroupID, b.[RepUpdateTime]
	INTO bettransRnG_20220915
	FROM bodb02.dbo.bettransRnG b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.bettransRnG14
	SELECT  b.[transid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[RefNo], b.[IsSum], b.[winlost], b.[awinlost], b.[mwinlost], b.[swinlost], b.[playercomm], b.[comm], 
			b.[acomm], b.[scomm], b.[Transdate3rd], b.[Additional], b.[Siteid], b.[JackpotInfo], b.[RefNo2], b.[ContributionRate], b.[BetStake], b.[ContributionStake3rd], 
			b.[epositiontaking], @SiteDBGroupID SiteDBGroupID
	INTO bettransRnG14_20220915
	FROM bodb02.dbo.bettransRnG14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.translog
	SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], 
			b.[gameID], b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], b.[checkCount], b.[SiteId], 
			b.[epositiontaking], @SiteDBGroupID SiteDBGroupID, b.[LicenseeTransId], b.[RepUpdateTime]
	INTO translog_20220915
	FROM bodb02.dbo.translog b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.translog14
	SELECT  b.[translogid], b.[custid], b.[transdate], b.[odds], b.[stake], b.[status], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[spositiontaking], 
			b.[playerdiscount], b.[discount], b.[adiscount], b.[sdiscount], b.[creator], b.[winlostdate], b.[betfrom], b.[virtualrate], b.[actualrate], b.[actual_stake], 
			b.[currency], b.[CurrencyName], b.[recommend], b.[mrecommend], b.[srecommend], b.[ip], b.[statusID], b.[balance], b.[Username], b.[transdesc], b.[productID], b.[gameID], 
			b.[eventID], b.[vendorID], b.[GameId3rd], b.[TranId3rd], b.[custom1], b.[custom2], b.[custom3], b.[LiveIndicator], @SiteDBGroupID SiteDBGroupID
	INTO translog14_20220915
	FROM bodb02.dbo.translog14 b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	
	--bodb02.dbo.bettransm
	-- since there is no index on custid for bettransm, need to join via refno
	SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
			bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], bm.[apositiontaking], 
			bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], 
			bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], 
			bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
	INTO bettransm_20220915
	FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bm.custid

	--bodb02.dbo.bettransm14
	SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
			bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], 
			bm.[apositiontaking], bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], 
			bm.[playercomm], bm.[comm], bm.[acomm], bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], 
			bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], 
			bm.[LiveBetAcceptTime], bm.[ReasonIDm], @SiteDBGroupID SiteDBGroupID
	INTO bettransm14_20220915
	FROM bodb02.dbo.bettransm14 bm WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = bm.custid

	--#tmp_refno
	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM dbo.bettrans_20220915 WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29

	INSERT INTO #tmp_refno (refno)
	SELECT DISTINCT refno
	FROM dbo.bettrans14_20220915  WITH (NOLOCK)
	WHERE bettype = 29 AND matchid = 29
	
   --bodb02.dbo.BetParlayDetail
	SELECT	bpd.[RefNo], bpd.[Serial], bpd.[transid], bpd.[winlostdate], bpd.[statuswinlost], bpd.[statusid], bpd.[matchid], bpd.[bettype], bpd.[stake], bpd.[odds], bpd.[betteam], bpd.[hdp1], bpd.[hdp2], 
			bpd.[livehomescore], bpd.[liveawayscore], bpd.[liveindicator], bpd.[betcheck], bpd.[transdesc]
	INTO BetParlayDetail_20220915
	FROM bodb02.dbo.BetParlayDetail bpd WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp ON tmp.refno = bpd.refno

	--bodb02.dbo.BetParlayResult
	SELECT	bpr.[RefNo], bpr.[Serial], bpr.[transid], bpr.[winlostdate], bpr.[statusid], bpr.[stake], bpr.[Odds], bpr.[mOdds], bpr.[winlost], bpr.[awinlost], bpr.[mwinlost], bpr.[swinlost], bpr.[playercomm], bpr.[comm], bpr.[acomm], bpr.[scomm]
	INTO BetParlayResult_20220915
	FROM bodb02.dbo.BetParlayResult bpr WITH (NOLOCK)
		INNER JOIN #tmp_refno tmp ON tmp.refno = bpr.refno

	--bodb02.dbo.zzzbettrans
	SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
			z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
			z.[keyid], z.[VoidingHistoryId], z.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
	INTO zzzbettrans_20220915
	FROM bodb02.dbo.zzzbettrans z WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = z.custid
		
	--bodb02.dbo.zzzbettransm
	SELECT  z.[transid], z.[custid], z.[transdate], z.[oddsid], z.[hdp1], z.[hdp2], z.[odds], z.[stake], z.[status], z.[winlost], z.[livehomescore], z.[liveawayscore], 
			z.[liveindicator], z.[betteam], z.[creator], z.[refno], z.[comstatus], z.[winlostdate], z.[betfrom], z.[betcheck], z.[checktime], z.[matchid], z.[bettype], 
			z.[keyid], z.[VoidingHistoryId], z.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
	INTO zzzbettransm_20220915
	FROM bodb02.dbo.zzzbettransm z WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = z.custid

	--bodb02.dbo.Transfer
	SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
			b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
			b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
	INTO Transfer_20220915
	FROM bodb02.dbo.Transfer b WITH (NOLOCK)
		INNER JOIN #tmp_cust tmp ON tmp.custid = b.custid

	--bodb02.dbo.Transfer_Coll
	SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
			b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
	INTO Transfer_Coll_20220915
	FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_20220915 b1 WITH (NOLOCK) ON b1.TransID = b.TransID
	WHERE b1.CustId <> 3 

	--bodb02.dbo.TransferInfo
	SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
			b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
	INTO TransferInfo_20220915
	FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)
		INNER JOIN dbo.Transfer_20220915 b1 WITH (NOLOCK) ON b1.TransID = b.TransID
	WHERE b1.CustId <> 3 

	------------------------------------------------
	DROP TABLE #tmp_cust
	DROP TABLE #tmp_refno

	