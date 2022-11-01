USE bodb02
GO

ALTER TABLE dbo.SSB_SettlementLogs 
	ADD SiteDBGroupId SMALLINT CONSTRAINT [DF_SSB_SettlementLogs_SiteDBGroupId]  DEFAULT (0) 

