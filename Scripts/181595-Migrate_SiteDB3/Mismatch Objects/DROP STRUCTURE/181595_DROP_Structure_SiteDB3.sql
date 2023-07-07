/*<info serverAlias="DBSIC-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230626@Louisa: Checking data before migration - table group 3 [Redmineid:#181595]					
	
*/


USE bodb02
GO

	----1. DROP table type
	DROP TYPE IF EXISTS dbo.TVP_SiteDB_CalculationLog
	DROP TYPE IF EXISTS dbo.TVP_SiteDB_CalculationLog_3rd

	----2. DROP column

	ALTER TABLE dbo.bettrans DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.bettransG DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.bettransLC DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.bettransRnG DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.Task_Archive_TVS DROP COLUMN VoidingHistoryIds
	GO
	ALTER TABLE dbo.TicketVoiding_MessageTemplateSetting DROP COLUMN IsCheckedVar
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetailTicket_Single DROP COLUMN SiteDBGroupID
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetailTicket_Single DROP COLUMN IsProcessed
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetailTicket_SubParlay DROP COLUMN SiteDBGroupID
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetailTicket_SubParlay DROP COLUMN IsProcessed
	GO
	ALTER TABLE dbo.Ticketvoiding_VoidBetAutomation_Service DROP COLUMN VoidingHistoryId
	GO
	ALTER TABLE dbo.TicketVoiding_VoidingHistory DROP COLUMN BroadcastSessionID
	GO
	ALTER TABLE dbo.TicketVoiding_VoidingHistory DROP COLUMN SiteDBGroupID
	GO
	ALTER TABLE dbo.translog DROP COLUMN SequenceID
	GO
	ALTER TABLE dbo.zzzbettrans DROP COLUMN source_keyid
	GO
	ALTER TABLE dbo.zzzbettransm DROP COLUMN source_keyid
	GO
	ALTER TABLE dbo.bettransG DROP COLUMN tstamp
	GO
	ALTER TABLE dbo.bettransLC DROP COLUMN tstamp
	GO
	ALTER TABLE dbo.bettransm DROP COLUMN tstamp
	GO
	ALTER TABLE dbo.TicketVoiding_Request DROP COLUMN SubIssueTypeId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN FilterFromBetId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN FilterToBetId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN IsFilterByTransTime
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN MinSingleTransId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN MaxSingleTransId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN MinMainParlayTransId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN MaxMainParlayTransId
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN IsCheckedHomeTeam
	GO
	ALTER TABLE dbo.TicketVoiding_RequestDetail DROP COLUMN IsCheckedAwayTeam
	GO
	ALTER TABLE dbo.Ticketvoiding_VoidBetAutomation_Service DROP COLUMN VoidingHistory
	GO


	----3. DROP index
	DROP INDEX IX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistoryId ON dbo.Ticketvoiding_VoidBetAutomation_Service 
	GO
	DROP INDEX IX_TicketVoiding_VoidingHistory_BroadcastSessionID ON dbo.TicketVoiding_VoidingHistory 
	GO
	DROP INDEX IX_zzzbettrans_source_keyid ON dbo.zzzbettrans 
	GO
	DROP INDEX IX_zzzbettransm_source_keyid ON dbo.zzzbettransm 
	GO
	DROP INDEX IX_tstamp ON dbo.bettransG 
	GO
	DROP INDEX IX_tstamp ON dbo.bettransLC 
	GO
	DROP INDEX IX_tstamp ON dbo.bettransm 
	GO
	DROP INDEX IX_tstamp ON dbo.bettransRnG 
	GO
	DROP INDEX IX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistory ON dbo.Ticketvoiding_VoidBetAutomation_Service 


	----4. DROP TABLE
	DROP TABLE dbo.SiteDB_SettlementLock
	GO
	DROP TABLE dbo.SiteDB_SettlementProcessing
	GO
	DROP TABLE dbo.SiteDB_SettlementService_CalculationLog_3rd_History
	GO
	DROP TABLE dbo.SiteDB_SettlementService_CalculationLog_History
	GO
	DROP TABLE dbo.TicketVoiding_Letstalk
	GO
	DROP TABLE dbo.TicketVoiding_RequestDetail_MixParlay
	GO
	DROP TABLE dbo.TicketVoiding_Void_Service








