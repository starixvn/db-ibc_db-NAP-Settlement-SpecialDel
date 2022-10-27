USE [bodb02]
GO
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB1_Process_Message]
as
/*  
	Created: Patrick@20221025
	Task: Process message
	DB: DBCTG-bodb02
	Revisions:  
		- 20221025@Patrick: Run parallels for sync logs [Redmine:#178694]
*/
begin
	set nocount on
	declare @__conversationHandle uniqueidentifier, @__messageType varchar(200), @__messageBody nvarchar(max)
		, @__messageId varchar(200), @__errmsg varchar(1024), @__errCode int, @__transInfo nvarchar(max)
		, @__params xml, @__tableName varchar(200), @__matchId int
		, @__action varchar(1), @__settlementAction varchar(20), @__ticketType varchar(1)
		, @__processingId bigint, @__startTime datetime2, @__endtime datetime2
		, @__sessionId bigint, @__siteDBGroupId smallint

	while 1 = 1
	begin
		waitfor (receive top(1) @__conversationHandle = conversation_handle
				, @__messageType = message_type_name
				, @__messageBody = message_body
			from dbo.sitedb1_bet_settle_queue
		), timeout 100

		if @@rowcount = 0
			return

		select @__messageId = newid(), @__startTime = sysdatetime(), @__params = cast(@__messageBody as xml)
			, @__errmsg = null, @__tableName = null, @__matchId = null, @__action = null, @__settlementAction = null
			, @__ticketType = null, @__transInfo = null, @__siteDBGroupId = null, @__sessionId = null
			, @__processingId = null

		--set deadlock_priority high
		begin try
			
			select @__tableName = T.C.value('@tblName', 'varchar(128)') 
				,@__matchId = T.C.value('@matchid','int')
				,@__action = T.C.value('@action','varchar(1)')
				,@__settlementAction = T.C.value('@setAction','varchar(20)')
				,@__ticketType = T.C.value('@ticketType','varchar(1)')
				,@__transInfo = T.C.value('@transInfo','varchar(max)')
				,@__siteDBGroupId = T.C.value('@siteDBGroupId','smallint')
				,@__sessionId = T.C.value('@sessionId','bigint')
				,@__processingId = T.C.value('@processingId','bigint')
			from @__params.nodes('/root/r') as T(C)

			exec dbo.NAP_SettlementService_Calculation @TransInfo = @__transInfo
				,@TableName						= @__tableName
				,@MatchId						= @__matchId
				,@Action						= @__action
				,@SettlementAction				= @__settlementAction
				,@TicketType					= @__ticketType
				--,@SiteDBGroupId				= @__siteDBGroupId
				--,@SessionId					= @__sessionId
				--,@ProcessingId				= @__processingId
				,@ErrCode						= @__errCode output
				,@ErrMsg						= @__errmsg output

		end try
		begin catch
			select @__errmsg = error_message()
			alter queue sitedb1_bet_settle_queue with status = off
		end catch
		
		--set deadlock_priority normal

		declare @__messageBodyTemp nvarchar(max)
		select @__messageBodyTemp = 'exec dbo.NAP_SettlementService_Calculation '
				+ case when @__transInfo is not null then ',@TransInfo=''' + @__transInfo + '''' else '' end
				+ case when @__tableName is not null then ',@TableName=''' + @__tableName + '''' else '' end
				+ case when @__matchId is not null then ',@MatchId=' + cast(@__matchId as varchar(20)) else '' end
				+ case when @__action is not null then ',@Action=''' + @__action + '''' else '' end
				+ case when @__transInfo is not null then ',@SettlementAction=''' + @__settlementAction + '''' else '' end
				+ case when @__ticketType is not null then ',@TicketType=''' + @__ticketType + '''' else '' end
				+ case when @__processingId is not null then ',@ProcessingId=' + cast(@__processingId as varchar(50)) + '' else '' end
				+ case when @__siteDBGroupId is not null then ',@SiteDBGroupId=' + cast(@__siteDBGroupId as varchar(50)) + '' else '' end
				+ case when @__sessionId is not null then ',@SessionId=' + cast(@__sessionId as varchar(50)) + '' else '' end
			, @__endtime = sysdatetime()

		exec dbo.SSB_Settlement_WriteLogs @MessageId = @__messageId
			, @MessageType			= @__messageType
			, @MessageBody			= @__messageBodyTemp
			, @StartTime			= @__startTime
			, @EndTime				= @__endtime
			, @SessionId			= @__sessionId
			, @ErrorMessage			= @__errmsg
			, @ConversationHandle	= @__conversationHandle
			, @QueueNo				= 1
			, @SiteDBGroupId		= @__siteDBGroupId

	end
end
