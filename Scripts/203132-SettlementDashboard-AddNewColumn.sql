/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02,DBBAL-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20240401@Kathy
	Task	  : Add new column [Redmine:#203132]
*/
ALTER TABLE SSB_SettlementLogs ADD MatchId INT
GO
ALTER TABLE SSB_SettlementLogs ADD EventTable TINYINT
GO
ALTER TABLE SSB_SettlementLogs ADD TableType TINYINT 

