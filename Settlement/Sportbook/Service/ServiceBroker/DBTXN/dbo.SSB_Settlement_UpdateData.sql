/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Settlement_UpdateData @ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
	, @QueueNo tinyint = null
as
/*  Created: Patrick@20210801
	Task: Update data @bettrans, @pending
	DB: DBTXN-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
*/
begin
	set nocount on
	
	declare @__startTime datetime2, @__sessionId bigint, @__strTransIds varchar(max)
		, @__processingId bigint, @__modds money, @__IsMarked bit, @__oddsType smallint, @__actionId int, @__matchid int, @__AffectedTicket int 
		, @__errmsg varchar(1024) = '', @__messageTypeNew varchar(200), @__endtime datetime2

	select	@__startTime = sysdatetime()	
			,@__matchid = PARSENAME(REPLACE(@MessageBody, '^', '.'), 2)
			,@__sessionId = PARSENAME(REPLACE(@MessageBody, '^', '.'), 1)

	while 1 = 1
	begin
		select @__strTransIds = '', @__processingId = 0, @__oddsType = 0, @__startTime = sysdatetime()
			, @__IsMarked = 0, @__modds = 0, @__actionId = 0, @__messageTypeNew = null

		update top(1) s
		set StatusId = 1
			, @__strTransIds = s.TransIds
			, @__modds = s.modds
			, @__IsMarked = s.IsMarked
			, @__oddsType = s.OddsType
			, @__actionId = s.ActionId
			, @__processingId = s.Id
		from dbo.SettlementProcessing s with(readpast)
		where s.sessionId = @__sessionId
			and s.MessageType = @MessageType
			and s.StatusId = 0

		if @@rowcount = 0
		begin
			
			update top(1) s
			set StatusId = 1
				, @__strTransIds = s.TransIds
				, @__modds = s.modds
				, @__IsMarked = s.IsMarked
				, @__oddsType = s.OddsType
				, @__actionId = s.ActionId
				, @__processingId = s.Id
				, @__messageTypeNew = s.MessageType
			from dbo.SettlementProcessing s with(readpast)
			where s.sessionId = @__sessionId
				and s.StatusId = 0
				and s.MessageType <> ''

			if @@rowcount = 0
				break

		end
		
		set deadlock_priority high
		select @__errmsg = ''
		begin try
			exec dbo.NAP_Admin_Calculate_Main @matchid = @__matchid
				, @IsSettingByProfile		= 1
				, @strTransIds				= @__strTransIds
				, @mode						= 'profile-major'
				, @SettlementProcessingId	= @__processingId
				, @modds					= @__modds
				, @IsMarked					= @__IsMarked
				, @OddsType					= @__oddsType
				, @ActionId					= @__actionId
				, @SessionId				= @__sessionId
				, @AffectedTicket			= @__AffectedTicket OUTPUT
				, @ErrMessage				= @__errmsg OUTPUT
		end try
		begin catch
			set @__errmsg = error_message()
		end catch

		set deadlock_priority normal

		declare @__messageBodyTemp nvarchar(max), @__messageTypeTemp varchar(128), @__delayTime varchar(50)
		select @__messageBodyTemp = 'exec dbo.NAP_Admin_Calculate_Main @matchid = ' + cast(@__matchid as varchar(20))
				+ ',@IsSettingByProfile=1,@mode=''profile-major'''
				+ case when @__strTransIds is not null then ',@strTransIds=''' + @__strTransIds + '''' else '' end
				+ case when @__processingId is not null then ',@SettlementProcessingId=' + cast(@__processingId as varchar(20)) else '' end
				+ case when @__modds is not null then ',@modds=' + cast(@__modds as varchar(20)) else '' end
				+ case when @__IsMarked is not null then ',@IsMarked=' + cast(@__IsMarked as varchar(20)) else '' end
				+ case when @__oddsType is not null then ',@OddsType=' + cast(@__oddsType as varchar(20)) else '' end
				+ case when @__actionId is not null then ',@ActionId=' + cast(@__actionId as varchar(20)) else '' end
				+ case when @__sessionId is not null then ',@SessionId=' + cast(@__sessionId as varchar(30)) else '' end
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
			, @AffectedTicket		= @__AffectedTicket
			, @TableType			= 1
			, @EventTable			= 1

		--waitfor on each batch exec ==> default 001ms
		select @__delayTime = dbo.f_Settlement_GetDelayTime('Wait_Exec_Each_Batch')
		waitfor delay @__delayTime -- delay between batches updated
		
	end	
end

go