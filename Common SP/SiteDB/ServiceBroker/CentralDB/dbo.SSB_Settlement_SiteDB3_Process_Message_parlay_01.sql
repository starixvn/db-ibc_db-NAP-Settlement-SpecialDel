USE [bodb02]
GO
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB3_Process_Message_parlay_01]
as
/*  Created: Kathy@20240215
	Task: Process parlay message
	DB: DBCTG-bodb02
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
			from dbo.sitedb3_parlaybet_settle_queue_01
		), timeout 100

		if @@rowcount = 0
			return

		select @__messageId = newid()
		exec dbo.SSB_Settlement_SiteDB_UpdateData_parlay @ConversationHandle = @__conversationHandle
			, @MessageType = @__messageType
			, @MessageBody = @__messageBody
			, @MessageId = @__messageId
			, @QueueNo = 1

	end
end
