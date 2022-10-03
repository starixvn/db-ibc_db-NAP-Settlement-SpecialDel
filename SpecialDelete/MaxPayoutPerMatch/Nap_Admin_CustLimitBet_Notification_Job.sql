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
		- 20220530@Tina: Cannot send notification via Letstalk [Redmine: #173376]
		- 20220607@Tina: remove some email of @Recipients on production environment
		- 20220317@Max: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
		- 20220823@Max: Remove Temp Code - [Redmine: #169407]
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
		- 20221003@Victiria: Add more email to @Recipients [Redemine: #178536]

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
	IF @@SERVERNAME IN ('DBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' 
	BEGIN
		SET @Recipients = 'dbaadmin@starixvn.com'
	END
	ELSE
	BEGIN
		SET @Recipients = 'dba_local@starixvn.com;starixqa@starixvn.com;qa@starixvn.com'
	END
		
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
		-- Send via letstalk for production and SIT											
		IF @@SERVERNAME IN ('DBTRANS', 'SITDBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' OR @@SERVERNAME LIKE 'SITDBGRP%' 
		BEGIN
			-- send letstalk
			SET @msg = 'NAP: CustLimitBet Failed! Queue waiting in queue over 5 minutes. 
-------------
SP: Nap_Admin_CustLimitBet_Notification_Job
QueueId: ' + @List_Waiting_5minutes +' 
'
			+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			
			EXECUTE  DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
				  , @JobId = NULL
				  , @JobName = N'vndba:Check slowly running or failed processes'
				  , @Message = @msg
				  , @CaseId = 1;
			
			-- Send email
			SET @Subject = 'NAP: CustLimitBet Notification!'	
			
			SET @Body = 'NAP: CustLimitBet Notification: QueueId still waiting in queue too long: ' + @List_Waiting_5minutes+ '. 
SP: Nap_Admin_CustLimitBet_Notification_Job. 
Sample: SELECT TOP 10 matchid FROM dbo.CustLimitBetQueue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, CreatedDate, GETDATE()) > 5. '
				
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
			
			SET @Body = 'NAP: CustLimitBet Notification: QueueId still waiting in queue too long: ' + @List_Waiting_5minutes+ '. 
SP: Nap_Admin_CustLimitBet_Notification_Job. 
Sample: SELECT TOP 10 matchid FROM dbo.CustLimitBetQueue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, CreatedDate, GETDATE()) > 5. '
				
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
		-- Send via letstalk for production	and SIT									
		IF @@SERVERNAME IN ('DBTRANS', 'SITDBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' OR @@SERVERNAME LIKE 'SITDBGRP%' 
		BEGIN
			-- send letstalk
			SET @msg = 'NAP: CustLimitbet Failed! Queue execution failed.
-----
SP: Nap_Admin_CustLimitBet_Notification_Job				
QueueId: ' + CONVERT(VARCHAR(MAX),@List_Failed)+ ' 
Table: bodb02.dbo.CustLimitBetQueue
'+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'

			EXECUTE  DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
				  , @JobId = NULL
				  , @JobName = N'vndba:Check slowly running or failed processes'
				  , @Message = @msg
				  , @CaseId = 1;
			
			-- Send email
			SET @Subject = 'NAP: CustLimitBet Failed!'	
			
			SET @Body = 'NAP: Queue execution failed. QueueId: ' + CONVERT(VARCHAR(MAX),@List_Failed)+ '. 
SP: Nap_Admin_CustLimitBet_Notification_Job. 
Sample: SELECT TOP 10 * FROM bodb02.dbo.CustLimitBetQueue WITH (NOLOCK). '
				
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
			SET @Subject = 'NAP: CustLimitBet Failed!'	
			
			SET @Body = 'NAP: Queue execution failed. QueueId: ' + CONVERT(VARCHAR(MAX),@List_Failed)+ '. 
SP: Nap_Admin_CustLimitBet_Notification_Job. 
Sample: SELECT TOP 10 * FROM bodb02.dbo.CustLimitBetQueue WITH (NOLOCK).'
				
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


