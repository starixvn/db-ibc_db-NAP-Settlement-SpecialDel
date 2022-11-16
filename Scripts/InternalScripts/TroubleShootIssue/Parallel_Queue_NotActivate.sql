-- IN CASE server got issue, after checking SiteDB_SettlementLock, can not do release command, it means data in the table SiteDB_SettlementProcessing not processed, need to do step below
---------> push command to activate queue--------------------------------------
DECLARE @SiteDBGroupId SMALLINT 
		,@MatchId INT 
		,@SessionId BIGINT
		,@TotalQueue INT = 4

SELECT @SiteDBGroupId = XXX, @SessionId = XXX

DECLARE	@QueueNo INT = 1
			,@MessageTypeTriggerPattern VARCHAR(200)
			,@MessageType VARCHAR(200)
			,@MessageContent VARCHAR(MAX)

SELECT @MessageTypeTriggerPattern  = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) +'_bet_settle_msg_type_'
		,@MessageType  = ''
		,@MessageContent = ''


WHILE (@QueueNo <= @totalQueue)
BEGIN
		
	SET @MessageType = @MessageTypeTriggerPattern 
							+ CASE WHEN @QueueNo < 10 THEN '0' ELSE '' END + CAST(@queueNo AS VARCHAR)
					
	SET @MessageContent = CAST(@SiteDBGroupId AS VARCHAR) + '^' + CAST(@SessionId AS VARCHAR)

	EXEC [dbo].[SSB_Send_Message] @MessageContent = @MessageContent
		, @FunctionName = 'settlement'
		, @MessageType = @MessageType
							
	SET @QueueNo = @QueueNo + 1		
END
				
	