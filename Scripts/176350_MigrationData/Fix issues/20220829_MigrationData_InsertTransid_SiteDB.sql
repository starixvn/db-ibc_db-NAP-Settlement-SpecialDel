/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220829@Victoria
    Task: 
    DB: DBSIG-bodb02

	Revisions: Script to insert data into SiteDB from CentralDB for the folowing transids: [Redmine:#]
					20577003631542312
					20935697825267826
					20935878213894148
					20942548298104886
					20942702916927522
					20950416678191172

*/

	USE bodb02
	GO

	DECLARE @SiteDBGroupID SMALLINT

	SET @SiteDBGroupID = 1

	--bettrans
	INSERT INTO dbo.bettrans (	[transid], [custid], [transdate], [oddsid], [hdp1], [hdp2], [odds], [stake], [status], [winlost], [awinlost], [mwinlost], [playercomm], [comm], 
								[acomm], [apositiontaking], [mpositiontaking], [tpositiontaking], [playerdiscount], [discount], [adiscount], [livehomescore], [liveawayscore], 
								[liveindicator], [betteam], [creator], [refno], [comstatus], [winlostdate], [betfrom], [betcheck], [checktime], [oddsspread], [actualrate], 
								[matchid], [recommend], [mrecommend], [ruben], [betid], [statuswinlost], [modds], [bettype], [betdaqid], [actual_stake], [currency], 
								[ip], [transdesc], [sdiscount], [scomm], [spositiontaking], [swinlost], [srecommend], [Username], [CurrencyName], [virtualrate], [oddstype], 
								[statusID], [currency2], [balance], [SecAcceptFlag], [transid2], [recommdate], [ExtraInfo], [WalletType], [BonusID], [RefCode], [SettlementTime],
								[epositiontaking], [ReasonID], [sort], [BetSiteID], [RepUpdateTime], b.[RepDstUpdateTime], [SiteDBGroupID], [FcUpdateTime])
	SELECT  b.[transid], b.[custid], b.[transdate], b.[oddsid], b.[hdp1], b.[hdp2], b.[odds], b.[stake], b.[status], b.[winlost], b.[awinlost], b.[mwinlost], b.[playercomm], b.[comm], 
			b.[acomm], b.[apositiontaking], b.[mpositiontaking], b.[tpositiontaking], b.[playerdiscount], b.[discount], b.[adiscount], b.[livehomescore], b.[liveawayscore], 
			b.[liveindicator], b.[betteam], b.[creator], b.[refno], b.[comstatus], b.[winlostdate], b.[betfrom], b.[betcheck], b.[checktime], b.[oddsspread], b.[actualrate], 
			b.[matchid], b.[recommend], b.[mrecommend], b.[ruben], b.[betid], b.[statuswinlost], b.[modds], b.[bettype], b.[betdaqid], b.[actual_stake], b.[currency], 
			b.[ip], b.[transdesc], b.[sdiscount], b.[scomm], b.[spositiontaking], b.[swinlost], b.[srecommend], b.[Username], b.[CurrencyName], b.[virtualrate], b.[oddstype], 
			b.[statusID], b.[currency2], b.[balance], b.[SecAcceptFlag], b.[transid2], b.[recommdate], b.[ExtraInfo], b.[WalletType], b.[BonusID], b.[RefCode], b.[SettlementTime],
			b.[epositiontaking], b.[ReasonID], b.[sort], b.[BetSiteID], b.[RepUpdateTime], b.[RepDstUpdateTime], @SiteDBGroupID AS SiteDBGroupID, b.[FcUpdateTime]
	FROM  DBCTG.bodb02.dbo.bettrans b WITH (NOLOCK)
	WHERE b.TransId IN (20577003631542312,
						20935697825267826,
						20935878213894148,
						20942548298104886,
						20942702916927522,
						20950416678191172)
		AND b.SiteDBGroupID = 0 

	