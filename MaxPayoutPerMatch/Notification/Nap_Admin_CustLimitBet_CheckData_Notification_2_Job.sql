/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_CheckData_Notification_2_Job]
(
	@Rule VARCHAR(50) = ''
)
AS

/*	
	Created: 20240610@Helen
    Task: Support check data for Max Payout Per Match setting - New Rule - New Job - [Redmine: #206245]
    DB: DBTXN/bodb02
    Revisions:
		- 20240610@Helen: Support check data for Max Payout Per Match setting - New Rule - New Job

	Param's explanation:		
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime DATETIME = getdate(),
			@EndTime DATETIME = getdate(),
			@ErrorMessage VARCHAR(MAX) = 'error message'
			
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''	
	
	IF @@SERVERNAME IN ('DBTRANS') OR @@SERVERNAME LIKE 'DBGRP%' 
	BEGIN
		SET @Recipients = 'dbaadmin@starixsoft.com;martin.chen@onelab.tw;member_core@onelab.tw;steve.liao@onelab.tw'
	END
	ELSE
	BEGIN
		SET @Recipients = 'dba_local@starixsoft.com;qa@starixsoft.com'
	END
	
	IF @Rule = 'Negative'
	BEGIN
		EXEC  [dbo].[Nap_Admin_CustLimitBet_Negative_Checking] @StartTime = @StartTime OUTPUT, @EndTime = @EndTime OUTPUT
														 ,@ErrorMessage = @ErrorMessage OUTPUT
	END
	IF @ErrorMessage <> ''
	BEGIN
		-- Send notification via email
		SET @Subject = 'NAP: CustLimitBet Failed !'	
			
		SET @Body = 'SP: Nap_Admin_CustLimitBet_Negative_Checking' + CHAR(13) + CHAR(10)
		+ 'Check from ' + CONVERT(varchar, @StartTime, 120) + ' to ' + CONVERT(varchar, @EndTime, 120) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
		+ @ErrorMessage + CHAR(13) + CHAR(10)
		
		EXEC msdb.dbo.sp_send_dbmail
				@recipients= @Recipients
				,@body=@Body
				,@sensitivity ='Personal'
				,@importance ='High'
				,@subject =@Subject
				,@body_format = 'TEXT'
				,@profile_name =DEFAULT;

		-- send letstalk
		EXECUTE  DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
				  , @JobId = NULL
				  , @JobName = N'bodb02 : Task Max Payout - Check Data'
				  , @Message = @Body
				  , @CaseId = 1;
	END
	
END		
GO
