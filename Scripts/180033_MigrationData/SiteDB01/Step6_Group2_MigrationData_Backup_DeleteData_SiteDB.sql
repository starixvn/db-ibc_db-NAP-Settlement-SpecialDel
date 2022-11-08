/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB01tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for the following tables [Redmineid:#180033] 
							 bettrans, transfer, bettransm, BettransInfo, Transfer_Coll, TransferInfo
								
*/

USE SiteDB01tmp
GO

------------------------------------------------
/*****************Copy Stucture of Tables************************/
SELECT TOP 1 *
INTO bettrans_20221115
FROM bodb02.dbo.bettrans b WITH (NOLOCK)

SELECT TOP 1 *
INTO BettransInfo_20221115
FROM bodb02.dbo.BettransInfo binfo WITH (NOLOCK)

SELECT TOP 1 *
INTO bettransm_20221115
FROM bodb02.dbo.bettransm bm WITH (NOLOCK)

SELECT TOP 1 *
INTO Transfer_20221115
FROM bodb02.dbo.Transfer b WITH (NOLOCK)

SELECT TOP 1 *
INTO Transfer_Coll_20221115
FROM bodb02.dbo.Transfer_Coll b WITH (NOLOCK)

SELECT TOP 1 *
INTO TransferInfo_20221115
FROM bodb02.dbo.TransferInfo b WITH (NOLOCK)

/*****************Truncate Table************************/
TRUNCATE TABLE bettrans_20221115
TRUNCATE TABLE BettransInfo_20221115
TRUNCATE TABLE bettransm_20221115
TRUNCATE TABLE Transfer_20221115
TRUNCATE TABLE Transfer_Coll_20221115
TRUNCATE TABLE TransferInfo_20221115

/*******************BACKUP & DELETE Data**********************/
--bodb02.dbo.bettrans
DELETE b
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[awinlost], deleted.[mwinlost], deleted.[playercomm], deleted.[comm], 
		deleted.[acomm], deleted.[apositiontaking], deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[livehomescore], deleted.[liveawayscore], 
		deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[oddsspread], deleted.[actualrate], 
		deleted.[matchid], deleted.[recommend], deleted.[mrecommend], deleted.[ruben], deleted.[betid], deleted.[statuswinlost], deleted.[modds], deleted.[bettype], deleted.[betdaqid], deleted.[actual_stake], deleted.[currency], 
		deleted.[ip], deleted.[transdesc], deleted.[sdiscount], deleted.[scomm], deleted.[spositiontaking], deleted.[swinlost], deleted.[srecommend], deleted.[Username], deleted.[CurrencyName], deleted.[virtualrate], deleted.[oddstype], 
		deleted.[statusID], deleted.[currency2], deleted.[balance], deleted.[SecAcceptFlag], deleted.[transid2], deleted.[recommdate], deleted.[ExtraInfo], deleted.[WalletType], deleted.[BonusID], deleted.[RefCode], deleted.[SettlementTime],
		deleted.[epositiontaking], deleted.[ReasonID], deleted.[sort], deleted.[BetSiteID], deleted.[RepUpdateTime], deleted.[RepDstUpdateTime], deleted.[SiteDBGroupID], deleted.[FcUpdateTime]
INTO bettrans_20221115 ([transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], 
						[acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
						[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [actualrate], 
						[matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], 
						[ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [virtualrate], [oddstype], 
						[statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], [RefCode], [SettlementTime],
						[epositiontaking], [ReasonID], [sort], [BetSiteID], [RepUpdateTime], [RepDstUpdateTime], [SiteDBGroupID], [FcUpdateTime])
FROM bodb02.dbo.bettrans b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.BettransInfo
DELETE binfo
OUTPUT deleted.[transid], deleted.[SecAcceptTime], deleted.[LiveBetAcceptTime], deleted.[OriginalOdds], deleted.[RepUpdateTime], deleted.[ThirdTransID]
INTO BettransInfo_20221115 ([transid], [SecAcceptTime], [LiveBetAcceptTime], [OriginalOdds], [RepUpdateTime], [ThirdTransID])
FROM bodb02.dbo.BettransInfo binfo WITH (ROWLOCK)
	INNER JOIN dbo.bettrans_20221115 b WITH (NOLOCK) ON b.transid = binfo.transid

--bodb02.dbo.bettransm
DELETE bm
OUTPUT  deleted.[transid], deleted.[custid], deleted.[transdate], deleted.[oddsid], deleted.[hdp1], deleted.[hdp2], deleted.[odds], deleted.[stake], deleted.[status], deleted.[winlost], deleted.[livehomescore], deleted.[liveawayscore], 
		deleted.[liveindicator], deleted.[betteam], deleted.[creator], deleted.[refno], deleted.[comstatus], deleted.[winlostdate], deleted.[betfrom], deleted.[betcheck], deleted.[checktime], deleted.[oddsspread], deleted.[apositiontaking], 
		deleted.[mpositiontaking], deleted.[tpositiontaking], deleted.[awinlost], deleted.[mwinlost], deleted.[playerdiscount], deleted.[discount], deleted.[adiscount], deleted.[playercomm], deleted.[comm], deleted.[acomm], 
		deleted.[actualrate], deleted.[matchid], deleted.[matchdate], deleted.[finalodds], deleted.[isfinish], deleted.[statuswinlost], deleted.[ruben], deleted.[bettype], deleted.[spositiontaking], deleted.[swinlost], deleted.[sdiscount], 
		deleted.[scomm], deleted.[statusID], deleted.[recommdate], deleted.[transdesc], deleted.[SecAcceptFlag], deleted.[SecAcceptTime], deleted.[LiveBetAcceptTime], deleted.[ReasonIDm], deleted.[RepUpdateTime], deleted.[SiteDBGroupID]
INTO bettransm_20221115 (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [livehomescore], [liveawayscore], 
							[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [apositiontaking], 
							[mpositiontaking], [tpositiontaking], [awinlost], [mwinlost], [playerdiscount], [discount], [adiscount], [playercomm], [comm], [acomm], 
							[actualrate], [matchid], [matchdate], [finalodds], [isfinish], [statuswinlost], [ruben], [bettype], [spositiontaking], [swinlost], [sdiscount], 
							[scomm], [statusID], [recommdate], [transdesc], [SecAcceptFlag], [SecAcceptTime], [LiveBetAcceptTime], [ReasonIDm], [RepUpdateTime], [SiteDBGroupID])
FROM bodb02.dbo.bettransm bm WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = bm.custid

--bodb02.dbo.Transfer
DELETE b
OUTPUT  deleted.[TransId], deleted.[CustId], deleted.[TransDate], deleted.[WinlostDate], deleted.[Bettype], deleted.[Stake], deleted.[Actual_Stake], deleted.[Winlost], deleted.[AWinlost], deleted.[MWinlost], deleted.[SWinlost], deleted.[PlayerComm], 
		deleted.[Comm], deleted.[AComm], deleted.[SComm], deleted.[StatusId], deleted.[RefNo], deleted.[TransDesc], deleted.[Recommend], deleted.[MRecommend], deleted.[SRecommend], deleted.[Username], deleted.[Currency], deleted.[CurrencyName], 
		deleted.[ActualRate], deleted.[Creator], deleted.[Balance], deleted.[IP], deleted.[CheckTime], deleted.[SerialNo], deleted.[RepUpdateTime]
INTO Transfer_20221115 ([TransId], [CustId], [TransDate], [WinlostDate], [Bettype], [Stake], [Actual_Stake], [Winlost], [AWinlost], [MWinlost], [SWinlost], [PlayerComm], 
						[Comm], [AComm], [SComm], [StatusId], [RefNo], [TransDesc], [Recommend], [MRecommend], [SRecommend], [Username], [Currency], [CurrencyName], 
						[ActualRate], [Creator], [Balance], [IP], [CheckTime], [SerialNo], [RepUpdateTime])
FROM bodb02.dbo.Transfer b WITH (ROWLOCK)
	INNER JOIN cust_Copy tmp WITH (NOLOCK) ON tmp.custid = b.custid

--bodb02.dbo.Transfer_Coll
DELETE b
OUTPUT  deleted.[CustId], deleted.[WinlostDate], deleted.[TransDate], deleted.[Bettype], deleted.[Debit], deleted.[Credit], deleted.[Currency], deleted.[ActualRate], deleted.[TransID], deleted.[RefNo], deleted.[Username], 
		deleted.[Recommend], deleted.[MRecommend], deleted.[SRecommend], deleted.[Creator], deleted.[TransDesc], deleted.[IP], deleted.[RepUpdateTime]
INTO Transfer_Coll_20221115 (	[CustId], [WinlostDate], [TransDate], [Bettype], [Debit], [Credit], [Currency], [ActualRate], [TransID], [RefNo], [Username], 
								[Recommend], [MRecommend], [SRecommend], [Creator], [TransDesc], [IP], [RepUpdateTime])
FROM bodb02.dbo.Transfer_Coll b WITH (ROWLOCK)
	INNER JOIN dbo.Transfer_20221115 b1 WITH (NOLOCK) ON b1.TransID = b.TransID

--bodb02.dbo.TransferInfo
DELETE b
OUTPUT	deleted.[TransId], deleted.[APositiontaking], deleted.[MPositiontaking], deleted.[SPositiontaking], deleted.[EPositiontaking], deleted.[PlayerDiscount], deleted.[Discount], deleted.[ADiscount], deleted.[SDiscount], 
		deleted.[WalletType], deleted.[BonusID], deleted.[Amount], deleted.[CheckerId], deleted.[CheckerName], deleted.[IsCollection], deleted.[IsDel], deleted.[RepUpdateTime] 
INTO TransferInfo_20221115 ([TransId], [APositiontaking], [MPositiontaking], [SPositiontaking], [EPositiontaking], [PlayerDiscount], [Discount], [ADiscount], [SDiscount], 
							[WalletType], [BonusID], [Amount], [CheckerId], [CheckerName], [IsCollection], [IsDel], [RepUpdateTime])
FROM bodb02.dbo.TransferInfo b WITH (ROWLOCK)
	INNER JOIN dbo.Transfer_20221115 b1 WITH (NOLOCK) ON b1.TransID = b.TransID	
