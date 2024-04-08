USE [bodb02]
GO
/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02,DBBAL-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER procedure [dbo].[SSB_Settlement_WriteLogs] @MessageId varchar(128)
	, @MessageType varchar(200) = null
	, @MessageBody nvarchar(max) = null
	, @StartTime datetime2 = null
	, @EndTime datetime2 = null
	, @SessionId bigint = null
	, @ErrorMessage varchar(1024) = ''
	, @ConversationHandle varchar(128) = ''
	, @QueueNo tinyint = null
	, @AffectedTicket int = null
	, @MatchId int = null 
	, @EventTable tinyint  = 0
	, @TableType tinyint = 0
	, @SiteDBGroupId smallint = 0
as
/*  Created: Patrick@20210801
	Task: Write logs
	DB: DBTXN-bodb02,SBSETTLE-bodb02,DBBAL-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20221025@Patrick: Add more column SiteDBGroupId [Redmine:#178694]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
*/
begin
	set nocount on
	
	IF OBJECT_ID('SSB_SettlementLogs','U') IS NOT NULL 
		insert into dbo.SSB_SettlementLogs(MessageId, MessageType, MessageBody, StartTime, EndTime, SessionId, ErrorMessage, ConversationHandle, QueueNo, AffectedTicket, SiteDBGroupId, EventTable, MatchId, TableType)
		values(@MessageId, @MessageType, @MessageBody, isnull(@StartTime, sysdatetime()), isnull(@EndTime, sysdatetime()), @SessionId, @ErrorMessage, @ConversationHandle, @QueueNo, @AffectedTicket, @SiteDBGroupId, @EventTable, @MatchId, @TableType)

	--send notification will be handled by another process
end
