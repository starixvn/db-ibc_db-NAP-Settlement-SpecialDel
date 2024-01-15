/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: setup ssb objects
--01
use bodb02
go

create message type parlaybet_settle_msg_type_01 validation = none
create contract parlaybet_settle_contract_01(parlaybet_settle_msg_type_01 sent by any)
create queue dbo.parlaybet_settle_queue_01 with status = on, retention = off
	, poison_message_handling (status = on) on [serviceBroker]
create service parlaybet_settle_send_service_01 on queue parlaybet_settle_queue_01(parlaybet_settle_contract_01)
create service parlaybet_settle_receive_service_01 on queue parlaybet_settle_queue_01(parlaybet_settle_contract_01)

--02
create message type parlaybet_settle_msg_type_02 validation = none
create contract parlaybet_settle_contract_02(parlaybet_settle_msg_type_02 sent by any)
create queue dbo.parlaybet_settle_queue_02 with status = on, retention = off
	, poison_message_handling (status = on) on [serviceBroker]
create service parlaybet_settle_send_service_02 on queue parlaybet_settle_queue_02(parlaybet_settle_contract_02)
create service parlaybet_settle_receive_service_02 on queue parlaybet_settle_queue_02(parlaybet_settle_contract_02)

--03
create message type parlaybet_settle_msg_type_03 validation = none
create contract parlaybet_settle_contract_03(parlaybet_settle_msg_type_03 sent by any)
create queue dbo.parlaybet_settle_queue_03 with status = on, retention = off
	, poison_message_handling (status = on) on [serviceBroker]
create service parlaybet_settle_send_service_03 on queue parlaybet_settle_queue_03(parlaybet_settle_contract_03)
create service parlaybet_settle_receive_service_03 on queue parlaybet_settle_queue_03(parlaybet_settle_contract_03)

--04
create message type parlaybet_settle_msg_type_04 validation = none
create contract parlaybet_settle_contract_04(parlaybet_settle_msg_type_04 sent by any)
create queue dbo.parlaybet_settle_queue_04 with status = on, retention = off
	, poison_message_handling (status = on) on [serviceBroker]
create service parlaybet_settle_send_service_04 on queue parlaybet_settle_queue_04(parlaybet_settle_contract_04)
create service parlaybet_settle_receive_service_04 on queue parlaybet_settle_queue_04(parlaybet_settle_contract_04)

