/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
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
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @MatchidList_Waiting_30minutes VARCHAR(MAX) = ''
			
	--SEND NOTIFICATION VIA EMAIL FOR LOCAL
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''	
		
	-- SEND NOTIFICATION VIA LESTALK ON PRODUCTION
	DECLARE @msg NVARCHAR(4000)	= ''
		 ,@title NVARCHAR(200)	= 'AutoVoid: Notification'
	
	------Sending notification if stay in queue too long, over 10 minutes -----------
	SET @MatchidList_Waiting_30minutes = ISNULL(STUFF((SELECT TOP 10 ',' + CAST(matchid  AS VARCHAR(50))
												FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
												WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 30												
												FOR XML PATH(''))
												,1,1,''),'')
	
	IF @MatchidList_Waiting_30minutes <> ''
	BEGIN
		-- Send via letstalk for production											
		IF @@SERVERNAME IN ('DBTRANS')
		BEGIN
			-- send letstalk
			SET @msg = 'Matchid waiting in queue over 10 minutes: 
			-------------
			' 
			+ @MatchidList_Waiting_30minutes
			+ CAST(CURRENT_TIMESTAMP AS VARCHAR(20)) + ' GMT-4'
			EXECUTE	DBNOTI.NotificationDB.dbo.Letstalk_SendMessage @To = 'NotiGroup3', @Msg = @msg, @Title=@title;
			
			-- Send email
			SET @Subject = 'TVS: Auto Void Notification!'	
			-- For testing------------
			--SET @Recipients = 'helen.do@starixsoft.com;max.tran@starixsoft.com;julien.le@starixsoft.com;kaka.huynh@starixsoft.com;tommy.nguyen@starixsoft.com;jane.dinh@starixsoft.com;charles.nguyen@starixsoft.com;raymond.le@starixsoft.com'
			
			-- For Production -----------
			SET @Recipients = 'dbaadmin@starixsoft.com;julien.le@starixsoft.com;helen.do@starixsoft.com;raymond.le@starixsoft.com;jacob.phan@starixsoft.com;max.tran@starixsoft.com;kaka.huynh@starixsoft.com;tommy.nguyen@starixsoft.com;charles.nguyen@starixsoft.com;jane.dinh@starixsoft.com'
			
			SET @Body = 'TVS: Auto Void Notification: Matchid still waiting in queue too long: ' + @MatchidList_Waiting_30minutes
						+ ' ( Sample: SELECT TOP 10 matchid FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 10 )'
				
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
			SET @Recipients = 'helen.do@starixsoft.com;max.tran@starixsoft.com;julien.le@starixsoft.com;kaka.huynh@starixsoft.com;tommy.nguyen@starixsoft.com;jane.dinh@starixsoft.com;charles.nguyen@starixsoft.com;raymond.le@starixsoft.com'
			-- For Production -----------
			/*
			SET @Recipients = 'it@starixsoft.com;julien.le@starixsoft.com;helen.do@starixsoft.com;raymond.le@starixsoft.com;jacob.phan@starixsoft.com;max.tran@starixsoft.com;kaka.huynh@starixsoft.com;tommy.nguyen@starixsoft.com;charles.nguyen@starixsoft.com;jane.dinh@starixsoft.com'
			*/
			SET @Body = 'TVS: Auto Void Notification: Matchid still waiting in queue too long: ' + @MatchidList_Waiting_30minutes
						+ ' ( Sample: SELECT TOP 10 matchid FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK) WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 10 )'
				
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


