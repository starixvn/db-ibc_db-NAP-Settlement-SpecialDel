/*<info serverAlias="DBCTG-bodb02"></info>*/

use bodb02
go
delete from sb.ConversationCount where functionname = 'parlaysettlement' and ContractName like 'sitedb__parlaybet%'

delete from sb.ConfigurationReferenceDetail where functionname = 'parlaysettlement' and ContractName like 'sitedb__parlaybet%'


insert into sb.ConversationCount(functionName, ContractName, Cnt)
values ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_01', 4)
	, ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_02', 4)
	, ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_03', 4)
	, ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_04', 4)
	

	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_01', 4)
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_02', 4)
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_03', 4)
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_04', 4)

	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_01', 4)
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_02', 4)
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_03', 4)
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_04', 4)

insert into sb.ConfigurationReferenceDetail(FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
values ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_01', 'sitedb1_parlaybet_settle_msg_type_01', 0, 10)
	, ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_02', 'sitedb1_parlaybet_settle_msg_type_02', 0, 10)
	, ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_03', 'sitedb1_parlaybet_settle_msg_type_03', 0, 10)
	, ('parlaysettlement', 'sitedb1_parlaybet_settle_contract_04', 'sitedb1_parlaybet_settle_msg_type_04', 0, 10)
	
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_01', 'sitedb2_parlaybet_settle_msg_type_01', 0, 10)
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_02', 'sitedb2_parlaybet_settle_msg_type_02', 0, 10)
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_03', 'sitedb2_parlaybet_settle_msg_type_03', 0, 10)
	, ('parlaysettlement', 'sitedb2_parlaybet_settle_contract_04', 'sitedb2_parlaybet_settle_msg_type_04', 0, 10)

	
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_01', 'sitedb3_parlaybet_settle_msg_type_01', 0, 10)
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_02', 'sitedb3_parlaybet_settle_msg_type_02', 0, 10)
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_03', 'sitedb3_parlaybet_settle_msg_type_03', 0, 10)
	, ('parlaysettlement', 'sitedb3_parlaybet_settle_contract_04', 'sitedb3_parlaybet_settle_msg_type_04', 0, 10)

--//site1
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb1_parlaybet_settle_contract_01'		  
	, @fromService = 'sitedb1_parlaybet_settle_receive_service_01'
	, @toService = 'sitedb1_parlaybet_settle_send_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb1_parlaybet_settle_contract_02'		  
	, @fromService = 'sitedb1_parlaybet_settle_receive_service_02'
	, @toService = 'sitedb1_parlaybet_settle_send_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb1_parlaybet_settle_contract_03'		  
	, @fromService = 'sitedb1_parlaybet_settle_receive_service_03'
	, @toService = 'sitedb1_parlaybet_settle_send_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb1_parlaybet_settle_contract_04'		  
	, @fromService = 'sitedb1_parlaybet_settle_receive_service_04'
	, @toService = 'sitedb1_parlaybet_settle_send_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'

--//site2

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb2_parlaybet_settle_contract_01'		  
	, @fromService = 'sitedb2_parlaybet_settle_receive_service_01'
	, @toService = 'sitedb2_parlaybet_settle_send_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb2_parlaybet_settle_contract_02'		  
	, @fromService = 'sitedb2_parlaybet_settle_receive_service_02'
	, @toService = 'sitedb2_parlaybet_settle_send_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb2_parlaybet_settle_contract_03'		  
	, @fromService = 'sitedb2_parlaybet_settle_receive_service_03'
	, @toService = 'sitedb2_parlaybet_settle_send_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb2_parlaybet_settle_contract_04'		  
	, @fromService = 'sitedb2_parlaybet_settle_receive_service_04'
	, @toService = 'sitedb2_parlaybet_settle_send_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'



--//site3
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb3_parlaybet_settle_contract_01'		  
	, @fromService = 'sitedb3_parlaybet_settle_receive_service_01'
	, @toService = 'sitedb3_parlaybet_settle_send_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb3_parlaybet_settle_contract_02'		  
	, @fromService = 'sitedb3_parlaybet_settle_receive_service_02'
	, @toService = 'sitedb3_parlaybet_settle_send_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb3_parlaybet_settle_contract_03'		  
	, @fromService = 'sitedb3_parlaybet_settle_receive_service_03'
	, @toService = 'sitedb3_parlaybet_settle_send_service_03'
	, @coversation_number = 4
	, @mode = 'Reset'

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'parlaysettlement'
	, @contractName = 'sitedb3_parlaybet_settle_contract_04'		  
	, @fromService = 'sitedb3_parlaybet_settle_receive_service_04'
	, @toService = 'sitedb3_parlaybet_settle_send_service_04'
	, @coversation_number = 4
	, @mode = 'Reset'