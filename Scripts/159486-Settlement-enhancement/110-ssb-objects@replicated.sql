/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--01
create message type bet_settle_msg_type_01 validation = none
create contract bet_settle_contract_01(bet_settle_msg_type_01 sent by any)
create queue dbo.bet_settle_queue_01 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_settle_send_service_01 on queue bet_settle_queue_01(bet_settle_contract_01)
create service bet_settle_receive_service_01 on queue bet_settle_queue_01(bet_settle_contract_01)

--02
create message type bet_settle_msg_type_02 validation = none
create contract bet_settle_contract_02(bet_settle_msg_type_02 sent by any)
create queue dbo.bet_settle_queue_02 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_settle_send_service_02 on queue bet_settle_queue_02(bet_settle_contract_02)
create service bet_settle_receive_service_02 on queue bet_settle_queue_02(bet_settle_contract_02)

--03
create message type bet_settle_msg_type_03 validation = none
create contract bet_settle_contract_03(bet_settle_msg_type_03 sent by any)
create queue dbo.bet_settle_queue_03 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_settle_send_service_03 on queue bet_settle_queue_03(bet_settle_contract_03)
create service bet_settle_receive_service_03 on queue bet_settle_queue_03(bet_settle_contract_03)

--04
create message type bet_settle_msg_type_04 validation = none
create contract bet_settle_contract_04(bet_settle_msg_type_04 sent by any)
create queue dbo.bet_settle_queue_04 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_settle_send_service_04 on queue bet_settle_queue_04(bet_settle_contract_04)
create service bet_settle_receive_service_04 on queue bet_settle_queue_04(bet_settle_contract_04)

--05
create message type bet_settle_msg_type_05 validation = none
create contract bet_settle_contract_05(bet_settle_msg_type_05 sent by any)
create queue dbo.bet_settle_queue_05 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_settle_send_service_05 on queue bet_settle_queue_05(bet_settle_contract_05)
create service bet_settle_receive_service_05 on queue bet_settle_queue_05(bet_settle_contract_05)

--06
create message type bet_settle_msg_type_06 validation = none
create contract bet_settle_contract_06(bet_settle_msg_type_06 sent by any)
create queue dbo.bet_settle_queue_06 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_settle_send_service_06 on queue bet_settle_queue_06(bet_settle_contract_06)
create service bet_settle_receive_service_06 on queue bet_settle_queue_06(bet_settle_contract_06)

