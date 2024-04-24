USE [bodb02]
GO
/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB1_Replicated_Process_Message_parlay]
as
/*
	Created by: 20221011@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
		- 20240410@Kathy: missing bettrans14 table [Redmine:#203737]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]

	Param's Explanation:  
		   
*/
begin
	set nocount on
	declare @__conversationHandle uniqueidentifier, @__messageBody nvarchar(max), @__messageBodyTemp nvarchar(max), @__params xml
			,@__siteDBGroupId smallint, @__sessionId bigint, @__messageType varchar(200), @__transInfo nvarchar(max), @__transinfoJson varbinary(max)
			,@__tableName varchar(200), @__matchId int, @__action varchar(1), @__settlementAction varchar(20), @__ticketType varchar(1)
			,@__totalQueue int,@__totalParlayQueue int, @__runOnServer varchar(100), @__is3rd bit, @__AffectedTicket int
			
			,@__messageId varchar(200), @__errmsg varchar(1024),@__startTime datetime2, @__endtime datetime2, @__TableType SMALLINT

	while 1 = 1
	begin
		waitfor (receive top(1) @__conversationHandle = conversation_handle
				, @__messageType = message_type_name
				, @__messageBody = message_body
			from dbo.sitedb1_bet_settle_queue_parlay
		), timeout 100

		if @@rowcount = 0
			return

		--set deadlock_priority high
		begin try
			SET @__params = cast(@__messageBody as xml)

			select @__siteDBGroupId = T.C.value('@SiteDBGroupId','smallint')
				,@__sessionId = T.C.value('@SessionId','bigint')
				,@__messageType = T.C.value('@MessageType','varchar(200)')
				,@__transInfo = T.C.value('@TransInfo','varchar(max)')
				,@__transinfoJson = convert( varbinary(max), T.C.value('@TransInfoJson','varchar(max)'),1)
				,@__tableName = T.C.value('@TableName', 'varchar(128)') 
				,@__matchId = T.C.value('@MatchId','int')
				,@__action = T.C.value('@Action','varchar(1)')
				,@__settlementAction = T.C.value('@SettlementAction','varchar(20)')
				,@__ticketType = T.C.value('@TicketType','varchar(1)')
				,@__totalQueue = T.C.value('@TotalQueue','int')
				,@__totalParlayQueue = T.C.value('@TotalParlayQueue','int')
				,@__runOnServer = T.C.value('@RunOnServer','varchar(100)')
				,@__is3rd = T.C.value('@Is3rd','bit')
			from @__params.nodes('/root/r') as T(C)

			select @__messageId = newid(), @__errmsg = '', @__startTime = sysdatetime()
			
			if @__tableName = 'bettrans14'
			begin
				exec dbo.Bet_ExecRep14_04 
					@TransInfoJson = @__transinfoJson
					,@TableName = @__tableName
					,@Action = @__action
					,@RunOnServer = @__runOnServer
					,@CalledByBrokerService	= 1
			end
			else 
			begin
				exec dbo.Bet_ExecRep_NAP_Admin_01 
					@SiteDBGroupId	= @__siteDBGroupId
					,@SessionId	= @__sessionId
					,@MessageType = @__messageType
					,@TransInfo	= @__transInfo
					,@TransInfoJson = @__transinfoJson
					,@TableName = @__tableName
					,@MatchId = @__matchId
					,@Action = @__action
					,@SettlementAction = @__settlementAction
					,@TicketType = @__ticketType
					,@TotalQueue = @__totalQueue
					,@TotalParlayQueue = @__totalParlayQueue
					,@RunOnServer = @__runOnServer			
					,@Is3rd	= @__is3rd	
					,@CalledByBrokerService	= 1
					,@AffectedTicket = @__AffectedTicket output
					,@ErrMsg = @__errmsg output
			end
		end try
		begin catch
			select @__errmsg = error_message()
		end catch

		--if got error then disable Queue as well
		if isnull(@__errmsg, '') <> ''
		begin
			alter queue sitedb1_bet_settle_queue_parlay with status = off
		end
		
		--set deadlock_priority normal

		select @__endtime = sysdatetime()
				,@__TableType = case 
									when @__tableName = 'bettrans' then 1
									when @__tableName = 'bettransm' then 2
									else 0
								end
				,@__messageBodyTemp = case when @__tableName = 'bettrans14' then 'EXEC dbo.Bet_ExecRep14_04 @TransInfoJson=''' + convert(nvarchar(max), @__transinfoJson, 1) + '''' 
																+ case when @__tableName is not null then ',@TableName=' + '''' + @__tableName + '''' else '' end
																+ case when @__action is not null then ',@Action=' + '''' + @__action + '''' else '' end
																+ case when @__runOnServer is not null then ',@RunOnServer=' + '''' + @__runOnServer + '''' else '' end
									 else 'EXEC dbo.Bet_ExecRep_NAP_Admin_01 '
										+ '@SiteDBGroupId=' + cast(@__siteDBGroupId as varchar(20))
										+ case when @__sessionId is not null then ',@SessionId=' + cast(@__sessionId as varchar(30)) else '' end
										+ case when @__messageType is not null then ',@MessageType=' + '''' + @__messageType + '''' else '' end
										+ case when @__transInfo is not null then ',@TransInfo=''' + convert(nvarchar(max),@__transInfo) + '''' else '' end
										+ case when @__transinfoJson is not null then ',@TransInfoJson=''' + convert(nvarchar(max), @__transinfoJson, 1) + '''' else '' end
										+ case when @__tableName is not null then ',@TableName=' + '''' + @__tableName + '''' else '' end
										+ case when @__matchId is not null then ',@MatchId=' + cast(@__matchId as varchar(20))  else '' end
										+ case when @__action is not null then ',@Action=' + '''' + @__action + '''' else '' end
										+ case when @__settlementAction is not null then ',@SettlementAction=' + '''' + @__settlementAction + '''' else '' end
										+ case when @__ticketType is not null then ',@TicketType=' + '''' + @__ticketType + '''' else '' end
										+ case when @__totalQueue is not null then ',@TotalQueue=' + cast(@__totalQueue as varchar(20))  else '' end
									+ case when @__totalParlayQueue is not null then ',@TotalParlayQueue=' + cast(@__totalParlayQueue as varchar(20))  else '' end
										+ case when @__runOnServer is not null then ',@RunOnServer=' + '''' + @__runOnServer + '''' else '' end
										+ case when @__is3rd is not null then ',@Is3rd=' + cast(@__is3rd as varchar(20))  else '' end
										+ ',@CalledByBrokerService=1'
									end

		exec dbo.SSB_Settlement_WriteLogs @MessageId = @__messageId
			, @MessageType			= @__messageType
			, @MessageBody			= @__messageBodyTemp
			, @StartTime			= @__startTime
			, @EndTime				= @__endtime
			, @SessionId			= @__sessionId
			, @ErrorMessage			= @__errmsg
			, @ConversationHandle	= @__conversationHandle
			, @QueueNo				= 0
			, @SiteDBGroupId		= @__siteDBGroupId
			, @MatchId				= @__matchId
			, @AffectedTicket 		= @__AffectedTicket 
			, @TableType			= @__TableType
			, @EventTable			= 1

	end
end
