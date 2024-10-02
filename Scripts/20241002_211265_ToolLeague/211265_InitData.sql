/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241002@Aries
	Task:  Support a tool to add leagues for Direct Payout [Redmine:#211265]
	DB: DBPRO-bodb02

	Revision:
		- 20241002@Aries: Support a tool to add leagues for Direct Payout [Redmine:#211265]

*/
USE bodb02
--Insert League HardCode Direct Soccer
INSERT INTO SettlementSetting(LeagueId,AutoType,WaitingTime)
SELECT value AS LeagueId, 8 AS AutoType, 0 AS WaitingTime
FROM STRING_SPLIT('95730,95731,96666,135822,147230,114806,150217',',')


--Insert League Fantasy Soccer
INSERT INTO SettlementSetting(LeagueId,AutoType,WaitingTime)
SELECT value AS LeagueId, 9 AS AutoType, 0 AS WaitingTime
FROM STRING_SPLIT('16371,65550,89611,149675,149676',',')


--Insert League Fantasy Basketball
INSERT INTO SettlementSetting(LeagueId,AutoType,WaitingTime)
SELECT value AS LeagueId, 10 AS AutoType, 0 AS WaitingTime
FROM STRING_SPLIT('56053,56037,56069,136578,99321,132325,16926,152504,152505,154350,155276',',')


	