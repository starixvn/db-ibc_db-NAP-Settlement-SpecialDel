/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220413@Kathy
	Task	: Add new column [Redmine:#170551]

*/
USE [bodb02]
GO 

ALTER TABLE SSB_SettlementLogs ADD AffectedTicket INT