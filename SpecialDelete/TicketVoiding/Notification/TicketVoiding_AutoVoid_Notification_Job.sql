/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoid_Notification_Job]
AS
/*	Created by: Helen
	Date 20200212
	Task: [TVS] Abnormal Void Bets Automation
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Helen:[TVS] Abnormal Void Bets Automation [Redmine:#127398]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200325@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20201012@Louisa: Update new email domain starixvn.com + Use DBNOTI instead of DBTP [Redmine:#143284]
		- 20210401@Max: [TVS] Auto void before KO time [Redmine: #150522]
		- 20210405@Max: Enhance [TVS] Auto void before KO time [Redmine: #150522]
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
		- 20230303@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230703@Max: [TVS] Enhance notification time [Redmine: #190711]
		- 20240710@Kathy: Change instance name [Redmine:#207768]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @MatchidList_Waiting_30minutes VARCHAR(MAX) = '',
			@MatchIdList_Failed VARCHAR(MAX) = '',
			@QueueList_Waiting_30minutes VARCHAR(MAX) = ''
			
	--SEND NOTIFICATION VIA EMAIL FOR LOCAL
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''	
		
	-- SEND NOTIFICATION VIA LESTALK ON PRODUCTION
	DECLARE @msg NVARCHAR(4000)	= ''
		 ,@title NVARCHAR(200)	= 'AutoVoid: Notification'
	
	------Sending notification if stay in queue too long, over 30 minutes -----------
	SET @MatchidList_Waiting_30minutes = ISNULL(STUFF((
												SELECT TOP 10 ',' + CAST(q.matchid  AS VARCHAR(50))
												FROM dbo.TicketVoiding_AutoVoidQueue q  WITH (NOLOCK)
													INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = q.MatchId
												WHERE q.StatusId = 0
													AND 1 = CASE 
																WHEN q.Action NOT IN ('VoidInstant5m', 'VoidInstant10m')  
																	AND DATEDIFF(MINUTE, q.CreatedDate, GETDATE()) BETWEEN 31 AND 32 THEN 1
																WHEN q.Action IN ('VoidInstant5m', 'VoidInstant10m') AND q.CreatedDate > m.GlobalShowTime
																	AND DATEDIFF(MINUTE, q.CreatedDate, GETDATE()) BETWEEN 31 AND 32 THEN 1
																WHEN q.Action IN ('VoidInstant5m', 'VoidInstant10m') AND q.CreatedDate <= m.GlobalShowTime
																	AND DATEDIFF(MINUTE, m.GlobalShowTime, GETDATE()) BETWEEN 31 AND 32 THEN 1 
																ELSE 0 END
												FOR XML PATH(''))
												,1,1,''),'')
	--Sending notification if auto void failed
	SET @MatchIdList_Failed = ISNULL(STUFF((SELECT TOP 10 ',' + CAST(matchid  AS VARCHAR(50))
												FROM dbo.TicketVoiding_AutoVoidQueue WITH (NOLOCK)
												WHERE StatusId = 3	
													AND DATEDIFF(MINUTE, ModifiedDate, GETDATE()) < 2
												FOR XML PATH(''))
												,1,1,''),'')

	------Sending notification if stay in queue too long, over 30 minutes -----------
	SET @QueueList_Waiting_30minutes = ISNULL(STUFF((
												SELECT TOP 10 ',' + CAST(q.QueueId  AS VARCHAR(50))
												FROM dbo.TicketVoiding_Queue q  WITH (NOLOCK)
												WHERE q.StatusId = 1
													AND DATEDIFF(MINUTE, q.Starttime, GETDATE()) BETWEEN 31 AND 32
												FOR XML PATH(''))
												,1,1,''),'')
	
	--In queue too long
	IF @MatchidList_Waiting_30minutes <> ''
	BEGIN
		-- Send via letstalk for production											
		IF @@SERVERNAME IN ('DBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' OR @@SERVERNAME LIKE 'DBSITEC%' 
		BEGIN
			-- send letstalk
			SET @msg = 'Matchid waiting in queue over 30 minutes: 
			-------------
			' 
			+ @MatchidList_Waiting_30minutes
			+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			EXECUTE	DBNOTI.NotificationDB.dbo.Letstalk_SendMessage @To = 'NotiGroup3', @Msg = @msg, @Title=@title;
			
			-- Send email
			SET @Subject = 'TVS: Auto Void Notification!'	
			-- For testing------------
			/*SET @Recipients = 'helen.do@starixvn.com;max.tran@starixvn.com;julien.le@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;jane.dinh@starixvn.com;charles.nguyen@starixvn.com;raymond.le@starixvn.com'
			*/
			-- For Production -----------
			SET @Recipients = 'dbaadmin@starixsoft.com'
			
			SET @Body = 'TVS: Auto Void Notification: Matchid still waiting in queue too long: ' + @MatchidList_Waiting_30minutes
						+ ' ( Sample: SELECT TOP 10 matchid FROM dbo.TicketVoiding_AutoVoidQueue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 30 )'
				
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
			SET @Subject = 'TVS: Auto Void Notification!'	
			-- For testing------------
			/*SET @Recipients = 'helen.do@starixvn.com;max.tran@starixvn.com;julien.le@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;jane.dinh@starixvn.com;charles.nguyen@starixvn.com;raymond.le@starixvn.com'
			*/
			-- For Production -----------
			
			SET @Recipients = 'dba_local@starixsoft.com'
			
			SET @Body = 'TVS: Auto Void Notification: Matchid still waiting in queue too long: ' + @MatchidList_Waiting_30minutes
						+ ' ( Sample: SELECT TOP 10 matchid FROM dbo.TicketVoiding_AutoVoidQueue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 30 )'
				
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

	--In queue too long
	IF @QueueList_Waiting_30minutes <> ''
	BEGIN
		-- Send via letstalk for production											
		IF @@SERVERNAME IN ('DBTRANS') OR @@SERVERNAME LIKE 'DBGRP%'  OR @@SERVERNAME LIKE 'DBSITEC%' 
		BEGIN
			-- send letstalk
			SET @msg = 'Queue waiting in queue over 30 minutes: 
			-------------
			' 
			+ @MatchidList_Waiting_30minutes
			+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			EXECUTE	DBNOTI.NotificationDB.dbo.Letstalk_SendMessage @To = 'NotiGroup3', @Msg = @msg, @Title=@title;
			
			-- Send email
			SET @Subject = 'TVS: Void Notification!'	
			-- For testing------------
			/*SET @Recipients = 'helen.do@starixvn.com;max.tran@starixvn.com;julien.le@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;jane.dinh@starixvn.com;charles.nguyen@starixvn.com;raymond.le@starixvn.com'
			*/
			-- For Production -----------
			SET @Recipients = 'dbaadmin@starixsoft.com'
			
			SET @Body = 'TVS: Void Notification: Queue still waiting in queue too long: ' + @QueueList_Waiting_30minutes
						+ ' ( Sample: SELECT TOP 10 QueueId FROM dbo.TicketVoiding_Queue WITH (NOLOCK) WHERE StatusId = 1 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 30 )'
				
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
			SET @Subject = 'TVS: Void Notification!'	
			-- For testing------------
			/*SET @Recipients = 'helen.do@starixvn.com;max.tran@starixvn.com;julien.le@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;jane.dinh@starixvn.com;charles.nguyen@starixvn.com;raymond.le@starixvn.com'
			*/
			-- For Production -----------
			
			SET @Recipients = 'dba_local@starixsoft.com'
			
			SET @Body = 'TVS: Void Notification: Queue still waiting in queue too long: ' + @QueueList_Waiting_30minutes
						+ ' ( Sample: SELECT TOP 10 QueueId FROM dbo.TicketVoiding_Queue WITH (NOLOCK) WHERE StatusId = 1 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 30 )'
				
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

	--Auto Void Failed
	IF @MatchIdList_Failed <> ''
	BEGIN
		-- Send via letstalk for production											
		IF @@SERVERNAME IN ('DBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' OR @@SERVERNAME LIKE 'DBSITEC%'  
		BEGIN
			-- send letstalk
			SET @msg = 'Ticket Voiding System: Void Bets Automation Failed !
				-----
				' 
				+'Matchid: ' + CONVERT(VARCHAR(MAX),@MatchIdList_Failed)
							+ ' ( Table: bodb02.dbo.TicketVoiding_AutoVoidQueue)'
				+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			EXECUTE	DBNOTI.NotificationDB.dbo.Letstalk_SendMessage @To = 'NotiGroup3', @Msg = @msg, @Title=@title;
			
			-- Send email
			SET @Subject = 'Ticket Voiding System: Void Bets Automation Failed !'	
			-- For testing------------
			/*SET @Recipients = 'helen.do@starixvn.com;max.tran@starixvn.com;julien.le@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;jane.dinh@starixvn.com;charles.nguyen@starixvn.com;raymond.le@starixvn.com'
			*/		
			-- For Production -----------
			
			SET @Recipients = 'dbaadmin@starixsoft.com'
			
			SET @Body = 'Ticket Voiding System: Void Bets automation failed: ''Matchid: ' + CONVERT(VARCHAR(MAX),@MatchIdList_Failed)
							+ ' ( Sample: SELECT TOP 10 * FROM bodb02.dbo.TicketVoiding_AutoVoidQueue WITH (NOLOCK) WHERE StatusId = 3 )'
				
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
			SET @Subject = 'Ticket Voiding System: Void Bets Automation Failed !'	
			-- For testing------------
			/*SET @Recipients = 'helen.do@starixvn.com;max.tran@starixvn.com;julien.le@starixvn.com;kaka.huynh@starixvn.com;tommy.nguyen@starixvn.com;jane.dinh@starixvn.com;charles.nguyen@starixvn.com;raymond.le@starixvn.com'
			*/			
			-- For Production -----------
			
			SET @Recipients = 'dba_local@starixsoft.com'
			
			SET @Body = 'Ticket Voiding System: Void Bets automation failed: ''Matchid: ' + CONVERT(VARCHAR(MAX),@MatchIdList_Failed)
							+ ' ( Sample: SELECT TOP 10 * FROM bodb02.dbo.TicketVoiding_AutoVoidQueue WITH (NOLOCK) StatusId = 3 )'
				
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


