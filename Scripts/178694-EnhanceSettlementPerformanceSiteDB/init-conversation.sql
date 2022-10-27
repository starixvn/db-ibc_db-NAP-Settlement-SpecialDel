/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/

use bodb02
go

select * from sb.ConversationCount

insert into sb.ConversationCount(functionName, ContractName, Cnt)
values('settlement', 'sitedb1_bet_settle_contract', 4)
	, ('settlement', 'sitedb1_bet_settle_contract_01', 4)
	, ('settlement', 'sitedb1_bet_settle_contract_02', 4)
	, ('settlement', 'sitedb1_bet_settle_contract_03', 4)
	, ('settlement', 'sitedb1_bet_settle_contract_04', 4)
	, ('settlement', 'sitedb2_bet_settle_contract', 4)
	, ('settlement', 'sitedb2_bet_settle_contract_01', 4)
	, ('settlement', 'sitedb2_bet_settle_contract_02', 4)
	, ('settlement', 'sitedb2_bet_settle_contract_03', 4)
	, ('settlement', 'sitedb2_bet_settle_contract_04', 4)

select * from sb.ConfigurationReferenceDetail

insert into sb.ConfigurationReferenceDetail(FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
values('settlement', 'sitedb1_bet_settle_contract', 'sitedb1_bet_settle_msg_type', 0, 10)
	, ('settlement', 'sitedb1_bet_settle_contract_01', 'sitedb1_bet_settle_msg_type_01', 0, 10)
	, ('settlement', 'sitedb1_bet_settle_contract_02', 'sitedb1_bet_settle_msg_type_02', 0, 10)
	, ('settlement', 'sitedb1_bet_settle_contract_03', 'sitedb1_bet_settle_msg_type_03', 0, 10)
	, ('settlement', 'sitedb1_bet_settle_contract_04', 'sitedb1_bet_settle_msg_type_04', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract', 'sitedb2_bet_settle_msg_type', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract_01', 'sitedb2_bet_settle_msg_type_01', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract_02', 'sitedb2_bet_settle_msg_type_02', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract_03', 'sitedb2_bet_settle_msg_type_03', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract_04', 'sitedb2_bet_settle_msg_type_04', 0, 10)

--//site1
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract'		  
	, @fromService = 'sitedb1_bet_settle_receive_service'
	, @toService = 'sitedb1_bet_settle_send_service'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract_01'		  
	, @fromService = 'sitedb1_bet_settle_receive_service_01'
	, @toService = 'sitedb1_bet_settle_send_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract_02'		  
	, @fromService = 'sitedb1_bet_settle_receive_service_02'
	, @toService = 'sitedb1_bet_settle_send_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract_03'		  
	, @fromService = 'sitedb1_bet_settle_receive_service_03'
	, @toService = 'sitedb1_bet_settle_send_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract_04'		  
	, @fromService = 'sitedb1_bet_settle_receive_service_04'
	, @toService = 'sitedb1_bet_settle_send_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'

--//site2
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract'		  
	, @fromService = 'sitedb2_bet_settle_receive_service'
	, @toService = 'sitedb2_bet_settle_send_service'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract_01'		  
	, @fromService = 'sitedb2_bet_settle_receive_service_01'
	, @toService = 'sitedb2_bet_settle_send_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract_02'		  
	, @fromService = 'sitedb2_bet_settle_receive_service_02'
	, @toService = 'sitedb2_bet_settle_send_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract_03'		  
	, @fromService = 'sitedb2_bet_settle_receive_service_03'
	, @toService = 'sitedb2_bet_settle_send_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract_04'		  
	, @fromService = 'sitedb2_bet_settle_receive_service_04'
	, @toService = 'sitedb2_bet_settle_send_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'