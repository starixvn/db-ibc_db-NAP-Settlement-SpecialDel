/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Replicated_SyncSiteDB_UpdateData @ConversationHandle uniqueidentifier
	, @MessageType varchar(200)
	, @MessageBody nvarchar(max)
	, @MessageId varchar(128)
as
/*  Created: Kathy@20220827
	Task: Pick conversation
	DB: SBSETTLE-bodb02,DBBAL-bodb02
	Revisions:  
		- 20220827@Kathy: Scale Out BetTrans [Redmine:#175251]
*/
begin
	DECLARE @starttime DATETIME
			,@endtime DATETIME
			,@errmsg VARCHAR(1024)

	SET @starttime = sysdatetime()
	
	set deadlock_priority high
	BEGIN TRY	
		EXEC sp_executesql @messagebody
	END TRY
	BEGIN CATCH
		SET @errmsg = ERROR_MESSAGE()
	END CATCH
	set deadlock_priority normal
	
	SET @endtime = sysdatetime()

	EXEC dbo.SSB_Settlement_WriteLogs @MessageId = @MessageId
		, @MessageType			= @MessageType
		, @MessageBody			= @MessageBody
		, @StartTime			= @starttime
		, @EndTime				= @endtime
		, @ErrorMessage			= @errmsg
		, @ConversationHandle	= @ConversationHandle

end
go