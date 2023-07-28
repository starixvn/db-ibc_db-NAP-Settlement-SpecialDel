USE [bodb02]
GO
/*<info serverAlias="SBSETTLE-bodb02, DBBAL-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB3_Replicated_Process_Message_parlay]
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
	declare @__conversationHandle uniqueidentifier, @__messageType varchar(200), @__messageBody nvarchar(max)
		, @__messageId varchar(200), @__errmsg varchar(1024)
		, @__startTime datetime2, @__endtime datetime2

	while 1 = 1
	begin
		waitfor (receive top(1) @__conversationHandle = conversation_handle
				, @__messageType = message_type_name
				, @__messageBody = message_body
			from dbo.sitedb3_bet_settle_queue_parlay
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
			alter queue sitedb3_bet_settle_queue_parlay with status = off
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
			, @SiteDBGroupId		= 3

	end
end
