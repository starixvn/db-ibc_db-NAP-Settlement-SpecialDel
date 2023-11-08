/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE [dbo].[Task_SBQueueStatusCheck_EmailNofify]
AS
/*
	Task: Email admins to notify about Service Broker Calculation queue has been disable
	Created: 20150919@Daniel
	Original: 
	Location: DB042, DB052, DB053, DB054, DB06, DBTP, DBLICAPIxx - bodb02

	Revision: 
		- 20180817@Billy:	Add Letstalk notification - [Redmine: #00000]
		- 20181219@Helen:	Apply service broker for othersports - [Redmine: 101611]
		- 20190524@Billy:	Change Letstalk linked server - [Redmine: #113125]
		- 20231026@Louisa: Update email domain from starixvn to starixsoft [Redmine:#195197]
*/
BEGIN;
	-- SEND warning email to DBA
	DECLARE @body VARCHAR(2000), @profile_name SYSNAME

	select 1 from sys.service_queues where name IN ('//Queue/Calculation_receive','Queue_Settlement_OtherSports') AND is_receive_enabled = 0

	IF @@ROWCOUNT = 0 RETURN

	SET @body = '[Service Broker] @'+ @@Servername +': Calculation Queue''s status was DISABLED. Please check urgently!'

	--PRINT @body

	EXEC msdb.dbo.sp_send_dbmail
	@recipients=N'dbaadmin@starixsoft.com',  --20150820 add TWDBA
	--@recipients=N'daniel.truong@starixsoft.com',
	@body=@body,
	@sensitivity ='Personal',
	@importance ='Normal',
	@copy_recipients ='',
	@subject ='Service Broker Alert',
	@profile_name =@profile_name
	
	EXECUTE	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage
				@ServerName	= N'PONTUS'
			,	@JobId		= NULL
			,	@JobName	= N'Custom Message'
			,	@Message	= @body
			,	@CaseId		= 1
			;
END
GO