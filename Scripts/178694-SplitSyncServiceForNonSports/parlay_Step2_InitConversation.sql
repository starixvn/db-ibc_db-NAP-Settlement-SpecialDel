/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/

use bodb02
go

select * from sb.ConversationCount

insert into sb.ConversationCount(functionName, ContractName, Cnt)
values('settlement', 'sitedb1_bet_settle_contract_parlay', 1)
	, ('settlement', 'sitedb2_bet_settle_contract_parlay', 1)

select * from sb.ConfigurationReferenceDetail

insert into sb.ConfigurationReferenceDetail(FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
values('settlement', 'sitedb1_bet_settle_contract_parlay', 'sitedb1_bet_settle_msg_type_parlay', 0, 10)
	, ('settlement', 'sitedb2_bet_settle_contract_parlay', 'sitedb2_bet_settle_msg_type_parlay', 0, 10)

--//site1
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb1_bet_settle_contract_parlay'		  
	, @fromService = 'sitedb1_bet_settle_receive_service_parlay'
	, @toService = 'sitedb1_bet_settle_send_service_parlay'
	, @coversation_number = 1
	, @mode = 'Reset'


--//site2
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb2_bet_settle_contract_parlay'		  
	, @fromService = 'sitedb2_bet_settle_receive_service_parlay'
	, @toService = 'sitedb2_bet_settle_send_service_parlay'
	, @coversation_number = 1
	, @mode = 'Reset'

