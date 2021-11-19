/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: Activate

--++exec Queue
alter queue dbo.bet_settle_queue_01 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_01, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_02 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_02, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_03 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_03, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_04 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_04, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_05 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_05, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_06 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_06, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_07 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_07, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_08 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_08, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)

--prepare Queue
alter queue dbo.bet_settle_queue_prepare_01 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_01, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_02 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_02, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_03 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_03, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_04 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_04, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_05 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_05, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_06 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_06, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_07 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_07, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_prepare_08 with status = ON, retention = off
	, activation (status = on, procedure_name = dbo.SSB_Settlement_Process_Message_Prepare_08, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)


go
