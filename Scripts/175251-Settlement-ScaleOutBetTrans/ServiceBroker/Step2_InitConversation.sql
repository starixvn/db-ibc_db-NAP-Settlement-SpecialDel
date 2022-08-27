USE bodb02
GO
--01
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_SiteDB_contract_01'		  
	, @fromService = 'bet_SiteDB_send_service_01'
	, @toService = 'bet_SiteDB_receive_service_01'
	, @coversation_number = 4
	, @mode = 'Reset'