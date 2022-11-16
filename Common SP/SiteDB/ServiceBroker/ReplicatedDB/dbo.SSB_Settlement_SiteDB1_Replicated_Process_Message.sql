USE [bodb02]
GO
/*<info serverAlias="SBSETTLE-bodb02, DBBAL-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB1_Replicated_Process_Message]
as
/*  
	Created: Patrick@20221025
	Task: Process message
	DB: SBSETTLE-bodb02, DBBAL-bodb02
	Revisions:  
		- 20221025@Patrick: Run parallels for sync logs [Redmine:#178694]
*/
begin
	set nocount on
	declare @__conversationHandle uniqueidentifier, @__messageType varchar(200), @__messageBody nvarchar(max)
		, @__messageId varchar(200), @__errmsg varchar(1024)
		, @__startTime datetime2, @__endtime datetime2

	while 1 = 1
	begin
		waitfor (receive top(1) @__conversationHandle = conversation_handle
				, @__messageType = message_type_name
				, @__messageBody = message_body
			from dbo.sitedb1_bet_settle_queue
		), timeout 100

		if @@rowcount = 0
			return

		--set deadlock_priority high
		begin try
			select @__messageId = newid(), @__errmsg = '', @__startTime = sysdatetime()
			exec (@__messageBody)

		end try
		begin catch
			select @__errmsg = error_message()
		end catch

		--if got error then disable Queue as well
		if isnull(@__errmsg, '') <> ''
		begin
			alter queue sitedb1_bet_settle_queue with status = off
		end
		
		--set deadlock_priority normal

		select @__endtime = sysdatetime()

		exec dbo.SSB_Settlement_WriteLogs @MessageId = @__messageId
			, @MessageType			= @__messageType
			, @MessageBody			= @__messageBody
			, @StartTime			= @__startTime
			, @EndTime				= @__endtime
			, @SessionId			= null
			, @ErrorMessage			= @__errmsg
			, @ConversationHandle	= @__conversationHandle
			, @QueueNo				= 0
			, @SiteDBGroupId		= 1

	end
end
