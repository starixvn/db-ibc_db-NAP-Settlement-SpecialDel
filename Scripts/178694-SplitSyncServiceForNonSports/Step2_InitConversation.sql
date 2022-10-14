/*<info serverAlias="SBSETTLE-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

-- sitedb1: 3rd
INSERT INTO sb.ConfigurationReferenceDetail (FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
VALUES ('settlement', 'bet_SiteDB_3rd_contract_01', 'bet_SiteDB_3rd_msg_type_01', 5, 20)

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_SiteDB_3rd_contract_01'		  
	, @fromService = 'bet_SiteDB_3rd_send_service_01'
	, @toService = 'bet_SiteDB_3rd_receive_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'


-- sitedb2: 3rd
INSERT INTO sb.ConfigurationReferenceDetail (FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
VALUES ('settlement', 'bet_SiteDB_3rd_contract_02', 'bet_SiteDB_3rd_msg_type_02', 5, 20)

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_SiteDB_3rd_contract_02'		  
	, @fromService = 'bet_SiteDB_3rd_send_service_02'
	, @toService = 'bet_SiteDB_3rd_receive_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'


-- sitedb2: SB
INSERT INTO sb.ConfigurationReferenceDetail (FunctionName, ContractName, MessageType, MinConversation, MaxConversation)
VALUES ('settlement', 'bet_SiteDB_contract_02', 'bet_SiteDB_msg_type_02', 5, 20)

exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_SiteDB_contract_02'		  
	, @fromService = 'bet_SiteDB_send_service_02'
	, @toService = 'bet_SiteDB_receive_service_02'
	, @coversation_number = 4
	, @mode = 'Reset'

GO

