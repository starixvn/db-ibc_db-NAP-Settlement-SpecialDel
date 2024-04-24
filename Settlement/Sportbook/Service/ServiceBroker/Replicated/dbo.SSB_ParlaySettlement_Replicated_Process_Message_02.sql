/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_ParlaySettlement_Replicated_Process_Message_02
as
/*  Created: Kathy@20240122
	Task: support multiple threads to settle parlay [Redmine:#199518]
	DB: DBTXN-bodb02
	Revisions:  
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		
*/
begin
	set nocount on
	declare @__conversationHandle uniqueidentifier, @__messageType varchar(200), @__messageBody nvarchar(max)
		, @__messageId varchar(200)

	while 1 = 1
	begin
		waitfor (receive top(1) @__conversationHandle = conversation_handle
				, @__messageType = message_type_name
				, @__messageBody = message_body
			from dbo.parlaybet_settle_queue_02
		), timeout 100

		if @@rowcount = 0
			return

		select @__messageId = newid()
		exec dbo.SSB_ParlaySettlement_Replicated_UpdateData @ConversationHandle = @__conversationHandle
			, @MessageType = @__messageType
			, @MessageBody = @__messageBody
			, @MessageId = @__messageId
			, @QueueNo = 2

	end
end
go
