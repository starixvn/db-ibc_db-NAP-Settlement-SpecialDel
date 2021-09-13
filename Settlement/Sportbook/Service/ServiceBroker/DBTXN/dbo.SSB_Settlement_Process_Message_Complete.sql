/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_Settlement_Process_Message_Complete
as
/*  Created: Patrick@20210801
	Task: Process message
	DB: DBTXN-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin
	set nocount on
	declare @__conversationHandle uniqueidentifier, @__messageType varchar(200), @__messageBoby nvarchar(max)
		, @__messageId varchar(200)

	waitfor (receive top(1) @__conversationHandle = conversation_handle
			, @__messageType = message_type_name
			, @__messageBoby = message_body
		from dbo.bet_settle_queue_complete
	), timeout 100

	if @@rowcount = 0
		return

	select @__messageId = newid()
	exec dbo.SSB_Settlement_Execute_Message @ConversationHandle = @__conversationHandle
		, @MessageType = @__messageType
		, @MessageBoby = @__messageBoby
		, @MessageId = @__messageId

end
go