/*<info serverAlias="DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Retry_Licensee_Job]
AS
/*	
	Created: 20230712@Max
    Task: Scale out DBTRANS for Credit market - [Redmine: #181595]
    DB: DBSID/bodb02
    Revisions:
		- 20230712@Max: Clone from DBTRANS - [Redmine: #181595]
		- 20240710@Kathy: Change instance name [Redmine:#207768]
		- 20250508@Aries: Change instance name DBTRANS [Redmine:#226591]
	
	Param's explanation:		
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @QueueId	BIGINT
		,@ErrCode		INT
		,@ErrMsg		VARCHAR(300)
		,@RetryTime INT = 5

	--SEND NOTIFICATION VIA EMAIL
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''
		,@List_QueueRetry_Success VARCHAR(MAX) = ''
		,@List_QueueRetry_Failed VARCHAR(MAX) = ''


	CREATE TABLE #CustLimitBet_QueueRetry (QueueId BIGINT, CreatedDate DATETIME, IsFinished INT DEFAULT(0))

	CREATE INDEX IX_IsFinished ON #CustLimitBet_QueueRetry (IsFinished)

	INSERT #CustLimitBet_QueueRetry (QueueId, CreatedDate)
	SELECT DISTINCT q.MainQueueId, Createddate
	FROM dbo.CustLimitBet_QueueRetry q WITH(NOLOCK)
	WHERE q.StatusId = 0
		AND DATEADD(SECOND, @RetryTime, q.Createddate) <= GETDATE()
	ORDER BY q.Createddate
	
	WHILE(1=1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = ''
	
		;WITH t AS (SELECT TOP (1) * FROM #CustLimitBet_QueueRetry WHERE IsFinished = 0)
		UPDATE t
		SET t.IsFinished = 1
			, @QueueId = t.QueueId
		FROM t
		
		IF @@ROWCOUNT = 0 
			BREAK

		BEGIN TRY
			EXEC dbo.NAP_Admin_CustLimitBet_Retry_Licensee
				@QueueId = @QueueId
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
		END CATCH

		IF (ISNULL(@ErrCode, 0) <> 0 )
		BEGIN
			UPDATE	q WITH(ROWLOCK, UPDLOCK)
			SET	StatusId = 2
				,Trycount = 5
			FROM dbo.CustLimitBet_QueueRetry q
			WHERE q.MainQueueId = @QueueId
				AND q.Trycount = 0
				AND q.StatusId = 0
		END
			
	END

	--SEND NOTIFICATION FOR LIST QUEUES RETRY
	--For PROD EVN
	--SET @Recipients = 'dbaadmin@starixvn.com;kiwi.tran@starixvn.com;helen.do@starixvn.com;max.tran@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;susan.le@starixvn.com'

	--For local Testing, input email need to test
	--SET @Recipients = 'max.tran@starixvn.com;susan.le@starixvn.com'

	IF @@SERVERNAME IN ('DBTRANS', 'DBTRANS\INST2') OR @@SERVERNAME LIKE 'DBGRP%' OR @@SERVERNAME LIKE 'DBSITEC%'  OR @@SERVERNAME LIKE 'SITDBSITEC%'  
	BEGIN
		SET @Recipients = 'dbaadmin@starixsoft.com'
	END
	ELSE
	BEGIN
		SET @Recipients = 'dba_local@starixsoft.com;qa@starixsoft.com'
	END

	SELECT @List_QueueRetry_Success = ISNULL(STUFF((SELECT DISTINCT TOP 10 ',' + CAST(tmp.QueueID  AS VARCHAR(50))
												FROM #CustLimitBet_QueueRetry tmp
													INNER JOIN dbo.CustLimitBet_QueueRetry q  WITH (NOLOCK) ON q.MainQueueId = tmp.QueueId
												WHERE q.StatusId = 1
												FOR XML PATH(''))
												,1,1,''),'')

	SELECT @List_QueueRetry_Failed = ISNULL(STUFF((SELECT DISTINCT TOP 10 ',' + CAST(tmp.QueueID  AS VARCHAR(50))
												FROM #CustLimitBet_QueueRetry tmp
													INNER JOIN dbo.CustLimitBet_QueueRetry q  WITH (NOLOCK) ON q.MainQueueId = tmp.QueueId
												WHERE q.StatusId = 2
												FOR XML PATH(''))
												,1,1,''),'')

	-- Send email
	SET @Subject = 'NAP: CustLimitBet Notification!'
	--Tina@16052023: Not send an email if retry successfully for the rejected action [redmine: 188130]
	--IF @List_QueueRetry_Success <> ''
	--BEGIN		
	--	SET @Body = 'NAP: CustLimitBet Notification: Retry successful for some queues have rejected transid not found on CustLimitBetHistory: ' + @List_QueueRetry_Success
				
	--	EXEC msdb.dbo.sp_send_dbmail
	--			@recipients= @Recipients
	--			,@body=@Body
	--			,@sensitivity ='Personal'
	--			,@importance ='High'
	--			,@subject =@Subject
	--			,@body_format = 'HTML'
	--			,@profile_name =DEFAULT;
	--END

	IF @List_QueueRetry_Failed <> ''
	BEGIN		
		SET @Body = 'NAP: CustLimitBet Notification: Retry failed for some queues have rejected transid not found on CustLimitBetHistory: ' + @List_QueueRetry_Failed
				
		EXEC msdb.dbo.sp_send_dbmail
				@recipients= @Recipients
				,@body=@Body
				,@sensitivity ='Personal'
				,@importance ='High'
				,@subject =@Subject
				,@body_format = 'TEXT'
				,@profile_name =DEFAULT;
	END

	DROP TABLE #CustLimitBet_QueueRetry
END	

GO


