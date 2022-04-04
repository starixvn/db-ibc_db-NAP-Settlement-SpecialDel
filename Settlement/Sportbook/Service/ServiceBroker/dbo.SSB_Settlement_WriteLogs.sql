/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Settlement_WriteLogs @MessageId varchar(128)
	, @MessageType varchar(200) = null
	, @MessageBody nvarchar(max) = null
	, @StartTime datetime2 = null
	, @EndTime datetime2 = null
	, @SessionId bigint = null
	, @ErrorMessage varchar(1024) = ''
	, @ConversationHandle varchar(128) = ''
	, @QueueNo tinyint = null
	, @AffectedTicket int = null
as
/*  Created: Patrick@20210801
	Task: Write logs
	DB: DBTXN-bodb02,SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
*/
begin
	set nocount on
	insert into dbo.SSB_SettlementLogs(MessageId, MessageType, MessageBody, StartTime, EndTime, SessionId, ErrorMessage, ConversationHandle, QueueNo, AffectedTicket)
	values(@MessageId, @MessageType, @MessageBody, isnull(@StartTime, sysdatetime()), isnull(@EndTime, sysdatetime()), @SessionId, @ErrorMessage, @ConversationHandle, @QueueNo, @AffectedTicket)

	--send notification will be handled by another process
end
go
