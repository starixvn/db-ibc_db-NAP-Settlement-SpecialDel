/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/

use bodb02
go

select * from sb.ConversationCount

insert into sb.ConversationCount(functionName, ContractName, Cnt)
values('settlement', 'sitedb1_bet_settle_contract_3rd', 1)
	, ('settlement', 'sitedb2_bet_settle_contract_3rd', 1)

select * from sb.ConfigurationReferenceDetail

insert into sb.ConfigurationReferenceDetail(FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
values('settlement', 'sitedb1_bet_settle_contract_3rd', 'sitedb1_bet_settle_msg_type_3rd', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract_3rd', 'sitedb2_bet_settle_msg_type_3rd', 0, 10)

--//site1
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract_3rd'		  
	, @fromService = 'sitedb1_bet_settle_receive_service_3rd'
	, @toService = 'sitedb1_bet_settle_send_service_3rd'
	, @coversation_number = 1
	, @mode = 'Reset'


--//site2
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract_3rd'		  
	, @fromService = 'sitedb2_bet_settle_receive_service_3rd'
	, @toService = 'sitedb2_bet_settle_send_service_3rd'
	, @coversation_number = 1
	, @mode = 'Reset'
