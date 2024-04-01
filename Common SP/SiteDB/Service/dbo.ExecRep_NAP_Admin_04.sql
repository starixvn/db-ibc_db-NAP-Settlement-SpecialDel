/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_04] 
	@Action VARCHAR(1)
	,@SiteDBGroupId SMALLINT 
	,@MatchId INT 
	,@SessionId BIGINT
	,@TotalQueue INT = 0
	
AS
/*
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE	@QueueNo INT = 1
			,@MessageTypeTriggerPattern VARCHAR(200)
			,@MessageType VARCHAR(200)
			,@MessageContent VARCHAR(MAX)

	SELECT @MessageTypeTriggerPattern  = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) +'_bet_settle_msg_type_'
			,@MessageType  = ''
			,@MessageContent = ''

	IF @Action = 'I'
	BEGIN
		WHILE (1=1)
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM dbo.SiteDB_SettlementLock WHERE SiteDBGroupId = @SiteDBGroupId AND matchid = @MatchId)
				WAITFOR DELAY '00:00:00.005' -- wait for another session of this match being executed
			ELSE
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementLock (SiteDBGroupId, MatchId, SessionId) VALUES (@SiteDBGroupId, @MatchId, @SessionId)

				WHILE (@QueueNo <= @totalQueue)
				BEGIN
		
					SET @MessageType = @MessageTypeTriggerPattern 
											+ CASE WHEN @QueueNo < 10 THEN '0' ELSE '' END + CAST(@queueNo AS VARCHAR)
					
					SET @MessageContent = CAST(@SiteDBGroupId AS VARCHAR) + '^' + CAST(@matchid AS VARCHAR) + '^' + CAST(@SessionId AS VARCHAR)

					EXEC [dbo].[SSB_Send_Message] @MessageContent = @MessageContent
						, @FunctionName = 'settlement'
						, @MessageType = @MessageType
							
					SET @QueueNo = @QueueNo + 1		
				END
				
				BREAK
			END
		END

		RETURN
	END
	ELSE IF @Action = 'D'
	BEGIN
		WHILE 1=1
		BEGIN
			IF EXISTS (SELECT	TOP 1 1 
						FROM	dbo.SiteDB_SettlementProcessing 
						WHERE	SiteDBGroupId = @SiteDBGroupId
								AND SessionId = @SessionId
			)
				WAITFOR DELAY '00:00:00.005' -- wait for release match
			ELSE
			BEGIN
				DELETE
				FROM	dbo.SiteDB_SettlementLock 
				WHERE	SiteDBGroupId = @SiteDBGroupId
						AND SessionId = @SessionId

				BREAK
			END
		END

		RETURN
	END

END
GO