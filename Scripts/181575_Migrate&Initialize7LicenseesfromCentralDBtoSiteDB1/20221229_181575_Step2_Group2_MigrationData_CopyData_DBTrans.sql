/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221229@July
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBCTG-SiteDB01tmp

	Revisions:
		- 20221229@July: SELECT data INTO new tables for the following tables [Redmineid:#181575] 
	Note:
		Group 2: bettrans, transfer, bettransm, BettransInfo, Transfer_Coll, TransferInfo						
*/

USE SiteDB01tmp
GO

DECLARE @SiteDBGroupID SMALLINT
DECLARE @debug_message VARCHAR(500)
	
SET @SiteDBGroupID = 1

/*******************Bet Tickets Tables**********************/
--DBCTG.bodb02.dbo.bettrans
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
		b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
		b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
		b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
		b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
		b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
		b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], b.[RepDstUpdateTime], @SiteDBGroupID SiteDBGroupID, b.[FcUpdateTime]
INTO bettrans_20221229
FROM DBCTG.bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN cust_20221229 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--DBCTG.bodb02.dbo.BettransInfo
SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[RepUpdateTime], binfo.[ThirdTransID]
INTO BettransInfo_20221229
FROM DBCTG.bodb02.dbo.BettransInfo binfo WITH (NOLOCK)
	INNER JOIN dbo.bettrans_20221229 b WITH (NOLOCK) ON b.transid = binfo.transid

--DBCTG.bodb02.dbo.bettransm
SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
		bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], bm.[apositiontaking], 
		bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], 
		bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], 
		bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[RepUpdateTime], @SiteDBGroupID SiteDBGroupID
INTO bettransm_20221229
FROM DBCTG.bodb02.dbo.bettransm bm WITH (NOLOCK)
	INNER JOIN cust_20221229 tmp WITH (NOLOCK) ON tmp.custid = bm.custid

--DBCTG.bodb02.dbo.Transfer
SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
		b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
		b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
INTO Transfer_20221229
FROM DBCTG.bodb02.dbo.Transfer b WITH (NOLOCK)
	INNER JOIN cust_20221229 tmp WITH (NOLOCK) ON tmp.custid = b.custid

--DBCTG.bodb02.dbo.Transfer_Coll
SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
		b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
INTO Transfer_Coll_20221229
FROM DBCTG.bodb02.dbo.Transfer_Coll b WITH (NOLOCK)
	INNER JOIN dbo.Transfer_20221229 b1 WITH (NOLOCK) ON b1.TransID = b.TransID

--DBCTG.bodb02.dbo.TransferInfo
SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
		b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
INTO TransferInfo_20221229
FROM DBCTG.bodb02.dbo.TransferInfo b WITH (NOLOCK)
	INNER JOIN dbo.Transfer_20221229 b1 WITH (NOLOCK) ON b1.TransID = b.TransID	



	