/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB3_Process_Message_3rd]
as
/*
	Created by: 20221011@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]

	Param's Explanation:  
		   
*/
begin
	set nocount on
	declare @__conversationHandle uniqueidentifier, @__messageType varchar(200)
		, @__messageBody nvarchar(max), @__messageId varchar(200)

	while 1 = 1
	begin
		waitfor (receive top(1) @__conversationHandle = conversation_handle
				, @__messageType = message_type_name
				, @__messageBody = message_body
			from dbo.sitedb3_bet_settle_queue_3rd
		), timeout 100

		if @@rowcount = 0
			return

		set @__messageId = newid()

		exec dbo.SSB_Settlement_SiteDB_Execute_Message_3rd @ConversationHandle = @__conversationHandle
			, @MessageBody = @__messageBody
			, @MessageType = @__messageType
			, @MessageId = @__messageId

	end
end
