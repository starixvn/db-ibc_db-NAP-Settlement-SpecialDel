USE [bodb02]
GO
/*<info serverAlias="SBSETTLE-bodb02,DBBAL-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROC dbo.SSB_Settlement_SiteDB_Replicated_UpdateData
	@ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
	, @QueueNo tinyint = null
as
/*  Created: Patrick@20210801
	Task: Pick conversation
	DB: SBSETTLE-bodb02, DBBAL-bodb02
	Revisions:  
		- 20221025@Patrick: Run parallels for sync logs [Redmine:#178694]
*/
begin
	set nocount on
	declare @__startTime datetime2, @__sessionId bigint, @__strTransInfo varbinary(max)
		, @__processingId bigint, @__delayTime varchar(50), @__siteDBGroupId smallint
		, @__settlementAction varchar(20), @__ticketType varchar(1)
		, @__errmsg varchar(1024) = '', @__messageTypeNew varchar(200), @__endtime datetime2

	select @__siteDBGroupId = substring(@MessageBody, 0, charindex('^', @MessageBody, 0))
	select @__sessionId = substring(@MessageBody, charindex('^', @MessageBody, 0) + 1, datalength(@MessageBody))

	while 1 = 1
	begin
		select @__strTransInfo = NULL, @__processingId = 0
			, @__messageTypeNew = null, @__startTime = sysdatetime()

		update top(1) s
		set StatusId = 1
			, @__strTransInfo = s.TransInfo
			, @__processingId = s.Id
			, @__settlementAction = s.SettlementAction
			, @__ticketType = s.TicketType
		from dbo.SiteDB_SettlementProcessing s with(readpast)
		where s.sessionId = @__sessionId
			and s.MessageType = @MessageType
			and s.siteDBGroupId = @__siteDBGroupId
			and s.StatusId = 0

		if @@rowcount = 0
		begin
			
			update top(1) s
			set StatusId = 1
				, @__strTransInfo = s.TransInfo
				, @__processingId = s.Id
				, @__settlementAction = s.SettlementAction
				, @__ticketType = s.TicketType
			from dbo.SiteDB_SettlementProcessing s with(readpast)
			where s.sessionId = @__sessionId
				and s.siteDBGroupId = @__siteDBGroupId
				and s.StatusId = 0
				and s.MessageType <> ''

			if @@rowcount = 0
			begin
				if exists (
					select top 1 1 
					from dbo.SiteDB_SettlementLock
					where SessionId = @__sessionId and SiteDBGroupId = @__siteDBGroupId
				)
				begin
					exec dbo.SSB_Send_Message @MessageContent = @MessageBody
						, @FunctionName = 'settlement'
						, @MessageType = @MessageType

					--wait for dbtrans send exec command via replication ==> default 100ms
					select @__delayTime = dbo.f_Settlement_GetDelayTime('Rep_Wait_Send_Exec')
					waitfor delay @__delayTime -- sitedb - waitfor sync logs / replication insert data
				end

				break
			end
		end

		set deadlock_priority high
		select @__errmsg = ''
		begin try
			exec dbo.Bet_ExecRep_NAP_Admin_01 
				@SiteDBGroupId					= @__siteDBGroupId
				, @SessionId					= @__sessionId
				, @TransInfoJson				= @__strTransInfo
				, @TableName					= 'bettrans'
				, @SettlementAction				= @__settlementAction
				, @TicketType					= @__ticketType
				, @SettlementProcessingId		= @__processingId	
				, @CalledByBrokerService 		= 1				

		end try
		begin catch
			set @__errmsg = error_message()
		end catch
		
		set deadlock_priority normal

		declare @__messageBodyTemp nvarchar(max), @__messageTypeTemp varchar(128)
		select	@__messageBodyTemp = 'exec dbo.Bet_ExecRep_NAP_Admin_01 '
									+ '@SiteDBGroupId=' + cast(@__siteDBGroupId as varchar(20))
									+ case when @__sessionId is not null then ',@SessionId=' + cast(@__sessionId as varchar(20)) else '' end
									+ ',@TableName=''bettrans'''
									+ case when @__settlementAction is not null then ',@SettlementAction=' + '''' + @__settlementAction + '''' else '' end
									+ case when @__ticketType is not null then ',@TicketType=' + '''' + @__ticketType + '''' else '' end
									+ case when @__processingId is not null then ',@SettlementProcessingId=' + cast(@__processingId as varchar(20)) else '' end
									+ '@CalledByBrokerService=1'
									+ case when @__strTransInfo is not null then ',@TransInfoJson=''' + convert(nvarchar(max), @__strTransInfo, 1) + '''' else '' end
				, @__messageTypeTemp = isnull(@__messageTypeNew, @MessageType)
				, @__endtime = sysdatetime()

		exec dbo.SSB_Settlement_WriteLogs @MessageId = @MessageId
			, @MessageType			= @__messageTypeTemp
			, @MessageBody			= @__messageBodyTemp
			, @StartTime			= @__startTime
			, @EndTime				= @__endtime
			, @SessionId			= @__sessionId
			, @ErrorMessage			= @__errmsg
			, @ConversationHandle	= @ConversationHandle
			, @QueueNo				= @QueueNo
			, @SiteDBGroupId		= @__siteDBGroupId

		--waitfor on each batch exec ==> default 001ms
		select @__delayTime = dbo.f_Settlement_GetDelayTime('SiteDB_Wait_Exec_Each_Batch')
		waitfor delay @__delayTime -- sitedb - delay between batches updated
	
	end

end
