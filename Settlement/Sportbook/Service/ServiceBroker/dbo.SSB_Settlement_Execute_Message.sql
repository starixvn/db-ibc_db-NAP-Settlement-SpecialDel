/*<info serverAlias="DBTXN-bodb02, SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Settlement_Execute_Message @ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
	, @QueueNo tinyint = null
as
/*  Created: Patrick@20210801
	Task: Execute message
	DB: DBTXN-bodb02, SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
*/
begin
	set nocount on
	declare @__startTime datetime2, @__endtime datetime2, @__errmsg varchar(1024)
	select @__startTime = sysdatetime()
	
	set deadlock_priority high
	begin try
		exec sp_executesql @MessageBoby
	end try
	begin catch
		set @__errmsg = error_message()
	end catch

	set deadlock_priority normal

	select @__endtime = sysdatetime()
	exec dbo.SSB_Settlement_WriteLogs @MessageId = @MessageId
		, @MessageType = @MessageType
		, @MessageBody = @MessageBody
		, @StartTime = @__startTime
		, @EndTime = @__endtime
		, @ErrorMessage = @__errmsg
		, @ConversationHandle = @ConversationHandle
		, @QueueNo = @QueueNo
end
go