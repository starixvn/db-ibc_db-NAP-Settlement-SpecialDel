USE [bodb02]
GO
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB2_Process_Message_03]
as
/*  Created: Patrick@20221025
	Task: Process message
	DB: DBCTG-bodb02
	
	Revisions:  
		- 20221025@Patrick: Run parallels for sync logs [Redmine:#178694]
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
			from dbo.sitedb2_bet_settle_queue_03
		), timeout 100

		if @@rowcount = 0
			return

		select @__messageId = newid()
		exec dbo.SSB_Settlement_SiteDB_UpdateData @ConversationHandle = @__conversationHandle
			, @MessageType = @__messageType
			, @MessageBody = @__messageBody
			, @MessageId = @__messageId
			, @QueueNo = 3

	end
end
