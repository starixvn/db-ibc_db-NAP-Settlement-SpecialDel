/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_CustWinLimitBet_Notification_Job]
AS
/*	
	Created: 20250602@July
    Task: [Synergy] - Integration - Potential Winning Limit/Threshold - [Redmine: #226514]
    DB: DBSIC-bodb02
    Revisions:
		- 20250602@July: Create new SP - [Redmine: #226514]

	Param's explanation:		
		Note: Only sitedb3
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ErrorMessage	VARCHAR(MAX)	= ''
			,@Subject		NVARCHAR(500)	= ''
			,@Body			NVARCHAR(MAX)	= ''
			,@Recipients	VARCHAR(MAX)	= ''	
	
	IF @@SERVERNAME LIKE 'DBGRP%' OR @@SERVERNAME LIKE 'DBSITEC%'
	BEGIN
		SET @Recipients = 'dbaadmin@starixsoft.com'
	END
	ELSE
	BEGIN
		SET @Recipients = 'dba_local@starixsoft.com;qa@starixsoft.com;gary.vu@starixsoft.com;july.nguyen@starixsoft.com'
	END
	
	EXEC  [dbo].[Task_CustWinLimitBet_CheckData_Job] @ErrorMessage = @ErrorMessage OUTPUT

	IF @ErrorMessage <> ''
	BEGIN
		-- Send notification via email
		SET @Subject = 'Data Consistency Potential Winning Limit - CustWinLimitBet Failed !'	
			
		SET @Body = 'SP: Task_CustWinLimitBet_CheckData_Job' + CHAR(13) + CHAR(10)
			+ @ErrorMessage
		
		EXEC msdb.dbo.sp_send_dbmail
				@recipients= @Recipients
				,@body=@Body
				,@sensitivity ='Personal'
				,@importance ='High'
				,@subject =@Subject
				,@body_format = 'TEXT'
				,@profile_name =DEFAULT;

	END
	
END		
GO
