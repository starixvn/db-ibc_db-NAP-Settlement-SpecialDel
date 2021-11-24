/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: Inactive 2 queues

--++exec Queue
alter queue dbo.bet_settle_queue_07 with status = ON, retention = off
	, activation (status = OFF, procedure_name = dbo.SSB_Settlement_Process_Message_07, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_08 with status = ON, retention = off
	, activation (status = OFF, procedure_name = dbo.SSB_Settlement_Process_Message_08, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)

--prepare Queue
alter queue dbo.bet_settle_queue_prepare_07 with status = ON, retention = off
	, activation (status = OFF, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_07, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_08 with status = ON, retention = off
	, activation (status = OFF, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_08, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)


go
