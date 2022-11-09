/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[SSB_Settlement_SiteDB_Execute_Message]
	@ConversationHandle uniqueidentifier
	, @MessageBody nvarchar(max)
	, @MessageType varchar(200)
	, @MessageId varchar(128)
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
	declare @__errmsg varchar(1024), @__errCode int, @__transInfo nvarchar(max)
		, @__params xml, @__tableName varchar(200), @__matchId int
		, @__action varchar(1), @__settlementAction varchar(20), @__ticketType varchar(1)
		, @__startTime datetime2, @__endtime datetime2
		, @__sessionId bigint, @__siteDBGroupId smallint, @__totalQueue int

	select @__startTime = sysdatetime(), @__params = cast(@MessageBody as xml)

	--set deadlock_priority high
	begin try
			
		select @__tableName = T.C.value('@TableName', 'varchar(128)') 
			,@__matchId = T.C.value('@MatchId','int')
			,@__action = T.C.value('@Action','varchar(1)')
			,@__settlementAction = T.C.value('@SettlementAction','varchar(20)')
			,@__ticketType = T.C.value('@TicketType','varchar(1)')
			,@__transInfo = T.C.value('@TransInfo','varchar(max)')
			,@__siteDBGroupId = T.C.value('@SiteDBGroupId','smallint')
			,@__sessionId = T.C.value('@SessionId','bigint')
			,@__totalQueue = T.C.value('@TotalQueue','int')
		from @__params.nodes('/root/r') as T(C)

		exec dbo.NAP_SettlementService_Calculation 
			@SiteDBGroupId					= @__siteDBGroupId
			,@SessionId						= @__sessionId
			,@MessageType					= @MessageType
			,@TransInfo						= @__transInfo
			,@TableName						= @__tableName
			,@MatchId						= @__matchId
			,@Action						= @__action
			,@SettlementAction				= @__settlementAction
			,@TicketType					= @__ticketType
			
			,@TotalQueue					= @__totalQueue	
			,@ErrCode						= @__errCode output
			,@ErrMsg						= @__errmsg output

	end try
	begin catch
		select @__errmsg = error_message()
	end catch

	--if got error then disable Queue as well
	if isnull(@__errmsg, '') <> ''
	begin
		if @MessageType = 'sitedb1_bet_settle_msg_type'
		begin
			alter queue sitedb1_bet_settle_queue with status = off
		end
		else if @MessageType = 'sitedb2_bet_settle_msg_type'
		begin
			alter queue sitedb2_bet_settle_queue with status = off
		end
	end
		
	--set deadlock_priority normal

	declare @__messageBodyTemp nvarchar(max)
	select @__messageBodyTemp = 'exec dbo.NAP_SettlementService_Calculation '
			+ '@SiteDBGroupId=' + cast(@__siteDBGroupId as varchar(50))
			+ case when @__sessionId is not null then ',@SessionId=' + cast(@__sessionId as varchar(50)) + '' else '' end
			+ case when @__tableName is not null then ',@TableName=''' + @__tableName + '''' else '' end
			+ case when @__matchId is not null then ',@MatchId=' + cast(@__matchId as varchar(20)) else '' end
			+ case when @__action is not null then ',@Action=''' + @__action + '''' else '' end
			+ case when @__settlementAction is not null then ',@SettlementAction=''' + @__settlementAction + '''' else '' end
			+ case when @__ticketType is not null then ',@TicketType=''' + @__ticketType + '''' else '' end
			+ case when @__totalQueue is not null then ',@TotalQueue=' + cast(@__totalQueue as varchar(50)) + '' else '' end
			+ case when @__transInfo is not null then ',@TransInfo=''' + @__transInfo + '''' else '' end
			
		, @__endtime = sysdatetime()

	exec dbo.SSB_Settlement_WriteLogs @MessageId = @MessageId
		, @MessageType			= @MessageType
		, @MessageBody			= @__messageBodyTemp
		, @StartTime			= @__startTime
		, @EndTime				= @__endtime
		, @SessionId			= @__sessionId
		, @ErrorMessage			= @__errmsg
		, @ConversationHandle	= @ConversationHandle
		, @QueueNo				= 0
		, @SiteDBGroupId		= @__siteDBGroupId
end