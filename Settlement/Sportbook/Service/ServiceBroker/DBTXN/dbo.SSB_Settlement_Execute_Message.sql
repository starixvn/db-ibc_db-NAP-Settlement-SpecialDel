/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Settlement_Execute_Message @ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
	, @QueueNo tinyint = null
as
/*  Created: Patrick@20210801
	Task: Execute message
	DB: DBTXN-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin
	set nocount on
	declare @__startTime datetime2, @__endtime datetime2, @__errmsg varchar(1024)
			,@__matchid int
			,@__action varchar(20)
			,@__mincustid int
			,@__maxcustid int
			,@__isresettledtickets bit
			,@__queueno smallint
			,@__sessionid bigint
			,@__actionid int
			,@__settlementprocessingid bigint
			,@__errcode int
			,@__paramxml xml
			,@__Log varchar(max)

	select @__startTime = sysdatetime()
			,@__paramxml = cast(@MessageBody as xml)

	select	@__matchid = T.C.value('@MatchId', 'int') 
			,@__action = T.C.value('@Action','varchar(20)')
			,@__mincustid = T.C.value('@MinCustId','int')
			,@__maxcustid = T.C.value('@MaxCustId','int')
			,@__isresettledtickets = T.C.value('@IsReSettledTickets','bit')
			,@__queueno = T.C.value('@QueueNo','smallint')
			,@__sessionid = T.C.value('@SessionId','bigint') 
			,@__actionid = T.C.value('@ActionID','int')
			,@__settlementprocessingid = T.C.value('@SettlementProcessingId','bigint')
	from	@__paramxml.nodes('/root/r') AS T(C)	

	set deadlock_priority high
	begin try
		EXEC dbo.NAP_Admin_Settlement_Queue @matchid = @__matchid
			,@action  = @__action
			,@MinCustId = @__MinCustId
			,@MaxCusId = @__MaxCustId
			,@IsReSettledTickets = @__IsReSettledTickets
			,@QueueNo  = @__queueno
			,@SessionId  = @__SessionId
			,@ActionId  = @__ActionID
			,@SettlementProcessingId  = @__SettlementProcessingId
			,@ErrCode = @__errcode output
			,@ErrMsg = @__errmsg output
	end try
	begin catch
		set @__errmsg = error_message()
	end catch

	set deadlock_priority normal

	select @__endtime = sysdatetime()

	set @__Log = 'EXEC dbo.NAP_Admin_Settlement_Queue @matchid = ' + cast(@__matchid as varchar(20)) 
			+ ',@action  = ''' + @__action + ''''
			+ ',@MinCustId = ' + cast(@__MinCustId as varchar(20))
			+ ',@MaxCusId = ' + cast(@__MaxCustId as varchar(20))
			+ ',@IsReSettledTickets = ' + cast(@__IsReSettledTickets as varchar)
			+ ',@QueueNo  = ' + cast(@__queueno as varchar(20))
			+ ',@SessionId  =' + cast(@__SessionId as varchar(30))
			+ ',@ActionId  =' + cast(@__ActionID as varchar(20))
			+ ',@SettlementProcessingId  =' + cast(@__SettlementProcessingId as varchar(30))

	exec dbo.SSB_Settlement_WriteLogs @MessageId = @MessageId
		, @MessageType = @MessageType
		, @MessageBody = @__Log
		, @StartTime = @__startTime
		, @EndTime = @__endtime
		, @ErrorMessage = @__errmsg
		, @ConversationHandle = @ConversationHandle
		, @QueueNo = @QueueNo
		, @SessionId = @__sessionid
end
go