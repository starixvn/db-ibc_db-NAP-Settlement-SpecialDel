/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02,SBSETTLE-bodb02"></info>*/
/*
	Created by: 20250709@Louisa
	Task: capture BroadcastSessionId  [Redmine:#232227]

	Revision:
		20250709@Louisa: Settlement Time Dashboard report  [Redmine:#232227]

*/
USE bodb02
GO

ALTER TABLE SSB_SettlementLogs  ADD BroadcastSessionId	varchar(50) NULL
GO