/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

use bodb02
go

create message type bet_SiteDB_msg_type_02 validation = none
create contract bet_SiteDB_contract_02(bet_SiteDB_msg_type_02 sent by any)
create queue dbo.bet_SiteDB_queue_02 with status = on, retention = off
	--, activation (status = on, procedure_name = '', max_queue_readers = 10, execute as N'dbo')
	, poison_message_handling (status = on) on [serviceBroker]
create service bet_SiteDB_send_service_02 on queue bet_SiteDB_queue_02(bet_SiteDB_contract_02)
create service bet_SiteDB_receive_service_02 on queue bet_SiteDB_queue_02(bet_SiteDB_contract_02)
