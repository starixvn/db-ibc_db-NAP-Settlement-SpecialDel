/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Nap_Admin_CustLimitBet_Notification_Job]
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20211011@Max: Change logic send Notification - [Redmine: #158073]

	Param's explanation:		
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @List_Waiting_5minutes VARCHAR(MAX) = '',
			@List_Failed VARCHAR(MAX) = '',
			@CurrentTime DATETIME = NULL
			
	--SEND NOTIFICATION VIA EMAIL
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''	
	
	--For PROD EVN
	SET @Recipients = 'dbaadmin@starixvn.com;kiwi.tran@starixvn.com;helen.do@starixvn.com;max.tran@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com'

	--For local Testing, input email need to test
	--SET @Recipients = 'max.tran@starixvn.com, xxx'
		
	-- SEND NOTIFICATION VIA LESTALK ON PRODUCTION
	DECLARE @msg NVARCHAR(4000)	= ''
		 ,@title NVARCHAR(200)	= 'CustLimitBet: Notification'
	
	SET @CurrentTime = GETDATE()
	------Sending notification if stay in queue too long, over 5 minutes -----------
	SET @List_Waiting_5minutes = ISNULL(STUFF((SELECT TOP 10 ',' + CAST(q.QueueID  AS VARCHAR(50))
												FROM dbo.CustLimitBetQueue q  WITH (NOLOCK)
												WHERE q.StatusId = 0
													AND q.ExecTime IS NULL
													AND DATEDIFF(MINUTE, q.CreatedDate, @CurrentTime) BETWEEN 5 AND 6
												FOR XML PATH(''))
												,1,1,''),'')
	--Sending notification if failed
	SET @List_Failed = ISNULL(STUFF((SELECT TOP 10 ',' + CAST(q.QueueID  AS VARCHAR(50))
												FROM dbo.CustLimitBetQueue q WITH (NOLOCK)
												WHERE q.Statusid = 2
													AND DATEDIFF(MINUTE, q.ExecTime, @CurrentTime) < 2
												FOR XML PATH(''))
												,1,1,''),'')
	
	--In queue too long
	IF @List_Waiting_5minutes <> ''
	BEGIN
		-- Send via letstalk for production											
		IF @@SERVERNAME IN ('DBTRANS')
		BEGIN
			-- send letstalk
			SET @msg = 'Queue waiting in queue over 5 minutes: 
			-------------
			' 
			+ @List_Waiting_5minutes
			+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			EXECUTE	DBNOTI.NotificationDB.dbo.Letstalk_SendMessage @To = 'DB.Job.Monitor', @Msg = @msg, @Title=@title;
			
			-- Send email
			SET @Subject = 'NAP: CustLimitBet Notification!'	
			
			SET @Body = 'NAP: CustLimitBet Notification: QueueId still waiting in queue too long: ' + @List_Waiting_5minutes
						+ ' ( Sample: SELECT TOP 10 matchid FROM dbo.CustLimitBetQueue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 5 )'
				
			EXEC msdb.dbo.sp_send_dbmail
					@recipients= @Recipients
					,@body=@Body
					,@sensitivity ='Personal'
					,@importance ='High'
					,@subject =@Subject
					,@body_format = 'HTML'
					,@profile_name =DEFAULT;
					
		END
		ELSE
		BEGIN
			-- Send via email 
			SET @Subject = 'NAP: CustLimitBet Notification!'	
			
			SET @Body = 'NAP: CustLimitBet Notification: QueueId still waiting in queue too long: ' + @List_Waiting_5minutes
						+ ' ( Sample: SELECT TOP 10 matchid FROM dbo.CustLimitBetQueue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 5 )'
				
			EXEC msdb.dbo.sp_send_dbmail
					@recipients= @Recipients
					,@body=@Body
					,@sensitivity ='Personal'
					,@importance ='High'
					,@subject =@Subject
					,@body_format = 'HTML'
					,@profile_name =DEFAULT;
		END			
	END

	--Failed
	IF @List_Failed <> ''
	BEGIN
		-- Send via letstalk for production											
		IF @@SERVERNAME IN ('DBTRANS')
		BEGIN
			-- send letstalk
			SET @msg = 'NAP: CustLimitbet Failed !
				-----
				' 
				+'QueueId: ' + CONVERT(VARCHAR(MAX),@List_Failed)
							+ ' ( Table: bodb02.dbo.CustLimitBetQueue)'
				+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			EXECUTE	DBNOTI.NotificationDB.dbo.Letstalk_SendMessage @To = 'DB.Job.Monitor', @Msg = @msg, @Title=@title;
			
			-- Send email
			SET @Subject = 'NAP: CustLimitBet Failed !'	
			
			SET @Body = 'NAP: CustLimitBet failed: ''QueueId: ' + CONVERT(VARCHAR(MAX),@List_Failed)
							+ ' ( Sample: SELECT TOP 10 * FROM bodb02.dbo.CustLimitBetQueue WITH (NOLOCK) )'
				
			EXEC msdb.dbo.sp_send_dbmail
					@recipients= @Recipients
					,@body=@Body
					,@sensitivity ='Personal'
					,@importance ='High'
					,@subject =@Subject
					,@body_format = 'HTML'
					,@profile_name =DEFAULT			

		END
		ELSE
		BEGIN
			-- Send via email 
			SET @Subject = 'NAP: CustLimitBet Failed !'	
			
			SET @Body = 'NAP: CustLimitBet failed: ''QueueId: ' + CONVERT(VARCHAR(MAX),@List_Failed)
							+ ' ( Sample: SELECT TOP 10 * FROM bodb02.dbo.CustLimitBetQueue WITH (NOLOCK) )'
				
			EXEC msdb.dbo.sp_send_dbmail
					@recipients= @Recipients
					,@body=@Body
					,@sensitivity ='Personal'
					,@importance ='High'
					,@subject =@Subject
					,@body_format = 'HTML'
					,@profile_name =DEFAULT;
		END			
	END
END		
GO


