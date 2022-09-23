/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Settlement_SendEmail @Recipients varchar(1024) = ''
	, @Subject varchar(512) = ''
	, @MessageBody nvarchar(max) = ''
as
/*  Created: Patrick@20210801
	Task: Sending email
	DB: DBTXN-bodb02,SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
		- 20220919@Max: Scale out DBTrans phase 1 [Redemine: #158293]
*/
begin
	set nocount on

	if isnull(@Recipients, '') = ''
	begin
		declare @__enviroment varchar(50)
		exec dbo.NAP_Set_ServerInfo @Environment = @__enviroment OUTPUT
		
		if @__enviroment = 'PROD' OR @@SERVERNAME LIKE 'DBGRP%' 
			set @Recipients = 'dbaadmin@starixvn.com'
		else if @__enviroment = 'SIT' OR @@SERVERNAME LIKE 'SITDBGRP%' 
			set @Recipients = 'pontus@starixvn.com'
		else if @__enviroment = 'DBBAL'
			set @Recipients = 'pontus@starixvn.com'
		else if @__enviroment = 'Local' OR @@SERVERNAME IN ('testdb053\TESTSITEDB')
			set @Recipients = 'kathy.nguyen@starixvn.com'
		else
			set @Recipients = 'pontus@starixvn.com'
	end

	exec msdb.dbo.sp_send_dbmail @recipients = @Recipients
		, @body						= @MessageBody
		, @sensitivity				= 'Personal'
		, @importance				= 'High'
		, @copy_recipients			= ''
		, @blind_copy_recipients	= ''
		, @subject					= @Subject
		, @profile_name				= default
		, @body_format = 'HTML'
	
end
go
