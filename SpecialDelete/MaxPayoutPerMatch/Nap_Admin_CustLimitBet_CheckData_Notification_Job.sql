/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_CheckData_Notification_Job]
AS
/*	
	Created: 20211111@Tina
    Task: Support check data for Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20211111@Tina: create
		- 20211119@Tina: run each 30 minutes (minute = 5 or 35)
		- 20211210@Tina: send Letstalk [Redmine: #159626]
		- 20220530@Tina: Cannot send notification via Letstalk [Redmine: #173376]
		- 20220607@Tina: remove some email of @Recipients on production environment
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
		- 20221003@Victoria: Add more email to @Recipients [Redemine: #178536]
		- 20221206@Max: MPO Remove invalid email address (LOCAL + SIT) [Redmine: #00000]

	Param's explanation:		
		
*/
BEGIN
	SET NOCOUNT ON

	IF(DATEPART(MINUTE, GETDATE()) NOT IN (5,35))
	BEGIN
		RETURN;
	END

	DECLARE @StartTime DATETIME = getdate(),
			@EndTime DATETIME = getdate(),
			@ErrorMessage VARCHAR(MAX) = 'error message'
			
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''	
	
	IF @@SERVERNAME IN ('DBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' 
	BEGIN
		SET @Recipients = 'dbaadmin@starixvn.com'
	END
	ELSE
	BEGIN
		SET @Recipients = 'dba_local@starixvn.com;qa@starixvn.com;kaka.huynh@starixvn.com;jane.dinh@starixvn.com;neil.dao@starixvn.com;tommy.nguyen@starixvn.com'
	END
	

	EXEC  [dbo].[Nap_Admin_CustLimitBet_CheckData_Job] @StartTime = @StartTime OUTPUT, @EndTime = @EndTime OUTPUT, @ErrorMessage = @ErrorMessage OUTPUT

	IF @ErrorMessage <> ''
	BEGIN
		-- Send notification via email
		SET @Subject = 'NAP: CustLimitBet Failed !'	
			
		SET @Body = 'NAP: '+ @ErrorMessage + CHAR(13) + CHAR(10) 
				  + 'Check from ' + CONVERT(varchar, @StartTime, 120) + ' to ' + CONVERT(varchar, @EndTime, 120)
		
		EXEC msdb.dbo.sp_send_dbmail
				@recipients= @Recipients
				,@body=@Body
				,@sensitivity ='Personal'
				,@importance ='High'
				,@subject =@Subject
				,@body_format = 'HTML'
				,@profile_name =DEFAULT;

		-- send letstalk
		EXECUTE  DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
				  , @JobId = NULL
				  , @JobName = N'vndba:Check slowly running or failed processes'
				  , @Message = @Body
				  , @CaseId = 1;
	END
	
END		
GO
