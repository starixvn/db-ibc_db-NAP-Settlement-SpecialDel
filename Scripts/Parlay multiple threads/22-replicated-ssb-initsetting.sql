/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: init setting

use bodb02
go

delete from sb.[ConfigurationReference] where functionname = 'parlaysettlement'
delete from sb.[ConversationCount] where functionname = 'parlaysettlement' and ContractName like 'parlaybet%'
delete from sb.[ConfigurationReferenceDetail]  where functionname = 'parlaysettlement' and ContractName like 'parlaybet%'

insert into [sb].[ConfigurationReference](FunctionName) 
values('parlaysettlement')


insert into [sb].[ConversationCount](FunctionName, ContractName, Cnt)
values('parlaysettlement', 'parlaybet_settle_contract_01', 4)
	, ('parlaysettlement', 'parlaybet_settle_contract_02', 4)
	, ('parlaysettlement', 'parlaybet_settle_contract_03', 4)
	, ('parlaysettlement', 'parlaybet_settle_contract_04', 4)
	
insert into [sb].[ConfigurationReferenceDetail](FunctionName, ContractName, MessageType)
values('parlaysettlement', 'parlaybet_settle_contract_01', 'parlaybet_settle_msg_type_01')
	, ('parlaysettlement', 'parlaybet_settle_contract_02', 'parlaybet_settle_msg_type_02')
	, ('parlaysettlement', 'parlaybet_settle_contract_03', 'parlaybet_settle_msg_type_03')
	, ('parlaysettlement', 'parlaybet_settle_contract_04', 'parlaybet_settle_msg_type_04')

--01
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'parlaybet_settle_contract_01'		  
	, @fromService = 'parlaybet_settle_send_service_01'
	, @toService = 'parlaybet_settle_receive_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

--02
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'parlaybet_settle_contract_02'		  
	, @fromService = 'parlaybet_settle_send_service_02'
	, @toService = 'parlaybet_settle_receive_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

--03
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'parlaybet_settle_contract_03'		  
	, @fromService = 'parlaybet_settle_send_service_03'
	, @toService = 'parlaybet_settle_receive_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

--04
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'parlaybet_settle_contract_04'		  
	, @fromService = 'parlaybet_settle_send_service_04'
	, @toService = 'parlaybet_settle_receive_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'

