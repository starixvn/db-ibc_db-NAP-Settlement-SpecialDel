/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02,DBBAL-bodb02"></info>*/

use bodb02
go

select * from sb.ConversationCount

insert into sb.ConversationCount(functionName, ContractName, Cnt)
values('settlement', 'sitedb3_bet_settle_contract_parlay', 1)

select * from sb.ConfigurationReferenceDetail

insert into sb.ConfigurationReferenceDetail(FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
values('settlement', 'sitedb3_bet_settle_contract_parlay', 'sitedb3_bet_settle_msg_type_parlay', 0, 10)
	
--//site3
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'sitedb3_bet_settle_contract_parlay'		  
	, @fromService = 'sitedb3_bet_settle_receive_service_parlay'
	, @toService = 'sitedb3_bet_settle_send_service_parlay'
	, @coversation_number = 1
	, @mode = 'Reset'


