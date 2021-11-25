/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: init setting

use bodb02
go

insert into [sb].[ConfigurationReference](FunctionName) 
values('settlement')

delete from sb.[ConversationCount]
delete from sb.[ConfigurationReferenceDetail]

insert into [sb].[ConversationCount](FunctionName, ContractName, Cnt)
values('settlement', 'bet_settle_contract_01', 4)
	, ('settlement', 'bet_settle_contract_02', 4)
	, ('settlement', 'bet_settle_contract_03', 4)
	, ('settlement', 'bet_settle_contract_04', 4)
	, ('settlement', 'bet_settle_contract_05', 4)
	, ('settlement', 'bet_settle_contract_06', 4)
	, ('settlement', 'bet_settle_contract_07', 4)
	, ('settlement', 'bet_settle_contract_08', 4)

insert into [sb].[ConversationCount](FunctionName, ContractName, Cnt)
values('settlement', 'bet_settle_contract_prepare_01', 4)
	, ('settlement', 'bet_settle_contract_prepare_02', 4)
	, ('settlement', 'bet_settle_contract_prepare_03', 4)
	, ('settlement', 'bet_settle_contract_prepare_04', 4)
	, ('settlement', 'bet_settle_contract_prepare_05', 4)
	, ('settlement', 'bet_settle_contract_prepare_06', 4)
	, ('settlement', 'bet_settle_contract_prepare_07', 4)
	, ('settlement', 'bet_settle_contract_prepare_08', 4)

insert into [sb].[ConfigurationReferenceDetail](FunctionName, ContractName, MessageType)
values('settlement', 'bet_settle_contract_01', 'bet_settle_msg_type_01')
	, ('settlement', 'bet_settle_contract_02', 'bet_settle_msg_type_02')
	, ('settlement', 'bet_settle_contract_03', 'bet_settle_msg_type_03')
	, ('settlement', 'bet_settle_contract_04', 'bet_settle_msg_type_04')
	, ('settlement', 'bet_settle_contract_05', 'bet_settle_msg_type_05')
	, ('settlement', 'bet_settle_contract_06', 'bet_settle_msg_type_06')
	, ('settlement', 'bet_settle_contract_07', 'bet_settle_msg_type_07')
	, ('settlement', 'bet_settle_contract_08', 'bet_settle_msg_type_08')

insert into [sb].[ConfigurationReferenceDetail](FunctionName, ContractName, MessageType)
values('settlement', 'bet_settle_contract_prepare_01', 'bet_settle_msg_type_prepare_01')
	, ('settlement', 'bet_settle_contract_prepare_02', 'bet_settle_msg_type_prepare_02')
	, ('settlement', 'bet_settle_contract_prepare_03', 'bet_settle_msg_type_prepare_03')
	, ('settlement', 'bet_settle_contract_prepare_04', 'bet_settle_msg_type_prepare_04')
	, ('settlement', 'bet_settle_contract_prepare_05', 'bet_settle_msg_type_prepare_05')
	, ('settlement', 'bet_settle_contract_prepare_06', 'bet_settle_msg_type_prepare_06')
	, ('settlement', 'bet_settle_contract_prepare_07', 'bet_settle_msg_type_prepare_07')
	, ('settlement', 'bet_settle_contract_prepare_08', 'bet_settle_msg_type_prepare_08')

select 'end conversation ''' + cast(conversation_handle as varchar(200)) +''' with cleanup ', * from sys.conversation_endpoints
--01
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_01'		  
	, @fromService = 'bet_settle_send_service_01'
	, @toService = 'bet_settle_receive_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

--02
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_02'		  
	, @fromService = 'bet_settle_send_service_02'
	, @toService = 'bet_settle_receive_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

--03
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_03'		  
	, @fromService = 'bet_settle_send_service_03'
	, @toService = 'bet_settle_receive_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

--04
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_04'		  
	, @fromService = 'bet_settle_send_service_04'
	, @toService = 'bet_settle_receive_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'

--05
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_05'		  
	, @fromService = 'bet_settle_send_service_05'
	, @toService = 'bet_settle_receive_service_05'
	, @coversation_number = 4
	, @mode = 'Reset'

--06
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_06'		  
	, @fromService = 'bet_settle_send_service_06'
	, @toService = 'bet_settle_receive_service_06'
	, @coversation_number = 4
	, @mode = 'Reset'

--07
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_07'		  
	, @fromService = 'bet_settle_send_service_07'
	, @toService = 'bet_settle_receive_service_07'
	, @coversation_number = 4
	, @mode = 'Reset'

--08
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_08'		  
	, @fromService = 'bet_settle_send_service_08'
	, @toService = 'bet_settle_receive_service_08'
	, @coversation_number = 4
	, @mode = 'Reset'

--prepare_01
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_01'		  
	, @fromService = 'bet_settle_send_service_prepare_01'
	, @toService = 'bet_settle_send_service_prepare_01'
	,@coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_02'		  
	, @fromService = 'bet_settle_send_service_prepare_02'
	, @toService = 'bet_settle_send_service_prepare_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_03'		  
	, @fromService = 'bet_settle_send_service_prepare_03'
	, @toService = 'bet_settle_send_service_prepare_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_04'		  
	, @fromService = 'bet_settle_send_service_prepare_04'
	, @toService = 'bet_settle_send_service_prepare_04'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_05'		  
	, @fromService = 'bet_settle_send_service_prepare_05'
	, @toService = 'bet_settle_send_service_prepare_05'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_06'		  
	, @fromService = 'bet_settle_send_service_prepare_06'
	, @toService = 'bet_settle_send_service_prepare_06'
	,@coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_07'		  
	, @fromService = 'bet_settle_send_service_prepare_07'
	, @toService = 'bet_settle_send_service_prepare_07'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_08'		  
	, @fromService = 'bet_settle_send_service_prepare_08'
	, @toService = 'bet_settle_send_service_prepare_08'
	,@coversation_number = 4
	, @mode = 'Reset'
