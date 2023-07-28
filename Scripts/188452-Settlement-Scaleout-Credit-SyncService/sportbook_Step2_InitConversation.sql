/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/

use bodb02
go

select * from sb.ConversationCount

insert into sb.ConversationCount(functionName, ContractName, Cnt)
values('settlement', 'sitedb3_bet_settle_contract', 1)
	, ('settlement', 'sitedb3_bet_settle_contract_01', 4)
	, ('settlement', 'sitedb3_bet_settle_contract_02', 4)
	, ('settlement', 'sitedb3_bet_settle_contract_03', 4)
	, ('settlement', 'sitedb3_bet_settle_contract_04', 4)

select * from sb.ConfigurationReferenceDetail

insert into sb.ConfigurationReferenceDetail(FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
values('settlement', 'sitedb3_bet_settle_contract', 'sitedb3_bet_settle_msg_type', 0, 10)
	, ('settlement', 'sitedb3_bet_settle_contract_01', 'sitedb3_bet_settle_msg_type_01', 0, 10)
	, ('settlement', 'sitedb3_bet_settle_contract_02', 'sitedb3_bet_settle_msg_type_02', 0, 10)
	, ('settlement', 'sitedb3_bet_settle_contract_03', 'sitedb3_bet_settle_msg_type_03', 0, 10)
	, ('settlement', 'sitedb3_bet_settle_contract_04', 'sitedb3_bet_settle_msg_type_04', 0, 10)
	

--//site3
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb3_bet_settle_contract'		  
	, @fromService = 'sitedb3_bet_settle_receive_service'
	, @toService = 'sitedb3_bet_settle_send_service'
	, @coversation_number = 1
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb3_bet_settle_contract_01'		  
	, @fromService = 'sitedb3_bet_settle_receive_service_01'
	, @toService = 'sitedb3_bet_settle_send_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb3_bet_settle_contract_02'		  
	, @fromService = 'sitedb3_bet_settle_receive_service_02'
	, @toService = 'sitedb3_bet_settle_send_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb3_bet_settle_contract_03'		  
	, @fromService = 'sitedb3_bet_settle_receive_service_03'
	, @toService = 'sitedb3_bet_settle_send_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb3_bet_settle_contract_04'		  
	, @fromService = 'sitedb3_bet_settle_receive_service_04'
	, @toService = 'sitedb3_bet_settle_send_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'

