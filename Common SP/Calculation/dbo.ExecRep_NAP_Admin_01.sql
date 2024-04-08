/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_01] 	
	@MatchId INT = 0
	,@Mode VARCHAR(20)
	,@TotalQueue INT = 0
	,@SessionId BIGINT
AS
/*
	Created by: 20210730@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20240401@Kathy: write log matchid, affectedticket, eventtable, tabletype [Redmine:#203132]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE	@QueueNo INT = 1
			,@MessageTypeTriggerPattern VARCHAR(200) = 'bet_settle_msg_type_'
			,@MessageType VARCHAR(200) = ''
			,@MessageContent VARCHAR(MAX) = ''

	IF @Mode = 'LockMatch'
	BEGIN
		WHILE (1=1)
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM dbo.SettlementLock WHERE matchid = @MatchId)
				WAITFOR DELAY '00:00:00.005' -- wait for another session of this match being executed
			ELSE
			BEGIN
				INSERT INTO dbo.SettlementLock (MatchId, SessionId) VALUES (@MatchId, @SessionId)

				WHILE (@QueueNo <= @totalQueue)
				BEGIN
		
					SET @MessageType = @MessageTypeTriggerPattern 
											+ CASE WHEN @QueueNo < 10 THEN '0' ELSE '' END + CAST(@queueNo AS VARCHAR)
					
					SET @MessageContent = CAST(@matchid AS VARCHAR) + '^' + CAST(@SessionId AS VARCHAR)

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
	ELSE IF @Mode = 'ReleaseMatch'
	BEGIN
		WHILE 1=1
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
						FROM dbo.SettlementProcessing 
						WHERE SessionId = @SessionId)
				WAITFOR DELAY '00:00:00.005' -- wait for release match
			ELSE
			BEGIN
				DELETE
				FROM	dbo.SettlementLock 
				WHERE	SessionId = @SessionId

				BREAK
			END
		END

		RETURN
	END

END
GO