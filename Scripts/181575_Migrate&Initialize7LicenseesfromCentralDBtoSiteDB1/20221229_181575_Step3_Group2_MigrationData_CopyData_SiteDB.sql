/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221229@July
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-bodb02

	Revisions:
		- 20221229@July: INSERT from the copy all data of the following tables [Redmineid:#181575] 

	Note: Run ON SITEDB01
		Group 2: bettrans, transfer, bettransm, BettransInfo, Transfer_Coll, TransferInfo					
*/

USE bodb02
GO

------------------------------------------------
/*******************Bet Tickets Tables**********************/
--TransferInfo
INSERT INTO dbo.TransferInfo	([TransId], [APositiontaking], [MPositiontaking], [SPositiontaking], [EPositiontaking], [PlayerDiscount], [Discount], [ADiscount], [SDiscount], 
								[WalletType], [BonusID], [Amount], [CheckerId], [CheckerName], [IsCollection], [IsDel], [RepUpdateTime])
SELECT  b.[TransId], b.[APositiontaking], b.[MPositiontaking], b.[SPositiontaking], b.[EPositiontaking], b.[PlayerDiscount], b.[Discount], b.[ADiscount], b.[SDiscount], 
		b.[WalletType], b.[BonusID], b.[Amount], b.[CheckerId], b.[CheckerName], b.[IsCollection], b.[IsDel], b.[RepUpdateTime]
FROM SiteDBtmp.dbo.TransferInfo_20221229 b WITH (NOLOCK)

--BettransInfo
INSERT INTO dbo.BettransInfo ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [RepUpdateTime], [ThirdTransID])
SELECT binfo.[transid], binfo.[SecAcceptTime], binfo.[LiveBetAcceptTime], binfo.[OriginalOdds], binfo.[RepUpdateTime], binfo.[ThirdTransID]
FROM SiteDBtmp.dbo.BettransInfo_20221229 binfo WITH (NOLOCK)

--Transfer_Coll
INSERT INTO dbo.Transfer_Coll	([CustId], [WinlostDate], [TransDate], [Bettype], [Debit], [Credit], [Currency], [ActualRate], [TransID], [RefNo], [Username], 
								[Recommend], [MRecommend], [SRecommend], [Creator], [TransDesc], [IP], [RepUpdateTime])
SELECT  b.[CustId], b.[WinlostDate], b.[TransDate], b.[Bettype], b.[Debit], b.[Credit], b.[Currency], b.[ActualRate], b.[TransID], b.[RefNo], b.[Username], 
		b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Creator], b.[TransDesc], b.[IP], b.[RepUpdateTime]
FROM SiteDBtmp.dbo.Transfer_Coll_20221229 b WITH (NOLOCK)


--bettrans
INSERT INTO dbo.bettrans (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], 
							[acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [actualrate], 
							[matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], 
							[ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [virtualrate], [oddstype], 
							[statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], [RefCode], [SettlementTime],
							[epositiontaking], [ReasonID], [sort], [BetSiteID], [RepUpdateTime], [RepDstUpdateTime], [SiteDBGroupID], [FcUpdateTime])
SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
		b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
		b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
		b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
		b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
		b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
		b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], b.[RepDstUpdateTime], b.[SiteDBGroupID], b.[FcUpdateTime]
FROM SiteDBtmp.dbo.bettrans_20221229 b WITH (NOLOCK)

--bettransm
INSERT INTO dbo.bettransm ( [transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], 
							[mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], 
							[actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], 
							[scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm], [RepUpdateTime], [SiteDBGroupID])
SELECT  bm.[transid], bm.[custid], bm.[transdate], bm.[oddsid], bm.[hdp1], bm.[hdp2], bm.[odds], bm.[stake], bm.[status], bm.[winlost], bm.[livehomescore], bm.[liveawayscore], 
		bm.[liveindicator], bm.[betteam], bm.[creator], bm.[refno], bm.[comstatus], bm.[winlostdate], bm.[betfrom], bm.[betcheck], bm.[checktime], bm.[oddsspread], bm.[apositiontaking], 
		bm.[mpositiontaking], bm.[tpositiontaking], bm.[awinlost], bm.[mwinlost], bm.[playerdiscount], bm.[discount], bm.[adiscount], bm.[playercomm], bm.[comm], bm.[acomm], 
		bm.[actualrate], bm.[matchid], bm.[matchdate], bm.[finalodds], bm.[isfinish], bm.[statuswinlost], bm.[ruben], bm.[bettype], bm.[spositiontaking], bm.[swinlost], bm.[sdiscount], 
		bm.[scomm], bm.[statusID], bm.[recommdate], bm.[transdesc], bm.[SecAcceptFlag], bm.[SecAcceptTime], bm.[LiveBetAcceptTime], bm.[ReasonIDm], bm.[RepUpdateTime], bm.[SiteDBGroupID]
FROM SiteDBtmp.dbo.bettransm_20221229 bm WITH (NOLOCK)

--Transfer
INSERT INTO dbo.Transfer	([TransId], [CustId], [TransDate], [WinlostDate], [Bettype], [Stake], [Actual_Stake], [Winlost], [AWinlost], [MWinlost], [SWinlost], [PlayerComm], 
							[Comm], [AComm], [SComm], [StatusId], [RefNo], [TransDesc], [Recommend], [MRecommend], [SRecommend], [Username], [Currency], [CurrencyName], 
							[ActualRate], [Creator], [Balance], [IP], [CheckTime], [SerialNo], [RepUpdateTime])
SELECT  b.[TransId], b.[CustId], b.[TransDate], b.[WinlostDate], b.[Bettype], b.[Stake], b.[Actual_Stake], b.[Winlost], b.[AWinlost], b.[MWinlost], b.[SWinlost], b.[PlayerComm], 
		b.[Comm], b.[AComm], b.[SComm], b.[StatusId], b.[RefNo], b.[TransDesc], b.[Recommend], b.[MRecommend], b.[SRecommend], b.[Username], b.[Currency], b.[CurrencyName], 
		b.[ActualRate], b.[Creator], b.[Balance], b.[IP], b.[CheckTime], b.[SerialNo], b.[RepUpdateTime]
FROM SiteDBtmp.dbo.Transfer_20221229 b WITH (NOLOCK)

go
