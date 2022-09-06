/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: Activate Queue
use bodb02
go

alter queue dbo.bet_SiteDB_queue_01 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Replicated_SyncSiteDB_Process_UAT1, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)