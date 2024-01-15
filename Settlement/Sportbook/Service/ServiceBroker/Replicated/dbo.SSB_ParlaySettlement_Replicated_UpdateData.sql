/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_ParlaySettlement_Replicated_UpdateData @ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
	, @QueueNo tinyint = null
as
/*  Created: Kathy@20240122
	Task: support multiple threads to settle parlay [Redmine:#199518]
	DB: DBTXN-bodb02
	Revisions:  
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		
*/
begin
	set nocount on

	declare @__startTime datetime2, @__endtime datetime2
		, @__sessionId bigint, @__strSubTransIds varchar(max), @__strMainTransIds varchar(max), @__strRefno_MainTransIds varchar(max)
		, @__parlayprocessingId bigint, @__MatchId int, @__EventDate smalldatetime, @__strSetting varchar(max), @__IsReSettledTickets bit, @__Action varchar(20), @__ActionId INT, @__AffectedTicket int
		, @__errmsg varchar(1024) = '', @__messageTypeNew varchar(200)

		, @__messageBodyTemp nvarchar(max), @__messageTypeTemp varchar(128), @__delayTime varchar(50)

	select @__startTime = sysdatetime(), @__sessionId = @MessageBody

	while 1 = 1
	begin
		select @__parlayprocessingId = 0 , @__MatchId = 0
			, @__strSubTransIds = '', @__strMainTransIds = '', @__strRefno_MainTransIds = ''
			, @__EventDate = NULL, @__Action = '', @__ActionId = NULL, @__strSetting = NULL, @__IsReSettledTickets = 0, @__AffectedTicket = 0
			, @__startTime = sysdatetime(), @__messageTypeNew = null

		update top(1) p
			set StatusId = 1
				, @__parlayprocessingId = p.Id
				, @__MatchId = p.MatchId
				, @__strSubTransIds = p.subTransIds
				, @__strMainTransIds = p.MainTransIds
				, @__strRefno_MainTransIds = p.RefnoMainTransIds
				, @__EventDate = p.EventDate
				, @__Action = p.Action
				, @__ActionId = p.ActionId
				, @__strSetting = p.strSetting
				, @__IsReSettledTickets = p.IsReSettledTickets
		from	dbo.ParlaySettlementProcessing p with(readpast)
		where	p.sessionId = @__sessionId
				and p.MessageType = @MessageType
				and p.StatusId = 0

		if @@rowcount = 0
		begin			
			update top(1) p
				set StatusId = 1
					, @__parlayprocessingId = p.Id
					, @__MatchId = p.MatchId
					, @__strSubTransIds = p.subTransIds
					, @__strMainTransIds = p.MainTransIds
					, @__strRefno_MainTransIds = p.RefnoMainTransIds
					, @__EventDate = p.EventDate
					, @__Action = p.Action
					, @__ActionId = p.ActionId
					, @__strSetting = p.strSetting
					, @__IsReSettledTickets = p.IsReSettledTickets
			from	dbo.ParlaySettlementProcessing p with(readpast)
			where	p.sessionId = @__sessionId
					and p.StatusId = 0
					and p.MessageType <> ''

			if @@rowcount = 0
				break
		end

		select @__errmsg = ''

		-- update bettransm
		set deadlock_priority high
		begin try
			EXEC dbo.NAP_Admin_Parlay_Calculate_3 @matchid = @__MatchId
				, @matchdate = @__EventDate
				, @action = @__Action
				, @strTransIds = @__strSubTransIds
				, @ServerName = @@servername
				, @AffectedTicket = @__AffectedTicket OUTPUT
		end try
		begin catch
			update p
				set StatusId = 3 -- failed
			from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
			where	p.Id = @__parlayprocessingId
			
			set @__errmsg = error_message()
		end catch
		set deadlock_priority normal

		select	@__messageBodyTemp = 'exec dbo.NAP_Admin_Parlay_Calculate_3 @matchid = ' + cast(@__MatchId as varchar(20))
					+ CASE WHEN @__EventDate IS NOT NULL THEN  ',@matchdate= ''' + cast(@__EventDate as varchar(20)) + '''' ELSE '' END
					+ CASE WHEN @__Action IS NOT NULL THEN  ',@Action= ''' + @__Action + '''' ELSE '' END
					+ CASE WHEN @__strSubTransIds IS NOT NULL THEN  ',@strTransIds= ''' + @__strSubTransIds + '''' ELSE '' END
					+ ',@ServerName= ''' + @@ServerName + ''''
					
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
			, @AffectedTicket		= @__AffectedTicket
			, @MatchId 				= @__matchid
			, @TableType 			= 2 -- bettransm
			, @EventTable 			= 1 -- match

		-- generate/update data on table betparlaydetail/betparlayresult
		if @__errmsg = ''
		begin
			update	p
				set StatusId = 10
			from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
			where	p.Id = @__parlayprocessingId

			set @__startTime = sysdatetime()
			set @__AffectedTicket = 0
			
			set deadlock_priority high
			begin try	
				 EXEC dbo.NAP_Admin_Calculate_MP_PreCal_29 @matchid = @__MatchId
					, @matchdate = @__EventDate
					, @strXML = @__strMainTransIds
					, @IsReSettledTickets = @__IsReSettledTickets
					, @strSetting = @__strSetting
					, @ServerName = @@servername
					, @AffectedTicket = @__AffectedTicket OUTPUT
			end try
			begin catch
				update p
					set StatusId = 13 -- failed
				from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
				where	p.Id = @__parlayprocessingId
			
				set @__errmsg = error_message()
			end catch
			set deadlock_priority normal

			select	@__messageBodyTemp = 'exec dbo.NAP_Admin_Calculate_MP_PreCal_29 @matchid = ' + cast(@__MatchId as varchar(20))
					+ CASE WHEN @__EventDate IS NOT NULL THEN ',@matchdate= ''' + cast(@__EventDate as varchar(20)) + '''' ELSE '' END
					+ CASE WHEN @__strMainTransIds IS NOT NULL THEN ',@strXML= ''' + @__strMainTransIds + '''' ELSE '' END
					+ ',@IsReSettledTickets= ' + cast(@__IsReSettledTickets as varchar(1))
					+ CASE WHEN @__strSetting IS NOT NULL THEN ',@strSetting= ''' + @__strSetting + '''' ELSE '' END
					+ ',@ServerName= ''' + @@ServerName + ''''
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
				, @AffectedTicket		= @__AffectedTicket
				, @MatchId 				= @__matchid
				, @TableType 			= 3 -- betparlaydetail/betparlayresult
				, @EventTable 			= 1 -- match

			-- update bettrans
			if @__errmsg = ''
			begin
				update p
					set StatusId = 20 -- completed generate/update betparlaydetail/betparlayresult
				from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
				where	p.Id = @__parlayprocessingId

				set @__startTime = sysdatetime()
				set @__AffectedTicket = 0
				
				set deadlock_priority high
				begin try
					exec dbo.NAP_Admin_Calculate_MP_29
						@matchdate = @__EventDate
						,@strXML = @__strRefno_MainTransIds
						,@MatchId = @__MatchId		
						,@ServerName = @@servername		
						,@AffectedTicket = @__AffectedTicket OUTPUT
				end try
				begin catch
					update p
						set StatusId = 23 -- failed
					from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
					where	p.Id = @__parlayprocessingId
			
					set @__errmsg = error_message()
				end catch
				set deadlock_priority normal

				select	@__messageBodyTemp = 'exec dbo.NAP_Admin_Calculate_MP_29 @matchid = ' + cast(@__MatchId as varchar(20))
							+ CASE WHEN @__EventDate IS NOT NULL THEN ',@matchdate= ''' + cast(@__EventDate as varchar(20)) + '''' ELSE '' END
							+ CASE WHEN @__strRefno_MainTransIds IS NOT NULL THEN ',@strXML= ''' + @__strRefno_MainTransIds + '''' ELSE '' END	
							+ ',@ServerName= ''' + @@ServerName + ''''						
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
					, @AffectedTicket		= @__AffectedTicket
					, @MatchId 				= @__matchid
					, @TableType 			= 1 -- bettrans
					, @EventTable 			= 1 -- match

				if @__errmsg = ''
				begin
					delete
					from	dbo.ParlaySettlementProcessing with(rowlock, updlock)
					where	Id = @__parlayprocessingId
				end
			end
		end

		--waitfor on each batch exec ==> default 001ms
		select @__delayTime = dbo.f_Settlement_GetDelayTime('Wait_Exec_Each_Batch')
		waitfor delay @__delayTime -- parlay settlement (sitedbgroupid = 0): delay between batches updated
		
	end	

	-- put command into ssb if currently there is no data to process
	begin
		if exists (
			select top 1 1 
			from dbo.ParlaySettlementLock
			where SessionId = @__sessionId
		)
		begin
			exec dbo.SSB_Send_Message @MessageContent = @__sessionId
				, @FunctionName = 'parlaysettlement'
				, @MessageType = @MessageType

			--wait for dbtrans send exec command via replication ==> default 100ms
			select @__delayTime = dbo.f_Settlement_GetDelayTime('Rep_Wait_Send_Exec')
			waitfor delay @__delayTime -- parlay settlement (sitedbgroupid = 0): waitfor dbtrans send exec command via replication
		end
	end
end

go