/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20210928@Kathy
	Task	  : inactive 2 unused queues
	DB		  : DBTXN/bodb02
*/
alter queue dbo.bet_settle_queue_07 with status = ON, retention = off
	, activation (status = OFF, procedure_name = dbo.SSB_Settlement_Replicated_Process_Message_07, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)
alter queue dbo.bet_settle_queue_08 with status = ON, retention = off
	, activation (status = OFF, procedure_name = dbo.SSB_Settlement_Replicated_Process_Message_08, max_queue_readers = 1, execute as N'dbo')
	, poison_message_handling (status = on)