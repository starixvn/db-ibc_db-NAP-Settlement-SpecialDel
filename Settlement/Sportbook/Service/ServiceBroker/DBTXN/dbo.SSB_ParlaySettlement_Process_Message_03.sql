/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_ParlaySettlement_Process_Message_03
as
/*  Created: Kathy@20240215
	Task: Process message
	DB: DBTXN-bodb02
	Revisions:  
		- 20240215@Kathy: Implement parlay settlement can run parallels [Redmine:#]
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
			from dbo.parlaybet_settle_queue_03
		), timeout 100

		if @@rowcount = 0
			return

		select @__messageId = newid()
		exec dbo.SSB_ParlaySettlement_UpdateData @ConversationHandle = @__conversationHandle
			, @MessageType = @__messageType
			, @MessageBody = @__messageBody
			, @MessageId = @__messageId
			, @QueueNo = 3

	end

end
go
