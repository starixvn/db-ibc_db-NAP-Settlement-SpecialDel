/*<info serverAlias="SBSETTLE-bodb02"></info>*/
/*
	Created by: 20250709@Louisa
	Task: capture BroadcastSessionId  [Redmine:#232227]

	Revision:
		20250709@Louisa: Settlement Time Dashboard report  [Redmine:#232227]

*/
USE bodb02
GO


ALTER TABLE SiteDB_SettlementProcessing ADD BroadcastSessionId	varchar(50) NULL
GO

ALTER TABLE SiteDB_ParlaySettlementProcessing ADD BroadcastSessionId	varchar(50) NULL
GO

