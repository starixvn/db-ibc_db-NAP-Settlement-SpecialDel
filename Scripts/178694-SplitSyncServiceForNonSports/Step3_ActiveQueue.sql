/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: Activate Queue
use bodb02
go

-- sitedb1: 3rd
alter queue dbo.bet_SiteDB_3rd_queue_01 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Replicated_SyncSiteDB_Process, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)

GO

-- sitedb2: 3rd
alter queue dbo.bet_SiteDB_3rd_queue_02 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Replicated_SyncSiteDB_Process, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
GO

-- sitedb2: SB
alter queue dbo.bet_SiteDB_queue_02 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Replicated_SyncSiteDB_Process, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
