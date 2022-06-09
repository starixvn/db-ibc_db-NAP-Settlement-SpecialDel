/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
--Task: adjust number of prepare queue

USE bodb02
GO
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

go

--++prepare
--01
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_01'		  
	, @fromService = 'bet_settle_send_service_prepare_01'
	, @toService = 'bet_settle_receive_service_prepare_01'
	, @coversation_number = 4
	, @mode = 'Reset'

--02
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_02'		  
	, @fromService = 'bet_settle_send_service_prepare_02'
	, @toService = 'bet_settle_receive_service_prepare_02'
	, @coversation_number = 4
	, @mode = 'Reset'

--03
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_03'		  
	, @fromService = 'bet_settle_send_service_prepare_03'
	, @toService = 'bet_settle_receive_service_prepare_03'
	, @coversation_number = 4
	, @mode = 'Reset'

--04
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_04'		  
	, @fromService = 'bet_settle_send_service_prepare_04'
	, @toService = 'bet_settle_receive_service_prepare_04'
	, @coversation_number = 4
	, @mode = 'Reset'

--05
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_05'		  
	, @fromService = 'bet_settle_send_service_prepare_05'
	, @toService = 'bet_settle_receive_service_prepare_05'
	, @coversation_number = 4
	, @mode = 'Reset'

--06
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_06'		  
	, @fromService = 'bet_settle_send_service_prepare_06'
	, @toService = 'bet_settle_receive_service_prepare_06'
	, @coversation_number = 4
	, @mode = 'Reset'

--07
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_07'		  
	, @fromService = 'bet_settle_send_service_prepare_07'
	, @toService = 'bet_settle_receive_service_prepare_07'
	, @coversation_number = 4
	, @mode = 'Reset'

--08
exec [sb].[DBA_ConversationManagement] 
	  @functionName = 'settlement'
	, @contractName = 'bet_settle_contract_prepare_08'		  
	, @fromService = 'bet_settle_send_service_prepare_08'
	, @toService = 'bet_settle_receive_service_prepare_08'
	, @coversation_number = 4
	, @mode = 'Reset'

go