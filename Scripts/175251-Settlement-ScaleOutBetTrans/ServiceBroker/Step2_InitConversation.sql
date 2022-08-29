USE bodb02
GO
--01

INSERT INTO sb.ConfigurationReferenceDetail (FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
VALUES ('settlement', 'bet_SiteDB_contract_01', 'bet_SiteDB_msg_type_01', 5, 20)

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_SiteDB_contract_01'		  
	, @fromService = 'bet_SiteDB_send_service_01'
	, @toService = 'bet_SiteDB_receive_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'