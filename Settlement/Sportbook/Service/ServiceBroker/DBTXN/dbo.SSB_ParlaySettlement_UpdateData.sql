/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_ParlaySettlement_UpdateData @ConversationHandle uniqueidentifier
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
		- 20240425@Kathy: enhance MaxPayout [Redmine:#199518]
		
*/
begin
	set nocount on

	declare @__startTime datetime2, @__endtime datetime2
		, @__sessionId bigint, @__strSubTransIds varchar(max), @__strMainTransIds varchar(max), @__strRefno_MainTransIds varchar(max), @__MainParlayMaxPO varchar(max), @__BroadcastSessionId varchar(50)
		, @__parlayprocessingId bigint, @__MatchId int, @__EventDate smalldatetime, @__strSetting varchar(max), @__IsReSettledTickets bit, @__Action varchar(20), @__ActionId int, @__AffectedTicket int
		, @__errmsg varchar(1024) = '', @__messageTypeNew varchar(200)

		, @__messageBodyTemp nvarchar(max), @__messageTypeTemp varchar(128), @__delayTime varchar(50)

	select @__startTime = sysdatetime(), @__sessionId = @MessageBody

	-- update bettransm
	while 1 = 1
	begin
		select @__parlayprocessingId = 0 , @__MatchId = 0
			, @__strSubTransIds = '', @__strMainTransIds = '', @__strRefno_MainTransIds = '', @__BroadcastSessionId = ''
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
				, @__BroadcastSessionId = p.BroadcastSessionId
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
					, @__BroadcastSessionId = p.BroadcastSessionId
			from	dbo.ParlaySettlementProcessing p with(readpast)
			where	p.sessionId = @__sessionId
					and p.StatusId = 0
					and p.MessageType <> ''

			if @@rowcount = 0
				break

		end

		select @__errmsg = ''

		set deadlock_priority high
		begin try			
			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchid	  		 = @__MatchId
				,@SessionId			 = @__sessionId
				,@ParlaySettlementProcessingId = @__parlayprocessingId
				,@mode				 = 'profile'
				,@Action			 = @__Action
				,@ActionId 			 = @__ActionId
				,@strTransIds		 = @__strSubTransIds
				,@strMainTransIds	 = @__strMainTransIds				
				,@strRefnoMainTransIds = @__strRefno_MainTransIds
				,@matchdate			 = @__EventDate
				,@IsReSettledTickets = @__IsReSettledTickets
				,@strSetting = @__strSetting
				,@BroadcastSessionId = @__BroadcastSessionId
				,@IsParallel = 1
				,@AffectedTicket = @__AffectedTicket OUTPUT
			
		end try
		begin catch
			update p
				set StatusId = 3 -- failed
			from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
			where	p.Id = @__parlayprocessingId
			
			set @__errmsg = error_message()
		end catch
		set deadlock_priority normal

		select	@__messageBodyTemp = 'exec dbo.NAP_Admin_Calculate_MP_broker @matchid = ' + cast(@__MatchId as varchar(20))
					+ ',@SessionId= ' + cast(@__sessionId as varchar(20)) 
					+ ',@ParlaySettlementProcessingId= ' + cast(@__parlayprocessingId as varchar(20)) 					
					+ ',@mode=''profile'''					
					+ ',@Action= ''' + @__Action + ''''
					+ ',@ActionId= ' + cast(@__ActionId as varchar(20)) 
					+ CASE WHEN @__strSubTransIds IS NOT NULL THEN ',@strTransIds= ''' + @__strSubTransIds + '''' ELSE '' END
					+ CASE WHEN @__strMainTransIds IS NOT NULL THEN ',@strMainTransIds= ''' + @__strMainTransIds + '''' ELSE '' END
					+ CASE WHEN @__strRefno_MainTransIds IS NOT NULL THEN ',@strRefnoMainTransIds= ''' + @__strRefno_MainTransIds + '''' ELSE '' END
					+ ',@matchdate= ''' + cast(@__EventDate as varchar(20)) + ''''
					+ ',@IsReSettledTickets= ' + cast(@__IsReSettledTickets as varchar(20)) 
					+ CASE WHEN @__strSetting IS NOT NULL THEN ',@strSetting= ''' + @__strSetting + '''' ELSE '' END
					+ CASE WHEN @__BroadcastSessionId IS NOT NULL THEN ',@BroadcastSessionId= ''' + @__BroadcastSessionId + '''' ELSE '' END
					+ ',@IsParallel= 1'
					
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
				EXEC dbo.NAP_Admin_Calculate_MP_broker 
					@matchid = @__MatchId
					,@SessionId			 = @__sessionId
					,@ParlaySettlementProcessingId = @__parlayprocessingId	
					,@mode = 'PRECAL-29'								
					,@strXML = @__strMainTransIds
					,@matchdate = @__EventDate
					,@IsReSettledTickets = @__IsReSettledTickets
					,@strSetting = @__strSetting
					,@IsParallel = 1
					,@AffectedTicket = @__AffectedTicket OUTPUT
			end try
			begin catch
				update p
					set StatusId = 13 -- failed
				from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
				where	p.Id = @__parlayprocessingId
			
				set @__errmsg = error_message()
			end catch
			set deadlock_priority normal

			select	@__messageBodyTemp = 'exec dbo.NAP_Admin_Calculate_MP_broker @matchid = ' + cast(@__MatchId as varchar(20))
					+ ',@SessionId= ' + cast(@__sessionId as varchar(20)) 
					+ ',@ParlaySettlementProcessingId= ' + cast(@__parlayprocessingId as varchar(20)) 		
					+ ',@mode=''PRECAL-29'''			
					+ CASE WHEN @__strMainTransIds IS NOT NULL THEN ',@strXML= ''' + @__strMainTransIds + '''' ELSE '' END
					+ CASE WHEN @__EventDate IS NOT NULL THEN ',@matchdate= ''' + cast(@__EventDate as varchar(20)) + '''' ELSE '' END
					+ ',@IsReSettledTickets= ' + cast(@__IsReSettledTickets as varchar(1))					
					+ CASE WHEN @__strSetting IS NOT NULL THEN ',@strSetting= ''' + @__strSetting + '''' ELSE '' END
					+ ',@IsParallel= 1'
					
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
					exec dbo.NAP_Admin_Calculate_MP_broker
						@MatchId = @__MatchId
						,@SessionId	= @__sessionId
						,@ParlaySettlementProcessingId = @__parlayprocessingId
						,@mode = '29'						
						,@matchdate = @__EventDate
						,@strXML = @__strRefno_MainTransIds
						,@ActionId = @__ActionId
						,@BroadcastSessionId = @__BroadcastSessionId
						,@IsCalculateBalance = 1
						,@IsParallel = 1
						,@AffectedTicket = @__AffectedTicket OUTPUT	
						,@AffectedTransIds = @__MainParlayMaxPO OUTPUT
						
				end try
				begin catch
					update p
						set StatusId = 23 -- failed
					from	dbo.ParlaySettlementProcessing p with(rowlock, updlock)
					where	p.Id = @__parlayprocessingId
			
					set @__errmsg = error_message()
				end catch
				set deadlock_priority normal

				select	@__messageBodyTemp = 'exec dbo.NAP_Admin_Calculate_MP_broker @matchid = ' + cast(@__MatchId as varchar(20))
						+ ',@SessionId= ' + cast(@__sessionId as varchar(20)) 
						+ ',@ParlaySettlementProcessingId= ' + cast(@__parlayprocessingId as varchar(20)) 
						+ ',@mode=''29'''
						+ CASE WHEN @__EventDate IS NOT NULL THEN ',@matchdate= ''' + cast(@__EventDate as varchar(20)) + '''' ELSE '' END
						+ CASE WHEN @__strRefno_MainTransIds IS NOT NULL THEN ',@strXML= ''' + @__strRefno_MainTransIds + '''' ELSE '' END
						+ CASE WHEN @__ActionId IS NOT NULL THEN ',@ActionId= ' + cast(@__ActionId as varchar(20)) ELSE '' END
						+ CASE WHEN @__BroadcastSessionId IS NOT NULL THEN ',@BroadcastSessionId= ''' + @__BroadcastSessionId + '''' ELSE '' END
						+ ',@IsCalculateBalance= 1' 
						+ ',@IsParallel= 1'
						
					
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
				
				--Insert Max Payout Queue
				if ISNULL(@__MainParlayMaxPO,'') <> ''
				begin
					set @__errmsg = ''
					set @__startTime = sysdatetime()
					
					begin try
						EXEC dbo.NAP_Set_CustLimitBetQueue_Insert_Parlay
							@TransIds = @__MainParlayMaxPO
					end try
					begin catch
						set @__errmsg = error_message()
					end catch

					select	@__messageBodyTemp = 'exec dbo.NAP_Set_CustLimitBetQueue_Insert_Parlay @TransIds= ' + '''' + @__MainParlayMaxPO + ''''
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
						, @MatchId 				= @__matchid
				end
			end
		end

		--waitfor on each batch exec ==> default 001ms
		select @__delayTime = dbo.f_Settlement_GetDelayTime('Wait_Exec_Each_Batch')
		waitfor delay @__delayTime -- parlay settlement: delay between batches updated
		
	end	

end

go