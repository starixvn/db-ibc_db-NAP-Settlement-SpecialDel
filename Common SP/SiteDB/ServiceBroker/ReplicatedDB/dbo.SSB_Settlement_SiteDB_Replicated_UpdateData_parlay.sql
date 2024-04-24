USE [bodb02]
GO
/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC dbo.SSB_Settlement_SiteDB_Replicated_UpdateData_parlay
	@ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
	, @QueueNo tinyint = null
as
/*  Created: Kathy@20240215
	Task: Process parlay message
	
	Revisions:  
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
*/
begin
	set nocount on
	declare @__startTime datetime2, @__sessionId bigint, @__strTransInfo varbinary(max)
		, @__parlayprocessingId bigint, @__sitedb_parlayprocessingId bigint
		, @__delayTime varchar(50), @__siteDBGroupId smallint, @__tablename varchar(128), @__matchid int, @__previousStatusId tinyint, @__AffectedTicket int, @__tabletype tinyint
		, @__settlementAction varchar(20), @__ticketType varchar(1), @__errorCode INT
		, @__errmsg varchar(1024) = '', @__messageTypeNew varchar(200), @__endtime datetime2
		, @__messageBodyTemp nvarchar(max), @__messageTypeTemp varchar(128)
	select @__siteDBGroupId = substring(@MessageBody, 0, charindex('^', @MessageBody, 0))
	select @__sessionId = substring(@MessageBody, charindex('^', @MessageBody, 0) + 1, datalength(@MessageBody))

	while 1 = 1
	begin
		select @__strTransInfo = NULL, @__parlayprocessingId = 0, @__tablename = '', @__settlementAction = '', @__ticketType = '', @__previousStatusId = 0, @__AffectedTicket = 0
			, @__messageTypeNew = null, @__startTime = sysdatetime()

		-- update bettransm/BetParlayDetail
		update top(1) s
			set StatusId = 1
				, @__previousStatusId = s.StatusId
				, @__strTransInfo = case 
										when s.StatusId = 0 then s.TransInfoBettransM
										when s.StatusId = 10 then s.TransInfoBetParlayResult
										when s.StatusId = 20 then s.TransInfoBettrans
										else NULL end
				, @__parlayprocessingId = s.Id
				, @__tablename = case 
										when s.StatusId = 10 then 'BetParlayResult'
										when s.StatusId = 20 then 'bettrans'
										else s.TableName
									end
				, @__settlementAction = s.SettlementAction
				, @__ticketType = s.TicketType
				, @__matchid = s.MatchId
		from dbo.SiteDB_ParlaySettlementProcessing s with(readpast)
		where s.sessionId = @__sessionId
			and s.MessageType = @MessageType
			and s.siteDBGroupId = @__siteDBGroupId
			and s.StatusId IN (0, 10, 20)
			and 1 = case 
						when s.StatusId = 0 and s.TransInfoBettransM is not null then 1
						when s.StatusId = 10 and s.TransInfoBetParlayResult is not null then 1
						when s.StatusId = 20 and s.TransInfoBettrans is not null then 1
						else 0
					end

		if @@rowcount = 0
		begin	
			-- update with another messagetype
			update top(1) s
				set StatusId = 1
					, @__previousStatusId = s.StatusId
					, @__strTransInfo = case 
											when s.StatusId = 0 then s.TransInfoBettransM
											when s.StatusId = 10 then s.TransInfoBetParlayResult
											when s.StatusId = 20 then s.TransInfoBettrans
											else NULL end
					, @__parlayprocessingId = s.Id
					, @__tablename = case 
										when s.StatusId = 10 then 'BetParlayResult'
										when s.StatusId = 20 then 'bettrans'
										else s.TableName
									end
					, @__settlementAction = s.SettlementAction
					, @__ticketType = s.TicketType
					, @__matchid = s.MatchId
			from dbo.SiteDB_ParlaySettlementProcessing s with(readpast)
			where s.sessionId = @__sessionId
				and s.siteDBGroupId = @__siteDBGroupId
				and s.StatusId IN (0, 10, 20)
				and s.MessageType <> ''
				and 1 = case 
						when s.StatusId = 0 and s.TransInfoBettransM is not null then 1
						when s.StatusId = 10 and s.TransInfoBetParlayResult is not null then 1
						when s.StatusId = 20 and s.TransInfoBettrans is not null then 1
						else 0
					end

			if @@rowcount = 0
			begin
				break
			end
		end

		if @__strTransInfo IS NULL
		begin
			break
		end

		set deadlock_priority high
		select @__errmsg = ''
		begin try
			exec dbo.Bet_ExecRep_NAP_Admin_01 
				@SiteDBGroupId					= @__siteDBGroupId
				, @SessionId					= @__sessionId
				, @MessageType					= ''
				, @TableName					= @__tablename
				, @MatchId						= @__matchid
				, @SettlementAction				= @__settlementAction
				, @TicketType					= @__ticketType
				, @ParlaySettlementProcessingId	= @__parlayprocessingId	
				, @CalledByBrokerService 		= 1			
				, @TransInfoJson				= @__strTransInfo				
				, @AffectedTicket 				= @__AffectedTicket OUTPUT
				, @ErrMsg						= @__errmsg OUTPUT
		end try
		begin catch
			set @__errmsg = error_message()
		end catch		
		set deadlock_priority normal
		
		if isnull(@__errmsg,'') <> ''
		begin 
			update p
				set StatusId = @__previousStatusId + 3 -- failed
					,TableName = @__tablename
			from	dbo.SiteDB_ParlaySettlementProcessing p with(rowlock, updlock)
			where	p.Id = @__parlayprocessingId
		end

		select	@__messageBodyTemp = 'exec dbo.Bet_ExecRep_NAP_Admin_01 '
									+ '@SiteDBGroupId=' + cast(@__siteDBGroupId as varchar(20))
									+ case when @__sessionId is not null then ',@SessionId=' + cast(@__sessionId as varchar(20)) else '' end
									+ ',@MessageType='''''
									+ ',@TableName=''' + @__tablename + ''''									
									+ case when @__matchid is not null then ',@MatchId=' + cast(@__matchid as varchar(20)) else '' end
									+ case when @__settlementAction is not null then ',@SettlementAction=' + '''' + @__settlementAction + '''' else '' end
									+ case when @__ticketType is not null then ',@TicketType=' + '''' + @__ticketType + '''' else '' end
									+ case when @__parlayprocessingId is not null then ',@ParlaySettlementProcessingId=' + cast(@__parlayprocessingId as varchar(20)) else '' end
									+ case when @__strTransInfo is not null then ',@TransInfoJson=''' + convert(nvarchar(max), @__strTransInfo, 1) + '''' else '' end
				, @__messageTypeTemp = isnull(@__messageTypeNew, @MessageType)
				, @__endtime = sysdatetime()
				, @__tabletype = case 
										when @__tablename = 'bettrans' then 1										
										when @__tablename in ('bettransm', 'bettransm/BetParlayDetail') then 2
										when @__tablename = 'BetParlayResult' then 3
										else 0 
									end

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
			, @AffectedTicket		= @__AffectedTicket
			, @MatchId 				= @__matchid
			, @TableType 			= @__tabletype
			, @EventTable 			= 1 -- match
		
		if isnull(@__errmsg,'') = ''
		begin
			if @__previousStatusId = 20
			begin
				delete
				from	dbo.SiteDB_ParlaySettlementProcessing with(rowlock, updlock)
				where	Id = @__parlayprocessingId
			end
			else
			begin
				update p
				set StatusId = @__previousStatusId + 10
				from	dbo.SiteDB_ParlaySettlementProcessing p with(rowlock, updlock)
				where	p.Id = @__parlayprocessingId
			end
		end
	end

	if exists (
				select top 1 1 
				from dbo.SiteDB_ParlaySettlementLock
				where SessionId = @__sessionId and SiteDBGroupId = @__siteDBGroupId
			)
	begin
		exec dbo.SSB_Send_Message @MessageContent = @MessageBody
			, @FunctionName = 'parlaysettlement'
			, @MessageType = @MessageType

		--wait for dbtrans send exec command via replication ==> default 100ms
		select @__delayTime = dbo.f_Settlement_GetDelayTime('Rep_Wait_Send_Exec')
		waitfor delay @__delayTime -- parlay settlement (sitedb) - waitfor sync logs / replication insert data
	end

end
