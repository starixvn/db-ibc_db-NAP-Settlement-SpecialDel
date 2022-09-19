/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
create procedure dbo.SSB_Replicated_SyncSiteDB_Process
as
/*  Created: Kathy@20220827
	Task: Pick conversation
	DB: SBSETTLE-bodb02,DBBAL-bodb02
	Revisions:  
		- 20220827@Kathy: Scale Out BetTrans [Redmine:#175251]
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
			from dbo.bet_SiteDB_queue_01
		), timeout 100

		if @@rowcount = 0
			return

		select @__messageId = newid()
		exec dbo.SSB_Replicated_SyncSiteDB_UpdateData @ConversationHandle = @__conversationHandle
			, @MessageType = @__messageType
			, @MessageBody = @__messageBody
			, @MessageId = @__messageId

	end
end
go
