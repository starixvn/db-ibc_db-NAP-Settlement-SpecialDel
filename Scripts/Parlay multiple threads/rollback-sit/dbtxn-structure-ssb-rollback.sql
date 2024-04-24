/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: setup ssb objects
--01
use bodb02
go
drop service parlaybet_settle_receive_service_01
drop service parlaybet_settle_send_service_01
drop queue dbo.parlaybet_settle_queue_01 
drop contract parlaybet_settle_contract_01
drop message type parlaybet_settle_msg_type_01

--02
drop service parlaybet_settle_receive_service_02
drop service parlaybet_settle_send_service_02
drop queue dbo.parlaybet_settle_queue_02
drop contract parlaybet_settle_contract_02
drop message type parlaybet_settle_msg_type_02

--03
drop service parlaybet_settle_receive_service_03
drop service parlaybet_settle_send_service_03
drop queue dbo.parlaybet_settle_queue_03
drop contract parlaybet_settle_contract_03
drop message type parlaybet_settle_msg_type_03

--04
drop service parlaybet_settle_receive_service_04
drop service parlaybet_settle_send_service_04
drop queue dbo.parlaybet_settle_queue_04
drop contract parlaybet_settle_contract_04
drop message type parlaybet_settle_msg_type_04

