/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/

/*
    Created: 20250611@Louisa
	Task: script move ticket to 14 [Redmine: #230022]
	DB:DBCTG/bodb02

	Revision:
		- 20250611@Louisa: script move ticket to 14 [Redmine: #230022]

*/

USE bodb02
GO


INSERT INTO	dbo.bettrans14
		(	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost
		,	playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount
		,	discount, adiscount, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus
		,	winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend
		,	ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, ip, transdesc
		,	sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, Username, CurrencyName
		,	oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID
		,	RefCode, SettlementTime, epositiontaking, ReasonID, sort, SiteDBGroupId, DeviceType
		)
SELECT	transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status, winlost, awinlost, mwinlost
	,	playercomm, comm, acomm, apositiontaking, mpositiontaking, tpositiontaking, playerdiscount
	,	discount, adiscount, livehomescore, liveawayscore, liveindicator, betteam, creator, refno, comstatus
	,	'2025-05-31 00:00:00' AS winlostdate, betfrom, betcheck, checktime, oddsspread, actualrate, matchid, recommend, mrecommend
	,	ruben, betid, statuswinlost, modds, bettype, betdaqid, actual_stake, currency, ip, transdesc
	,	sdiscount, scomm, spositiontaking, swinlost, srecommend, virtualrate, Username, CurrencyName
	,	oddstype, statusID, currency2, balance, SecAcceptFlag, transid2, ExtraInfo, WalletType, BonusID
	,	RefCode, SettlementTime, epositiontaking, ReasonID, sort, SiteDBGroupId, DeviceType
FROM	dbo.bettrans WITH (NOLOCK)
WHERE	transid = 139965201695899699


