/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
alter procedure dbo.SSB_Settlement_MonitorLogs @MonitorDurationWithInMin int = 120
as
/*  Created: Patrick@20210801
	Task: Sending email
	DB: DBTXN-bodb02,SBSETTLE-bodb02
	Revisions:  
		- 20210801@Patrick: Implement settlement can run parallels [Redmine:#159486]
		- 2022011@Louisa: hardcode job name for DBTrans and SiteDB [Redmine:#182771]
		- 20230113@Kathy: extend errorMessage [Redmine:#182763]
		- 20240710@Kathy: Change instance name [Redmine:#207768]
		- 20250508@Aries: Change instance name DBTRANS [Redmine:#226591]
*/
begin
	set nocount on
	declare @__errorMessage varchar(1024), @__errorMessageTemp varchar(2000), @__fromDate datetime2, @__errorStartTime datetime2
	declare @__errorMessages table(messageId varchar(128), startTime datetime2, endTime datetime2, errorMessage varchar(1024))
	declare @__serverName varchar(100)
			,@__JobName  nvarchar(100)

	select @__fromDate = dateadd(minute, -@MonitorDurationWithInMin, sysdatetime())
	select @__serverName =  @@SERVERNAME

	if @__serverName IN ('DBTRANS', 'DBTRANS\INST2') OR @__serverName LIKE 'DBGRP%' OR @__serverName LIKE 'DBSITEC%'  OR @__serverName LIKE 'SITDBSITEC%'  
	begin
		set @__JobName = 'vndba:Check slowly running or failed processes'
	end
	else
	begin
		set @__JobName = N'bodb02: Check Settlement status'
	end

	insert into @__errorMessages(messageId, startTime, endTime, errorMessage)
	select top(10) MessageId, StartTime, EndTime, ErrorMessage
	from dbo.SSB_SettlementLogs with(nolock)
	where StartTime >= @__fromDate and isnull(Resolved, 0) = 0 
		and ErrorMessage is not null and ErrorMessage <> ''
	order by StartTime desc

	if @@rowcount = 0 --no data
		return
	
	select top(1) @__errorStartTime = startTime, @__errorMessage = errorMessage
	from @__errorMessages order by startTime asc

	begin --++send email to notify for dba check
		declare @email_body nvarchar(max), @subject nvarchar(200)
		set @email_body = '
		   <html>
			 <body>
			  <style>
					table {border-collapse: collapse;}
					table, td, th {border: 1px solid black;text-align: center;}
					th {text-align: left; padding: 8px;}
				</style>
			  <h2> Hey guys, Settlement got errors at ['+convert(varchar(50), @__errorStartTime, 121)+']. Please check logs at dbo.SSB_SettlementLogs table!!!</h2>
			  <p><b>Send time:</b> ' + convert(varchar(50), getdate(), 121) + ' </p> 
			  {<table1>}
			</body>
			</html>'

		declare @table1 varchar(max), @rowData varchar(max)
		set @table1 = '
			<table>
				<tr>
				<th style="text-align:center">MessageId</th>
				<th style="text-align:center">StartTime</th>
				<th style="text-align:center">EndTime</th>
				<th style="text-align:center">Error</th>
				</tr>
				{<row>}
			</table>'

		set @rowData = convert(varchar(max), (
			select MessageId as 'td1'
				, convert(varchar(50), startTime, 121) as 'td2'
				, convert(varchar(50), endTime, 121) as 'td1'
				, errorMessage as 'td2'
			from @__errorMessages t order by startTime
			for xml path('tr'), type
		))

		set @rowData = replace(replace(@rowData, 'td1>', 'td>'), 'td2>', 'td>')
		set @table1 = replace(@table1, '{<row>}', @rowData)
		set @email_body = replace(@email_body, '{<table1>}', @table1)

		select @subject	= N'Settlement - SSB - Notification at ' + @@servername
		--++send email
		exec dbo.SSB_Settlement_SendEmail @Recipients = ''--get email address by enviroment
			, @Subject = @subject
			, @MessageBody = @email_body
	end
	
	begin -- --++letstalk to notify for dba check
		
		set @__errorMessageTemp = 'Hey guys, Settlement got errors at ['+convert(varchar(50), @__errorStartTime, 121)+'] on [' + @@servername + ']. Please check logs at dbo.SSB_SettlementLogs table!!! Err: ' + isnull(@__errorMessage, '???')
		execute	DBNOTI.NotificationDB.dbo.DBA_Letstalk_NewJobMessage @ServerName = @@ServerName
			, @JobId = NULL
			, @JobName = @__JobName
			, @Message = @__errorMessageTemp
			, @CaseId = 1;
	
	end

end
go
